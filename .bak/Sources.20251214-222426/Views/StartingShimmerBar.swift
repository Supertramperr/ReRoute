import SwiftUI

struct StartingShimmerBar: View {
    var height: CGFloat = 10
    var cornerRadius: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let cycle = 1.2
                let phase = (t.truncatingRemainder(dividingBy: cycle)) / cycle   // 0..1

                let w = geo.size.width
                let highlightW = max(80, w * 0.35)
                let startX = -highlightW
                let endX = w + highlightW
                let x = startX + (endX - startX) * phase

                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                        )

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.00),
                                    .init(color: Color.white.opacity(0.26), location: 0.50),
                                    .init(color: .clear, location: 1.00),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: highlightW, height: height)
                        .offset(x: x - w/2)
                        .blendMode(.screen)
                        .opacity(0.95)
                        .mask(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .frame(width: w, height: height)
                        )
                }
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }
}
