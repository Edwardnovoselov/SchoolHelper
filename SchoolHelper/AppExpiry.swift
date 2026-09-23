import Foundation

/// Когда приложение перестанет открываться.
///
/// Приложение, установленное через бесплатный Apple ID, работает 7 дней, потом его
/// нужно переустановить (данные при этом сохраняются). Дату окончания берём из файла
/// embedded.mobileprovision, который Sideloadly кладёт внутрь приложения при установке.
enum AppExpiry {
    /// Дата окончания. nil — неизвестна (например, запуск на симуляторе).
    static let date: Date? = readExpirationDate()

    /// Сколько дней осталось: 0 — истекает сегодня, 1 — завтра и т. д.
    static func daysLeft(now: Date = Date()) -> Int? {
        guard let expiry = date else { return nil }
        return Calendar.current.dateComponents([.day], from: now.startOfDay, to: expiry.startOfDay).day
    }

    private static func readExpirationDate() -> Date? {
        // Файл подписан, но внутри лежит обычный plist — находим его начало и конец
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let raw = try? Data(contentsOf: url),
              let start = raw.range(of: Data("<?xml".utf8)),
              let end = raw.range(of: Data("</plist>".utf8), in: start.lowerBound..<raw.endIndex)
        else { return nil }

        let plistData = raw.subdata(in: start.lowerBound..<end.upperBound)
        let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        return plist?["ExpirationDate"] as? Date
    }
}
