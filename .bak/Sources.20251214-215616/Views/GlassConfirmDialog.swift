import SwiftUI

struct GlassConfirmDialog: View {
    let title: String
    let subtitle: String
    let bullets: [String]
    let warning: String?

    let showDontAskAgain: Bool
    @Binding var dontAskAgainValue: Bool

    let primaryTitle: String
    let primaryDestructive: Bool

    let onPrimary: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }

                if let warning {
                    Text(warning)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(bullets, id: \.self) { b in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").foregroundStyle(.secondary)
                            Text(b).foregroundStyle(.secondary)
                        }
                    }
                }

                if showDontAskAgain {
                    Toggle("Don’t ask again", isOn: $dontAskAgainValue)
                        .toggleStyle(.switch)
                }

                HStack(spacing: 10) {
                    Button("Cancel") { onCancel() }
                        .buttonStyle(.bordered)

                    Spacer()

                    Button(primaryTitle) { onPrimary() }
                        .buttonStyle(primaryDestructive ? .borderedProminent : .borderedProminent)
                        .tint(primaryDestructive ? .red : .accentColor)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 10)
            .frame(maxWidth: 340)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.98).combined(with: .opacity),
                removal: .opacity
            ))
        }
        .animation(.easeOut(duration: 0.18), value: UUID())
    }
}
