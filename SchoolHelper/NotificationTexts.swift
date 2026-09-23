import Foundation

/// Заголовок и текст одного уведомления.
struct NotificationText {
    let title: String
    let body: String
}

/// Собирает тексты уведомлений из расписания и ДЗ.
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
        if lessons.isEmpty {
            lines.append("Уроков нет 🎉")
        } else {
            lines += lessons.map { "\($0.number). \($0.subject)" }
        }
        if !activities.isEmpty {
            lines.append("После школы:")
            lines += activities.map { "\($0.time.text) — \($0.title)" }
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
        if lessons.isEmpty && homework.isEmpty {
            lines.append("Уроков нет 🎉")
        } else {
            lines += lessonLines(lessons: lessons, homework: homework)
            if homework.isEmpty {
                lines.append("ДЗ на завтра не записано")
            }
        }
        if !activities.isEmpty {
            lines.append("После школы:")
            lines += activities.map { "\($0.time.text) — \($0.title)" }
        }

        return NotificationText(
            title: "📚 Завтра \(Weekday.name(weekday).lowercased())",
            body: lines.joined(separator: "\n")
        )
    }

    /// Строки вида "1. Математика — ДЗ: стр. 45, № 3". Если ДЗ нет — только урок.
    static func lessonLines(lessons: [Lesson], homework: [Homework]) -> [String] {
        var lines: [String] = []
        for lesson in lessons {
            let tasks = homework.filter { $0.lessonNumber == lesson.number }.map(\.text)
            if tasks.isEmpty {
                lines.append("\(lesson.number). \(lesson.subject)")
            } else {
                lines.append("\(lesson.number). \(lesson.subject) — ДЗ: \(tasks.joined(separator: "; "))")
            }
        }
        // ДЗ на урок, которого уже нет в расписании (например, расписание поменяли)
        let numbers = Set(lessons.map(\.number))
        for hw in homework where !numbers.contains(hw.lessonNumber) {
            lines.append("\(hw.lessonNumber). \(hw.subject) — ДЗ: \(hw.text)")
        }
        return lines
    }
}
