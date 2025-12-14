import SwiftUI
import AppKit

struct AboutView: View {
    @StateObject private var windowRef = WindowReference()

    private let cornerRadius: CGFloat = 20
    private let contentPadding = EdgeInsets(top: 10, leading: 16, bottom: 14, trailing: 16)

    var body: some View {
        ZStack {
            WindowAccessor { w in windowRef.window = w }

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(liquidGlassRim)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    TrafficLights(window: { windowRef.window }, closeAction: closeWindow)

                    Text("About ReRoute")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Spacer()
                }

                Divider().opacity(0.5)

                HStack(spacing: 14) {
                    Image(systemName: "wifi.router")
                        .font(.system(size: 34, weight: .semibold))
                        .opacity(0.92)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("ReRoute")
                            .font(.system(size: 18, weight: .semibold))

                        Text("Menu bar router reboot + verify")
                            .font(.system(size: 12))
                            .opacity(0.85)

                        Text("⌘R Reboot · ⌘, Settings · ⌘L Log")
                            .font(.system(size: 11))
                            .opacity(0.72)
                            .padding(.top, 2)
                    }

                    Spacer()
                }
                .padding(.top, 2)

                Spacer(minLength: 0)

                HStack {
                    Spacer()
                    Button("Done") { closeWindow() }
                        .buttonStyle(GlassPrimaryButtonStyle())
                }
                .padding(.trailing, 2)
                .padding(.bottom, 2)
            }
            .padding(contentPadding)
        }
        .frame(width: 420, height: 200, alignment: .topLeading)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear { DispatchQueue.main.async { windowRef.window?.makeFirstResponder(nil) } }
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

            // Disabled/grey green (like your reference)
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

private struct GlassPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.vertical, 7)
            .padding(.horizontal, 14)
            .background(Color.white.opacity(configuration.isPressed ? 0.18 : 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
    }
}
