import SwiftUI

/// Какой день недели сейчас редактируем (нужно для окна редактирования).
private struct EditingDay: Identifiable {
    let weekday: Int
    var id: Int { weekday }
}

/// Вкладка «Расписание»: уроки по дням (пн–сб) и кружки/секции.
struct ScheduleView: View {
    @EnvironmentObject private var store: DataStore
    @State private var editingDay: EditingDay? = nil
    @State private var editingActivity: ExtraActivity? = nil

    var body: some View {
        NavigationStack {
            List {
                // Уроки: по строке на каждый учебный день
                Section {
                    ForEach(Weekday.schoolDays, id: \.self) { weekday in
                        Button {
                            editingDay = EditingDay(weekday: weekday)
                        } label: {
                            dayRow(weekday)
                        }
                    }
                } header: {
                    Text("Уроки")
                } footer: {
                    Text("Нажмите на день, чтобы заполнить или изменить уроки.")
                }

                // Дополнительные занятия после школы
                Section {
                    let activities = store.data.sortedActivities
                    ForEach(activities) { activity in
                        Button {
                            editingActivity = activity
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(activity.title)
                                    .foregroundStyle(Color.primary)
                                Text("\(Weekday.name(activity.weekday)), \(activity.time.text)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            store.deleteActivity(activities[index])
                        }
                    }

                    Button {
                        editingActivity = ExtraActivity(title: "", weekday: 1,
                                                        time: TimeOfDay(hour: 15, minute: 0))
                    } label: {
                        Label("Добавить занятие", systemImage: "plus")
                    }
                } header: {
                    Text("Кружки и секции")
                } footer: {
                    Text("Чтобы удалить занятие, смахните его влево.")
                }
            }
            .navigationTitle("Расписание")
            .sheet(item: $editingDay) { day in
                DayScheduleEditView(weekday: day.weekday, lessons: store.data.lessons(on: day.weekday))
                    .environmentObject(store)
            }
            .sheet(item: $editingActivity) { activity in
                ActivityEditView(activity: activity,
                                 isNew: !store.data.activities.contains(where: { $0.id == activity.id }))
                    .environmentObject(store)
            }
        }
    }

    /// Строка дня: название и список уроков.
    private func dayRow(_ weekday: Int) -> some View {
        let lessons = store.data.lessons(on: weekday)
        let summary = lessons.isEmpty
            ? "не заполнено"
            : lessons.map { "\($0.number). \($0.subject)" }.joined(separator: "\n")

        return VStack(alignment: .leading, spacing: 4) {
            Text(Weekday.name(weekday))
                .font(.headline)
                .foregroundStyle(Color.primary)
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
