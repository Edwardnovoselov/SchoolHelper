import Foundation
import Combine

/// Хранилище всех данных приложения.
/// Данные лежат в одном JSON-файле на телефоне (без сервера и регистрации).
/// После любого изменения файл сохраняется, а уведомления перепланируются.
@MainActor
final class DataStore: ObservableObject {
    static let shared = DataStore()

    /// Файл с данными в папке «Документы» приложения
    static let fileURL = URL.documentsDirectory.appending(path: "school-data.json")

    /// Все данные. Любое изменение сразу сохраняется в файл.
    @Published var data: AppData {
        didSet {
            guard data != oldValue else { return }
            save()
            scheduleNotificationsSoon()
        }
    }

    private var rescheduleTask: Task<Void, Never>? = nil

    private init() {
        data = Self.load()
        // Сразу создаём файл, чтобы кнопка «Сохранить копию данных» работала с первого дня
        if !FileManager.default.fileExists(atPath: Self.fileURL.path) {
            save()
        }
    }

    // MARK: - Уроки

    /// Заменить все уроки дня. subjects[0] — 1-й урок, subjects[1] — 2-й и т. д.
    /// Пустая строка означает, что урока нет.
    func setLessons(_ subjects: [String], for weekday: Int) {
        var lessons = data.lessons.filter { $0.weekday != weekday }
        for (index, raw) in subjects.enumerated() {
            let subject = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !subject.isEmpty {
                lessons.append(Lesson(weekday: weekday, number: index + 1, subject: subject))
            }
        }
        data.lessons = lessons
    }

    /// Все предметы, которые уже есть в расписании (для быстрого выбора).
    var allSubjects: [String] {
        Set(data.lessons.map(\.subject)).sorted { $0.localizedCompare($1) == .orderedAscending }
    }

    // MARK: - Кружки и секции

    func saveActivity(_ activity: ExtraActivity) {
        data.activities.upsert(activity)
    }

    func deleteActivity(_ activity: ExtraActivity) {
        data.activities.remove(id: activity.id)
    }

    // MARK: - Домашнее задание

    func saveHomework(_ homework: Homework) {
        data.homework.upsert(homework)
    }

    func deleteHomework(_ homework: Homework) {
        data.homework.remove(id: homework.id)
    }

    /// Заготовка для нового ДЗ: ближайший учебный день, первый урок.
    func newHomework() -> Homework {
        let day = nextSchoolDay()
        let firstLesson = data.lessons(on: Weekday.of(day)).first
        return Homework(dayKey: DayKey.from(day),
                        lessonNumber: firstLesson?.number ?? 1,
                        subject: firstLesson?.subject ?? "",
                        text: "")
    }

    /// Ближайший день после сегодняшнего, в который есть уроки.
    func nextSchoolDay() -> Date {
        for offset in 1...7 {
            let day = Date().addingDays(offset)
            if !data.lessons(on: Weekday.of(day)).isEmpty {
                return day
            }
        }
        return Date().addingDays(1)
    }

    /// Актуальное ДЗ, сгруппированное по дням (прошедшие дни не показываем).
    var homeworkByDay: [HomeworkDay] {
        let today = DayKey.today()
        let keys = Set(data.homework.map(\.dayKey)).filter { $0 >= today }.sorted()
        return keys.map { HomeworkDay(dayKey: $0, items: data.homework(on: $0)) }
    }

    /// Автоудаление: убираем ДЗ за дни, которые уже закончились.
    func removeOldHomework() {
        let today = DayKey.today()
        // Ключи дней — строки "2026-09-24", их можно сравнивать как текст
        data.homework.removeAll { $0.dayKey < today }
    }

    // MARK: - Обновление

    /// При каждом открытии приложения: убрать старое ДЗ и заново запланировать уведомления.
    func refresh() async {
        removeOldHomework()
        await NotificationManager.reschedule(with: data)
    }

    /// Наступил новый день (полночь), а приложение открыто — чистим ДЗ и обновляем экран.
    func dayChanged() {
        objectWillChange.send()
        removeOldHomework()
        scheduleNotificationsSoon()
    }

    // MARK: - Резервная копия

    /// Загрузить данные из файла резервной копии. Возвращает текст для сообщения.
    func importBackup(from url: URL) -> String {
        // Файл выбран через «Файлы» — нужно попросить к нему доступ
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let raw = try Data(contentsOf: url)
            data = try JSONDecoder().decode(AppData.self, from: raw)
            removeOldHomework()
            return "Готово! Расписание и ДЗ восстановлены."
        } catch {
            return "Не удалось прочитать файл. Это точно копия из этого приложения?"
        }
    }

    // MARK: - Работа с файлом

    private static func load() -> AppData {
        // При первом запуске файла ещё нет — начинаем с пустых данных
        guard let raw = try? Data(contentsOf: fileURL) else { return AppData() }
        do {
            return try JSONDecoder().decode(AppData.self, from: raw)
        } catch {
            // Файл есть, но не читается — сохраняем его копию, чтобы данные не пропали совсем
            let backup = fileURL.deletingLastPathComponent().appending(path: "school-data-broken.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: fileURL, to: backup)
            print("Не удалось прочитать данные: \(error)")
            return AppData()
        }
    }

    private func save() {
        do {
            let raw = try JSONEncoder().encode(data)
            try raw.write(to: Self.fileURL, options: .atomic)
        } catch {
            print("Не удалось сохранить данные: \(error)")
        }
    }

    /// Перепланировать уведомления через полсекунды.
    /// Если данные меняются несколько раз подряд, перепланирование выполнится один раз.
    private func scheduleNotificationsSoon() {
        rescheduleTask?.cancel()
        rescheduleTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await NotificationManager.reschedule(with: self.data)
        }
    }
}

// Вспомогательные функции для списков с id
extension Array where Element: Identifiable {
    /// Заменить элемент с таким же id или добавить новый.
    mutating func upsert(_ item: Element) {
        if let index = firstIndex(where: { $0.id == item.id }) {
            self[index] = item
        } else {
            append(item)
        }
    }

    /// Удалить элемент по id.
    mutating func remove(id: Element.ID) {
        removeAll { $0.id == id }
    }
}
