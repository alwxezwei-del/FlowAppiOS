import SwiftUI

/** App entry point */
@main
struct FlowAppiOSApp: App {
    @State private var container = AppContainer()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            FlowApp(container: container)
                .onAppear { container.initData() }
                .onChange(of: scenePhase) { _, phase in
                    // The interval may have elapsed while the process was dead, finish it on return
                    if phase == .active { container.timerController.finishIfElapsed() }
                }
        }
    }
}
