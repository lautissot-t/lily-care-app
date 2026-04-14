import SwiftUI

// MARK: - Colors

extension Color {
    static let lilyCream  = Color(red: 1.0,  green: 0.97, blue: 0.94)
    static let lilyCoral  = Color(red: 0.93, green: 0.42, blue: 0.32)
    static let lilyBrown  = Color(red: 0.28, green: 0.18, blue: 0.12)
    static let lilyPeach  = Color(red: 1.0,  green: 0.91, blue: 0.84)
    static let lilyMocha  = Color(red: 0.55, green: 0.38, blue: 0.28)
}

// MARK: - Models

struct Task: Identifiable, Codable, Sendable {
    var id: UUID
    var name: String
    var emoji: String
    var frequencyDays: Int?
    var lastCompleted: Date?
    var nextDue: Date
    var shopLink: String
    var notes: String
    var completions: [Completion]

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String = "🐾",
        frequencyDays: Int? = nil,
        lastCompleted: Date? = nil,
        nextDue: Date = Date(),
        shopLink: String = "",
        notes: String = "",
        completions: [Completion] = []
    ) {
        self.id = id; self.name = name; self.emoji = emoji
        self.frequencyDays = frequencyDays; self.lastCompleted = lastCompleted
        self.nextDue = nextDue; self.shopLink = shopLink
        self.notes = notes; self.completions = completions
    }

    var daysUntilDue: Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: nextDue)
        ).day ?? 0
    }

    var isUrgent: Bool { daysUntilDue <= 3 }

    var dueDateLabel: String {
        switch daysUntilDue {
        case ..<(-1): return "\(-daysUntilDue) days overdue"
        case -1:      return "1 day overdue"
        case 0:       return "Due today"
        case 1:       return "Due tomorrow"
        default:      return "Due in \(daysUntilDue) days"
        }
    }

    var frequencyLabel: String {
        guard let d = frequencyDays else { return "One-time" }
        switch d {
        case 7:   return "Every week"
        case 14:  return "Every 2 weeks"
        case 30:  return "Every month"
        case 60:  return "Every 2 months"
        case 90:  return "Every 3 months"
        case 180: return "Every 6 months"
        case 240: return "Every 8 months"
        case 365: return "Every year"
        default:  return "Every \(d) days"
        }
    }
}

struct Completion: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var date: Date
    var completedBy: String
    var notes: String
}

// MARK: - Store

@MainActor
@Observable
final class TaskStore {
    var tasks: [Task] = []

    init() {
        load()
        if tasks.isEmpty { tasks = Self.sampleTasks() }
    }

    var urgentTasks: [Task] {
        tasks.filter { $0.isUrgent }.sorted { $0.daysUntilDue < $1.daysUntilDue }
    }

    var upcomingTasks: [Task] {
        tasks.filter { !$0.isUrgent }.sorted { $0.daysUntilDue < $1.daysUntilDue }
    }

    func add(_ task: Task)    { tasks.append(task); save() }
    func delete(_ task: Task) { tasks.removeAll { $0.id == task.id }; save() }

    func update(_ task: Task) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[i] = task; save()
    }

    func checkIn(task: Task, completedBy: String, notes: String) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[i].completions.insert(
            Completion(date: Date(), completedBy: completedBy, notes: notes), at: 0)
        tasks[i].lastCompleted = Date()
        if let freq = task.frequencyDays {
            tasks[i].nextDue = Calendar.current.date(
                byAdding: .day, value: freq, to: Date()) ?? Date()
        }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        UserDefaults.standard.set(data, forKey: "lily_tasks")
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: "lily_tasks"),
              let decoded = try? JSONDecoder().decode([Task].self, from: data) else { return }
        tasks = decoded
    }

    static func sampleTasks() -> [Task] {
        let cal = Calendar.current
        let today = Date()
        func due(_ days: Int) -> Date { cal.date(byAdding: .day, value: days, to: today)! }
        return [
            Task(name: "Buy dog food",   emoji: "🍖", frequencyDays: 30,  nextDue: due(-1)),
            Task(name: "Buy canned food",emoji: "🥫", frequencyDays: 14,  nextDue: today),
            Task(name: "Medication",     emoji: "💊", frequencyDays: 14,  nextDue: due(2)),
            Task(name: "Vet appointment",emoji: "🏥",                     nextDue: due(15)),
            Task(name: "Grooming",       emoji: "✂️", frequencyDays: 60,  nextDue: due(28)),
            Task(name: "Buy collar",     emoji: "🎀",                     nextDue: due(45)),
        ]
    }
}

// MARK: - Home

struct ContentView: View {
    @State private var store = TaskStore()
    @State private var showAddTask = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.lilyCream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        headerView
                        if store.tasks.isEmpty {
                            emptyStateView
                        } else {
                            taskListView
                        }
                    }
                }

                addButton
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskView(store: store)
        }
    }

    var headerView: some View {
        VStack(spacing: 6) {
            Image("LilyHero")
                .resizable()
                .scaledToFill()
                .frame(width: 130, height: 130)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.lilyPeach, lineWidth: 4))
                .shadow(color: Color.lilyCoral.opacity(0.2), radius: 10, y: 4)
                .padding(.top, 64)
                .padding(.bottom, 4)

            Text("Lily's Care")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.lilyBrown)

            Text("Here's what Lily needs 🐾")
                .font(.subheadline)
                .foregroundStyle(Color.lilyMocha.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
    }

    var taskListView: some View {
        VStack(spacing: 28) {
            if !store.urgentTasks.isEmpty {
                taskSection("Needs attention ⚠️", tasks: store.urgentTasks)
            }
            if !store.upcomingTasks.isEmpty {
                taskSection("Coming up 📅", tasks: store.upcomingTasks)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 100)
    }

    func taskSection(_ title: String, tasks: [Task]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Color.lilyBrown)

            ForEach(tasks) { task in
                NavigationLink {
                    TaskDetailView(task: task, store: store)
                } label: {
                    TaskRowView(task: task)
                }
                .buttonStyle(.plain)
            }
        }
    }

    var emptyStateView: some View {
        VStack(spacing: 16) {
            Text("🎉").font(.system(size: 72))
            Text("All done!")
                .font(.system(.title2, design: .rounded).bold())
                .foregroundStyle(Color.lilyBrown)
            Text("Lily is all taken care of")
                .font(.subheadline)
                .foregroundStyle(Color.lilyMocha.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    var addButton: some View {
        Button { showAddTask = true } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.lilyCoral)
                .clipShape(Circle())
                .shadow(color: Color.lilyCoral.opacity(0.4), radius: 10, y: 4)
        }
        .padding(.trailing, 24)
        .padding(.bottom, 36)
    }
}

// MARK: - Task Row

struct TaskRowView: View {
    let task: Task

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(task.isUrgent ? Color.lilyPeach : Color.white)
                    .frame(width: 50, height: 50)
                    .shadow(color: .black.opacity(0.04), radius: 4)
                Text(task.emoji).font(.system(size: 26))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(task.name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.lilyBrown)
                Text(task.dueDateLabel)
                    .font(.caption)
                    .foregroundStyle(task.daysUntilDue < 0 ? Color.lilyCoral : Color.lilyMocha)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.lilyMocha.opacity(0.3))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(task.isUrgent ? Color.lilyPeach.opacity(0.45) : Color.white)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }
}

// MARK: - Task Detail

struct TaskDetailView: View {
    let task: Task
    let store: TaskStore
    @State private var showCheckIn = false
    @State private var showEdit = false

    var body: some View {
        ZStack {
            Color.lilyCream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    heroCard
                    infoCard
                    checkInButton
                    if !task.completions.isEmpty { historySection }
                }
                .padding(.top, 20)
                .padding(.bottom, 48)
            }
        }
        .navigationTitle(task.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEdit = true }
                    .foregroundStyle(Color.lilyCoral)
            }
        }
        .sheet(isPresented: $showCheckIn) {
            CheckInView(task: task, store: store)
        }
        .sheet(isPresented: $showEdit) {
            AddTaskView(store: store, editing: task)
        }
    }

    var heroCard: some View {
        VStack(spacing: 8) {
            Text(task.emoji).font(.system(size: 60))
            Text(task.name)
                .font(.system(.title2, design: .rounded).bold())
                .foregroundStyle(Color.lilyBrown)
            Text(task.dueDateLabel)
                .font(.subheadline)
                .foregroundStyle(task.daysUntilDue < 0 ? Color.lilyCoral : Color.lilyMocha)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 10)
        )
        .padding(.horizontal, 20)
    }

    var infoCard: some View {
        VStack(spacing: 0) {
            InfoRow(icon: "arrow.clockwise", label: "Frequency", value: task.frequencyLabel)
            if let last = task.lastCompleted {
                Divider().padding(.leading, 52)
                InfoRow(icon: "clock", label: "Last done",
                        value: last.formatted(.dateTime.month(.wide).day().year()))
            }
            Divider().padding(.leading, 52)
            InfoRow(icon: "calendar", label: "Next due",
                    value: task.nextDue.formatted(.dateTime.month(.wide).day().year()))
            if !task.shopLink.isEmpty {
                Divider().padding(.leading, 52)
                InfoRow(icon: "cart", label: "Shop link", value: task.shopLink)
            }
            if !task.notes.isEmpty {
                Divider().padding(.leading, 52)
                InfoRow(icon: "note.text", label: "Notes", value: task.notes)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 8)
        )
        .padding(.horizontal, 20)
    }

    var checkInButton: some View {
        Button { showCheckIn = true } label: {
            Label("Mark as done", systemImage: "checkmark.circle.fill")
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.lilyCoral)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 20)
    }

    var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Color.lilyBrown)
                .padding(.horizontal, 20)

            ForEach(task.completions.prefix(10)) { c in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.lilyPeach).frame(width: 38, height: 38)
                        Text("✓")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.lilyCoral)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.completedBy.isEmpty ? "Someone" : c.completedBy)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.lilyBrown)
                        Text(c.date.formatted(.dateTime.month(.wide).day().year()))
                            .font(.caption)
                            .foregroundStyle(Color.lilyMocha)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(Color.lilyCoral)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.lilyMocha)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.lilyBrown)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Check-In

struct CheckInView: View {
    let task: Task
    let store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @State private var completedBy = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lilyCream.ignoresSafeArea()

                VStack(spacing: 28) {
                    VStack(spacing: 8) {
                        Text(task.emoji).font(.system(size: 56))
                        Text("Marking done:")
                            .font(.subheadline)
                            .foregroundStyle(Color.lilyMocha)
                        Text(task.name)
                            .font(.system(.title3, design: .rounded).bold())
                            .foregroundStyle(Color.lilyBrown)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Who did it?").fieldCaption()
                            TextField("Your name", text: $completedBy)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .formRow()

                        Divider().padding(.leading, 16)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes (optional)").fieldCaption()
                            TextField("Any notes...", text: $notes, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .formRow()
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.05), radius: 8)
                    )
                    .padding(.horizontal, 20)

                    Button {
                        store.checkIn(task: task, completedBy: completedBy, notes: notes)
                        dismiss()
                    } label: {
                        Text("Done! 🐾")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.lilyCoral)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .navigationTitle("Check In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.lilyCoral)
                }
            }
        }
    }
}

// MARK: - Add / Edit Task

struct AddTaskView: View {
    let store: TaskStore
    var editing: Task? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "🐾"
    @State private var isRecurring = true
    @State private var frequencyDays = 30
    @State private var nextDue = Date()
    @State private var shopLink = ""
    @State private var notes = ""

    let emojiOptions = ["🐾","🍖","🥫","💊","🏥","✂️","🎀","🛁","🦴","🐶","⭐","📦","🧴","🪮","🎾","🏅"]
    let freqOptions  = [7, 14, 30, 60, 90, 180, 240, 365]

    var isEditing: Bool { editing != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lilyCream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        emojiPicker
                        formCard
                        saveButton
                        if isEditing { deleteButton }
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.lilyCoral)
                }
            }
            .onAppear { prefill() }
        }
    }

    var emojiPicker: some View {
        VStack(spacing: 12) {
            Text(emoji).font(.system(size: 56))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                ForEach(emojiOptions, id: \.self) { e in
                    Button { emoji = e } label: {
                        Text(e).font(.title3)
                            .frame(width: 40, height: 40)
                            .background(emoji == e ? Color.lilyPeach : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white)
            .shadow(color: .black.opacity(0.05), radius: 8))
        .padding(.horizontal, 20)
    }

    var formCard: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Task name").fieldCaption()
                TextField("e.g. Buy dog food", text: $name)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .formRow()

            Divider().padding(.leading, 16)

            HStack {
                Text("Recurring task").fieldCaption()
                Spacer()
                Toggle("", isOn: $isRecurring)
                    .labelsHidden()
                    .tint(Color.lilyCoral)
            }
            .formRow()

            if isRecurring {
                Divider().padding(.leading, 16)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Repeat every").fieldCaption()
                        Picker("", selection: $frequencyDays) {
                            ForEach(freqOptions, id: \.self) { d in
                                Text(freqLabel(d)).tag(d)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.lilyCoral)
                        .padding(.leading, -8)
                    }
                    Spacer()
                }
                .formRow()
            }

            Divider().padding(.leading, 16)

            HStack {
                Text("Next due").fieldCaption()
                Spacer()
                DatePicker("", selection: $nextDue, displayedComponents: .date)
                    .labelsHidden()
                    .tint(Color.lilyCoral)
            }
            .formRow()

            Divider().padding(.leading, 16)

            VStack(alignment: .leading, spacing: 4) {
                Text("Shop link (optional)").fieldCaption()
                TextField("https://...", text: $shopLink)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .formRow()

            Divider().padding(.leading, 16)

            VStack(alignment: .leading, spacing: 4) {
                Text("Notes (optional)").fieldCaption()
                TextField("Any notes...", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .formRow()
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(.white)
            .shadow(color: .black.opacity(0.05), radius: 8))
        .padding(.horizontal, 20)
    }

    var saveButton: some View {
        Button { saveTask() } label: {
            Text(isEditing ? "Save changes" : "Add task")
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(name.isEmpty ? Color.gray.opacity(0.3) : Color.lilyCoral)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(name.isEmpty)
        .padding(.horizontal, 20)
    }

    var deleteButton: some View {
        Button(role: .destructive) {
            if let t = editing { store.delete(t) }
            dismiss()
        } label: {
            Text("Delete task")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.red.opacity(0.75))
        }
    }

    func freqLabel(_ days: Int) -> String {
        switch days {
        case 7:   return "Every week"
        case 14:  return "Every 2 weeks"
        case 30:  return "Every month"
        case 60:  return "Every 2 months"
        case 90:  return "Every 3 months"
        case 180: return "Every 6 months"
        case 240: return "Every 8 months"
        case 365: return "Every year"
        default:  return "Every \(days) days"
        }
    }

    func prefill() {
        guard let t = editing else { return }
        name = t.name; emoji = t.emoji
        isRecurring = t.frequencyDays != nil
        frequencyDays = t.frequencyDays ?? 30
        nextDue = t.nextDue; shopLink = t.shopLink; notes = t.notes
    }

    func saveTask() {
        if var t = editing {
            t.name = name; t.emoji = emoji
            t.frequencyDays = isRecurring ? frequencyDays : nil
            t.nextDue = nextDue; t.shopLink = shopLink; t.notes = notes
            store.update(t)
        } else {
            store.add(Task(name: name, emoji: emoji,
                          frequencyDays: isRecurring ? frequencyDays : nil,
                          nextDue: nextDue, shopLink: shopLink, notes: notes))
        }
        dismiss()
    }
}

// MARK: - View Helpers

extension View {
    func formRow() -> some View {
        self.padding(.horizontal, 16).padding(.vertical, 12)
    }
}

extension Text {
    func fieldCaption() -> some View {
        self.font(.caption.weight(.semibold))
            .foregroundStyle(Color.lilyMocha)
            .textCase(.uppercase)
    }
}

#Preview {
    ContentView()
}
