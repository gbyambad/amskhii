import SwiftUI

/// iOS version of the Overview tab (`lib/features/overview/overview_screen.dart`).
/// Limits aren't shown: they can't be set on iOS yet.
struct TodayView: View {
  let summary: TodaySummary

  var body: some View {
    ReportScroll {
      ScreenHeader(caption: Format.date(summary.asOf), title: "Дэлгэцийн цаг")
      TodayCard(summary: summary)
      PickupsCard(summary: summary)
      AppListCard(summary: summary)
    }
  }
}

private struct TodayCard: View {
  let summary: TodaySummary

  var body: some View {
    let diff = summary.total - summary.previousDayTotal
    let peak = summary.peakUsageHour
    let peakText = "\(Format.hour(peak))–\(Format.hour(peak + 1)) · \(Format.minutes(summary.hourlyScreenTime[peak]))"
    Card {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Өнөөдөр нийт").textRole(.label)
            Text(Format.duration(summary.total)).numeric(36)
          }
          Spacer(minLength: 8)
          // No history yesterday (new install, new phone): nothing to compare.
          if summary.previousDayTotal > 0 {
            StatChip(label: "\(Format.minutes(abs(diff))) өчигдрөөс", systemImage: diff < 0 ? "arrow.down" : "arrow.up")
          }
        }
        HourlyBarChart(values: summary.hourlyScreenTime, currentHour: summary.currentHour, height: 80) { _ in
          Palette.accent
        }
        .accessibilityElement()
        .accessibilityLabel("Цаг тутмын ашиглалт. Хамгийн их нь \(peakText)")
        Text("Хамгийн их: \(peakText)").textRole(.caption)
      }
    }
  }
}

private struct PickupsCard: View {
  let summary: TodaySummary

  @State private var start = 9
  @State private var end = 17

  var body: some View {
    let count = summary.pickups(from: start, to: end)
    let span = "\(Format.hour(start))–\(Format.hour(end))"
    let peak = summary.peakPickupHour
    Card {
      VStack(alignment: .leading, spacing: 14) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Утсаа шалгасан").textRole(.label)
          HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(summary.pickups)").numeric(36)
            Text("  удаа").textRole(.body)
          }
        }
        Text("Хэдээс хэдийн хооронд").textRole(.rowTitle)
        VStack(spacing: 0) {
          StepperRow(
            label: "Эхлэх",
            value: Format.hour(start),
            onDecrement: start > 0 ? { start -= 1 } : nil,
            onIncrement: start < end - 1 ? { start += 1 } : nil,
            decrementLabel: "Эхлэх цагийг 1 цагаар багасгах",
            incrementLabel: "Эхлэх цагийг 1 цагаар нэмэх"
          )
          .padding(.vertical, 4)
          Rectangle().fill(Palette.line).frame(height: 1)
          StepperRow(
            label: "Дуусах",
            value: Format.hour(end),
            onDecrement: end > start + 1 ? { end -= 1 } : nil,
            onIncrement: end < 24 ? { end += 1 } : nil,
            decrementLabel: "Дуусах цагийг 1 цагаар багасгах",
            incrementLabel: "Дуусах цагийг 1 цагаар нэмэх"
          )
          .padding(.vertical, 4)
        }
        .padding(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 6))
        .background(Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text("\(count)").numeric(26, color: Palette.warmText)
          Text("удаа · \(span)").textRole(.caption, size: 13)
          Spacer(minLength: 0)
          Text("цагт дунджаар \(Int((Double(count) / Double(end - start)).rounded()))").textRole(.caption)
        }
        HourlyBarChart(
          values: summary.hourlyPickups.map(Double.init),
          currentHour: summary.currentHour,
          height: 56
        ) { hour in
          hour >= start && hour < end ? Palette.warm : Palette.idleBar
        }
        .accessibilityElement()
        .accessibilityLabel("Цаг тутам утсаа шалгасан тоо, \(span) хооронд \(count) удаа")
        Text("Хамгийн их: \(Format.hour(peak))–\(Format.hour(peak + 1)) · \(summary.hourlyPickups[peak]) удаа")
          .textRole(.caption)
      }
    }
  }
}

private enum Metric: CaseIterable {
  case time, pickups, notifications

  var label: String {
    switch self {
    case .time: "Цаг"
    case .pickups: "Нээсэн"
    case .notifications: "Мэдэгдэл"
    }
  }

  var title: String {
    switch self {
    case .time: "Хамгийн их ашигласан"
    case .pickups: "Утсаа аваад хамгийн олон нээсэн"
    case .notifications: "Хамгийн их мэдэгдэл"
    }
  }

  func value(_ app: AppUsage) -> Double {
    switch self {
    case .time: app.screenTime
    case .pickups: Double(app.pickups)
    case .notifications: Double(app.notifications)
    }
  }

  func format(_ app: AppUsage) -> String {
    switch self {
    case .time: Format.duration(app.screenTime)
    case .pickups: "\(app.pickups) удаа"
    case .notifications: "\(app.notifications) мэдэгдэл"
    }
  }

  func total(_ apps: [AppUsage]) -> String {
    switch self {
    case .time: "Нийт \(Format.duration(apps.reduce(0) { $0 + $1.screenTime }))"
    case .pickups: "Нийт \(apps.reduce(0) { $0 + $1.pickups }) удаа"
    case .notifications: "Нийт \(apps.reduce(0) { $0 + $1.notifications })"
    }
  }
}

private struct AppListCard: View {
  let summary: TodaySummary

  @State private var metric = Metric.time

  var body: some View {
    let apps = summary.apps.sorted { metric.value($0) > metric.value($1) }
    let maxValue = apps.first.map(metric.value) ?? 0
    Card(padding: EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)) {
      VStack(alignment: .leading, spacing: 0) {
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            Text(metric.title).textRole(.cardTitle)
            Spacer(minLength: 8)
            Text(metric.total(apps)).textRole(.caption)
          }
          SegmentedPills(options: Metric.allCases.map { ($0, $0.label) }, selected: $metric)
        }
        .padding(EdgeInsets(top: 10, leading: 18, bottom: 8, trailing: 18))
        if apps.isEmpty {
          Text("Өнөөдөр ашигласан апп алга байна.")
            .textRole(.body)
            .padding(EdgeInsets(top: 8, leading: 18, bottom: 16, trailing: 18))
        }
        ForEach(apps) { app in
          AppUsageRow(app: app, metric: metric, share: maxValue == 0 ? 0 : metric.value(app) / maxValue)
        }
      }
    }
  }
}

private struct AppUsageRow: View {
  let app: AppUsage
  let metric: Metric
  /// This app's value relative to the top app for `metric`.
  let share: Double

  var body: some View {
    HStack(spacing: 12) {
      AppIcon(token: app.token, id: app.id, name: app.name)
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 8) {
          Text(app.name).textRole(.rowTitle).lineLimit(1)
          Spacer(minLength: 0)
          Text(metric.format(app)).textRole(.rowTitle, size: 14)
        }
        ProgressTrack(value: share)
        Text(metric == .time ? app.category.label : "\(Format.duration(app.screenTime)) · \(app.category.label)")
          .textRole(.caption)
      }
    }
    .padding(EdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18))
    .accessibilityElement(children: .combine)
  }
}
