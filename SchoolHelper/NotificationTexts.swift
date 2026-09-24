import Foundation

/// Заголовок и текст одного уведомления.
struct NotificationText {
    let title: String
    let body: String
}

/// Собирает тексты уведомлений из расписания и ДЗ.
///
/// iOS показывает в свёрнутом уведомлении только заголовок и ~4 строки текста,
/// поэтому текст компактный: уроки — сплошной строкой, кружки — одной строкой,
/// а ДЗ вечером приходит отдельным уведомлением.
/// Полный текст виден, если нажать на уведомление и подержать.
enum NotificationTexts {

    /// Утро: уроки на сегодня + занятия после школы.
    /// Возвращает nil, если в этот день ничего нет и в настройках выключено «уведомлять в дни без уроков».
    /// force = true — собрать текст в любом случае (для тестовой кнопки).
    static func morning(for day: Date, data: AppData, force: Bool = false) -> NotificationText? {
        let weekday = Weekday.of(day)
        let lessons = data.lessons(on: weekday)
        let activities = data.activities(on: weekday)

        if lessons.isEmpty && activities.isEmpty && !data.settings.notifyOnDaysOff && !force {
            return nil
        }

        var lines: [String] = []
        lines.append(lessons.isEmpty ? "Уроков нет 🎉" : lessonsLine(lessons))
        if !activities.isEmpty {
            lines.append("После школы: " + activitiesLine(activities))
        }

        return NotificationText(
            title: "☀️ Сегодня \(Weekday.name(weekday).lowercased())",
            body: lines.joined(separator: "\n")
        )
    }

    /// Вечер, уведомление 1: расписание на завтра (уроки + кружки).
    static func evening(for day: Date, data: AppData, force: Bool = false) -> NotificationText? {
        let tomorrow = day.addingDays(1)
        let weekday = Weekday.of(tomorrow)
        let lessons = data.lessons(on: weekday)
        let activities = data.activities(on: weekday)
        let homework = data.homework(on: DayKey.from(tomorrow))

        if lessons.isEmpty && activities.isEmpty && homework.isEmpty && !data.settings.notifyOnDaysOff && !force {
            return nil
        }

        var lines: [String] = []
        lines.append(lessons.isEmpty ? "Уроков нет 🎉" : lessonsLine(lessons))
        if !activities.isEmpty {
            lines.append("После школы: " + activitiesLine(activities))
        }
        // Если ДЗ нет, отдельного уведомления про ДЗ не будет — напоминаем здесь
        if homework.isEmpty && !lessons.isEmpty {
            lines.append("ДЗ на завтра не записано")
        }

        return NotificationText(
            title: "📚 Завтра \(Weekday.name(weekday).lowercased())",
            body: lines.joined(separator: "\n")
        )
    }

    /// Вечер, уведомление 2: домашнее задание на завтра. nil — если ДЗ не записано.
    static func eveningHomework(for day: Date, data: AppData) -> NotificationText? {
        let tomorrow = day.addingDays(1)
        let lessons = data.lessons(on: Weekday.of(tomorrow))
        let homework = data.homework(on: DayKey.from(tomorrow))
        guard !homework.isEmpty else { return nil }

        // По строке на задание: "• Математика: стр. 45, № 3"
        let lines = homework.map { hw in
            let subject = lessons.first(where: { $0.number == hw.lessonNumber })?.subject ?? hw.subject
            return "• \(subject): \(hw.text)"
        }

        return NotificationText(
            title: "✏️ ДЗ на завтра (\(homework.count))",
            body: lines.joined(separator: "\n")
        )
    }

    /// Уроки одной строкой: "Математика, Русский, Литература".
    /// Если уроки начинаются не с первого или есть «окна» — с номерами: "2. Русский, 3. Литература".
    private static func lessonsLine(_ lessons: [Lesson]) -> String {
        let fromFirstInRow = lessons.enumerated().allSatisfy { $0.offset + 1 == $0.element.number }
        if fromFirstInRow {
            return lessons.map(\.subject).joined(separator: ", ")
        }
        return lessons.map { "\($0.number). \($0.subject)" }.joined(separator: ", ")
    }

    /// Кружки одной строкой: "15:00 Футбол, 18:00 Музыка".
    private static func activitiesLine(_ activities: [ExtraActivity]) -> String {
        activities.map { "\($0.time.text) \($0.title)" }.joined(separator: ", ")
    }
}
