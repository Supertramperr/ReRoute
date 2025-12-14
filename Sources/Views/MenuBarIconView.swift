import SwiftUI

struct MenuBarIconView: View {
    @EnvironmentObject var model: AppModel
    @State private var rotation: Double = 0

    private var shouldSpin: Bool {
        if case .rebooting = model.operation { return true }
        return false
    }

    var body: some View {
        Image(systemName: model.menuSymbolName)
            .symbolRenderingMode(.hierarchical)
            .rotationEffect(.degrees(rotation))
            .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: rotation)
            .onAppear {
                if shouldSpin { rotation = 360 }
            }
            .onChange(of: shouldSpin) { spin in
                rotation = spin ? 360 : 0
            }
    }
}
