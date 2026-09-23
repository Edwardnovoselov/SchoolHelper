import SwiftUI

/// Окно добавления / изменения кружка или секции.
struct ActivityEditView: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var activity: ExtraActivity
    private let isNew: Bool

    init(activity: ExtraActivity, isNew: Bool) {
        _activity = State(initialValue: activity)
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название, например «Футбол»", text: $activity.title)
                    Picker("День недели", selection: $activity.weekday) {
                        ForEach(Weekday.allDays, id: \.self) { day in
                            Text(Weekday.name(day)).tag(day)
                        }
                    }
                    DatePicker("Время", selection: $activity.time.date, displayedComponents: .hourAndMinute)
                }

                if !isNew {
                    Section {
                        Button("Удалить занятие", role: .destructive) {
                            store.deleteActivity(activity)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Новое занятие" : "Изменить занятие")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(trimmedTitle.isEmpty)
                }
            }
        }
    }

    private var trimmedTitle: String {
        activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        activity.title = trimmedTitle
        store.saveActivity(activity)
        dismiss()
    }
}
