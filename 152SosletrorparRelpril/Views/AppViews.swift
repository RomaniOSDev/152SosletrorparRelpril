import SwiftUI
import UniformTypeIdentifiers
import StoreKit

struct OnboardingView: View {
    @State private var page = 0
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.appBackground, Color.appSurface.opacity(0.55), Color.appBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            TabView(selection: $page) {
                OnboardingCanvasPage(title: "Align Every Goal", subtitle: "Build a clear task map for your current priorities.", shapeSeed: 0).tag(0)
                OnboardingCanvasPage(title: "Manage Priorities", subtitle: "Track dependencies and keep your timeline focused.", shapeSeed: 1).tag(1)
                OnboardingCanvasPage(title: "Improve Time Efficiency", subtitle: "Measure estimate accuracy and optimize each sprint.", shapeSeed: 2).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            VStack {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Color.appPrimary : Color.appSurface.opacity(0.6))
                            .frame(width: index == page ? 28 : 10, height: 8)
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
                    }
                }
                .padding(.top, 20)

                Spacer()
                Button(page == 2 ? "Get Organized" : "Next") {
                    withAnimation(.spring) {
                        page == 2 ? onComplete() : (page += 1)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
    }
}

struct OnboardingCanvasPage: View {
    let title: String
    let subtitle: String
    let shapeSeed: CGFloat

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color.appSurface, Color.appBackground.opacity(0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.appAccent.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 10)

                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: 20, y: size.height * 0.8))
                    path.addCurve(
                        to: CGPoint(x: size.width - 20, y: size.height * 0.2),
                        control1: CGPoint(x: size.width * 0.25, y: size.height * (0.5 + 0.1 * shapeSeed)),
                        control2: CGPoint(x: size.width * 0.75, y: size.height * (0.5 - 0.1 * shapeSeed))
                    )
                    context.stroke(path, with: .color(.appAccent.opacity(0.3)), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    context.stroke(path, with: .color(.appAccent), style: StrokeStyle(lineWidth: 5, lineCap: .round))

                    for index in 0..<6 {
                        let x = CGFloat(index) * (size.width / 6) + 18
                        let y = size.height * (0.78 - CGFloat(index % 3) * 0.16 + shapeSeed * 0.03)
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 10, height: 10)), with: .color(.appPrimary))
                    }
                }
                .padding(16)
            }
            .frame(height: 330)

            VStack(spacing: 8) {
                Text(title).font(.title2.bold()).foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7).padding(.horizontal, 16)
                Text(subtitle).foregroundStyle(Color.appTextSecondary).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7).padding(.horizontal, 16)
            }
            .padding(.vertical, 10)
            .appCardStyle(cornerRadius: 18)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

struct HomeView: View {
    @EnvironmentObject private var manager: TaskManager
    @State private var quickTitle = ""
    @State private var quickDeadline = Date().addingTimeInterval(3600)
    @State private var quickPriority = 2
    @State private var quickModule: ModuleType = .shortTerm
    @State private var quickEstimate = "30"
    @State private var addTaskFeedback = ""
    @State private var addTaskFeedbackIsError = false
    @State private var editingTask: UserTask?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroWidget

                HStack(spacing: 12) {
                    progressRingWidget
                    focusWidget
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Session Difficulty").foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
                    Picker("Difficulty", selection: $manager.selectedDifficulty) {
                        ForEach(DifficultyLevel.allCases) { level in Text(level.title).tag(level) }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(16)
                .appCardStyle(cornerRadius: 16)

                deadlineWidget

                NavigationLink(destination: ModuleSelectionView()) {
                    card(title: "Module Selection", subtitle: "Short, mid and long-term objective progress")
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Quick Add Task").foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
                    TextField("", text: $quickTitle, prompt: Text("Task title").foregroundStyle(Color.appTextSecondary))
                        .foregroundStyle(Color.appTextPrimary)
                        .padding(12)
                        .background(Color.appBackground.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    DatePicker("Deadline", selection: $quickDeadline, displayedComponents: [.date, .hourAndMinute])
                        .tint(Color.appAccent)
                        .foregroundStyle(Color.appTextPrimary)
                    Picker("Module", selection: $quickModule) {
                        ForEach(ModuleType.allCases, id: \.self) { module in
                            Text(module.title).tag(module)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.appPrimary)
                    Stepper("Priority: \(quickPriority)", value: $quickPriority, in: 1...3)
                        .foregroundStyle(Color.appTextPrimary)
                    TextField("", text: $quickEstimate, prompt: Text("Estimated minutes").foregroundStyle(Color.appTextSecondary))
                        .keyboardType(.numberPad)
                        .foregroundStyle(Color.appTextPrimary)
                        .padding(12)
                        .background(Color.appBackground.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Button("Add Task") {
                        let trimmedTitle = quickTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmedTitle.isEmpty == false else {
                            addTaskFeedback = "Enter task title first."
                            addTaskFeedbackIsError = true
                            return
                        }

                        let estimate = max(5, Int(quickEstimate) ?? 30)
                        manager.addTask(
                            title: trimmedTitle,
                            details: "Quick created task",
                            deadline: quickDeadline,
                            priority: quickPriority,
                            estimatedMinutes: estimate,
                            module: quickModule
                        )
                        quickTitle = ""
                        quickEstimate = "30"
                        quickDeadline = Date().addingTimeInterval(3600)
                        quickPriority = 2
                        quickModule = .shortTerm
                        addTaskFeedback = "Task added successfully."
                        addTaskFeedbackIsError = false
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    if addTaskFeedback.isEmpty == false {
                        Text(addTaskFeedback)
                            .foregroundStyle(addTaskFeedbackIsError ? Color.appPrimary : Color.appAccent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(16)
                .appCardStyle(cornerRadius: 16)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Session Templates").foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
                    ForEach(manager.templates) { template in
                        Button {
                            manager.applyTemplate(template)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.title).foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
                                    Text("\(template.durationMinutes)m • \(template.module.title)").foregroundStyle(Color.appTextSecondary).lineLimit(1).minimumScaleFactor(0.7)
                                }
                                Spacer()
                                Text("Use").foregroundStyle(Color.appPrimary).lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .padding(12)
                            .background(Color.appBackground.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .appCardStyle(cornerRadius: 16)

                ForEach(manager.userTasks.sorted(by: { $0.deadline < $1.deadline })) { task in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(task.title).foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
                            Spacer()
                            Text(task.isCompleted ? "Done" : "Active").foregroundStyle(task.isCompleted ? Color.appAccent : Color.appPrimary).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        Text(task.details).foregroundStyle(Color.appTextSecondary).lineLimit(1).minimumScaleFactor(0.7)
                        Text("Deadline: \(task.deadline.formatted(date: .abbreviated, time: .omitted))").foregroundStyle(Color.appTextSecondary).lineLimit(1).minimumScaleFactor(0.7)
                        HStack(spacing: 10) {
                            Button(task.isCompleted ? "Mark Active" : "Mark Done") {
                                var mutableTask = task
                                mutableTask.isCompleted.toggle()
                                manager.updateTask(mutableTask)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            Button("Edit") {
                                editingTask = task
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appCardStyle(cornerRadius: 16)
                }
            }
            .padding(16)
        }
        .appScreenBackground()
        .navigationTitle("Home")
        .sheet(item: $editingTask) { task in
            TaskEditSheet(task: task) { updatedTask in
                manager.updateTask(updatedTask)
            }
        }
    }

    private var completionRatio: Double {
        let total = max(manager.userTasks.count, 1)
        let done = manager.userTasks.filter(\.isCompleted).count
        return Double(done) / Double(total)
    }

    private var heroWidget: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(Color.appSurface)
            Canvas { context, size in
                var wave = Path()
                wave.move(to: CGPoint(x: 0, y: size.height * 0.7))
                wave.addCurve(
                    to: CGPoint(x: size.width, y: size.height * 0.45),
                    control1: CGPoint(x: size.width * 0.2, y: size.height * 0.95),
                    control2: CGPoint(x: size.width * 0.7, y: size.height * 0.15)
                )
                context.stroke(wave, with: .color(.appAccent.opacity(0.8)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                for i in 0..<6 {
                    let x = CGFloat(i) * (size.width / 6) + 20
                    let y = size.height * (0.75 - CGFloat(i % 3) * 0.15)
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 10, height: 10)), with: .color(.appPrimary))
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Today Focus")
                    .font(.headline.bold())
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(manager.userTasks.filter(\.isCompleted).count) of \(manager.userTasks.count) tasks completed")
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Efficiency \(Int(manager.activityProgress.averageEfficiency * 100))%")
                    .foregroundStyle(Color.appAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)
        }
        .frame(height: 170)
    }

    private var progressRingWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Completion").foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
            ZStack {
                Circle().stroke(Color.appBackground.opacity(0.5), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: completionRatio)
                    .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(completionRatio * 100))%")
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(height: 92)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .appCardStyle(cornerRadius: 16)
    }

    private var focusWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Snapshot").foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
            Canvas { context, size in
                let values = manager.moduleCompletion.values.map { CGFloat($0) }
                for index in values.indices {
                    let barWidth = (size.width / CGFloat(max(values.count, 1))) - 8
                    let x = CGFloat(index) * (barWidth + 8)
                    let h = max(10, size.height * values[index])
                    let rect = CGRect(x: x, y: size.height - h, width: barWidth, height: h)
                    context.fill(Path(roundedRect: rect, cornerSize: CGSize(width: 6, height: 6)), with: .color(.appPrimary))
                }
            }
            .frame(height: 92)
            Text("Streak: \(manager.weeklyReview.productivityStreak) days")
                .foregroundStyle(Color.appTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .appCardStyle(cornerRadius: 16)
    }

    private var deadlineWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Upcoming Deadlines").foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
            ForEach(manager.userTasks.sorted(by: { $0.deadline < $1.deadline }).prefix(3), id: \.id) { task in
                HStack {
                    Circle()
                        .fill(task.isCompleted ? Color.appAccent : Color.appPrimary)
                        .frame(width: 8, height: 8)
                    Text(task.title).foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
                    Spacer()
                    Text(task.deadline.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding(14)
        .appCardStyle(cornerRadius: 16)
    }
}

struct TaskEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var details: String
    @State private var deadline: Date
    @State private var priority: Int
    @State private var module: ModuleType
    @State private var estimate: String
    let originalTask: UserTask
    let onSave: (UserTask) -> Void

    init(task: UserTask, onSave: @escaping (UserTask) -> Void) {
        self.originalTask = task
        self.onSave = onSave
        _title = State(initialValue: task.title)
        _details = State(initialValue: task.details)
        _deadline = State(initialValue: task.deadline)
        _priority = State(initialValue: task.priority)
        _module = State(initialValue: task.module)
        _estimate = State(initialValue: "\(task.estimatedMinutes)")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    TextField("", text: $title, prompt: Text("Task title").foregroundStyle(Color.appTextSecondary))
                        .foregroundStyle(Color.appTextPrimary)
                        .padding(12)
                        .background(Color.appBackground.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    TextField("", text: $details, prompt: Text("Task details").foregroundStyle(Color.appTextSecondary))
                        .foregroundStyle(Color.appTextPrimary)
                        .padding(12)
                        .background(Color.appBackground.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    DatePicker("Deadline", selection: $deadline, displayedComponents: [.date, .hourAndMinute])
                        .tint(Color.appAccent)
                        .foregroundStyle(Color.appTextPrimary)

                    Stepper("Priority: \(priority)", value: $priority, in: 1...3)
                        .foregroundStyle(Color.appTextPrimary)

                    Picker("Module", selection: $module) {
                        ForEach(ModuleType.allCases, id: \.self) { module in
                            Text(module.title).tag(module)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.appPrimary)

                    TextField("", text: $estimate, prompt: Text("Estimated minutes").foregroundStyle(Color.appTextSecondary))
                        .keyboardType(.numberPad)
                        .foregroundStyle(Color.appTextPrimary)
                        .padding(12)
                        .background(Color.appBackground.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(16)
            }
            .appScreenBackground()
            .navigationTitle("Edit Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = originalTask
                        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? originalTask.title : title.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.details = details
                        updated.deadline = deadline
                        updated.priority = priority
                        updated.module = module
                        updated.estimatedMinutes = max(5, Int(estimate) ?? originalTask.estimatedMinutes)
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ModuleSelectionView: View {
    @EnvironmentObject private var manager: TaskManager

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(ModuleType.allCases, id: \.self) { module in
                    let value = manager.moduleCompletion[module] ?? 0
                    VStack(alignment: .leading, spacing: 10) {
                        Text(module.title).foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
                        ProgressView(value: value).tint(.appAccent)
                        Text("\(Int(value * 100))% completed").foregroundStyle(Color.appTextSecondary).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                ForEach(ActivityType.allCases, id: \.self) { activity in
                    let unlocked = isUnlocked(activity)
                    let stars = manager.activityProgress.starsByActivity[activity] ?? 0
                    NavigationLink(destination: destination(activity: activity)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(activity.title).foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
                                Text(unlocked ? "Ready" : "Locked").foregroundStyle(unlocked ? Color.appAccent : Color.appTextSecondary).lineLimit(1).minimumScaleFactor(0.7)
                            }
                            Spacer()
                            Text(String(repeating: "★", count: stars) + String(repeating: "☆", count: max(0, 3 - stars))).foregroundStyle(Color.appPrimary).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .padding(16)
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!unlocked)
                }

                NavigationLink(destination: DependencyEditorView()) {
                    card(title: "Dependency Editor", subtitle: "Configure depends-on links between tasks")
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .appScreenBackground()
        .navigationTitle("Modules")
    }

    private func isUnlocked(_ activity: ActivityType) -> Bool {
        switch activity {
        case .timeline: return true
        case .evaluator: return (manager.activityProgress.completionCountByActivity[.timeline] ?? 0) > 0
        case .sprint: return (manager.activityProgress.completionCountByActivity[.evaluator] ?? 0) > 0
        }
    }

    @ViewBuilder
    private func destination(activity: ActivityType) -> some View {
        switch activity {
        case .timeline: TaskTimelineActivityView(manager: manager)
        case .evaluator: EfficiencyEvaluatorView(manager: manager)
        case .sprint: StrategicSprintPlannerView(manager: manager)
        }
    }
}

struct TimelineTabView: View {
    @EnvironmentObject private var manager: TaskManager
    @State private var selectedModule: ModuleType?
    @State private var showCompletedOnly = false
    @State private var minPriority = 1
    @State private var zoom: CGFloat = 1.0

    var body: some View {
        ScrollView {
            let tasks = filteredTasks
            VStack(spacing: 12) {
                timelineHero(tasks: tasks)

                VStack(alignment: .leading, spacing: 8) {
                    Picker("Module Filter", selection: Binding(get: { selectedModule }, set: { selectedModule = $0 })) {
                        Text("All Modules").tag(Optional<ModuleType>.none)
                        ForEach(ModuleType.allCases, id: \.self) { module in
                            Text(module.title).tag(Optional(module))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.appPrimary)
                    Toggle("Completed only", isOn: $showCompletedOnly).tint(Color.appAccent).foregroundStyle(Color.appTextPrimary)
                    Stepper("Min priority: \(minPriority)", value: $minPriority, in: 1...3).foregroundStyle(Color.appTextPrimary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Zoom").foregroundStyle(Color.appTextSecondary).lineLimit(1).minimumScaleFactor(0.7)
                        Slider(value: Binding(get: { Double(zoom) }, set: { zoom = CGFloat($0) }), in: 0.8...2.0)
                            .tint(Color.appPrimary)
                    }
                }
                .padding(12)
                .appCardStyle(cornerRadius: 12)

                HStack(spacing: 10) {
                    miniMetric("Visible", "\(tasks.count)")
                    miniMetric("Completed", "\(tasks.filter(\.isCompleted).count)")
                    miniMetric("Zoom", "\(String(format: "%.1fx", Double(zoom)))")
                }

                Canvas { context, size in
                    var baseline = Path()
                    baseline.move(to: CGPoint(x: 20, y: 24))
                    baseline.addLine(to: CGPoint(x: 20, y: max(24, size.height - 24)))
                    context.stroke(baseline, with: .color(.appTextSecondary.opacity(0.4)), style: StrokeStyle(lineWidth: 3, lineCap: .round))

                    guard tasks.isEmpty == false else { return }

                    let rowSpacing: CGFloat = 72 * zoom
                    for index in tasks.indices {
                        let task = tasks[index]
                        let y = CGFloat(index + 1) * rowSpacing
                        let x = 36 + CGFloat(index % 2) * min(120, size.width * 0.3)

                        if index < tasks.count - 1 {
                            let nextY = CGFloat(index + 2) * rowSpacing
                            let nextX = 36 + CGFloat((index + 1) % 2) * min(120, size.width * 0.3)
                            var segment = Path()
                            segment.move(to: CGPoint(x: x, y: y))
                            segment.addLine(to: CGPoint(x: nextX, y: nextY))
                            context.stroke(segment, with: .color(.appAccent.opacity(0.3)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            context.stroke(segment, with: .color(.appAccent), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        }

                        let nodeRect = CGRect(x: x - 9, y: y - 9, width: 18, height: 18)
                        context.fill(
                            Path(ellipseIn: nodeRect),
                            with: .color(task.isCompleted ? .appPrimary : .appAccent.opacity(0.5))
                        )
                    }
                }
                .frame(height: max(260, CGFloat(max(tasks.count, 1)) * 74 * zoom))
                .padding(16)
                .appCardStyle(cornerRadius: 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Timeline Events").foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
                    ForEach(tasks.prefix(6), id: \.id) { task in
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().fill(task.isCompleted ? Color.appPrimary : Color.appAccent.opacity(0.25))
                                Image(systemName: task.isCompleted ? "checkmark" : "clock")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(task.isCompleted ? Color.appBackground : Color.appAccent)
                            }
                            .frame(width: 22, height: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title).foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
                                Text(task.deadline.formatted(date: .abbreviated, time: .shortened))
                                    .foregroundStyle(Color.appTextSecondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            Spacer()
                            Text(task.module.title.replacingOccurrences(of: " Objectives", with: ""))
                                .foregroundStyle(Color.appTextSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .padding(10)
                        .background(Color.appBackground.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(14)
                .appCardStyle(cornerRadius: 14)

                if tasks.isEmpty {
                    Text("No tasks yet. Add tasks from Dashboard to build your timeline.")
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(16)
        }
        .appScreenBackground()
        .navigationTitle("Timeline")
    }

    private func timelineHero(tasks: [UserTask]) -> some View {
        ZStack {
            Canvas { context, size in
                var pulse = Path(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height), cornerSize: CGSize(width: 16, height: 16))
                context.fill(pulse, with: .linearGradient(
                    Gradient(colors: [.appSurface, .appBackground.opacity(0.9)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                ))
                var wave = Path()
                wave.move(to: CGPoint(x: 0, y: size.height * 0.65))
                wave.addCurve(
                    to: CGPoint(x: size.width, y: size.height * 0.35),
                    control1: CGPoint(x: size.width * 0.2, y: size.height * 0.95),
                    control2: CGPoint(x: size.width * 0.75, y: size.height * 0.05)
                )
                context.stroke(wave, with: .color(.appAccent.opacity(0.9)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Visual Timeline").font(.title3.bold()).foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
                Text("\(tasks.count) tasks in active flow").foregroundStyle(Color.appTextSecondary).lineLimit(1).minimumScaleFactor(0.7)
                Text("Dependencies and timing at a glance").foregroundStyle(Color.appAccent).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)
        }
        .frame(height: 128)
        .appCardStyle(cornerRadius: 16)
    }

    private func miniMetric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(title).foregroundStyle(Color.appTextSecondary).lineLimit(1).minimumScaleFactor(0.7)
            Text(value).foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .padding(6)
        .appCardStyle(cornerRadius: 10)
    }

    private var filteredTasks: [UserTask] {
        manager.userTasks
            .filter { selectedModule == nil || $0.module == selectedModule }
            .filter { !showCompletedOnly || $0.isCompleted }
            .filter { $0.priority <= minPriority }
            .sorted { $0.deadline < $1.deadline }
    }
}

struct ReportsView: View {
    @EnvironmentObject private var manager: TaskManager
    private let activityTitles = ["Timeline", "Evaluator", "Sprint"]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                reportsHeader

                HStack(spacing: 10) {
                    reportStatCard("Sessions", "\(manager.activityProgress.totalSessions)", "calendar")
                    reportStatCard("Tasks", "\(manager.activityProgress.totalCompletedTasks)", "checkmark.seal")
                    reportStatCard("Average", "\(Int(manager.activityProgress.averageEfficiency * 100))%", "speedometer")
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Efficiency Overview")
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    BarChartView(values: chartValues)
                        .frame(height: 220)
                    HStack(spacing: 12) {
                        ForEach(Array(activityTitles.enumerated()), id: \.offset) { index, title in
                            reportLegend(title, value: "\(Int(chartValues[index] * 100))%")
                        }
                    }
                }
                .padding(16)
                .appCardStyle(cornerRadius: 16)

                weeklyReviewCard

                if manager.achievements.isEmpty {
                    Text("No achievements yet. Complete activities to generate report insights.")
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appCardStyle(cornerRadius: 12)
                } else {
                    ForEach(manager.achievements) { item in
                        AchievementBanner(achievement: item)
                    }
                }
            }
            .padding(16)
        }
        .appScreenBackground()
        .navigationTitle("Reports")
    }

    private var chartValues: [Double] {
        [
            Double(manager.activityProgress.starsByActivity[.timeline] ?? 0) / 3,
            Double(manager.activityProgress.starsByActivity[.evaluator] ?? 0) / 3,
            Double(manager.activityProgress.starsByActivity[.sprint] ?? 0) / 3
        ]
    }

    private var reportsHeader: some View {
        ZStack {
            Canvas { context, size in
                var line = Path()
                line.move(to: CGPoint(x: 0, y: size.height * 0.75))
                line.addCurve(
                    to: CGPoint(x: size.width, y: size.height * 0.25),
                    control1: CGPoint(x: size.width * 0.25, y: size.height * 0.95),
                    control2: CGPoint(x: size.width * 0.75, y: size.height * 0.05)
                )
                context.stroke(line, with: .color(.appAccent.opacity(0.8)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Performance Report")
                    .font(.title3.bold())
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Track consistency and optimize upcoming sessions.")
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)
        }
        .frame(height: 128)
        .appCardStyle(cornerRadius: 16)
    }

    private var weeklyReviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Review").foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
            reviewRow("Completion Rate", "\(Int(manager.weeklyReview.completionRate * 100))%")
            reviewRow("Estimate Error", "\(Int(manager.weeklyReview.averageEstimateError * 100))%")
            reviewRow("Productivity Streak", "\(manager.weeklyReview.productivityStreak) days")
            if manager.weeklyReview.topBlockedTasks.isEmpty {
                Text("Top blocked tasks: none").foregroundStyle(Color.appTextSecondary).lineLimit(1).minimumScaleFactor(0.7)
            } else {
                ForEach(manager.weeklyReview.topBlockedTasks, id: \.id) { task in
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.appPrimary)
                        Text(task.title).foregroundStyle(Color.appTextSecondary).lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .padding(14)
        .appCardStyle(cornerRadius: 12)
    }

    private func reportStatCard(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(Color.appPrimary).font(.system(size: 14, weight: .semibold))
            Text(title).foregroundStyle(Color.appTextSecondary).lineLimit(1).minimumScaleFactor(0.7)
            Text(value).font(.headline).foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 68)
        .padding(8)
        .appCardStyle(cornerRadius: 12)
    }

    private func reportLegend(_ title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(Color.appAccent).frame(width: 8, height: 8)
            Text(title).foregroundStyle(Color.appTextSecondary).lineLimit(1).minimumScaleFactor(0.7)
            Text(value).foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.appSurface.opacity(0.55))
        .clipShape(Capsule())
    }

    private func reviewRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Color.appTextSecondary).lineLimit(1).minimumScaleFactor(0.7)
            Spacer()
            Text(value).foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var manager: TaskManager
    @State private var selectedResetScope: ResetScope = .all
    @State private var exportURL: URL?
    @State private var showingImporter = false
    @State private var importStatus = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statCard("Total Sessions", "\(manager.activityProgress.totalSessions)")
                statCard("Completed Tasks", "\(manager.activityProgress.totalCompletedTasks)")
                statCard("Average Efficiency", "\(Int(manager.activityProgress.averageEfficiency * 100))%")
                statCard("Current Difficulty", manager.selectedDifficulty.title)
                statCard("Overdue Tasks", "\(manager.overdueTasksCount)")

                Button("Smart Re-prioritize Tasks") { manager.smartReprioritize() }.buttonStyle(PrimaryButtonStyle())

                VStack(alignment: .leading, spacing: 10) {
                    Text("Reset With Scope").foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
                    Picker("Reset Scope", selection: $selectedResetScope) {
                        ForEach(ResetScope.allCases, id: \.self) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.appPrimary)
                    Button(selectedResetScope.title) {
                        manager.reset(scope: selectedResetScope)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(14)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Backup").foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
                    Button("Export JSON Backup") {
                        exportURL = manager.exportBackup()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(exportURL != nil)
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Text("Share Exported File")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Color.appSurface)
                                .foregroundStyle(Color.appTextPrimary)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appAccent, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    Button("Import JSON Backup") { showingImporter = true }
                        .buttonStyle(SecondaryButtonStyle())
                    if importStatus.isEmpty == false {
                        Text(importStatus).foregroundStyle(Color.appTextSecondary).lineLimit(2).minimumScaleFactor(0.7)
                    }
                }
                .padding(14)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Support").foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
                    Button("Rate Us") { rateApp() }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Privacy Policy") { openLink(.privacyPolicy) }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Terms") { openLink(.termsOfUse) }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(14)
                .appCardStyle(cornerRadius: 12)
            }
            .padding(16)
        }
        .appScreenBackground()
        .navigationTitle("Settings")
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                importStatus = manager.importBackup(from: url) ? "Backup imported successfully." : "Import failed."
            case .failure:
                importStatus = "Import cancelled."
            }
        }
    }

    private func statCard(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
            Spacer()
            Text(value).foregroundStyle(Color.appAccent).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(16)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func openLink(_ link: AppLink) {
        if let url = link.url {
            UIApplication.shared.open(url)
        }
    }

    private func rateApp() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
}

struct TaskTimelineActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TaskTimelineViewModel

    init(manager: TaskManager) {
        _viewModel = StateObject(wrappedValue: TaskTimelineViewModel(manager: manager))
    }

    var body: some View {
        ActivityContainer(title: "Task Timeline Visualizer") {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16).fill(Color.appSurface)
                    ForEach(viewModel.unplacedTasks, id: \.id) { task in
                        let x = viewModel.placements[task.id] ?? 18
                        Text(task.title)
                            .foregroundStyle(Color.appTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(10)
                            .background(Color.appPrimary.opacity(0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .offset(x: x, y: CGFloat(task.priority * 56))
                            .gesture(DragGesture().onChanged { value in
                                viewModel.placeTask(task, x: value.location.x, timelineWidth: geo.size.width)
                            })
                    }
                }
            }
            .frame(height: 260)

            Button("Complete Timeline Session") { viewModel.completeSession() }.buttonStyle(PrimaryButtonStyle())
            if viewModel.didFinish {
                CompletionResultView(
                    stars: viewModel.earnedStars,
                    title: "Timeline Session Complete",
                    statPairs: [("Alignment", "\(Int(viewModel.efficiency * 100))%"), ("Placed Tasks", "\(viewModel.placements.count)")],
                    nextTitle: "Next Session",
                    secondaryTitle: "View Timeline",
                    onNext: { viewModel.reload() },
                    onSecondary: { dismiss() }
                )
            }
        }
    }
}

struct DependencyEditorView: View {
    @EnvironmentObject private var manager: TaskManager

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if manager.userTasks.count < 2 {
                    Text("Add at least two tasks to create dependencies.")
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    ForEach(manager.userTasks, id: \.id) { child in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Task: \(child.title)")
                                .foregroundStyle(Color.appTextPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            ForEach(manager.userTasks.filter { $0.id != child.id }, id: \.id) { parent in
                                Toggle(
                                    "Depends on: \(parent.title)",
                                    isOn: Binding(
                                        get: { manager.taskDependencies[child.id, default: []].contains(parent.id) },
                                        set: { manager.updateDependency(child: child.id, dependsOn: parent.id, enabled: $0) }
                                    )
                                )
                                .tint(Color.appAccent)
                                .foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        .padding(14)
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(16)
        }
        .appScreenBackground()
        .navigationTitle("Dependencies")
    }
}

struct EfficiencyEvaluatorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EfficiencyEvaluatorViewModel

    init(manager: TaskManager) {
        _viewModel = StateObject(wrappedValue: EfficiencyEvaluatorViewModel(manager: manager))
    }

    var body: some View {
        ActivityContainer(title: "Efficiency Evaluator") {
            Picker("Task", selection: $viewModel.selectedTaskID) {
                Text("Choose Task").tag(Optional<UUID>.none)
                ForEach(viewModel.availableTasks) { task in
                    Text(task.title).tag(Optional(task.id))
                }
            }
            .pickerStyle(.menu)
            .tint(Color.appPrimary)
            .foregroundStyle(Color.appTextPrimary)

            TextField("", text: $viewModel.estimateText, prompt: Text("Estimated minutes").foregroundStyle(Color.appTextSecondary))
                .keyboardType(.numberPad)
                .foregroundStyle(Color.appTextPrimary)
                .padding(12)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            TextField("", text: $viewModel.actualText, prompt: Text("Actual minutes").foregroundStyle(Color.appTextSecondary))
                .keyboardType(.numberPad)
                .foregroundStyle(Color.appTextPrimary)
                .padding(12)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Button("Add Entry") { viewModel.submitEntry() }.buttonStyle(PrimaryButtonStyle())
            BarChartView(values: viewModel.entries.map { min(1, $0.estimate / max($0.actual, 1)) }).frame(height: 160).padding(12).background(Color.appSurface).clipShape(RoundedRectangle(cornerRadius: 12))
            Button("Calculate Stars") { viewModel.finish() }.buttonStyle(PrimaryButtonStyle())
            if viewModel.didFinish {
                CompletionResultView(
                    stars: viewModel.earnedStars,
                    title: "Evaluation Complete",
                    statPairs: [("Precision", "\(Int(viewModel.precision * 100))%"), ("Entries", "\(viewModel.entries.count)")],
                    nextTitle: "Next Session",
                    secondaryTitle: "View Timeline",
                    onNext: { viewModel.resetSession() },
                    onSecondary: { dismiss() }
                )
            }
        }
    }
}

struct StrategicSprintPlannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: StrategicSprintViewModel

    init(manager: TaskManager) {
        _viewModel = StateObject(wrappedValue: StrategicSprintViewModel(manager: manager))
    }

    var body: some View {
        ActivityContainer(title: "Strategic Sprint Planner") {
            Text("Elapsed: \(viewModel.elapsedSeconds)s").foregroundStyle(Color.appTextSecondary).lineLimit(1).minimumScaleFactor(0.7)
            ForEach(viewModel.orderedTasks) { task in
                HStack {
                    Text(task.title).foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
                    Spacer()
                    Button(viewModel.selectedIDs.contains(task.id) ? "Selected" : "Select") { viewModel.toggleTask(task) }.buttonStyle(.bordered).tint(.appAccent)
                    Button("Up") { viewModel.moveTaskUp(task) }.buttonStyle(.bordered).tint(.appPrimary)
                }
                .padding(12)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Button("Complete Sprint") { viewModel.finish() }.buttonStyle(PrimaryButtonStyle())
            if viewModel.didFinish {
                CompletionResultView(
                    stars: viewModel.earnedStars,
                    title: "Sprint Complete",
                    statPairs: [("Priority Completion", "\(Int(viewModel.completionRate * 100))%"), ("Selected Tasks", "\(viewModel.selectedIDs.count)")],
                    nextTitle: "Next Session",
                    secondaryTitle: "View Timeline",
                    onNext: { viewModel.resetSession() },
                    onSecondary: { dismiss() }
                )
            }
        }
    }
}

struct CompletionResultView: View {
    let stars: Int
    let title: String
    let statPairs: [(String, String)]
    let nextTitle: String
    let secondaryTitle: String
    let onNext: () -> Void
    let onSecondary: () -> Void
    @State private var visibleStars = 0
    @State private var showBanner = false

    var body: some View {
        VStack(spacing: 14) {
            Text(title).foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    Text(index < visibleStars ? "★" : "☆").font(.system(size: 34)).foregroundStyle(Color.appPrimary).shadow(color: Color.appAccent.opacity(index < visibleStars ? 0.8 : 0), radius: 10)
                }
            }
            if showBanner {
                Text("Achievement Unlocked").frame(maxWidth: .infinity).padding(12).background(Color.appAccent.opacity(0.25)).foregroundStyle(Color.appTextPrimary).clipShape(RoundedRectangle(cornerRadius: 10)).transition(.move(edge: .top))
            }
            ForEach(statPairs, id: \.0) { pair in
                HStack {
                    Text(pair.0).foregroundStyle(Color.appTextSecondary).lineLimit(1).minimumScaleFactor(0.7)
                    Spacer()
                    Text(pair.1).foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            HStack(spacing: 10) {
                Button(nextTitle, action: onNext).buttonStyle(PrimaryButtonStyle())
                Button(secondaryTitle, action: onSecondary).buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(14)
        .appCardStyle(cornerRadius: 14)
        .onAppear {
            for index in 0..<stars {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) { withAnimation(.spring()) { visibleStars = index + 1 } }
            }
            withAnimation(.spring().delay(0.5)) { showBanner = true }
        }
    }
}

struct AchievementBanner: View {
    let achievement: Achievement

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(achievement.title).foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
            Text(achievement.subtitle).foregroundStyle(Color.appTextSecondary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle(cornerRadius: 12)
    }
}

struct BarChartView: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 6).fill(Color.appAccent).frame(height: max(8, geo.size.height * value)).frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

struct ActivityContainer<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
                content
            }
            .padding(16)
        }
        .appScreenBackground()
        .navigationTitle("Activity")
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                LinearGradient(
                    colors: [Color.appPrimary.opacity(configuration.isPressed ? 0.85 : 1), Color.appAccent.opacity(configuration.isPressed ? 0.75 : 0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(Color.appBackground)
            .shadow(color: Color.appAccent.opacity(0.35), radius: 10, x: 0, y: 6)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                LinearGradient(
                    colors: [Color.appSurface.opacity(configuration.isPressed ? 0.8 : 1), Color.appBackground.opacity(configuration.isPressed ? 0.7 : 0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(Color.appTextPrimary)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appAccent, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

func card(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title).foregroundStyle(Color.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
        Text(subtitle).foregroundStyle(Color.appTextSecondary).lineLimit(1).minimumScaleFactor(0.7)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .appCardStyle(cornerRadius: 16)
}

extension View {
    func appCardStyle(cornerRadius: CGFloat = 14) -> some View {
        self
            .background(
                LinearGradient(
                    colors: [Color.appSurface, Color.appBackground.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.appAccent.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 8)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    func appScreenBackground() -> some View {
        self.background(
            LinearGradient(
                colors: [Color.appBackground, Color.appSurface.opacity(0.55), Color.appBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}
