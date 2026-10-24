import DeviceActivity
import ManagedSettings
import SwiftUI

/// Matches the Dart `AppCategory`.
enum UsageCategory: CaseIterable {
  case social, video, chat, other

  /// Messaging apps iOS files under Social.
  private static let chatApps: Set<String> = [
    "com.facebook.Messenger",
    "net.whatsapp.WhatsApp",
    "ph.telegra.Telegraph",
    "com.viber",
    "org.whispersystems.signal",
    "com.apple.MobileSMS",
    "jp.naver.line",
    "com.hammerandchisel.discord",
    "com.tencent.xin",
  ]

  /// iOS only names its categories in the phone's language; names other than
  /// English fall into `other`.
  init(app: Application, category: ActivityCategory) {
    if let id = app.bundleIdentifier, Self.chatApps.contains(id) {
      self = .chat
      return
    }
    switch category.localizedDisplayName?.lowercased() {
    case "social": self = .social
    case "entertainment": self = .video
    default: self = .other
    }
  }
}

extension Application {
  /// Stable across segments, unlike the position in the results.
  var usageKey: String { bundleIdentifier ?? localizedDisplayName ?? "" }
}

struct AppUsage: Identifiable {
  let id: String
  let name: String
  let token: ApplicationToken?
  let category: UsageCategory
  var screenTime: TimeInterval = 0
  /// Pickups that opened this app first; iOS doesn't count other opens.
  var pickups = 0
  var notifications = 0

  init(_ app: Application, category: ActivityCategory) {
    id = app.usageKey
    name = app.localizedDisplayName ?? app.bundleIdentifier ?? "?"
    token = app.token
    self.category = UsageCategory(app: app, category: category)
  }
}

/// Today so far, bucketed by hour of day.
struct TodaySummary {
  let asOf: Date
  var hourlyScreenTime = [TimeInterval](repeating: 0, count: 24)
  var hourlyPickups = [Int](repeating: 0, count: 24)
  var previousDayTotal: TimeInterval = 0
  var apps: [AppUsage] = []

  var total: TimeInterval { hourlyScreenTime.reduce(0, +) }
  var pickups: Int { hourlyPickups.reduce(0, +) }
  /// Hours after this one have not happened yet.
  var currentHour: Int { Calendar.current.component(.hour, from: asOf) }
  var peakUsageHour: Int { hourlyScreenTime.indices.max { hourlyScreenTime[$0] < hourlyScreenTime[$1] } ?? 0 }
  var peakPickupHour: Int { hourlyPickups.indices.max { hourlyPickups[$0] < hourlyPickups[$1] } ?? 0 }

  /// Pickups in `start..<end` hours.
  func pickups(from start: Int, to end: Int) -> Int { hourlyPickups[start..<end].reduce(0, +) }
}

struct DaySummary: Identifiable {
  let date: Date
  var screenTime: TimeInterval = 0
  var pickups = 0

  var id: Date { date }
  var hasData: Bool { screenTime > 0 || pickups > 0 }
}

struct AppWeekUsage: Identifiable {
  let id: String
  let name: String
  let token: ApplicationToken?
  var screenTime: TimeInterval = 0
  /// Ratio against the week before: `0.08` is 8% more; `nil` when unused then.
  var change: Double?
}

/// The last seven days, oldest first; the last entry is today.
struct WeekSummary {
  var days: [DaySummary]
  /// `nil` when the phone kept nothing from the week before.
  var previousDailyAverage: TimeInterval?
  var byCategory: [UsageCategory: TimeInterval] = [:]
  var topApps: [AppWeekUsage] = []

  var total: TimeInterval { days.reduce(0) { $0 + $1.screenTime } }

  /// Over days with any use; a fresh install has no history for the others.
  var dailyAverage: TimeInterval {
    let count = days.filter(\.hasData).count
    return count == 0 ? 0 : total / Double(count)
  }

  var changeVsPrevious: Double? {
    guard let previous = previousDailyAverage, previous > 0 else { return nil }
    return dailyAverage / previous - 1
  }

  var averagePickups: Int {
    let withData = days.filter(\.hasData)
    guard !withData.isEmpty else { return 0 }
    return Int((Double(withData.reduce(0) { $0 + $1.pickups }) / Double(withData.count)).rounded())
  }

  var mostPickupsDay: DaySummary { days.max { $0.pickups < $1.pickups } ?? days[days.count - 1] }
}
