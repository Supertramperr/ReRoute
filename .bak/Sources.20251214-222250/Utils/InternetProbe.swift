import Foundation

final class InternetProbe {
    var onUpdate: ((Bool) -> Void)?

    private var timer: DispatchSourceTimer?
    private let session: URLSession
    private var last: Bool?

    // Strict connectivity check:
    // Online ONLY if this returns HTTP 204 (anything else = captive portal / offline / intercepted).
    private let url = URL(string: "https://clients3.google.com/generate_204")!

    init() {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.urlCache = nil
        cfg.httpShouldSetCookies = false
        cfg.timeoutIntervalForRequest = 2.5
        cfg.timeoutIntervalForResource = 2.5
        self.session = URLSession(configuration: cfg)
    }

    func start(interval: TimeInterval = 2.0) {
        stop()
        let t = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        t.schedule(deadline: .now(), repeating: interval)
        t.setEventHandler { [weak self] in
            self?.tick()
        }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        Task { [weak self] in
            guard let self else { return }
            let ok = await self.checkOnce()
            if self.last != ok {
                self.last = ok
                self.onUpdate?(ok)
            }
        }
    }

    private func checkOnce() async -> Bool {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 2.5

        do {
            let (_, resp) = try await session.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            return code == 204
        } catch {
            return false
        }
    }
}
