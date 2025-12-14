import SwiftUI

struct CancelPulseLabel: View {
    let seconds: Int
    @State private var pulse = false

    var body: some View {
        Text("Cancel (\(seconds))")
            .fontWeight(.semibold)
            .opacity(pulse ? 1.0 : 0.86)
            .scaleEffect(pulse ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}
