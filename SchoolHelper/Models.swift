import Foundation

// MARK: - Время дня

/// Время без даты, например 07:00 или 15:30.
struct TimeOfDay: Codable, Equatable {
    var hour: Int
    var minute: Int

    /// Текстом: "07:05"
    var text: String { String(format: "%02d:%02d", hour, minute) }

    /// Минут с полуночи — удобно для сортировки
    var totalMinutes: Int { hour * 60 + minute }

    /// Нужна для DatePicker: превращаем время в дату (сегодняшнюю) и обратно.
    var date: Date {
        get {
            Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        }
        set {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            hour = parts.hour ?? 0
            minute = parts.minute ?? 0
        }
    }
}

// MARK: - Расписание

/// Один урок в расписании.
struct Lesson: Identifiable, Codable, Equatable {
    var id = UUID()
    var weekday: Int      // 1 = понедельник … 6 = суббота
    var number: Int       // порядковый номер урока: 1, 2, 3…
    var subject: String   // название предмета
}

/// Дополнительное занятие после школы (кружок, секция).
struct ExtraActivity: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var weekday: Int      // 1 = понедельник … 7 = воскресенье
    var time: TimeOfDay
}

// MARK: - Домашнее задание

/// Домашнее задание на конкретный урок конкретного дня.
struct Homework: Identifiable, Codable, Equatable {
    var id = UUID()
    var dayKey: String     // день урока, строкой: "2026-09-25"
    var lessonNumber: Int  // номер урока в этот день
    var subject: String    // предмет (запоминаем, чтобы показать в уведомлении)
    var text: String       // само задание
}

/// Все ДЗ на один день (для вкладки «ДЗ»).
struct HomeworkDay: Identifiable {
    let dayKey: String
    let items: [Homework]
    var id: String { dayKey }
}

// MARK: - Настройки

/// Настройки уведомлений.
struct NotificationSettings: Codable, Equatable {
    var morningEnabled = true
    var morningTime = TimeOfDay(hour: 7, minute: 0)
    var eveningEnabled = true
    var eveningTime = TimeOfDay(hour: 17, minute: 30)
    /// Присылать ли уведомления в дни без уроков и занятий (например, в воскресенье)
    var notifyOnDaysOff = false
}

// MARK: - Все данные приложения

/// Всё, что приложение хранит на телефоне. Сохраняется одним JSON-файлом.
struct AppData: Codable, Equatable {
    var lessons: [Lesson] = []
    var activities: [ExtraActivity] = []
    var homework: [Homework] = []
    var settings = NotificationSettings()
}

// Удобные выборки из данных
extension AppData {
    /// Уроки в заданный день недели, по порядку номеров.
    func lessons(on weekday: Int) -> [Lesson] {
        lessons.filter { $0.weekday == weekday }.sorted { $0.number < $1.number }
    }

    /// Кружки и секции в заданный день недели, по времени.
    func activities(on weekday: Int) -> [ExtraActivity] {
        activities.filter { $0.weekday == weekday }.sorted { $0.time.totalMinutes < $1.time.totalMinutes }
    }

    /// Все кружки: сначала по дню недели, потом по времени.
    var sortedActivities: [ExtraActivity] {
        activities.sorted {
            ($0.weekday, $0.time.totalMinutes) < ($1.weekday, $1.time.totalMinutes)
        }
    }

    /// ДЗ на конкретный день, по номерам уроков.
    func homework(on dayKey: String) -> [Homework] {
        homework.filter { $0.dayKey == dayKey }.sorted { $0.lessonNumber < $1.lessonNumber }
    }
}
