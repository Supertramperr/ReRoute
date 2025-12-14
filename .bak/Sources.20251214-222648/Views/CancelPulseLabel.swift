import SwiftUI

struct CancelPulseLabel: View {
    let seconds: Int

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let k = 0.5 + 0.5 * sin(t * 5.0) // gentle pulse

            Text(labelText)
                .fontWeight(.semibold)
                .opacity(0.85 + 0.15 * k)
                .scaleEffect(1.0 + 0.03 * k)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var labelText: String {
        if seconds > 0 { return "Cancel (\(seconds)s)" }
        return "Cancel"
    }
}
