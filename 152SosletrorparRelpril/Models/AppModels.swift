import Foundation

enum DifficultyLevel: String, CaseIterable, Codable, Identifiable {
    case focused
    case balanced
    case intense

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focused: return "Focused"
        case .balanced: return "Balanced"
        case .intense: return "Intense"
        }
    }
}

enum ModuleType: String, CaseIterable, Codable, Identifiable {
    case shortTerm
    case midTerm
    case longTerm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shortTerm: return "Short-Term Objectives"
        case .midTerm: return "Mid-Term Objectives"
        case .longTerm: return "Long-Term Objectives"
        }
    }
}

enum ActivityType: String, CaseIterable, Codable, Identifiable {
    case timeline
    case evaluator
    case sprint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timeline: return "Task Timeline Visualizer"
        case .evaluator: return "Efficiency Evaluator"
        case .sprint: return "Strategic Sprint Planner"
        }
    }
}

struct UserTask: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var details: String
    var deadline: Date
    var priority: Int
    var estimatedMinutes: Int
    var actualMinutes: Int?
    var isCompleted: Bool
    var module: ModuleType
    var createdAt: Date
}

struct ActivityProgress: Codable {
    var starsByActivity: [ActivityType: Int]
    var completionCountByActivity: [ActivityType: Int]
    var totalSessions: Int
    var totalCompletedTasks: Int
    var averageEfficiency: Double
}

extension ActivityProgress {
    static let initial = ActivityProgress(
        starsByActivity: [.timeline: 0, .evaluator: 0, .sprint: 0],
        completionCountByActivity: [.timeline: 0, .evaluator: 0, .sprint: 0],
        totalSessions: 0,
        totalCompletedTasks: 0,
        averageEfficiency: 0
    )
}

struct Achievement: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
}

enum ResetScope: String, CaseIterable, Identifiable {
    case all
    case activityOnly
    case starsOnly
    case tasksOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Reset All Progress"
        case .activityOnly: return "Reset Activity Data"
        case .starsOnly: return "Reset Stars Only"
        case .tasksOnly: return "Reset Tasks Only"
        }
    }
}

struct SessionTemplate: Identifiable {
    let id = UUID()
    let title: String
    let durationMinutes: Int
    let module: ModuleType
    let suggestedPriority: Int
}

struct WeeklyReview {
    let completionRate: Double
    let averageEstimateError: Double
    let topBlockedTasks: [UserTask]
    let productivityStreak: Int
}

struct BackupPayload: Codable {
    let userTasks: [UserTask]
    let taskDependencies: [UUID: [UUID]]
    let taskEstimates: [UUID: Int]
    let activityProgress: ActivityProgress
    let selectedDifficulty: DifficultyLevel
}
