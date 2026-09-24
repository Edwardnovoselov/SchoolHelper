import Foundation
import UserNotifications

/// Планирует локальные уведомления (утро и вечер) на несколько дней вперёд.
///
/// Каждое уведомление — отдельное, на конкретную дату, с уже готовым текстом.
/// Когда данные меняются (расписание, ДЗ, настройки) или приложение открывают,
/// все уведомления собираются заново с актуальным текстом.
@MainActor
enum NotificationManager {
    /// На сколько дней вперёд планируем. iOS хранит максимум 64 уведомления, у нас не больше 3 × 14 + 1 = 43.
    static let daysAhead = 14

    private static var center: UNUserNotificationCenter { .current() }

    /// Спросить разрешение на уведомления (окно iOS покажет только один раз).
    static func requestPermission() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Ошибка запроса разрешения на уведомления: \(error)")
        }
    }

    /// true — пользователь запретил уведомления в настройках iPhone.
    static func isDenied() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .denied
    }

    /// Сколько уведомлений сейчас запланировано (для экрана настроек).
    static func pendingCount() async -> Int {
        let pending = await center.pendingNotificationRequests()
        return pending.filter { !$0.identifier.hasPrefix("test") }.count
    }

    /// Главная функция: заново собрать все уведомления из актуальных данных.
    static func reschedule(with data: AppData) async {
        let now = Date()
        let today = now.startOfDay
        var requests: [UNNotificationRequest] = []

        for offset in 0..<daysAhead {
            let day = today.addingDays(offset)
            let key = DayKey.from(day)

            if data.settings.morningEnabled,
               let text = NotificationTexts.morning(for: day, data: data),
               let request = makeRequest(id: "morning-\(key)", text: text, day: day,
                                         time: data.settings.morningTime, now: now) {
                requests.append(request)
            }

            if data.settings.eveningEnabled,
               let text = NotificationTexts.evening(for: day, data: data),
               let request = makeRequest(id: "evening-\(key)", text: text, day: day,
                                         time: data.settings.eveningTime, now: now) {
                requests.append(request)
            }

            // ДЗ — отдельным уведомлением на 5 секунд позже и без звука (чтобы не звенело дважды)
            if data.settings.eveningEnabled,
               let text = NotificationTexts.eveningHomework(for: day, data: data),
               let request = makeRequest(id: "homework-\(key)", text: text, day: day,
                                         time: data.settings.eveningTime, second: 5,
                                         withSound: false, now: now) {
                requests.append(request)
            }
        }

        // Напоминание продлить приложение: накануне дня окончания, в 19:00
        if let expiry = AppExpiry.date {
            let text = NotificationText(
                title: "⚠️ Продлите приложение «Школа»",
                body: "Оно работает до \(expiry.formatted(date: .abbreviated, time: .shortened)). "
                    + "Переустановите его через Sideloadly на компьютере — расписание и ДЗ сохранятся."
            )
            if let request = makeRequest(id: "expiry", text: text, day: expiry.startOfDay.addingDays(-1),
                                         time: TimeOfDay(hour: 19, minute: 0), now: now) {
                requests.append(request)
            }
        }

        // Убираем запланированные уведомления, которых больше нет в новом списке (тестовые не трогаем)
        let newIDs = Set(requests.map(\.identifier))
        let pending = await center.pendingNotificationRequests()
        let obsolete = pending.map(\.identifier).filter { !newIDs.contains($0) && !$0.hasPrefix("test") }
        center.removePendingNotificationRequests(withIdentifiers: obsolete)

        // Добавляем новые. Уведомление с тем же id просто заменяется новым текстом.
        for request in requests {
            do {
                try await center.add(request)
            } catch {
                print("Не удалось запланировать уведомление \(request.identifier): \(error)")
            }
        }
    }

    /// Тестовые уведомления через 5 секунд — с тем же текстом, что придёт утром или вечером.
    static func sendTest(evening: Bool, data: AppData) async {
        let now = Date()
        let tests: [(id: String, text: NotificationText?, delay: TimeInterval, withSound: Bool)]
        if evening {
            tests = [
                ("test-evening", NotificationTexts.evening(for: now, data: data, force: true), 5, true),
                ("test-homework", NotificationTexts.eveningHomework(for: now, data: data), 10, false),
            ]
        } else {
            tests = [("test-morning", NotificationTexts.morning(for: now, data: data, force: true), 5, true)]
        }

        for test in tests {
            guard let text = test.text else { continue }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: test.delay, repeats: false)
            let content = makeContent(text, thread: test.id, withSound: test.withSound)
            let request = UNNotificationRequest(identifier: test.id, content: content, trigger: trigger)
            do {
                try await center.add(request)
            } catch {
                print("Не удалось отправить тестовое уведомление: \(error)")
            }
        }
    }

    // MARK: - Вспомогательное

    /// Уведомление на конкретный день и время. nil — если это время уже прошло.
    private static func makeRequest(id: String, text: NotificationText, day: Date, time: TimeOfDay,
                                    second: Int = 0, withSound: Bool = true,
                                    now: Date) -> UNNotificationRequest? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        components.hour = time.hour
        components.minute = time.minute
        components.second = second

        guard let fireDate = Calendar.current.date(from: components), fireDate > now else {
            return nil
        }

        // Группа уведомлений: "morning", "evening", "homework"… Разные группы iOS
        // не складывает в одну стопку, поэтому расписание и ДЗ видны по отдельности.
        let thread = String(id.prefix(while: { $0 != "-" }))
        let content = makeContent(text, thread: thread, withSound: withSound)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    private static func makeContent(_ text: NotificationText, thread: String,
                                    withSound: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = text.title
        content.body = text.body
        content.threadIdentifier = thread
        if withSound {
            content.sound = .default
        }
        return content
    }
}

/// Нужен, чтобы уведомление показывалось, даже когда приложение открыто на экране.
@MainActor
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// Нажали на уведомление — открываем вкладку «Сегодня».
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        await DataStore.shared.openTodayTab()
    }
}
