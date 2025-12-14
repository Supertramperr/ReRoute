import Foundation

enum PingProbe {
    static func pingOnce(host: String, timeoutMs: Int = 1000) async -> Bool {
        await Task.detached(priority: .utility) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/sbin/ping")
            // macOS: -n numeric, -c 1 one packet, -W wait ms (per reply)
            p.arguments = ["-n", "-c", "1", "-W", "\(timeoutMs)", host]

            let devNull = FileHandle.nullDevice
            p.standardOutput = devNull
            p.standardError = devNull

            do {
                try p.run()
                p.waitUntilExit()
                return p.terminationStatus == 0
            } catch {
                return false
            }
        }.value
    }
}
