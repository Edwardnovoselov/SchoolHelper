import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Вкладка «Настройки»: время уведомлений, проверка, продление и резервная копия.
struct SettingsView: View {
    @EnvironmentObject private var store: DataStore
    @State private var pendingCount = 0
    @State private var notificationsDenied = false
    @State private var showImporter = false
    @State private var alertText = ""
    @State private var showAlert = false

    var body: some View {
        NavigationStack {
            Form {
                // Предупреждение, если уведомления запрещены
                if notificationsDenied {
                    Section {
                        Text("Уведомления запрещены. Разрешите их в настройках iPhone, иначе напоминания не придут.")
                            .foregroundStyle(.red)
                        Button("Открыть настройки iPhone") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }

                Section {
                    Toggle("Включено", isOn: $store.data.settings.morningEnabled)
                    DatePicker("Время", selection: $store.data.settings.morningTime.date,
                               displayedComponents: .hourAndMinute)
                } header: {
                    Text("Утреннее уведомление")
                } footer: {
                    Text("Уроки на сегодня, кружки и секции.")
                }

                Section {
                    Toggle("Включено", isOn: $store.data.settings.eveningEnabled)
                    DatePicker("Время", selection: $store.data.settings.eveningTime.date,
                               displayedComponents: .hourAndMinute)
                } header: {
                    Text("Вечернее уведомление")
                } footer: {
                    Text("Два уведомления: расписание на завтра и отдельно домашнее задание на завтра.")
                }

                Section {
                    Toggle("Уведомлять в дни без уроков", isOn: $store.data.settings.notifyOnDaysOff)
                } footer: {
                    Text("Если выключено, в воскресенье и в другие пустые дни уведомления не приходят.")
                }

                Section {
                    Button("Тест: утреннее уведомление") { sendTest(evening: false) }
                    Button("Тест: вечернее уведомление") { sendTest(evening: true) }
                    LabeledContent("Запланировано уведомлений", value: "\(pendingCount)")
                } header: {
                    Text("Проверка")
                } footer: {
                    Text("Тестовое уведомление придёт через 5 секунд. Можно заблокировать телефон и подождать.")
                }

                Section {
                    if let expiry = AppExpiry.date {
                        LabeledContent("Работает до", value: expiry.formatted(date: .abbreviated, time: .shortened))
                    } else {
                        Text("Дата неизвестна")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Продление")
                } footer: {
                    Text("С бесплатным Apple ID приложение работает 7 дней. Чтобы продлить, переустановите его через Sideloadly на компьютере — расписание и ДЗ сохранятся. Накануне придёт напоминание.")
                }

                Section {
                    ShareLink(item: DataStore.fileURL) {
                        Label("Сохранить копию данных", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("Восстановить из копии", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Резервная копия")
                } footer: {
                    Text("Копию можно сохранить в «Файлы» или отправить себе в мессенджер. Восстановление заменит текущие расписание и ДЗ.")
                }
            }
            .navigationTitle("Настройки")
            .task { await reloadStatus() }
            .onChange(of: store.data.settings) {
                // Уведомления перепланируются через полсекунды — потом обновим счётчик
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    await reloadStatus()
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    alertText = store.importBackup(from: url)
                case .failure:
                    alertText = "Не удалось открыть файл."
                }
                showAlert = true
            }
            .alert(alertText, isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func sendTest(evening: Bool) {
        let data = store.data
        Task { await NotificationManager.sendTest(evening: evening, data: data) }
    }

    @MainActor
    private func reloadStatus() async {
        pendingCount = await NotificationManager.pendingCount()
        notificationsDenied = await NotificationManager.isDenied()
    }
}
