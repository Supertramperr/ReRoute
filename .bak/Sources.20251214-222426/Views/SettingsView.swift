import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var showPassword = false

    @StateObject private var windowRef = WindowReference()

    private enum Field { case host, user, pass }
    @FocusState private var focused: Field?

    private let labelWidth: CGFloat = 110
    private let fieldWidth: CGFloat = 330
    private let cornerRadius: CGFloat = 20

    // Adjust margins here
    private let contentPadding = EdgeInsets(top: 8, leading: 22, bottom: 18, trailing: 10)

    // Adjust Done button position here (bigger = moves Up/Left away from edges)
    private let doneInsetRight: CGFloat = 2
    private let doneInsetBottom: CGFloat = 14

    var body: some View {
        ZStack {
            WindowAccessor { w in
                windowRef.window = w
            }

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(liquidGlassRim)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    TrafficLights(
                        window: { windowRef.window },
                        closeAction: closeSettings
                    )

                    Text("ReRoute Settings")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Spacer()
                }
                .padding(.top, 2)

                Divider().opacity(0.5)

                Text("Router")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 10) {
                    LabeledRow(label: "Router Host", labelWidth: labelWidth) {
                        TextField("192.168.1.1", text: $model.routerHost)
                            .textFieldStyle(.plain)
                            .frame(width: fieldWidth)
                            .focused($focused, equals: .host)
                            .glassField()
                    }

                    LabeledRow(label: "Username", labelWidth: labelWidth) {
                        TextField("admin", text: $model.routerUsername)
                            .textFieldStyle(.plain)
                            .frame(width: fieldWidth)
                            .focused($focused, equals: .user)
                            .glassField()
                    }

                    LabeledRow(label: "Password", labelWidth: labelWidth) {
                        HStack(spacing: 8) {
                            Group {
                                if showPassword {
                                    TextField("Password", text: $model.routerPassword)
                                } else {
                                    SecureField("Password", text: $model.routerPassword)
                                }
                            }
                            .textFieldStyle(.plain)
                            .focused($focused, equals: .pass)
                            .frame(maxWidth: .infinity)

                            Button { showPassword.toggle() } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .font(.system(size: 13, weight: .semibold))
                                    .opacity(0.85)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(width: fieldWidth)
                        .glassField()
                    }
                }

                Divider().opacity(0.5)

                Text("Confirmations")
                    .font(.system(size: 13, weight: .semibold))
                    .opacity(0.9)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Ask confirmation for Reboot Now", isOn: $model.askConfirmRebootNow)
                    Toggle("Notify when internet is back", isOn: $model.notifyWhenBack)
                    Toggle("Open Terminal in Debug Mode", isOn: $model.openTerminalDebug)
                }

                Spacer(minLength: 0)

                HStack {
                    Spacer()
                    Button("Done") {
                        closeSettings()
                    }
                    .buttonStyle(GlassPrimaryButtonStyle())
                }
                // Done button positioning (Up + Left)
                .padding(.trailing, 6)
                .padding(.bottom, 6)
                .offset(x: -doneInsetRight, y: -doneInsetBottom)
            }
            .padding(contentPadding)
        }
        // Must match WindowManager size to prevent cropping
        .frame(width: 560, height: 372, alignment: .topLeading)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear {
            DispatchQueue.main.async {
                focused = nil
                windowRef.window?.makeFirstResponder(nil)
            }
        }
    }

    private func closeSettings() {
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

private struct TrafficLights: View {
    let window: () -> NSWindow?
    let closeAction: () -> Void
    @State private var hover = false

    private var canZoom: Bool {
        window()?.styleMask.contains(.resizable) ?? false
    }

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

private struct LabeledRow<Content: View>: View {
    let label: String
    let labelWidth: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .frame(width: labelWidth, alignment: .leading)
                .opacity(0.9)
            content
            Spacer(minLength: 0)
        }
    }
}

private extension View {
    func glassField() -> some View {
        self
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            )
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
