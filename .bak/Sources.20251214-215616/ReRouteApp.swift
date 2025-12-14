import SwiftUI

@main
struct ReRouteApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            RootMenuView()
                .environmentObject(model)
                .frame(width: 360)
        } label: {
            MenuBarIconView()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window) // enables full custom UI + live updates while open
    }
}
