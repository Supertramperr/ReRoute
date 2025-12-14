import Foundation

enum TerminalHelper {
    static func openTail(logFilePath: String) {
        // Open Terminal and run: tail -f "<log>"
        // Best-effort; if Terminal automation is blocked, it fails silently.
        let escaped = logFilePath.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
          activate
          do script "tail -f \\"\(escaped)\\""
        end tell
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        try? p.run()
    }
}
