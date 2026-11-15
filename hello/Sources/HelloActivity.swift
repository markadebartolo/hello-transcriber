import Foundation
import NaturalLanguage

struct HelloActivity {
    struct Day: Codable, Identifiable {
        var id: String
        var sessions = 0
        var words = 0
    }

    private static let storageKey = "Hello.dictationActivity.v1"
    private var days: [Day]

    init(defaults: UserDefaults = .standard) {
        days = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode([Day].self, from: $0) } ?? []
    }

    func recentDays(ending now: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> [Day] {
        (-6...0).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
            let key = Self.dayKey(date, calendar: calendar)
            return days.first { $0.id == key } ?? Day(id: key)
        }
    }

    mutating func record(_ transcript: String, at now: Date = .now,
                         calendar: Calendar = .autoupdatingCurrent, defaults: UserDefaults = .standard) {
        guard !transcript.allSatisfy(\.isWhitespace) else { return }
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = transcript
        var count = 0
        tokenizer.enumerateTokens(in: transcript.startIndex..<transcript.endIndex) { _, _ in
            count += 1
            return true
        }
        days = recentDays(ending: now, calendar: calendar)
        if let index = days.indices.last {
            days[index].sessions += 1
            days[index].words += count
        }
        if let data = try? JSONEncoder().encode(days) { defaults.set(data, forKey: Self.storageKey) }
    }

    mutating func reset(defaults: UserDefaults = .standard) {
        days = []
        defaults.removeObject(forKey: Self.storageKey)
    }

    private static func dayKey(_ date: Date, calendar: Calendar) -> String {
        // Use the local day in a fixed calendar so language or display settings
        // changes do not alter the stored keys.
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
