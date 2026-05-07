import Foundation
import Combine

final class TaskManager: ObservableObject {
    @Published var userTasks: [UserTask] {
        didSet { persistTasks() }
    }
    @Published var taskDependencies: [UUID: [UUID]] {
        didSet { persistDependencies() }
    }
    @Published var taskEstimates: [UUID: Int] {
        didSet { persistEstimates() }
    }
    @Published var activityProgress: ActivityProgress {
        didSet { persistActivityProgress() }
    }
    @Published var selectedDifficulty: DifficultyLevel {
        didSet { UserDefaults.standard.set(selectedDifficulty.rawValue, forKey: "taskManager.selectedDifficulty") }
    }

    private let userTasksKey = "taskManager.userTasks"
    private let taskDependenciesKey = "taskManager.taskDependencies"
    private let taskEstimatesKey = "taskManager.taskEstimates"
    private let activityProgressKey = "taskManager.activityProgress"
    private let lastStarsKey = "taskManager.lastStars"
    private var lastStars: [Int]

    init() {
        userTasks = Self.read([UserTask].self, key: "taskManager.userTasks") ?? Self.sampleTasks()
        taskDependencies = Self.read([UUID: [UUID]].self, key: "taskManager.taskDependencies") ?? [:]
        taskEstimates = Self.read([UUID: Int].self, key: "taskManager.taskEstimates") ?? [:]
        activityProgress = Self.read(ActivityProgress.self, key: "taskManager.activityProgress") ?? .initial
        selectedDifficulty = DifficultyLevel(rawValue: UserDefaults.standard.string(forKey: "taskManager.selectedDifficulty") ?? "") ?? .balanced
        lastStars = Self.read([Int].self, key: lastStarsKey) ?? []
    }

    var achievements: [Achievement] {
        var result: [Achievement] = []
        let completed = userTasks.filter(\.isCompleted).count
        if completed >= 3 {
            result.append(Achievement(title: "Momentum Builder", subtitle: "Complete at least 3 tasks"))
        }
        if activityProgress.starsByActivity.values.filter({ $0 == 3 }).count == 3 {
            result.append(Achievement(title: "Precision Master", subtitle: "Earn 3 stars in all activities"))
        }
        if activityProgress.totalSessions >= 5 {
            result.append(Achievement(title: "Consistent Planner", subtitle: "Finish 5 productivity sessions"))
        }
        if overdueTasksCount == 0 && userTasks.isEmpty == false {
            result.append(Achievement(title: "Schedule Guardian", subtitle: "No overdue tasks in your current board"))
        }
        if weeklyReview.averageEstimateError < 0.15 && activityProgress.totalSessions >= 3 {
            result.append(Achievement(title: "Estimate Sharpness", subtitle: "Keep estimate error below 15%"))
        }
        return result
    }

    var templates: [SessionTemplate] {
        [
            SessionTemplate(title: "Deep Work", durationMinutes: 45, module: .midTerm, suggestedPriority: 1),
            SessionTemplate(title: "Planning", durationMinutes: 30, module: .shortTerm, suggestedPriority: 2),
            SessionTemplate(title: "Strategy Block", durationMinutes: 60, module: .longTerm, suggestedPriority: 1)
        ]
    }

    var overdueTasksCount: Int {
        userTasks.filter { !$0.isCompleted && $0.deadline < Date() }.count
    }

    var weeklyReview: WeeklyReview {
        let windowStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recent = userTasks.filter { $0.createdAt >= windowStart }
        let done = recent.filter(\.isCompleted)
        let completionRate = recent.isEmpty ? 0 : Double(done.count) / Double(recent.count)

        let errors = done.compactMap { task -> Double? in
            guard let actual = task.actualMinutes, actual > 0 else { return nil }
            return abs(Double(task.estimatedMinutes - actual)) / Double(actual)
        }
        let estimateError = errors.isEmpty ? 0 : errors.reduce(0, +) / Double(errors.count)

        let blocked = userTasks
            .filter { !$0.isCompleted && (taskDependencies[$0.id]?.isEmpty == false) }
            .sorted { $0.deadline < $1.deadline }
        return WeeklyReview(
            completionRate: completionRate,
            averageEstimateError: estimateError,
            topBlockedTasks: Array(blocked.prefix(3)),
            productivityStreak: currentStreakDays()
        )
    }

    var moduleCompletion: [ModuleType: Double] {
        Dictionary(uniqueKeysWithValues: ModuleType.allCases.map { module in
            let tasks = userTasks.filter { $0.module == module }
            guard tasks.isEmpty == false else { return (module, 0) }
            let completed = tasks.filter(\.isCompleted).count
            return (module, Double(completed) / Double(tasks.count))
        })
    }

    func updateTask(_ task: UserTask) {
        guard let index = userTasks.firstIndex(where: { $0.id == task.id }) else { return }
        userTasks[index] = task
    }

    func addTask(title: String, details: String, deadline: Date, priority: Int, estimatedMinutes: Int, module: ModuleType) {
        let task = UserTask(
            id: UUID(),
            title: title,
            details: details,
            deadline: deadline,
            priority: priority,
            estimatedMinutes: estimatedMinutes,
            actualMinutes: nil,
            isCompleted: false,
            module: module,
            createdAt: Date()
        )
        userTasks.append(task)
        taskEstimates[task.id] = estimatedMinutes
    }

    func applyTemplate(_ template: SessionTemplate) {
        addTask(
            title: "\(template.title) Session",
            details: "Template-generated task",
            deadline: Date().addingTimeInterval(Double(template.durationMinutes * 60)),
            priority: template.suggestedPriority,
            estimatedMinutes: template.durationMinutes,
            module: template.module
        )
    }

    func updateDependency(child: UUID, dependsOn parent: UUID, enabled: Bool) {
        var list = taskDependencies[child] ?? []
        if enabled {
            if parent != child && !list.contains(parent) { list.append(parent) }
        } else {
            list.removeAll { $0 == parent }
        }
        taskDependencies[child] = list
    }

    func smartReprioritize() {
        let now = Date()
        userTasks = userTasks.map { task in
            var mutable = task
            let hoursToDeadline = max(1, task.deadline.timeIntervalSince(now) / 3600)
            let dependencyPenalty = Double(taskDependencies[task.id]?.count ?? 0) * 0.8
            let ageHours = max(0, now.timeIntervalSince(task.createdAt) / 3600)
            let urgency = (24 / hoursToDeadline) + dependencyPenalty + (ageHours / 72)
            let normalized = min(3, max(1, Int(round(urgency))))
            mutable.priority = normalized
            return mutable
        }
    }

    func recordActivityResult(activity: ActivityType, stars: Int, completedTasks: Int, efficiency: Double) {
        let clampedStars = min(3, max(1, stars))
        activityProgress.starsByActivity[activity] = max(activityProgress.starsByActivity[activity] ?? 0, clampedStars)
        activityProgress.completionCountByActivity[activity, default: 0] += 1
        activityProgress.totalSessions += 1
        activityProgress.totalCompletedTasks += completedTasks

        let sessions = max(activityProgress.totalSessions, 1)
        let historical = activityProgress.averageEfficiency * Double(max(sessions - 1, 0))
        activityProgress.averageEfficiency = (historical + efficiency) / Double(sessions)
        lastStars.append(clampedStars)
        lastStars = Array(lastStars.suffix(3))
        Self.write(lastStars, key: lastStarsKey)
        adjustDifficultyAdaptively()
    }

    func reset(scope: ResetScope) {
        let defaults = UserDefaults.standard

        switch scope {
        case .all:
            defaults.removeObject(forKey: userTasksKey)
            defaults.removeObject(forKey: taskDependenciesKey)
            defaults.removeObject(forKey: taskEstimatesKey)
            defaults.removeObject(forKey: activityProgressKey)
            defaults.removeObject(forKey: "taskManager.selectedDifficulty")
            defaults.removeObject(forKey: lastStarsKey)
            userTasks = Self.sampleTasks()
            taskDependencies = [:]
            taskEstimates = [:]
            activityProgress = .initial
            selectedDifficulty = .balanced
            lastStars = []
        case .activityOnly:
            defaults.removeObject(forKey: activityProgressKey)
            defaults.removeObject(forKey: lastStarsKey)
            activityProgress = .initial
            lastStars = []
        case .starsOnly:
            activityProgress.starsByActivity = [.timeline: 0, .evaluator: 0, .sprint: 0]
            defaults.removeObject(forKey: lastStarsKey)
            lastStars = []
        case .tasksOnly:
            defaults.removeObject(forKey: userTasksKey)
            defaults.removeObject(forKey: taskDependenciesKey)
            defaults.removeObject(forKey: taskEstimatesKey)
            userTasks = Self.sampleTasks()
            taskDependencies = [:]
            taskEstimates = [:]
        }
        NotificationCenter.default.post(name: .taskManagerDidReset, object: nil)
    }

    func exportBackup() -> URL? {
        let payload = BackupPayload(
            userTasks: userTasks,
            taskDependencies: taskDependencies,
            taskEstimates: taskEstimates,
            activityProgress: activityProgress,
            selectedDifficulty: selectedDifficulty
        )
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("focusflow-backup.json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    func importBackup(from url: URL) -> Bool {
        guard
            let data = try? Data(contentsOf: url),
            let payload = try? JSONDecoder().decode(BackupPayload.self, from: data)
        else { return false }
        userTasks = payload.userTasks
        taskDependencies = payload.taskDependencies
        taskEstimates = payload.taskEstimates
        activityProgress = payload.activityProgress
        selectedDifficulty = payload.selectedDifficulty
        NotificationCenter.default.post(name: .taskManagerDidReset, object: nil)
        return true
    }

    private func persistTasks() { Self.write(userTasks, key: userTasksKey) }
    private func persistDependencies() { Self.write(taskDependencies, key: taskDependenciesKey) }
    private func persistEstimates() { Self.write(taskEstimates, key: taskEstimatesKey) }
    private func persistActivityProgress() { Self.write(activityProgress, key: activityProgressKey) }

    private static func read<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func write<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func sampleTasks() -> [UserTask] {
        let now = Date()
        return [
            UserTask(id: UUID(), title: "Weekly planning", details: "Map goals and milestones", deadline: now.addingTimeInterval(3600 * 24), priority: 1, estimatedMinutes: 45, actualMinutes: nil, isCompleted: false, module: .shortTerm, createdAt: now),
            UserTask(id: UUID(), title: "Project refinement", details: "Resolve blockers", deadline: now.addingTimeInterval(3600 * 48), priority: 2, estimatedMinutes: 60, actualMinutes: nil, isCompleted: false, module: .midTerm, createdAt: now),
            UserTask(id: UUID(), title: "Roadmap alignment", details: "Organize strategic tasks", deadline: now.addingTimeInterval(3600 * 72), priority: 3, estimatedMinutes: 75, actualMinutes: nil, isCompleted: false, module: .longTerm, createdAt: now)
        ]
    }

    private func adjustDifficultyAdaptively() {
        guard lastStars.count == 3 else { return }
        if lastStars.allSatisfy({ $0 == 3 }) {
            selectedDifficulty = selectedDifficulty == .focused ? .balanced : .intense
        } else if lastStars.filter({ $0 == 1 }).count >= 2 {
            selectedDifficulty = selectedDifficulty == .intense ? .balanced : .focused
        }
    }

    private func currentStreakDays() -> Int {
        let completedDates = Set(userTasks.filter(\.isCompleted).map { Calendar.current.startOfDay(for: $0.deadline) })
        guard completedDates.isEmpty == false else { return 0 }
        var streak = 0
        for offset in 0..<30 {
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { break }
            let start = Calendar.current.startOfDay(for: day)
            if completedDates.contains(start) {
                streak += 1
            } else if offset > 0 {
                break
            }
        }
        return streak
    }
}

extension Notification.Name {
    static let taskManagerDidReset = Notification.Name("taskManagerDidReset")
}
