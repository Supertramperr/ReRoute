import Foundation

final class RouterClient {

    enum RouterError: LocalizedError {
        case invalidURL
        case loginKeyNotFound
        case authKeyNotFound
        case httpStatus(Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid router URL."
            case .loginKeyNotFound: return "Failed to extract login session key."
            case .authKeyNotFound: return "Failed to extract authenticated session key."
            case .httpStatus(let s): return "Router returned HTTP \(s)."
            }
        }
    }

    private let session: URLSession

    init() {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.waitsForConnectivity = false
        cfg.timeoutIntervalForRequest = 12
        cfg.timeoutIntervalForResource = 12
        cfg.httpShouldSetCookies = true
        cfg.httpCookieAcceptPolicy = .always
        cfg.httpCookieStorage = HTTPCookieStorage()
        self.session = URLSession(configuration: cfg)
    }

    // MARK: - Public

    func fetchLoginSessionKey(host: String) async throws -> String {
        let (data, resp) = try await get(host: host, path: "/")
        try ensureOK(resp)
        let html = decodeHTML(data)
        if let key = Regexes.varSessionKey.firstMatch(in: html) { return key }
        throw RouterError.loginKeyNotFound
    }

    func login(host: String, loginKey: String, username: String, password: String) async throws {
        let path = "/postlogin.cgi"
        let query = ["sessionKey": loginKey]
        let body = FormEncoder.encode([
            "sessionKey": loginKey,
            "loginUsername": username,
            "loginPassword": password
        ])
        let (_, resp) = try await post(host: host, path: path, query: query, body: body, referer: nil)
        try ensureOK(resp)
    }

    func fetchAuthenticatedSessionKey(host: String) async throws -> String {
        // Pages that are usually reachable post-login and often embed the session key.
        let candidates = [
            "/securite-pb1-motdepasse.html",
            "/securite.html",
            "/wifi.html",
            "/reseau.html",
            "/telephonie.html",
            "/config.html"
        ]

        for p in candidates {
            do {
                let (data, resp) = try await get(host: host, path: p)
                if (200..<400).contains(resp.statusCode) == false { continue }

                // 1) SessionKey in final URL (redirects etc)
                let finalURL = resp.url?.absoluteString ?? ""
                if let key = Regexes.sessionKeyParam.firstMatch(in: finalURL) { return key }

                // 2) SessionKey embedded in HTML
                let html = decodeHTML(data)
                if let key = Regexes.varSessionKey.firstMatch(in: html) { return key }                // var sessionkey='...'
                if let key = Regexes.sessionKeyParam.firstMatch(in: html) { return key }             // sessionKey=123
                if let key = Regexes.hiddenInputSessionKey.firstMatch(in: html) { return key }       // <input ... value=123>
            } catch {
                continue
            }
        }

        throw RouterError.authKeyNotFound
    }




    func reboot(host: String, sessionKey: String) async throws {
        let base = "http://\(host)"

        guard let rebootURL = URL(string: "\(base)/rebootinfo.cgi?sessionKey=\(sessionKey)") else {
            throw NSError(domain: "ReRoute", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid reboot URL"])
        }

        graceLog("POST rebootinfo.cgi")

        var req = URLRequest(url: rebootURL)
        req.httpMethod = "POST"
        req.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        req.timeoutInterval = 15

        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        // Important: include sessionKey in referer (matches what these firmwares expect)
        req.setValue("\(base)/securite-pb1-motdepasse.html?sessionKey=\(sessionKey)", forHTTPHeaderField: "Referer")
        req.setValue(base, forHTTPHeaderField: "Origin")
        req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        req.setValue("ReRoute", forHTTPHeaderField: "User-Agent")

        req.httpBody = "sessionKey=\(sessionKey)".data(using: .utf8)

        let (data, r) = try await session.data(for: req)
        guard let resp = r as? HTTPURLResponse else { throw RouterError.httpStatus(0) }

        let text = decodeHTML(data)
        let head = String(text.prefix(260))
        graceLog("rebootinfo http=\(resp.statusCode) head=\(head)")

        if resp.statusCode != 200 {
            throw NSError(domain: "ReRoute", code: resp.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "rebootinfo.cgi http=\(resp.statusCode) head=\(head)"])
        }

        // If we got the login page back, reboot wasn't accepted.
        let lower = text.lowercased()
        if lower.contains("postlogin.cgi") || lower.contains("loginusername") || lower.contains("value=\"login\"") {
            throw NSError(domain: "ReRoute", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "reboot rejected (got login page). head=\(head)"])
        }

        // Some firmwares require a follow-up hit on reboot.cgi referenced in the returned HTML/JS.
        func normalizeCandidate(_ raw: String) -> URL? {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { return nil }

            let abs: String
            if t.lowercased().hasPrefix("http") { abs = t }
            else if t.hasPrefix("/") { abs = base + t }
            else { abs = base + "/" + t }

            guard var u = URL(string: abs) else { return nil }

            let hasKey = URLComponents(url: u, resolvingAgainstBaseURL: false)?
                .queryItems?
                .contains(where: { $0.name.lowercased() == "sessionkey" }) ?? false

            if !hasKey {
                var c = URLComponents(url: u, resolvingAgainstBaseURL: false)
                var items = c?.queryItems ?? []
                items.append(URLQueryItem(name: "sessionKey", value: sessionKey))
                c?.queryItems = items
                if let nu = c?.url { u = nu }
            }
            return u
        }

        var candidates: [URL] = []

        if let re = try? NSRegularExpression(pattern: #"reboot\.cgi[^'"<\s]*"#, options: [.caseInsensitive]) {
            let ns = text as NSString
            let range = NSRange(location: 0, length: ns.length)
            for m in re.matches(in: text, options: [], range: range) {
                let raw = ns.substring(with: m.range)
                if let u = normalizeCandidate(raw) { candidates.append(u) }
            }
        }

        // Hard fallbacks
        if let u = normalizeCandidate("/reboot.cgi?sessionKey=\(sessionKey)") { candidates.append(u) }
        if let u = normalizeCandidate("/reboot.cgi") { candidates.append(u) }

        // de-dup preserving order
        var seen = Set<String>()
        candidates = candidates.filter { seen.insert($0.absoluteString).inserted }

        for u in candidates {
            // Try POST first (closest to what router UIs do)
            do {
                graceLog("TRIGGER POST \(u.path)")
                var r = URLRequest(url: u)
                r.httpMethod = "POST"
                r.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
                r.timeoutInterval = 6
                r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                r.setValue(rebootURL.absoluteString, forHTTPHeaderField: "Referer")
                r.setValue(base, forHTTPHeaderField: "Origin")
                r.httpBody = "sessionKey=\(sessionKey)".data(using: .utf8)
                _ = try await session.data(for: r)
            } catch { }

            // Then GET as a fallback
            do {
                graceLog("TRIGGER GET \(u.path)")
                var r = URLRequest(url: u)
                r.httpMethod = "GET"
                r.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
                r.timeoutInterval = 6
                r.setValue(rebootURL.absoluteString, forHTTPHeaderField: "Referer")
                r.setValue(base, forHTTPHeaderField: "Origin")
                _ = try await session.data(for: r)
            } catch { }
        }
    }




    func waitForDown(host: String, timeoutSeconds: Int, onProgress: @escaping (Double) -> Void) async throws -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < Double(timeoutSeconds) {
            try Task.checkCancellation()
            let frac = min(1.0, Date().timeIntervalSince(start) / Double(timeoutSeconds))
            onProgress(frac)

            let ok = await isRouterReachable(host: host)
            if !ok { return true }
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        return false
    }

    func waitForUp(host: String, timeoutSeconds: Int, onProgress: @escaping (Double) -> Void) async throws -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < Double(timeoutSeconds) {
            try Task.checkCancellation()
            let frac = min(1.0, Date().timeIntervalSince(start) / Double(timeoutSeconds))
            onProgress(frac)

            let ok = await isRouterReachable(host: host)
            if ok { return true }
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        return false
    }

    // MARK: - Helpers

    private func decodeHTML(_ data: Data) -> String {
        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .isoLatin1) { return s }
        return String(decoding: data, as: UTF8.self)
    }

    private func isRouterReachable(host: String) async -> Bool {
        do {
            let (_, resp) = try await get(host: host, path: "/", timeout: 2)
            return (200..<400).contains(resp.statusCode)
        } catch {
            return false
        }
    }

    // MARK: - HTTP

    private func url(host: String, path: String, query: [String: String]? = nil) throws -> URL {
        var comps = URLComponents()
        comps.scheme = "http"
        comps.host = host
        comps.path = path
        if let query {
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let u = comps.url else { throw RouterError.invalidURL }
        return u
    }

    private func ensureOK(_ resp: HTTPURLResponse) throws {
        if (200..<400).contains(resp.statusCode) { return }
        throw RouterError.httpStatus(resp.statusCode)
    }

    private func get(host: String, path: String, timeout: TimeInterval = 10) async throws -> (Data, HTTPURLResponse) {
        let u = try url(host: host, path: path)
        var req = URLRequest(url: u)
        req.httpMethod = "GET"
        req.timeoutInterval = timeout
        req.setValue("text/html,*/*;q=0.8", forHTTPHeaderField: "Accept")
        let (data, r) = try await session.data(for: req)
        guard let resp = r as? HTTPURLResponse else { throw RouterError.httpStatus(0) }
        return (data, resp)
    }

    private func post(host: String, path: String, query: [String: String], body: Data, referer: String?) async throws -> (Data, HTTPURLResponse) {
        let u = try url(host: host, path: path, query: query)
        var req = URLRequest(url: u)
        req.httpMethod = "POST"
        req.httpBody = body
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if let referer { req.setValue(referer, forHTTPHeaderField: "Referer") }
        req.setValue("text/html,*/*;q=0.8", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 20
        let (data, r) = try await session.data(for: req)
        guard let resp = r as? HTTPURLResponse else { throw RouterError.httpStatus(0) }
        return (data, resp)
    }
}

enum Regexes {
    // Matches: var sessionkey = '760547835';
    static let varSessionKey = RegexHelper(pattern: #"var\s+sessionkey\s*=\s*['"]([0-9]+)['"]"#)

    // Matches: sessionKey=2086302005 (in URLs or HTML)
    static let sessionKeyParam = RegexHelper(pattern: #"sessionKey=([0-9]+)"#)

    // Matches: <input name="sessionKey" value="123">
    static let hiddenInputSessionKey = RegexHelper(pattern: #"name=["']sessionKey["'][^>]*value=["']?([0-9]+)"#)
}

struct RegexHelper {
    let regex: NSRegularExpression

    init(pattern: String) {
        self.regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    func firstMatch(in text: String) -> String? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let m = regex.firstMatch(in: text, options: [], range: range),
              m.numberOfRanges >= 2,
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }
}

enum FormEncoder {
    static func encode(_ dict: [String: String]) -> Data {
        let s = dict.map { k, v in
            "\(urlEncode(k))=\(urlEncode(v))"
        }.joined(separator: "&")
        return Data(s.utf8)
    }

    private static func urlEncode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }
}



private func graceLog(_ msg: String) {
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let line = "\(iso.string(from: Date())) GRACE " + msg + "\n"
    let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    let logURL = dir.appendingPathComponent("router-reboot").appendingPathComponent("run.log")
    try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    if let data = line.data(using: .utf8) {
        if let h = try? FileHandle(forWritingTo: logURL) {
            try? h.seekToEnd()
            try? h.write(contentsOf: data)
            try? h.close()
        } else {
            try? data.write(to: logURL, options: .atomic)
        }
    }
}

