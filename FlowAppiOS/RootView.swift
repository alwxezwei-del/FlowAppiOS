import SwiftUI

enum FlowTab: String, CaseIterable, Identifiable {
    case home, tasks, focus, statistics
    var id: String { rawValue }
    var title: String {
        switch self { case .home: "Home"; case .tasks: "Tasks"; case .focus: "Focus"; case .statistics: "Stats" }
    }
    var icon: String {
        switch self { case .home: "house"; case .tasks: "checkmark.circle"; case .focus: "timer"; case .statistics: "chart.bar" }
    }
    var selectedIcon: String {
        switch self { case .home: "house.fill"; case .tasks: "checkmark.circle.fill"; case .focus: "timer.circle.fill"; case .statistics: "chart.bar.fill" }
    }
}

struct RootView: View {
    @Environment(\.flow) private var flow
    @State private var tab: FlowTab = .home

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { HomeScreen(selectedTab: $tab) }.tag(FlowTab.home).tabItem { Label("Home", systemImage: tab == .home ? "house.fill" : "house") }
            NavigationStack { TasksScreen(selectedTab: $tab) }.tag(FlowTab.tasks).tabItem { Label("Tasks", systemImage: tab == .tasks ? "checkmark.circle.fill" : "checkmark.circle") }
            NavigationStack { FocusScreen() }.tag(FlowTab.focus).tabItem { Label("Focus", systemImage: tab == .focus ? "timer.circle.fill" : "timer") }
            NavigationStack { StatisticsScreen() }.tag(FlowTab.statistics).tabItem { Label("Stats", systemImage: tab == .statistics ? "chart.bar.fill" : "chart.bar") }
        }
        .flowThemed()
    }
}
