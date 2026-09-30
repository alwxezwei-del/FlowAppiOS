import Foundation
import SwiftUI

enum AccentColor: String, CaseIterable, Codable, Identifiable {
    case purple, violet, blue, teal, green, orange, pink

    var id: String { rawValue }

    var label: String {
        switch self {
        case .purple: "Purple"
        case .violet: "Violet"
        case .blue: "Blue"
        case .teal: "Teal"
        case .green: "Green"
        case .orange: "Orange"
        case .pink: "Pink"
        }
    }

    var symbol: String {
        switch self {
        case .purple: "sparkles"
        case .violet: "moon.stars.fill"
        case .blue: "briefcase.fill"
        case .teal: "leaf.fill"
        case .green: "figure.run"
        case .orange: "flame.fill"
        case .pink: "heart.fill"
        }
    }
}

enum TaskPriority: String, CaseIterable, Codable, Identifiable {
    case low, normal, high
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum TaskStatus: String, Codable {
    case active, completed
}

struct FlowTask: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var notes: String
    var categoryID: UUID?
    var estimateMinutes: Int
    var focusedMinutes: Int
    var dueDate: Date?
    var priority: TaskPriority
    var status: TaskStatus
    var createdAt: Date
    var completedAt: Date?

    var isCompleted: Bool { status == .completed }
    var progress: Double {
        guard estimateMinutes > 0 else { return focusedMinutes > 0 ? 1 : 0 }
        return min(Double(focusedMinutes) / Double(estimateMinutes), 1)
    }
}

struct FlowHabit: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var icon: String
    var color: AccentColor
    var targetPerDay: Int
    var note: String
    var completedDates: Set<String>
    var createdAt: Date

    func isCompleted(on date: Date) -> Bool { completedDates.contains(date.flowDayKey) }
}

struct FlowCategory: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var color: AccentColor
    var icon: String
}

struct FocusSession: Identifiable, Codable, Hashable {
    var id = UUID()
    var taskID: UUID?
    var plannedMinutes: Int
    var actualMinutes: Int
    var startedAt: Date
    var endedAt: Date
    var completed: Bool
}

enum ThemeMode: String, CaseIterable, Codable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct AppSettings: Codable, Hashable {
    var themeMode: ThemeMode = .system
    var accentColor: AccentColor = .purple
    var focusMinutes: Int = 25
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 15
    var notificationsEnabled: Bool = true
    var startOfWeekMonday: Bool = true
}

extension Date {
    var flowDayKey: String {
        DateFormatter.flowDay.string(from: self)
    }

    var isToday: Bool { Calendar.current.isDateInToday(self) }

    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
}

extension DateFormatter {
    static let flowDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
