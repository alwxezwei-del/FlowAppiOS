import SwiftUI
import UIKit

struct FlowApp: View {
    let container: AppContainer

    var body: some View {
        let settings = container.settingsStore.settings
        FlowAppContent(container: container, router: container.router)
            .flowTheme(themeMode: settings.themeMode, accentColor: settings.accentColor)
    }
}

/**
 * App navigation graph
 */
private struct FlowAppContent: View {
    let container: AppContainer
    @Bindable var router: AppRouter

    @Environment(\.flowColors) private var colors

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $router.selectedTab) {
                ForEach(TopLevelDestination.allCases, id: \.self) { tab in
                    NavigationStack(path: pathBinding(for: tab)) {
                        root(for: tab)
                            .navigationDestination(for: FlowRoute.self) { destination($0) }
                    }
                    .toolbar(.hidden, for: .tabBar)
                    .tag(tab)
                }
            }

            if router.isTopLevel {
                FlowBottomBar(selected: router.selectedTab) { router.navigateToTopLevel($0) }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: router.isTopLevel)
        .background(colors.layer0.ignoresSafeArea())
    }

    private func pathBinding(for tab: TopLevelDestination) -> Binding<[FlowRoute]> {
        Binding(get: { router.path(for: tab) }, set: { router.setPath($0, for: tab) })
    }

    @ViewBuilder
    private func root(for tab: TopLevelDestination) -> some View {
        switch tab {
        case .home: HomeScreen(container: container)
        case .tasks: TasksScreen(container: container)
        case .focus: FocusScreen(container: container)
        case .statistics: StatisticsScreen(container: container)
        }
    }

    @ViewBuilder
    private func destination(_ route: FlowRoute) -> some View {
        switch route {
        case .taskEditor(let taskId): TaskEditorScreen(container: container, taskId: taskId)
        case .habitEditor(let habitId): HabitEditorScreen(container: container, habitId: habitId)
        case .habitDetails(let habitId): HabitDetailsScreen(container: container, habitId: habitId)
        case .habits: HabitsScreen(container: container)
        case .history: HistoryScreen(container: container)
        case .settings: SettingsScreen(container: container)
        }
    }
}

/** App bottom navigation bar, without ripple and selection indicator */
struct FlowBottomBar: View {
    let selected: TopLevelDestination
    let onSelect: (TopLevelDestination) -> Void

    @Environment(\.flowColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TopLevelDestination.allCases, id: \.self) { destination in
                let isSelected = destination == selected
                Button { onSelect(destination) } label: {
                    VStack(spacing: FlowSpacers.x4) {
                        Image(systemName: isSelected ? destination.selectedIcon : destination.unselectedIcon)
                            .font(.system(size: 20))
                            .foregroundStyle(isSelected ? colors.primary : colors.iconSecondary)
                            .frame(height: 26)
                        Text(destination.title)
                            .font(FlowTypography.caption)
                            .foregroundStyle(isSelected ? colors.primary : colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, FlowSpacers.x12)
                    .padding(.bottom, FlowSpacers.x8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .background(colors.layer1.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { colors.divider.frame(height: hairline) }
    }
}

/** Keeps the swipe-back gesture working with the system navigation bar hidden */
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
