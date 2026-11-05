import Foundation

/// What the app and its extensions share through the App Group, minus the
/// Screen Time side (in `SharedRules.swift`): the rules and schedules Dart
/// saves, the same JSON as `LocalSettingsStore`. Needs only Foundation, so
/// the home-screen widget (ScreenTimeWidget) builds it too.
///
/// Built into Runner, ScreenTimeMonitor, ScreenTimeShield and ScreenTimeWidget.
enum SharedRules {
  static let appGroup = "group.com.amskhii.amskhii"
  static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

  private static let rulesKey = "rules.v1"
  private static let schedulesKey = "schedules.v1"

  // MARK: - Rules from Dart

  /// Dart's `LimitRule`. On iOS the rules map is keyed by pick id.
  struct Rule: Decodable {
    let limitMinutes: Int?
    let blocked: Bool
    let onLimit: String

    var warnOnly: Bool { onLimit == "warn" }
  }

  /// Dart's `BlockSchedule`.
  struct Schedule: Decodable {
    let id: String
    let name: String
    /// Dart's `ScheduleKind`: `bedtime`, `work`, `family` or `custom`.
    let kind: String
    let startMinute: Int
    let endMinute: Int
    /// 1 = Monday ... 7 = Sunday, as Dart's `DateTime.weekday`.
    let weekdays: [Int]
    let enabled: Bool
    /// `nil` blocks everything; on iOS otherwise a single pick id.
    let appIds: [String]?

    var crossesMidnight: Bool { endMinute < startMinute }

    /// As on Android: a window that crosses midnight belongs to the day it starts on.
    func isActive(at date: Date) -> Bool {
      guard enabled, startMinute != endMinute else { return false }
      let calendar = Calendar.current
      let weekday = dartWeekday(calendar.component(.weekday, from: date))
      let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
      if !crossesMidnight { return weekdays.contains(weekday) && minute >= startMinute && minute < endMinute }
      let yesterday = weekday == 1 ? 7 : weekday - 1
      return (weekdays.contains(weekday) && minute >= startMinute) || (weekdays.contains(yesterday) && minute < endMinute)
    }

    /// The window running at [date], else the next one to start within a
    /// week; `nil` when off or on no days.
    func window(around date: Date) -> DateInterval? {
      guard enabled, startMinute != endMinute, !weekdays.isEmpty else { return nil }
      let calendar = Calendar.current
      let today = calendar.startOfDay(for: date)
      // From yesterday, whose window may still be running past midnight.
      for offset in -1...7 {
        guard let day = calendar.date(byAdding: .day, value: offset, to: today),
              weekdays.contains(dartWeekday(calendar.component(.weekday, from: day))),
              let endDay = calendar.date(byAdding: .day, value: crossesMidnight ? 1 : 0, to: day),
              let start = calendar.date(byAdding: .minute, value: startMinute, to: day),
              let end = calendar.date(byAdding: .minute, value: endMinute, to: endDay)
        else { continue }
        if end > date { return DateInterval(start: start, end: end) }
      }
      return nil
    }
  }

  private struct RulesFile: Decodable {
    let apps: [String: Rule]
  }

  static func save(rules: String, schedules: String) {
    defaults.set(rules, forKey: rulesKey)
    defaults.set(schedules, forKey: schedulesKey)
  }

  static var rules: [String: Rule] {
    decode(RulesFile.self, key: rulesKey)?.apps ?? [:]
  }

  static var schedules: [Schedule] {
    decode([Schedule].self, key: schedulesKey) ?? []
  }

  static func schedule(id: String) -> Schedule? {
    schedules.first { $0.id == id }
  }

  private static func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
    guard let json = defaults.string(forKey: key) else { return nil }
    return try? JSONDecoder().decode(type, from: Data(json.utf8))
  }

  /// Dart's 1 = Monday ... 7 = Sunday from Calendar's 1 = Sunday ... 7 = Saturday.
  static func dartWeekday(_ calendarWeekday: Int) -> Int { calendarWeekday == 1 ? 7 : calendarWeekday - 1 }

  static func calendarWeekday(_ dartWeekday: Int) -> Int { dartWeekday % 7 + 1 }

  /// `1ц 30м`, as Dart's `formatDuration`.
  static func formatMinutes(_ minutes: Int) -> String {
    let h = minutes / 60, m = minutes % 60
    if h == 0 { return "\(m)м" }
    return m == 0 ? "\(h)ц" : "\(h)ц \(m)м"
  }

  /// `07:00`.
  static func formatMinuteOfDay(_ minute: Int) -> String {
    String(format: "%02d:%02d", minute / 60 % 24, minute % 60)
  }
}
