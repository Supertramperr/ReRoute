import Foundation
import SwiftUI
import AppKit

final class AppModel: ObservableObject {

    enum InternetStatus: String, Equatable {
        case online = "Online"
        case offline = "Offline"
    }

    enum Operation: Equatable {
        case idle
        case starting
        case rebooting
        case failed(String)

        var label: String {
            switch self {
            case .idle: return "Idle"
            case .starting: return "Starting…"
            case .rebooting: return "Rebooting"
case .failed: return "Failed"
            }
        }

        var isBusy: Bool {
            switch self {
            case .starting, .rebooting:
                return true
            default:
                return false
            }
        }
    }

    // Settings
    @AppStorage("reroute.routerHost") var routerHost: String = "192.168.1.1"
    @AppStorage("reroute.routerUsername") var routerUsername: String = "admin"
    @AppStorage("reroute.routerPassword") var routerPassword: String = "admin"
    @AppStorage("reroute.askConfirmRebootNow") var askConfirmRebootNow: Bool = true
    @AppStorage("reroute.notifyWhenBack") var notifyWhenBack: Bool = true
    @AppStorage("reroute.openTerminalDebug") var openTerminalDebug: Bool = true

    // UI state
    @Published var internet: InternetStatus = .online
    @Published var operation: Operation = .idle
    @Published var progress: Double = 0.0               // 0..1
    @Published var startingCountdown: Int = 0           // 5..1 during grace
    @Published var lastUpdate: Date? = nil
    @Published var lastReboot: Date? = nil
    @Published var lastError: String? = nil
    @Published var lastSuccessAt: Date? = nil

    // Used by StatusBlock ETA
    @Published var estimatedRebootSeconds: Double = 107
    @Published var progressStartedAt: Date? = nil

    // Internal
    private let startingGraceSeconds: Int = 5
    private let log = AppLog()
    private let router = RouterClient()
    private let internetProbe = InternetProbe()
    private var rebootTask: Task<Void, Never>? = nil
    private var progressTask: Task<Void, Never>? = nil

    init() {
        estimatedRebootSeconds = loadEstimateSeconds()

        internetProbe.onUpdate = { [weak self] isOnline in
            DispatchQueue.main.async {
                guard let self else { return }
                self.internet = isOnline ? .online : .offline
                self.touch()
            }
        }
        internetProbe.start()
    }

    func touch() { lastUpdate = Date() }

    func cancel() {
        guard operation == .starting else { return }
        log.write("CANCEL requested by user")

        rebootTask?.cancel()
        progressTask?.cancel()
        rebootTask = nil
        progressTask = nil

        DispatchQueue.main.async {
            self.operation = .idle
            self.startingCountdown = 0
            self.progress = 0.0
            self.progressStartedAt = nil
            self.lastError = nil
            self.touch()
        }
    }

    func rebootNow(debugMode: Bool) {
        guard operation.isBusy == false else { return }

        lastError = nil
        DispatchQueue.main.async {
            self.operation = .starting
            self.startingCountdown = self.startingGraceSeconds
            self.progress = 0.0
            self.progressStartedAt = nil
            self.touch()
        }

        if debugMode && openTerminalDebug {
            TerminalHelper.openTail(logFilePath: log.filePath)
        }

        rebootTask?.cancel()
        rebootTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.runReboot(debugMode: debugMode)
        }
    }

    private func runReboot(debugMode: Bool) async {
        do {
            log.write("START (debug=\(debugMode))")

            // Grace countdown: 5..1. No progress movement here.
            try try await graceCountdown(seconds: startingGraceSeconds)
            try Task.checkCancellation()

            let host = routerHost.trimmingCharacters(in: .whitespacesAndNewlines)
            let user = routerUsername
            let pass = routerPassword

            // Commit phase begins: hide cancel + switch to rebooting
            await MainActor.run {
                self.startingCountdown = 0
                self.operation = .rebooting
                self.progress = 0.0
                self.progressStartedAt = nil
                self.touch()
            }

            log.write("GET / (login page)")
            let loginKey = try await router.fetchLoginSessionKey(host: host)
            log.write("loginKey=\(loginKey)")

            log.write("POST postlogin.cgi")
            try await router.login(host: host, loginKey: loginKey, username: user, password: pass)

            log.write("GET securite-pb1-motdepasse.html (auth key)")
            let authKey = try await router.fetchAuthenticatedSessionKey(host: host)
            log.write("authKey=\(authKey)")

            log.write("POST rebootinfo.cgi")
            try await router.reboot(host: host, sessionKey: authKey)

            let postAt = Date()
            await MainActor.run {
                self.progress = 0.0
                self.progressStartedAt = postAt
                self.touch()
            }

            startLinearProgress(from: postAt)
            log.write("monitoring ping+wan")
            let result = try await monitorReboot(host: host)

            // Success
            let measured = Date().timeIntervalSince(postAt)
            updateEstimateSeconds(with: measured)

            await MainActor.run {
                self.progressTask?.cancel()
                self.progressTask = nil

                self.progress = 1.0
                self.operation = .idle
                self.lastReboot = Date()
                self.lastSuccessAt = Date()
                self.lastError = nil
                self.progressStartedAt = nil
                self.touch()
            }

            scheduleProgressResetIfIdle(after: 5)

            if notifyWhenBack {
                NotificationHelper.notify(
                    title: "Internet is back",
                    body: "ReRoute confirmed WAN up (routerUp=\(result.routerUp), wanUp=\(result.wanUp))."
                )
            }

        } catch is CancellationError {
            log.write("CANCELLED")
            await MainActor.run {
                self.progressTask?.cancel()
                self.progressTask = nil

                self.operation = .idle
                self.startingCountdown = 0
                self.progress = 0.0
                self.progressStartedAt = nil
                self.touch()
            }
        } catch {
            log.write("ERROR: \(error.localizedDescription)")
            await MainActor.run {
                self.progressTask?.cancel()
                self.progressTask = nil

                self.operation = .failed(error.localizedDescription)
                self.lastError = error.localizedDescription
                self.startingCountdown = 0
                self.progress = 0.0
                self.progressStartedAt = nil
                self.touch()
            }
            NotificationHelper.notify(title: "Router reboot failed", body: error.localizedDescription)
        }

        rebootTask = nil
    }

    private func graceCountdown(seconds: Int) async throws {
        await MainActor.run {
            self.operation = .starting
            self.startingCountdown = seconds
            self.progress = 0.0
            self.progressStartedAt = nil
            self.touch()
        }

        guard seconds > 0 else { return }

        for remaining in stride(from: seconds, to: 0, by: -1) {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { throw CancellationError() }
            await MainActor.run {
                self.startingCountdown = max(0, remaining - 1)
                self.touch()
            }
        }
    }


    private func startLinearProgress(from start: Date) {
        progressTask?.cancel()
        let total = max(30.0, min(240.0, estimatedRebootSeconds))
        let maxWait = 240.0

        progressTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(start)

                // Phase 1: 0% -> 95% over the estimated duration.
                // Phase 2: 95% -> 99% over the remaining maxWait window (so it never "stalls" visually).
                let p: Double
                if elapsed <= total {
                    let r = min(max(elapsed / total, 0), 1)
                    p = r * 0.95
                } else {
                    let tail = max(1.0, maxWait - total)
                    let r = min(max((elapsed - total) / tail, 0), 1)
                    p = 0.95 + r * 0.04
                }

                await MainActor.run {
                    if self.operation.isBusy {
                        self.progress = min(max(p, 0), 0.99)
                        self.touch()
                    }
                }

                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }


    private struct MonitorResult {
        let routerDown: Bool
        let routerUp: Bool
        let wanDown: Bool
        let wanUp: Bool
    }

    
    private func routerReachable(host: String) async -> Bool {
        guard let url = URL(string: "http://\(host)/") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 1.2
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse) != nil
        } catch {
            return false
        }
    }

private func monitorReboot(host: String) async throws -> MonitorResult {
        let maxSeconds = 240
        var routerDown = false
        var routerUp = false
        var wanDown = false
        var wanUp = false

        for i in 0..<maxSeconds {
            try Task.checkCancellation()

            // Router ping
            let rOK = await self.routerReachable(host: host)
            if !routerDown && !rOK {
                routerDown = true
                log.write("ROUTER_DOWN at i=\(i)")
            }
            if routerDown && !routerUp && rOK {
                routerUp = true
                log.write("ROUTER_UP at i=\(i)")
}

            // WAN probe
            let wOK = await wanIsUp()
            if !wanDown && !wOK {
                wanDown = true
                log.write("WAN_DOWN at i=\(i)")
            }
            if wanDown && !wanUp && wOK {
                wanUp = true
                log.write("WAN_UP at i=\(i)")
            }

            if routerDown && routerUp && wanUp {
                log.write("DONE (confirmed=true) routerDown=true routerUp=true wanUp=true")
                return MonitorResult(routerDown: routerDown, routerUp: routerUp, wanDown: wanDown, wanUp: wanUp)
            }

            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }

        log.write("DONE (confirmed=false)")
        throw NSError(domain: "ReRoute", code: 1, userInfo: [NSLocalizedDescriptionKey: "Timeout waiting for router/WAN to return"])
    }

    private func wanIsUp() async -> Bool {
        guard let url = URL(string: "http://clients3.google.com/generate_204") else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 3

        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse {
                return (200...399).contains(http.statusCode)
            }
            return false
        } catch {
            return false
        }
    }

    private func scheduleProgressResetIfIdle(after seconds: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            if self.operation.isBusy == false && self.progress >= 0.999 {
                self.progress = 0.0
                self.progressStartedAt = nil
                self.touch()
            }
        }
    }

    func openRouterUI() {
        guard let url = URL(string: "http://\(routerHost)/") else { return }
        NSWorkspace.shared.open(url)
    }

    func openLog() {
        let url = URL(fileURLWithPath: log.filePath)
        NSWorkspace.shared.open(url)
    }

    func openSettingsWindow() {
        Task { @MainActor in
            WindowManager.shared.showSettings(model: self)
        }
    }

    func openAboutWindow() {
        Task { @MainActor in
            WindowManager.shared.showAbout()
        }
    }

    func copyDiagnostics() {
        let text = """
        Router host: \(routerHost)
        Internet: \(internet.rawValue)
        Operation: \(operation.label)
        Progress: \(Int((progress * 100).rounded()))%
        Last reboot: \(lastReboot?.description ?? "n/a")
        Error: \(lastError ?? "n/a")
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    var menuSymbolName: String {
        if let t = lastSuccessAt, Date().timeIntervalSince(t) < 5.0 {
            return "checkmark.circle"
        }

        switch operation {
        case .starting:
            return "hourglass"
        case .rebooting:
            return "arrow.clockwise"
case .failed:
            return "exclamationmark.triangle"
        case .idle:
            return internet == .online ? "wifi" : "wifi.slash"
        }
    }

    private var Key_rebootEMA: String { "reroute.rebootEMASeconds" }

    private func loadEstimateSeconds() -> Double {
        let v = UserDefaults.standard.double(forKey: Key_rebootEMA)
        return v > 0 ? v : 107.0
    }

    private func updateEstimateSeconds(with measured: Double) {
        let clamped = max(30.0, min(240.0, measured))
        let prev = loadEstimateSeconds()
        let alpha = 0.20
        let next = alpha * clamped + (1.0 - alpha) * prev
        UserDefaults.standard.set(next, forKey: Key_rebootEMA)

        DispatchQueue.main.async {
            self.estimatedRebootSeconds = next
            self.touch()
        }
    }
}

private extension AppModel.InternetStatus {
    var isOnline: Bool { self == .online }
}
