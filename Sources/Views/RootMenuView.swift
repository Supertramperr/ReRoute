import SwiftUI
import AppKit

struct RootMenuView: View {
    @EnvironmentObject var model: AppModel

    private enum Screen { case main, more }
    @State private var screen: Screen = .main
    @State private var showConfirmReboot = false

    var body: some View {
        ZStack {
            switch screen {
            case .main:
                mainView
                    .transition(.opacity.combined(with: .scale(scale: 0.995)))
            case .more:
                MoreView(onBack: { screen = .main })
                    .environmentObject(model)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(.easeOut(duration: 0.16), value: screen)
    }

    private var mainView: some View {
        VStack(spacing: 10) {
            MenuSection {
                MenuRow(title: "Reboot Now…", systemImage: "arrow.clockwise") {
                    if model.internet == .offline || model.askConfirmRebootNow {
                        showConfirmReboot = true
                    } else {
                        model.rebootNow(debugMode: false)
                    }
                }
                .disabled(model.operation != .idle)

                if model.operation == .starting {
                    MenuRow(
                        title: "Cancel (\(max(0, model.startingCountdown)))",
                        systemImage: "xmark.circle"
                    ) {
                        model.cancel()
                    }
                    .reroutePulse(true)
                }
            }

            Divider().opacity(0.5)

            StatusBlockView()
                .environmentObject(model)

            Divider().opacity(0.5)

            MenuSection {
                MenuRowDisclosure(title: "More", systemImage: "ellipsis.circle") {
                    screen = .more
                }

                MenuRow(title: "Quit", systemImage: "xmark.circle") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(10) // outer margin of the whole menu
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 8)
        .overlay {
            if showConfirmReboot {
                GlassConfirmDialog(
                    title: "Reboot Router",
                    subtitle: "http://\(model.routerHost) • Internet: \(model.internet.rawValue)",
                    bullets: [
                        "Internet may be unavailable briefly.",
                        "We’ll verify connectivity after reboot."
                    ],
                    warning: (model.internet == .offline) ? "Internet is currently Offline." : nil,
                    showDontAskAgain: true,
                    dontAskAgainValue: $model.askConfirmRebootNow.mapNegated(),
                    primaryTitle: "Reboot",
                    primaryDestructive: true,
                    onPrimary: {
                        showConfirmReboot = false
                        model.rebootNow(debugMode: false)
                    },
                    onCancel: { showConfirmReboot = false }
                )
            }
        }
    }
}

private struct MenuSection<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { VStack(spacing: 0) { content } } // IMPORTANT: no dead gaps between rows
}

private struct MenuRow: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage).frame(width: 18)
                Text(title)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(HoverGlowRowStyle(hover: hover))
        .onHover { hover = $0 }
        .keyboardShortcutIf(shortcutKey(), modifiers: .command)
    }

    private func shortcutKey() -> KeyEquivalent? {
        if title.hasPrefix("Reboot") { return "r" }
        if title == "Quit" { return "q" }
        return nil
    }
}

private struct MenuRowDisclosure: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage).frame(width: 18)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .opacity(0.55)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(HoverGlowRowStyle(hover: hover))
        .onHover { hover = $0 }
    }
}

private struct HoverGlowRowStyle: ButtonStyle {
    let hover: Bool

    // TUNE THESE to remove “dead margins” while keeping it clickable:
    private let vPad: CGFloat = 7
    private let hPad: CGFloat = 8
    private let radius: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        let isActiveHover = hover && !configuration.isPressed
        let fill = configuration.isPressed ? 0.12 : (isActiveHover ? 0.08 : 0.0)
        let stroke = isActiveHover ? 0.18 : 0.0

        return configuration.label
            .padding(.vertical, vPad)
            .padding(.horizontal, hPad)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.white.opacity(fill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.white.opacity(stroke), lineWidth: 1)
            )
            .shadow(color: isActiveHover ? Color.white.opacity(0.06) : .clear, radius: 10, x: 0, y: 0)
            .contentShape(Rectangle()) // IMPORTANT: hit-test includes the padded area
    }
}

private extension Binding where Value == Bool {
    func mapNegated() -> Binding<Bool> {
        Binding<Bool>(get: { !wrappedValue }, set: { wrappedValue = !$0 })
    }
}

private struct ReRoutePulse: ViewModifier {
    let enabled: Bool
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .opacity(enabled ? (pulse ? 1.0 : 0.86) : 1.0)
            .scaleEffect(enabled ? (pulse ? 1.03 : 1.0) : 1.0)
            .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = enabled }
            .onChange(of: enabled) { v in pulse = v }
    }
}

private extension View {
    func reroutePulse(_ enabled: Bool) -> some View { self.modifier(ReRoutePulse(enabled: enabled)) }

    @ViewBuilder
    func keyboardShortcutIf(_ key: KeyEquivalent?, modifiers: EventModifiers) -> some View {
        if let key { self.keyboardShortcut(key, modifiers: modifiers) } else { self }
    }
}
