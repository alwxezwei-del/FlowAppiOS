import SwiftUI

@main
struct FlowAppiOSApp: App {
    @StateObject private var store = FlowStore(seedSamples: true)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
