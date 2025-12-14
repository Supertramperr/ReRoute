import SwiftUI
import AppKit

struct MoreView: View {
    @EnvironmentObject var model: AppModel
    let onBack: () -> Void

    @State private var showConfirmDebug = false

    var body: some View {
        VStack(spacing: 10) {
            // Back row
            Button(action: onBack) {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.left").frame(width: 18)
                    Text("Back")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(MenuRowStyle())

            Divider().opacity(0.5)

            MenuRow(title: "Open Router UI", systemImage: "safari") {
                // optional: close popover as well
                NSApp.keyWindow?.close()
                model.openRouterUI()
            }

            MenuRow(title: "Open Log", systemImage: "doc.text.magnifyingglass") {
                NSApp.keyWindow?.close()
                model.openLog()
            }
            .keyboardShortcut("l", modifiers: .command)

            Divider().opacity(0.5)

            MenuRow(title: "Reboot (Debug Mode)…", systemImage: "terminal") {
                showConfirmDebug = true
            }

            Divider().opacity(0.5)

            MenuRow(title: "Settings…", systemImage: "gearshape") {
                // FIX: close popover BEFORE opening the window so it isn't hidden behind
                NSApp.keyWindow?.close()
                model.openSettingsWindow()
            }
            .keyboardShortcut(",", modifiers: .command)

            MenuRow(title: "About", systemImage: "info.circle") {
                NSApp.keyWindow?.close()
                model.openAboutWindow()
            }

            if model.lastError != nil {
                Divider().opacity(0.5)
                MenuRow(title: "Copy Diagnostics", systemImage: "doc.on.doc") { model.copyDiagnostics() }
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

private struct MenuRow: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage).frame(width: 18)
                Text(title)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuRowStyle())
    }
}

private struct MenuRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(configuration.isPressed ? Color.white.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
