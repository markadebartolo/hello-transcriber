import Foundation

@main
struct HelloActivityTests {
    static func main() {
        let suite = "HelloActivityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 0, minute: 15))!
        let priorDay = calendar.date(byAdding: .minute, value: -30, to: now)!
        let expired = calendar.date(byAdding: .day, value: -7, to: now)!

        var activity = HelloActivity(defaults: defaults)
        activity.record("Old words", at: expired, calendar: calendar, defaults: defaults)
        activity.record("Hello there!", at: priorDay, calendar: calendar, defaults: defaults)
        activity.record("Good morning", at: now, calendar: calendar, defaults: defaults)
        activity.record("  \n", at: now, calendar: calendar, defaults: defaults)

        var reloaded = HelloActivity(defaults: defaults)
        let recent = reloaded.recentDays(ending: now, calendar: calendar)
        precondition(recent.count == 7)
        precondition(recent.map(\.words).reduce(0, +) == 4, "Do not include an eighth day")
        precondition(recent.map(\.sessions).reduce(0, +) == 2, "Ignore blank results")
        precondition(recent.last?.words == 2 && recent.last?.sessions == 1)
        precondition(recent[5].id == "2026-11-02" && recent[5].words == 2, "Use local midnight")
        reloaded.reset(defaults: defaults)
        precondition(HelloActivity(defaults: defaults).recentDays(ending: now, calendar: calendar)
            .allSatisfy { $0.sessions == 0 && $0.words == 0 })
        print("Hello activity: local-day grouping, seven-day totals, blank exclusion, persistence and reset passed")
    }
}
