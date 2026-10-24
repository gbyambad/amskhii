import DeviceActivity
import SwiftUI

struct TodayReport: DeviceActivityReportScene {
  let context: DeviceActivityReport.Context = .today
  let content: (TodaySummary) -> TodayView

  /// Apps under a minute with no pickups or notifications aren't listed.
  private static let minListed: TimeInterval = 60
  private static let maxApps = 50

  /// `data` holds hourly segments for yesterday and today.
  func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> TodaySummary {
    let calendar = Calendar.current
    var summary = TodaySummary(asOf: Date())
    var apps: [String: AppUsage] = [:]

    for await device in data {
      for await segment in device.activitySegments {
        let start = segment.dateInterval.start
        guard calendar.isDate(start, inSameDayAs: summary.asOf) else {
          summary.previousDayTotal += segment.totalActivityDuration
          continue
        }
        let hour = calendar.component(.hour, from: start)
        summary.hourlyScreenTime[hour] += segment.totalActivityDuration
        summary.hourlyPickups[hour] += segment.totalPickupsWithoutApplicationActivity
        for await category in segment.categories {
          for await activity in category.applications {
            summary.hourlyPickups[hour] += activity.numberOfPickups
            let key = activity.application.usageKey
            var app = apps[key] ?? AppUsage(activity.application, category: category.category)
            app.screenTime += activity.totalActivityDuration
            app.pickups += activity.numberOfPickups
            app.notifications += activity.numberOfNotifications
            apps[key] = app
          }
        }
      }
    }

    summary.apps = Array(
      apps.values
        .filter { $0.screenTime >= Self.minListed || $0.pickups > 0 || $0.notifications > 0 }
        .sorted { $0.screenTime > $1.screenTime }
        .prefix(Self.maxApps)
    )
    return summary
  }
}

struct WeekReport: DeviceActivityReportScene {
  let context: DeviceActivityReport.Context = .week
  let content: (WeekSummary) -> WeekView

  private static let topApps = 4

  /// `data` holds daily segments for the last 14 days.
  func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> WeekSummary {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    // Oldest first; 0...6 is the week before, 7...13 this week ending today.
    var days = (0..<14).map { DaySummary(date: calendar.date(byAdding: .day, value: $0 - 13, to: today)!) }
    var thisWeek: [String: AppWeekUsage] = [:]
    var lastWeek: [String: TimeInterval] = [:]
    var byCategory: [UsageCategory: TimeInterval] = [:]

    for await device in data {
      for await segment in device.activitySegments {
        let start = calendar.startOfDay(for: segment.dateInterval.start)
        guard let index = calendar.dateComponents([.day], from: days[0].date, to: start).day,
              days.indices.contains(index) else { continue }
        days[index].screenTime += segment.totalActivityDuration
        days[index].pickups += segment.totalPickupsWithoutApplicationActivity
        for await category in segment.categories {
          for await activity in category.applications {
            days[index].pickups += activity.numberOfPickups
            let app = activity.application
            let duration = activity.totalActivityDuration
            if index < 7 {
              lastWeek[app.usageKey, default: 0] += duration
              continue
            }
            thisWeek[app.usageKey, default: AppWeekUsage(
              id: app.usageKey,
              name: app.localizedDisplayName ?? app.bundleIdentifier ?? "?",
              token: app.token
            )].screenTime += duration
            byCategory[UsageCategory(app: app, category: category.category), default: 0] += duration
          }
        }
      }
    }

    // Average only the days the phone still has data for.
    let previousDays = days[..<7].filter { $0.screenTime > 0 }
    let previousAverage = previousDays.isEmpty
      ? nil
      : previousDays.reduce(0) { $0 + $1.screenTime } / Double(previousDays.count)

    let top = thisWeek.values
      .filter { $0.screenTime > 0 }
      .sorted { $0.screenTime > $1.screenTime }
      .prefix(Self.topApps)
      .map { app -> AppWeekUsage in
        var app = app
        if let before = lastWeek[app.id], before > 0 { app.change = app.screenTime / before - 1 }
        return app
      }

    return WeekSummary(
      days: Array(days[7...]),
      previousDailyAverage: previousAverage,
      byCategory: byCategory.filter { $0.value > 0 },
      topApps: top
    )
  }
}
