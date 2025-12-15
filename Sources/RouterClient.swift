import Foundation

final class RouterClient {

    enum RouterError: LocalizedError {
        case invalidHost
        case loginKeyNotFound
        case authKeyNotFound
        case curlFailed(Int, String)
        case rebootRejected(String)

        var errorDescription: String? {
            switch self {
            case .invalidHost: return "Invalid router host."
            case .loginKeyNotFound: return "Failed to extract login session key."
            case .authKeyNotFound: return "Failed to extract authenticated session key."
            case .curlFailed(let code, let msg): return "curl failed (\(code)): \(msg)"
            case .rebootRejected(let head): return "reboot rejected (got login page). head=\(head)"
            }
        }
    }

    private let cookieJarURL: URL
    private let fm = FileManager.default

    init() {
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("router-reboot", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        cookieJarURL = dir.appendingPathComponent("curl-\(UUID().uuidString).cookies")
        try? fm.removeItem(at: cookieJarURL)
    }

    deinit {
        try? fm.removeItem(at: cookieJarURL)
    }

    // MARK: - Public API (same signatures AppModel expects)

    func fetchLoginSessionKey(host: String) async throws -> String {
        let host = try normalizeHost(host)
        let html = try await curlGET("http://\(host)/", maxTime: 8)
        if let k = extractVarSessionKey(html) { return k }
        throw RouterError.loginKeyNotFound
    }

    func login(host: String, loginKey: String, username: String, password: String) async throws {
        let host = try normalizeHost(host)
        let base = "http://\(host)"
        let url = "\(base)/postlogin.cgi?sessionKey=\(loginKey)"
        let body = "sessionKey=\(loginKey)&loginUsername=\(urlEncode(username))&loginPassword=\(urlEncode(password))"
        _ = try await curlPOST(url,
                              body: body,
                              headers: [
                                "Origin: \(base)",
                                "Referer: \(base)/"
                              ],
                              maxTime: 12)
    }

    func fetchAuthenticatedSessionKey(host: String) async throws -> String {
        let host = try normalizeHost(host)
        // Use the exact page you used manually.
        let html = try await curlGET("http://\(host)/securite-pb1-motdepasse.html", maxTime: 8)
        if let k = extractVarSessionKey(html) { return k }
        throw RouterError.authKeyNotFound
    }

    func reboot(host: String, sessionKey: String) async throws {
        let host = try normalizeHost(host)
        let base = "http://\(host)"
        let url = "\(base)/rebootinfo.cgi?sessionKey=\(sessionKey)"
        let body = "sessionKey=\(sessionKey)"

        let html = try await curlPOST(url,
                                      body: body,
                                      headers: [
                                        "Origin: \(base)",
                                        "Referer: \(base)/securite-pb1-motdepasse.html"
                                      ],
                                      maxTime: 15)

        // If not authenticated, routers often return the login form (still 200).
        let lower = html.lowercased()
        if lower.contains("postlogin.cgi") || lower.contains("loginusername") || lower.contains("value=\"login\"") {
            let head = String(html.prefix(240))
            throw RouterError.rebootRejected(head)
        }
    }

    // MARK: - curl helpers

    private func curlGET(_ url: String, maxTime: Int) async throws -> String {
        try await runCurl([
            "-fsS",
            "--max-time", "\(maxTime)",
            "-c", cookieJarURL.path,
            "-b", cookieJarURL.path,
            "-H", "User-Agent: ReRoute",
            url
        ])
    }

    private func curlPOST(_ url: String, body: String, headers: [String], maxTime: Int) async throws -> String {
        var args: [String] = [
            "-fsS",
            "--max-time", "\(maxTime)",
            "-c", cookieJarURL.path,
            "-b", cookieJarURL.path,
            "-H", "User-Agent: ReRoute",
            "-H", "Content-Type: application/x-www-form-urlencoded"
        ]
        for h in headers { args += ["-H", h] }
        args += ["-d", body, url]
        return try await runCurl(args)
    }

    private func runCurl(_ args: [String]) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
            p.arguments = args

            let out = Pipe()
            let err = Pipe()
            p.standardOutput = out
            p.standardError = err

            try p.run()
            p.waitUntilExit()

            let outData = out.fileHandleForReading.readDataToEndOfFile()
            let errData = err.fileHandleForReading.readDataToEndOfFile()

            let stdout = String(data: outData, encoding: .utf8) ?? ""
            let stderr = String(data: errData, encoding: .utf8) ?? ""

            if p.terminationStatus != 0 {
                throw RouterError.curlFailed(Int(p.terminationStatus), stderr.isEmpty ? stdout : stderr)
            }
            return stdout
        }.value
    }

    // MARK: - parsing / utilities

    private func extractVarSessionKey(_ html: String) -> String? {
        let pattern = #"var\s+sessionkey\s*=\s*['"]([0-9]+)['"]"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let m = re.firstMatch(in: html, options: [], range: range),
              m.numberOfRanges >= 2,
              let r = Range(m.range(at: 1), in: html) else { return nil }
        return String(html[r])
    }

    private func normalizeHost(_ host: String) throws -> String {
        let h = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.isEmpty { throw RouterError.invalidHost }
        // Accept "192.168.1.1" only; strip scheme if user pasted it.
        if h.hasPrefix("http://") { return String(h.dropFirst("http://".count)).trimmingCharacters(in: CharacterSet(charactersIn: "/")) }
        if h.hasPrefix("https://") { return String(h.dropFirst("https://".count)).trimmingCharacters(in: CharacterSet(charactersIn: "/")) }
        return h.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func urlEncode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }
}
