import SwiftUI

struct MenuBarIconView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let symbol = symbolName()
        Image(systemName: symbol)
            .symbolRenderingMode(.hierarchical)
            .rotationEffect(model.operation.isRunning ? .degrees(model.progress * 360.0) : .degrees(0))
            .animation(model.operation.isRunning ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default,
                       value: model.operation.isRunning)
            .help(tooltip())
            .frame(width: 18, height: 18)
    }

    private func tooltip() -> String {
        let pct = Int((model.progress * 100).rounded())
        return "Internet: \(model.internet.rawValue)\nOperation: \(model.operation.label)\nProgress: \(pct)%"
    }

    private func symbolName() -> String {
        // Priority: operation first, then internet
        switch model.operation {
        case .starting, .rebooting:
            return "arrow.clockwise"
        case .verifying:
            return "antenna.radiowaves.left.and.right"
        case .failed:
            return "exclamationmark.triangle"
        case .cancelled:
            return "xmark.circle"
        case .idle:
            return (model.internet == .offline) ? "wifi.slash" : "wifi"
        }
    }
}
