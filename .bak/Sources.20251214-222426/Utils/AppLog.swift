import Foundation

final class AppLog {
    private let url: URL

    init() {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let d = dir.appendingPathComponent("router-reboot", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        self.url = d.appendingPathComponent("run.log")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? Data().write(to: url)
        }
    }

    var filePath: String { url.path }

    func write(_ line: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let out = "\(stamp) \(line)\n"
        if let data = out.data(using: .utf8) {
            if let fh = try? FileHandle(forWritingTo: url) {
                try? fh.seekToEnd()
                try? fh.write(contentsOf: data)
                try? fh.close()
            }
        }
    }
}
