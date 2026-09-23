import SwiftUI
import UIKit
import Combine

/// Главный экран с вкладками внизу.
struct ContentView: View {
    @EnvironmentObject private var store: DataStore

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Сегодня", systemImage: "sun.max") }
            ScheduleView()
                .tabItem { Label("Расписание", systemImage: "calendar") }
            HomeworkView()
                .tabItem { Label("ДЗ", systemImage: "book") }
            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
        }
        // iOS сообщает о смене дня (полночь), если приложение в этот момент открыто
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            store.dayChanged()
        }
    }
}
