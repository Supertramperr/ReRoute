import SwiftUI

struct GlassPanel: ViewModifier {
    var padding: CGFloat = 14
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(liquidGlassRim(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 8)
    }

    private func liquidGlassRim(cornerRadius: CGFloat) -> some View {
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

extension View {
    func rerouteGlassPanel(padding: CGFloat = 14, cornerRadius: CGFloat = 16) -> some View {
        self.modifier(GlassPanel(padding: padding, cornerRadius: cornerRadius))
    }
}
