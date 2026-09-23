import SwiftUI

/// Вкладка «Сегодня»: уроки на сегодня и на следующий учебный день.
/// Нажмите на урок — откроется окно, где можно записать ДЗ на этот урок.
struct TodayView: View {
    @EnvironmentObject private var store: DataStore
    @State private var editing: Homework? = nil

    var body: some View {
        NavigationStack {
            List {
                expiryWarning

                if store.data.lessons.isEmpty {
                    Text("Сначала заполните расписание во вкладке «Расписание».")
                        .foregroundStyle(.secondary)
                } else {
                    daySection(Date())
                    daySection(store.nextSchoolDay())
                    Text("Нажмите на урок, чтобы записать домашнее задание.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Сегодня")
            .sheet(item: $editing) { hw in
                HomeworkEditView(homework: hw,
                                 isNew: !store.data.homework.contains(where: { $0.id == hw.id }))
                    .environmentObject(store)
            }
        }
    }

    // MARK: - Напоминание о продлении (за 2 дня до окончания)

    @ViewBuilder
    private var expiryWarning: some View {
        if let days = AppExpiry.daysLeft(), days <= 2 {
            let title = days <= 0
                ? "Сегодня приложение перестанет открываться!"
                : "Через \(days) дн. приложение перестанет открываться."
            Section {
                Text(title)
                    .font(.headline)
                Text("Переустановите его через Sideloadly на компьютере — расписание и ДЗ сохранятся.")
                    .font(.subheadline)
            }
            .foregroundStyle(.red)
        }
    }

    // MARK: - Уроки, ДЗ и занятия на один день

    @ViewBuilder
    private func daySection(_ date: Date) -> some View {
        let key = DayKey.from(date)
        let weekday = Weekday.of(date)
        let lessons = store.data.lessons(on: weekday)
        let activities = store.data.activities(on: weekday)
        let homework = store.data.homework(on: key)

        Section(DayKey.title(key)) {
            if lessons.isEmpty && activities.isEmpty {
                Text("Уроков нет")
                    .foregroundStyle(.secondary)
            }
            ForEach(lessons) { lesson in
                Button {
                    // Если ДЗ на этот урок уже есть — открываем его, иначе создаём новое
                    editing = homework.first(where: { $0.lessonNumber == lesson.number })
                        ?? Homework(dayKey: key, lessonNumber: lesson.number, subject: lesson.subject, text: "")
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(lesson.number). \(lesson.subject)")
                            .foregroundStyle(Color.primary)
                        ForEach(homework.filter { $0.lessonNumber == lesson.number }) { hw in
                            Text("ДЗ: \(hw.text)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            ForEach(activities) { activity in
                Label("\(activity.time.text) — \(activity.title)", systemImage: "figure.run")
            }
        }
    }
}
