import SwiftUI
import UserNotifications

/// Точка входа в приложение.
@main
struct SchoolHelperApp: App {
    @StateObject private var store = DataStore.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Чтобы уведомления показывались, даже когда приложение открыто на экране
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task {
                    // При первом запуске iOS спросит разрешение на уведомления
                    await NotificationManager.requestPermission()
                    await store.refresh()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            // Приложение открыли: чистим старое ДЗ и заново планируем уведомления
            if phase == .active {
                Task { await store.refresh() }
            }
        }
    }
}
