import Foundation
import SwiftUI
import Combine

final class TaskTimelineViewModel: ObservableObject {
    @Published var unplacedTasks: [UserTask] = []
    @Published var placements: [UUID: CGFloat] = [:]
    @Published var didFinish = false
    @Published var earnedStars = 0
    @Published var efficiency = 0.0

    private let manager: TaskManager
    private var dependenciesResolved = 0
    private var dependenciesTotal = 1

    init(manager: TaskManager) {
        self.manager = manager
        reload()
    }

    func reload() {
        unplacedTasks = manager.userTasks.sorted { $0.deadline < $1.deadline }
        placements = [:]
        didFinish = false
        earnedStars = 0
        efficiency = 0
        dependenciesResolved = 0
        dependenciesTotal = max(manager.taskDependencies.count, 1)
    }

    func placeTask(_ task: UserTask, x: CGFloat, timelineWidth: CGFloat) {
        let clamped = min(max(16, x), max(16, timelineWidth - 16))
        placements[task.id] = clamped
        evaluateDependencies()
    }

    func completeSession() {
        let coverage = Double(placements.count) / Double(max(unplacedTasks.count, 1))
        let dependencyScore = Double(dependenciesResolved) / Double(max(dependenciesTotal, 1))
        let difficultyMultiplier: Double = switch manager.selectedDifficulty {
        case .focused: 0.95
        case .balanced: 1.0
        case .intense: 1.1
        }
        efficiency = min(1, ((coverage * 0.6) + (dependencyScore * 0.4)) * difficultyMultiplier)
        earnedStars = stars(from: efficiency)
        didFinish = true
        manager.recordActivityResult(activity: .timeline, stars: earnedStars, completedTasks: placements.count, efficiency: efficiency)
    }

    private func evaluateDependencies() {
        let deps = manager.taskDependencies
        dependenciesResolved = deps.reduce(0) { partial, item in
            let (child, parents) = item
            guard let childX = placements[child] else { return partial }
            let resolved = parents.allSatisfy { parent in
                guard let parentX = placements[parent] else { return false }
                return parentX <= childX
            }
            return partial + (resolved ? 1 : 0)
        }
    }

    private func stars(from score: Double) -> Int {
        if score >= 0.85 { return 3 }
        if score >= 0.6 { return 2 }
        return 1
    }
}

final class EfficiencyEvaluatorViewModel: ObservableObject {
    @Published var availableTasks: [UserTask] = []
    @Published var selectedTaskID: UUID?
    @Published var estimateText = ""
    @Published var actualText = ""
    @Published var entries: [(title: String, estimate: Double, actual: Double)] = []
    @Published var didFinish = false
    @Published var earnedStars = 0
    @Published var precision = 0.0

    private let manager: TaskManager

    init(manager: TaskManager) {
        self.manager = manager
        availableTasks = manager.userTasks
        selectedTaskID = manager.userTasks.first?.id
    }

    func submitEntry() {
        guard
            let id = selectedTaskID,
            let task = manager.userTasks.first(where: { $0.id == id }),
            let estimate = Double(estimateText), estimate > 0,
            let actual = Double(actualText), actual > 0
        else { return }

        entries.append((task.title, estimate, actual))
        manager.taskEstimates[id] = Int(estimate)
        var updatedTask = task
        updatedTask.actualMinutes = Int(actual)
        updatedTask.isCompleted = true
        manager.updateTask(updatedTask)

        estimateText = ""
        actualText = ""
    }

    func finish() {
        guard entries.isEmpty == false else { return }
        let normalizedErrors = entries.map { abs($0.estimate - $0.actual) / $0.actual }
        let meanError = normalizedErrors.reduce(0, +) / Double(normalizedErrors.count)
        let difficultyOffset: Double = switch manager.selectedDifficulty {
        case .focused: 0.1
        case .balanced: 0.0
        case .intense: -0.1
        }
        precision = max(0, min(1, 1 - meanError + difficultyOffset))
        earnedStars = precision >= 0.85 ? 3 : (precision >= 0.65 ? 2 : 1)
        didFinish = true
        manager.recordActivityResult(activity: .evaluator, stars: earnedStars, completedTasks: entries.count, efficiency: precision)
    }

    func resetSession() {
        entries.removeAll()
        estimateText = ""
        actualText = ""
        didFinish = false
        earnedStars = 0
        precision = 0
        availableTasks = manager.userTasks
        selectedTaskID = manager.userTasks.first?.id
    }
}

final class StrategicSprintViewModel: ObservableObject {
    @Published var orderedTasks: [UserTask] = []
    @Published var selectedIDs: Set<UUID> = []
    @Published var elapsedSeconds = 0
    @Published var didFinish = false
    @Published var earnedStars = 0
    @Published var completionRate = 0.0

    private let manager: TaskManager
    private var cancellable: AnyCancellable?

    init(manager: TaskManager) {
        self.manager = manager
        self.orderedTasks = manager.userTasks.sorted { $0.priority < $1.priority }
        startTimer()
    }

    deinit {
        cancellable?.cancel()
    }

    func toggleTask(_ task: UserTask) {
        if selectedIDs.contains(task.id) {
            selectedIDs.remove(task.id)
        } else {
            selectedIDs.insert(task.id)
        }
    }

    func moveTaskUp(_ task: UserTask) {
        guard let index = orderedTasks.firstIndex(of: task), index > 0 else { return }
        orderedTasks.swapAt(index, index - 1)
    }

    func finish() {
        let selectedTasks = orderedTasks.filter { selectedIDs.contains($0.id) }
        guard selectedTasks.isEmpty == false else { return }
        let topHalf = Array(orderedTasks.prefix(max(1, orderedTasks.count / 2)))
        let importantCompleted = selectedTasks.filter { topHalf.contains($0) }.count
        completionRate = Double(importantCompleted) / Double(selectedTasks.count)
        let speedFactor: Double = switch manager.selectedDifficulty {
        case .focused: 0.05
        case .balanced: 0.0
        case .intense: -0.05
        }
        let normalized = min(1, max(0, completionRate + speedFactor))
        earnedStars = normalized >= 0.8 ? 3 : (normalized >= 0.55 ? 2 : 1)
        didFinish = true
        manager.recordActivityResult(activity: .sprint, stars: earnedStars, completedTasks: selectedTasks.count, efficiency: normalized)
    }

    func resetSession() {
        selectedIDs.removeAll()
        elapsedSeconds = 0
        didFinish = false
        earnedStars = 0
        completionRate = 0
        orderedTasks = manager.userTasks.sorted { $0.priority < $1.priority }
    }

    private func startTimer() {
        let interval: TimeInterval = switch manager.selectedDifficulty {
        case .focused: 1.2
        case .balanced: 1.0
        case .intense: 0.7
        }
        cancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.elapsedSeconds += 1
            }
    }
}
