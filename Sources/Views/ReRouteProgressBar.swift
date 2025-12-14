import SwiftUI

struct ReRouteProgressBar: View {
    let value: Double
    let total: Double

    private let height: CGFloat = 8
    private let trackOpacity: Double = 0.10
    private let borderOpacity: Double = 0.10
    private let fillOpacity: Double = 0.95

    private var ratio: Double {
        guard total > 0 else { return 0 }
        return min(max(value / total, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let fillW = max(0, w * ratio)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(trackOpacity))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(borderOpacity), lineWidth: 1)
                    )

                Capsule()
                    .fill(Color.accentColor.opacity(fillOpacity))
                    .frame(width: fillW)
                    .opacity(ratio <= 0.00001 ? 0 : 1) // fully empty at 0%
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
    }
}
