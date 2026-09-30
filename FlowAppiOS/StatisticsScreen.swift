import SwiftUI

enum StatsPeriod: String, CaseIterable, Hashable { case week = "Week", month = "Month", year = "Year" }

struct StatisticsScreen: View {
    @EnvironmentObject private var store: FlowStore
    @Environment(\.flow) private var flow
    @State private var period: StatsPeriod = .week

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                FlowTopBar(title: "Statistics").padding(.horizontal, -16)
                FlowSegmentedControl(items: StatsPeriod.allCases, selection: $period) { $0.rawValue }
                FlowCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Focus time").font(.system(size: 14)).foregroundStyle(flow.textSecondary)
                        HStack(alignment: .firstTextBaseline) {
                            Text(totalFocusLabel).font(.system(size: 32, weight: .medium)).foregroundStyle(flow.textMain)
                            Spacer()
                            Text("+12%").font(.system(size: 14, weight: .semibold)).foregroundStyle(flow.success)
                        }
                        BarChart(values: chartValues)
                    }
                }
                FlowCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Completion").font(.system(size: 14)).foregroundStyle(flow.textSecondary)
                        Text("\(completionPercent)%").font(.system(size: 32, weight: .medium)).foregroundStyle(flow.textMain)
                        Text("\(completedTasks) of \(store.tasks.count) tasks completed").font(.system(size: 13)).foregroundStyle(flow.textSecondary)
                        FlowProgressBar(value: Double(completionPercent) / 100)
                    }
                }
                distribution(title: "Focus areas", rows: categoryRows)
                distribution(title: "Habit consistency", rows: habitRows)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(flow.layer0.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private var completedTasks: Int { store.tasks.filter(\.isCompleted).count }
    private var completionPercent: Int { store.tasks.isEmpty ? 0 : Int(Double(completedTasks) / Double(store.tasks.count) * 100) }
    private var totalFocus: Int { store.sessions.map(\.actualMinutes).reduce(0, +) }
    private var totalFocusLabel: String { totalFocus < 60 ? "\(totalFocus)m" : "\(totalFocus / 60)h \(totalFocus % 60)m" }
    private var chartValues: [Double] { (0..<7).map { offset in Double(store.sessions.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: Date().addingDays(offset - 6)) }.map(\.actualMinutes).reduce(0, +)) } }

    private var categoryRows: [(String, String, Double, AccentColor, String)] {
        store.categories.map { category in
            let tasks = store.tasks.filter { $0.categoryID == category.id }
            let value = tasks.map(\.focusedMinutes).reduce(0, +)
            return (category.name, "\(value)m", Double(value) / Double(max(totalFocus, 1)), category.color, category.icon)
        }.filter { $0.2 > 0 || !store.sessions.isEmpty }
    }

    private var habitRows: [(String, String, Double, AccentColor, String)] {
        store.habits.map { habit in
            let done = habit.completedDates.count
            return (habit.name, "\(done)/7", min(Double(done) / 7, 1), habit.color, habit.icon)
        }
    }

    private func distribution(title: String, rows: [(String, String, Double, AccentColor, String)]) -> some View {
        VStack(spacing: 10) {
            SectionHeader(title: title)
            FlowCard {
                VStack(spacing: 14) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 12) {
                            FlowIconBadge(icon: row.4, accent: row.3, size: 32)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Text(row.0).font(.system(size: 14)).foregroundStyle(flow.textMain); Spacer(); Text(row.1).font(.system(size: 14)).foregroundStyle(flow.textSecondary) }
                                FlowProgressBar(value: row.2, color: row.3.color(for: flow.isDark ? .dark : .light), height: 5)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct BarChart: View {
    @Environment(\.flow) private var flow
    var values: [Double]

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(index == values.count - 1 ? flow.primary : flow.layer3)
                        .frame(height: max(14, CGFloat(value / max((values.max() ?? 1), 1)) * 118))
                    Text(label(index)).font(.system(size: 11)).foregroundStyle(flow.textTertiary)
                }.frame(maxWidth: .infinity)
            }
        }.frame(height: 150)
    }

    private func label(_ index: Int) -> String { ["M","T","W","T","F","S","S"][safe: index] ?? "" }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
