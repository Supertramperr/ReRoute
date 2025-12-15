import SwiftUI
import AppKit

struct AboutView: View {
    @StateObject private var windowRef = WindowReference()

    private let cornerRadius: CGFloat = 20

    // Adjust About window size here
    private let windowSize = CGSize(width: 280, height: 280)

    var body: some View {
        ZStack {
            WindowAccessor { w in windowRef.window = w }

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(liquidGlassRim)

            VStack(spacing: 10) {
                // Title row (traffic lights + title)
                HStack(spacing: 10) {
                    TrafficLights(window: { windowRef.window }, closeAction: closeWindow)

                    Text("About ReRoute")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()
                }
                .padding(.top, 2)

                Spacer(minLength: 2)

                // Centered content
                VStack(spacing: 10) {
                    Image(systemName: "wifi.router")
                        .font(.system(size: 46, weight: .semibold))
                        .opacity(0.92)

                    Text("ReRoute")
                        .font(.system(size: 18, weight: .semibold)) // keep current size intent

                    Text("⌘R Reboot · ⌘, Settings · ⌘L Log")
                        .font(.system(size: 11))
                        .opacity(0.78)

                    Text("Version \(appVersionString())")
                        .font(.system(size: 11))
                        .opacity(0.72)
                        .padding(.top, 2)

                    Text("Copyright © Sun Keynar")
                        .font(.system(size: 11))
                        .opacity(0.72)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Spacer(minLength: 8)
            }
            .padding(14)
        }
        .frame(width: windowSize.width, height: windowSize.height, alignment: .topLeading)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear { DispatchQueue.main.async { windowRef.window?.makeFirstResponder(nil) } }
    }

    private func appVersionString() -> String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return v ?? "1.0"
    }

    private func closeWindow() {
        guard let w = windowRef.window else { return }
        w.orderOut(nil)
        w.close()
    }

    private var liquidGlassRim: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.26),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [ Color.white.opacity(0.22), Color.clear ],
                        startPoint: .topLeading,
                        endPoint: .center
                    ),
                    lineWidth: 1
                )
                .blendMode(.screen)
                .opacity(0.7)
        }
        .allowsHitTesting(false)
    }
}

private final class WindowReference: ObservableObject { weak var window: NSWindow? }

private struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { self.onResolve(v.window) }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { self.onResolve(nsView.window) }
    }
}

private struct TrafficLights: View {
    let window: () -> NSWindow?
    let closeAction: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(spacing: 7) {
            Light(color: .red, symbol: "xmark", showSymbol: hover) { closeAction() }
            Light(color: .yellow, symbol: "minus", showSymbol: hover) { window()?.miniaturize(nil) }

            // Grey disabled green (as requested earlier)
            Circle()
                .fill(Color.gray.opacity(0.35))
                .frame(width: 12, height: 12)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5))
        }
        .onHover { hover = $0 }
    }

    private struct Light: View {
        let color: Color
        let symbol: String
        let showSymbol: Bool
        let action: () -> Void
        var body: some View {
            Button(action: action) {
                ZStack {
                    Circle().fill(color).frame(width: 12, height: 12)
                    if showSymbol {
                        Image(systemName: symbol)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.black.opacity(0.65))
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}
