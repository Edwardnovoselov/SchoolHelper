import SwiftUI

/// Окно редактирования уроков одного дня: строки «1.», «2.», … — впишите предметы по порядку.
struct DayScheduleEditView: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss

    /// Сколько строк для уроков показываем
    private static let maxLessons = 8

    private let weekday: Int
    /// subjects[0] — 1-й урок, subjects[1] — 2-й и т. д. Пустая строка — урока нет.
    @State private var subjects: [String]

    init(weekday: Int, lessons: [Lesson]) {
        self.weekday = weekday
        var list = Array(repeating: "", count: Self.maxLessons)
        for lesson in lessons where (1...Self.maxLessons).contains(lesson.number) {
            list[lesson.number - 1] = lesson.subject
        }
        _subjects = State(initialValue: list)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(0..<Self.maxLessons, id: \.self) { index in
                        HStack {
                            Text("\(index + 1).")
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .leading)
                            TextField("нет урока", text: $subjects[index])

                            // Кнопка быстрого выбора предмета, который уже есть в расписании
                            let known = store.allSubjects
                            if !known.isEmpty {
                                Menu {
                                    ForEach(known, id: \.self) { subject in
                                        Button(subject) { subjects[index] = subject }
                                    }
                                } label: {
                                    Image(systemName: "list.bullet")
                                }
                            }
                        }
                    }
                } footer: {
                    Text("Впишите предметы по порядку. Пустая строка — урока нет. Кнопка справа — выбрать предмет, который уже есть в расписании.")
                }
            }
            .navigationTitle(Weekday.name(weekday))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                }
            }
        }
    }

    private func save() {
        store.setLessons(subjects, for: weekday)
        dismiss()
    }
}
