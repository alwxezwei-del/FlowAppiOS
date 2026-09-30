import SwiftUI
import UIKit

struct RootView: View {
    @Environment(Router.self) private var router
    @Environment(SettingsService.self) private var settings

    var body: some View {
        @Bindable var router = router
        let theme = settings.settings

        VStack(spacing: 0) {
            TabView(selection: $router.tab) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    NavigationStack(path: path(for: tab)) {
                        root(of: tab)
                            .navigationDestination(for: Route.self) { screen($0) }
                    }
                    .toolbar(.hidden, for: .tabBar)
                    .tag(tab)
                }
            }

            if router.isAtRoot {
                BottomBar(selected: router.tab) { router.tab = $0 }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: router.isAtRoot)
        .flowTheme(theme.themeMode, accent: theme.accentColor)
    }

    private func path(for tab: AppTab) -> Binding<[Route]> {
        Binding(get: { router.paths[tab, default: []] }, set: { router.paths[tab] = $0 })
    }

    @ViewBuilder
    private func root(of tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView()
        case .tasks: TasksView()
        case .focus: FocusView()
        case .stats: StatsView()
        }
    }

    @ViewBuilder
    private func screen(_ route: Route) -> some View {
        switch route {
        case .taskEditor(let id): TaskEditorView(taskId: id)
        case .habitEditor(let id): HabitEditorView(habitId: id)
        case .habitDetails(let id): HabitDetailsView(habitId: id)
        case .habits: HabitsView()
        case .history: HistoryView()
        case .settings: SettingsView()
        }
    }
}

private struct BottomBar: View {
    let selected: AppTab
    let onSelect: (AppTab) -> Void

    @Environment(\.colors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isSelected = tab == selected
                Button { onSelect(tab) } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon(selected: isSelected))
                            .font(.system(size: 20))
                            .foregroundStyle(isSelected ? colors.primary : colors.iconSecondary)
                            .frame(height: 26)
                        Text(tab.title)
                            .font(.flowCaption)
                            .foregroundStyle(isSelected ? colors.primary : colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .background(colors.layer1.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { colors.divider.frame(height: 0.33) }
    }
}

private extension AppTab {
    var title: String {
        switch self {
        case .home: "Home"
        case .tasks: "Tasks"
        case .focus: "Focus"
        case .stats: "Stats"
        }
    }

    func icon(selected: Bool) -> String {
        switch self {
        case .home: selected ? "house.fill" : "house"
        case .tasks: selected ? "checkmark.circle.fill" : "checkmark.circle"
        case .focus: "timer"
        case .stats: selected ? "chart.bar.fill" : "chart.bar"
        }
    }
}

// Screens draw their own top bar, and hiding the system one disables swipe-back. This brings it back.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
