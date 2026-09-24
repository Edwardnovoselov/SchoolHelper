import Foundation

/// Заголовок и текст одного уведомления.
struct NotificationText {
    let title: String
    let body: String
}

/// Собирает тексты уведомлений из расписания и ДЗ.
///
/// iOS показывает в свёрнутом уведомлении только 4–5 строк, поэтому текст компактный:
/// все уроки — одной строкой, кружки — одной строкой, ДЗ — по строке на предмет.
/// Полный текст виден, если нажать на уведомление и подержать (или потянуть его вниз).
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
        lines.append(lessons.isEmpty ? "Уроков нет 🎉" : "Уроки: " + lessonsLine(lessons))
        if !activities.isEmpty {
            lines.append("После школы: " + activitiesLine(activities))
        }

        return NotificationText(
            title: "☀️ Сегодня \(Weekday.name(weekday).lowercased())",
            body: lines.joined(separator: "\n")
        )
    }

    /// Вечер: расписание на завтра + домашнее задание на завтра.
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
        lines.append(lessons.isEmpty ? "Уроков нет 🎉" : "Уроки: " + lessonsLine(lessons))
        if !activities.isEmpty {
            lines.append("После школы: " + activitiesLine(activities))
        }

        if homework.isEmpty {
            if !lessons.isEmpty {
                lines.append("ДЗ не записано")
            }
        } else {
            // По строке на каждое задание: "• Математика: стр. 45, № 3"
            for hw in homework {
                let subject = lessons.first(where: { $0.number == hw.lessonNumber })?.subject ?? hw.subject
                lines.append("• \(subject): \(hw.text)")
            }
        }

        return NotificationText(
            title: "📚 Завтра \(Weekday.name(weekday).lowercased())",
            body: lines.joined(separator: "\n")
        )
    }

    /// "1. Математика, 2. Русский, 3. Физкультура"
    private static func lessonsLine(_ lessons: [Lesson]) -> String {
        lessons.map { "\($0.number). \($0.subject)" }.joined(separator: ", ")
    }

    /// "15:00 Футбол, 18:00 Музыка"
    private static func activitiesLine(_ activities: [ExtraActivity]) -> String {
        activities.map { "\($0.time.text) \($0.title)" }.joined(separator: ", ")
    }
}
