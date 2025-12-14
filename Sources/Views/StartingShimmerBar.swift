import SwiftUI

struct StartingShimmerBar: View {
    private let height: CGFloat = 8
    @State private var t: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let highlightW = max(40, w * 0.35)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))

                Capsule()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.00),
                                .init(color: Color.white.opacity(0.22), location: 0.50),
                                .init(color: .clear, location: 1.00),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: highlightW, height: height)
                    .offset(x: (t * (w + highlightW)) - highlightW)
                    .blendMode(.screen)
                    .opacity(0.95)
            }
            .clipShape(Capsule()) // IMPORTANT: no bleed outside bar
            .onAppear {
                t = 0
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { t = 1 }
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }
}
