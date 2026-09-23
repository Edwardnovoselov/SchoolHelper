import SwiftUI

/// Вкладка «ДЗ»: список домашних заданий по дням.
/// Нажмите «+», чтобы записать ДЗ; на строку — изменить; смахните влево — удалить.
struct HomeworkView: View {
    @EnvironmentObject private var store: DataStore
    @State private var editing: Homework? = nil

    var body: some View {
        NavigationStack {
            List {
                let days = store.homeworkByDay
                if days.isEmpty {
                    Text("Домашних заданий нет. Нажмите «+» вверху, чтобы записать.")
                        .foregroundStyle(.secondary)
                }

                ForEach(days) { day in
                    Section(DayKey.title(day.dayKey)) {
                        ForEach(day.items) { hw in
                            Button {
                                editing = hw
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(hw.lessonNumber). \(hw.subject)")
                                        .font(.headline)
                                    Text(hw.text)
                                }
                                .foregroundStyle(Color.primary)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                store.deleteHomework(day.items[index])
                            }
                        }
                    }
                }

                Text("ДЗ удаляется само, когда день урока закончился.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Домашнее задание")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editing = store.newHomework()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editing) { hw in
                HomeworkEditView(homework: hw,
                                 isNew: !store.data.homework.contains(where: { $0.id == hw.id }))
                    .environmentObject(store)
            }
        }
    }
}
