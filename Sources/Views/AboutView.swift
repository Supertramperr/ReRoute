import SwiftUI
import AppKit

struct AboutView: View {
        private let contentYOffset: CGFloat = -100

@StateObject private var windowRef = WindowReference()

    private let cornerRadius: CGFloat = 20
    private let contentPadding = EdgeInsets(top: 8, leading: 16, bottom: 14, trailing: 16)

    private var versionString: String {
        let v = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
        return "Version \(v)"
    }

    var body: some View {
        ZStack {
            WindowAccessor { w in
                windowRef.window = w
            }

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(liquidGlassRim)

            VStack(alignment: .leading, spacing: 12) {
                // Header row (same styling as Settings)
                HStack(spacing: 10) {
                    TrafficLights(
                        window: { windowRef.window },
                        closeAction: closeWindow
                    )

                    Text("About")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Spacer()
                }
                .padding(.top, 2)

                Divider().opacity(0.5)

                // Centered content
                VStack(spacing: 10) {
                    AboutLogoMark()
                        .frame(width: 64, height: 64)
                        .accessibilityHidden(true)

                    Text("ReRoute")
                        .font(.system(size: 22, weight: .semibold))

                    Text("⌘R Reboot · ⌘, Settings · ⌘L Log")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .opacity(0.78)

                    Text(versionString)
                        .font(.system(size: 12, weight: .regular))
                        .opacity(0.72)

                    Text("Copyright © Sun Keynar")
                        .font(.system(size: 12, weight: .regular))
                        .opacity(0.70)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.top, 2)
            }
            .padding(contentPadding)
        }
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear {
            DispatchQueue.main.async {
                windowRef.window?.makeFirstResponder(nil)
            }
        }
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

// MARK: - Logo (remove extra wifi icon)
private struct AboutLogoMark: View {
    var body: some View {
        Image(systemName: "wifi.router")
            .font(.system(size: 40, weight: .semibold))
            .opacity(0.95)
    }
}

// MARK: - Window plumbing (same approach as Settings)
private final class WindowReference: ObservableObject {
    weak var window: NSWindow?
}

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

// MARK: - Traffic lights (match Settings: green disabled)
private struct TrafficLights: View {
    let window: () -> NSWindow?
    let closeAction: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(spacing: 7) {
            Light(color: .red, symbol: "xmark", showSymbol: hover) {
                closeAction()
            }

            Light(color: .yellow, symbol: "minus", showSymbol: hover) {
                window()?.miniaturize(nil)
            }

            DisabledGreenLight()
        }
        .onHover { hover = $0 }
    }

    private struct DisabledGreenLight: View {
        var body: some View {
            Circle()
                .fill(Color.gray.opacity(0.35))
                .frame(width: 12, height: 12)
                .overlay(
                    Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5)
                )
        }
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
