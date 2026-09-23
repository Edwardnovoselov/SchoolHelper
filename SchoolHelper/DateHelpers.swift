import Foundation

/// Дни недели. В приложении считаем так: 1 = понедельник … 7 = воскресенье.
enum Weekday {
    static let names = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"]
    static let shortNames = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    /// Учебные дни: пн–сб
    static let schoolDays = Array(1...6)
    /// Все дни: для кружков и секций
    static let allDays = Array(1...7)

    static func name(_ weekday: Int) -> String {
        names.indices.contains(weekday - 1) ? names[weekday - 1] : "?"
    }

    static func shortName(_ weekday: Int) -> String {
        shortNames.indices.contains(weekday - 1) ? shortNames[weekday - 1] : "?"
    }

    /// День недели для даты. iOS считает 1 = воскресенье, переводим в наш формат.
    static func of(_ date: Date) -> Int {
        let iosWeekday = Calendar.current.component(.weekday, from: date) // 1 = вс, 2 = пн … 7 = сб
        return (iosWeekday + 5) % 7 + 1
    }
}

/// «Ключ дня» — дата строкой вида "2026-09-25".
/// Такие строки удобно хранить и сравнивать: "2026-09-24" < "2026-09-25".
enum DayKey {
    private static var calendar: Calendar { Calendar(identifier: .gregorian) }

    static func from(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func today() -> String {
        from(Date())
    }

    /// Обратно: "2026-09-25" → дата (полночь этого дня).
    static func date(from key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Заголовок для списка: "Сегодня, Чт 24.09", "Завтра, Пт 25.09", "Пн 28.09".
    static func title(_ key: String) -> String {
        guard let date = date(from: key) else { return key }
        let c = calendar.dateComponents([.month, .day], from: date)
        let text = "\(Weekday.shortName(Weekday.of(date))) " + String(format: "%02d.%02d", c.day ?? 0, c.month ?? 0)
        if key == today() { return "Сегодня, " + text }
        if key == from(Date().addingDays(1)) { return "Завтра, " + text }
        return text
    }
}

extension Date {
    /// Та же дата плюс (или минус) несколько дней.
    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    /// Полночь этого дня.
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}
