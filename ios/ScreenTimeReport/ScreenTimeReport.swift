import DeviceActivity
import SwiftUI

/// Screen Time report extension. iOS hands usage only to this process and
/// shows what it draws inside the app's `amskhii/usage_report` view; none of
/// the numbers reach the app or Dart.
@main
struct ScreenTimeReport: DeviceActivityReportExtension {
  var body: some DeviceActivityReportScene {
    TodayReport { TodayView(summary: $0) }
    WeekReport { WeekView(summary: $0) }
  }
}

extension DeviceActivityReport.Context {
  /// Names shared with `Runner/UsageReportView.swift`.
  static let today = Self("today")
  static let week = Self("week")
}
