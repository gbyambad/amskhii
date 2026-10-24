import DeviceActivity
import Flutter
import SwiftUI

/// Platform view `amskhii/usage_report`, created with `{report: "today" | "week"}`.
final class UsageReportFactory: NSObject, FlutterPlatformViewFactory {
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    let report = (args as? [String: Any])?["report"] as? String
    return UsageReportPlatformView(report: report == "week" ? .week : .today)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

private final class UsageReportPlatformView: NSObject, FlutterPlatformView {
  private let host: UIHostingController<UsageReportView>

  init(report: UsageReportView.Report) {
    host = UIHostingController(rootView: UsageReportView(report: report))
    host.view.backgroundColor = .clear
  }

  func view() -> UIView { host.view }
}

/// One scene of the report extension in `ios/ScreenTimeReport`, which draws it
/// out of process; the context names match that extension's.
struct UsageReportView: View {
  enum Report { case today, week }

  let report: Report

  /// Moved on return to the app so the report picks up the latest usage.
  @State private var now = Date()

  var body: some View {
    DeviceActivityReport(context, filter: filter)
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
        now = Date()
      }
  }

  private var context: DeviceActivityReport.Context {
    switch report {
    case .today: DeviceActivityReport.Context("today")
    case .week: DeviceActivityReport.Context("week")
    }
  }

  /// Today's report also gets yesterday, to compare against; the week gets
  /// the week before, for its average.
  private var filter: DeviceActivityFilter {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: now)
    let end = calendar.date(byAdding: .day, value: 1, to: today)!
    switch report {
    case .today:
      let start = calendar.date(byAdding: .day, value: -1, to: today)!
      return DeviceActivityFilter(segment: .hourly(during: DateInterval(start: start, end: end)))
    case .week:
      let start = calendar.date(byAdding: .day, value: -13, to: today)!
      return DeviceActivityFilter(segment: .daily(during: DateInterval(start: start, end: end)))
    }
  }
}
