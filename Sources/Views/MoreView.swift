import SwiftUI
import AppKit

struct MoreView: View {
    @EnvironmentObject var model: AppModel
    let onBack: () -> Void

    @State private var showConfirmDebug = false

    var body: some View {
        VStack(spacing: 0) {
            MenuRowBack(title: "Back", systemImage: "chevron.left") {
                onBack()
            }

            Divider().opacity(0.5).padding(.vertical, 6)

            MenuRow(title: "Open Router UI", systemImage: "safari") {
                NSApp.keyWindow?.close()
                model.openRouterUI()
            }

            MenuRow(title: "Open Log", systemImage: "doc.text.magnifyingglass") {
                NSApp.keyWindow?.close()
                model.openLog()
            }
            .keyboardShortcut("l", modifiers: .command)

            Divider().opacity(0.5).padding(.vertical, 6)

            MenuRow(title: "Reboot (Debug Mode)…", systemImage: "terminal") {
                showConfirmDebug = true
            }

            Divider().opacity(0.5).padding(.vertical, 6)

            MenuRow(title: "Settings…", systemImage: "gearshape") {
                NSApp.keyWindow?.close()
                model.openSettingsWindow()
            }
            .keyboardShortcut(",", modifiers: .command)

            MenuRow(title: "About", systemImage: "info.circle") {
                NSApp.keyWindow?.close()
                model.openAboutWindow()
            }

            if model.lastError != nil {
                Divider().opacity(0.5).padding(.vertical, 6)
                MenuRow(title: "Copy Diagnostics", systemImage: "doc.on.doc") {
                    model.copyDiagnostics()
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 8)
        .overlay {
            if showConfirmDebug {
                GlassConfirmDialog(
                    title: "Reboot Router (Debug Mode)",
                    subtitle: "Streams diagnostics to Terminal",
                    bullets: ["Runs reboot and streams diagnostics to Terminal."],
                    warning: (model.internet == .offline) ? "Internet is currently Offline." : nil,
                    showDontAskAgain: false,
                    dontAskAgainValue: .constant(false),
                    primaryTitle: "Reboot in Debug Mode",
                    primaryDestructive: true,
                    onPrimary: {
                        showConfirmDebug = false
                        model.rebootNow(debugMode: true)
                    },
                    onCancel: { showConfirmDebug = false }
                )
            }
        }
    }
}

private struct MenuRowBack: View {
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
    }
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
    }
}

private struct HoverGlowRowStyle: ButtonStyle {
    let hover: Bool

    // Adjust margins/feel here (same idea as main menu):
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
            .contentShape(Rectangle())
    }
}
