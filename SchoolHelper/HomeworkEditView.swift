import SwiftUI

/// Окно записи / изменения домашнего задания: выбираем день, урок и пишем задание.
struct HomeworkEditView: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var homework: Homework
    @State private var day: Date
    private let isNew: Bool

    init(homework: Homework, isNew: Bool) {
        _homework = State(initialValue: homework)
        _day = State(initialValue: DayKey.date(from: homework.dayKey) ?? Date())
        self.isNew = isNew
    }

    /// Уроки в выбранный день (из расписания)
    private var lessons: [Lesson] {
        store.data.lessons(on: Weekday.of(day))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("День урока", selection: $day, in: Date().startOfDay...,
                               displayedComponents: .date)

                    if lessons.isEmpty {
                        Text("В этот день нет уроков в расписании. Выберите другой день или сначала заполните расписание.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Урок", selection: $homework.lessonNumber) {
                            ForEach(lessons) { lesson in
                                Text("\(lesson.number). \(lesson.subject)").tag(lesson.number)
                            }
                        }
                    }
                }

                Section("Что задали") {
                    TextField("Например: стр. 45, № 3–5", text: $homework.text, axis: .vertical)
                        .lineLimit(3...10)
                }

                if !isNew {
                    Section {
                        Button("Удалить ДЗ", role: .destructive) {
                            store.deleteHomework(homework)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Новое ДЗ" : "Изменить ДЗ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear { fixLessonSelection() }
            .onChange(of: day) { fixLessonSelection() }
        }
    }

    /// Сохранять можно, если выбран урок и написан текст задания.
    private var canSave: Bool {
        let hasText = !homework.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasLesson = lessons.contains(where: { $0.number == homework.lessonNumber })
        return hasText && hasLesson
    }

    /// Если в выбранный день нет урока с таким номером — выбираем первый урок дня.
    private func fixLessonSelection() {
        if !lessons.contains(where: { $0.number == homework.lessonNumber }), let first = lessons.first {
            homework.lessonNumber = first.number
        }
    }

    private func save() {
        homework.dayKey = DayKey.from(day)
        homework.subject = lessons.first(where: { $0.number == homework.lessonNumber })?.subject ?? homework.subject
        homework.text = homework.text.trimmingCharacters(in: .whitespacesAndNewlines)
        store.saveHomework(homework)
        dismiss()
    }
}
