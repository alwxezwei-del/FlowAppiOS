import SwiftUI

@main
struct FlowAppiOSApp: App {
    @State private var services = AppServices()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .onChange(of: scenePhase) { _, phase in
                    // The timer may have run out while the app was in the background
                    if phase == .active { services.focus.finishIfElapsed() }
                }
        }
    }
}
