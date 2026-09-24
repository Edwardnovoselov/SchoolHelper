import SwiftUI
import UIKit
import Combine

/// Главный экран с вкладками внизу.
struct ContentView: View {
    @EnvironmentObject private var store: DataStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            TodayView()
                .tabItem { Label("Сегодня", systemImage: "sun.max") }
                .tag(0)
            ScheduleView()
                .tabItem { Label("Расписание", systemImage: "calendar") }
                .tag(1)
            HomeworkView()
                .tabItem { Label("ДЗ", systemImage: "book") }
                .tag(2)
            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
                .tag(3)
        }
        // iOS сообщает о смене дня (полночь), если приложение в этот момент открыто
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            store.dayChanged()
        }
    }
}
