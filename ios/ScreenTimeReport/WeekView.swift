import SwiftUI

/// iOS version of the Report tab (`lib/features/report/report_screen.dart`).
/// The limit line and streak wait for limits on iOS.
struct WeekView: View {
  let summary: WeekSummary

  var body: some View {
    ReportScroll {
      ScreenHeader(caption: rangeLabel, title: "7 хоногийн тайлан")
      AverageCard(summary: summary)
      if summary.total > 0 { CategoryCard(summary: summary) }
      if !summary.topApps.isEmpty { TopAppsCard(summary: summary) }
    }
  }

  private var rangeLabel: String {
    let calendar = Calendar.current
    let first = calendar.dateComponents([.month, .day], from: summary.days[0].date)
    let last = calendar.dateComponents([.month, .day], from: summary.days[summary.days.count - 1].date)
    return first.month == last.month
      ? "\(first.month!)-р сарын \(first.day!)–\(last.day!)"
      : "\(first.month!)-р сарын \(first.day!) – \(last.month!)-р сарын \(last.day!)"
  }
}

private func dayLabel(_ summary: WeekSummary, _ index: Int) -> String {
  let date = summary.days[index].date
  let name = index == summary.days.count - 1 ? "Өнөөдөр" : Format.weekdayName(date)
  return "\(name), \(Format.shortDate(date))"
}

private struct AverageCard: View {
  let summary: WeekSummary

  /// Index into the week; `nil` follows today.
  @State private var selected: Int?

  var body: some View {
    let index = selected ?? summary.days.count - 1
    let day = summary.days[index]
    let busiest = summary.mostPickupsDay
    Card {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Өдрийн дундаж").textRole(.label)
          Text(Format.duration(summary.dailyAverage)).numeric(36)
          if let change = summary.changeVsPrevious {
            StatChip(
              label: "Өмнөх 7 хоногоос \(Int((abs(change) * 100).rounded()))% \(change < 0 ? "бага" : "их")",
              systemImage: change < 0 ? "arrow.down" : "arrow.up"
            )
          }
        }
        WeekChart(summary: summary, selected: index) { selected = $0 }
        (Text(dayLabel(summary, index)).font(Typeface.onest(13, .bold)).foregroundColor(Palette.ink)
          + Text(" · \(Format.duration(day.screenTime)) · \(day.pickups) удаа шалгасан"))
          .textRole(.caption, size: 13)
        Rectangle().fill(Palette.divider).frame(height: 1)
        Text(
          "Өдөрт дунджаар \(summary.averagePickups) удаа утсаа шалгасан · "
            + "Хамгийн их: \(Format.weekdayName(busiest.date)), \(busiest.pickups)"
        )
        .textRole(.caption)
      }
    }
  }
}

private struct WeekChart: View {
  private static let barArea: CGFloat = 136
  private static let labelArea: CGFloat = 24

  let summary: WeekSummary
  let selected: Int
  let onSelect: (Int) -> Void

  var body: some View {
    let longest = summary.days.map(\.screenTime).max() ?? 0
    // Leave headroom so the tallest bar sits below the top.
    let scale = max(longest, 60) / 0.92
    HStack(alignment: .bottom, spacing: 6) {
      ForEach(summary.days.indices, id: \.self) { i in
        let day = summary.days[i]
        let isSelected = i == selected
        VStack(spacing: 0) {
          Spacer(minLength: 0)
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Palette.accent.opacity(isSelected ? 1 : 0.45))
            .frame(height: day.screenTime / scale * Self.barArea)
          Text(Format.weekdayShort(day.date))
            .font(Typeface.onest(12, .semibold))
            .foregroundStyle(isSelected ? Palette.ink : Palette.muted)
            .frame(height: Self.labelArea)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(i) }
        .accessibilityElement()
        .accessibilityLabel("\(dayLabel(summary, i)): \(Format.duration(day.screenTime))")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onSelect(i) }
      }
    }
    .frame(height: Self.barArea + Self.labelArea)
  }
}

private struct CategoryCard: View {
  let summary: WeekSummary

  var body: some View {
    let total = summary.total
    let entries = summary.byCategory.sorted { $0.value > $1.value }
    let percent = { (seconds: TimeInterval) in max(1, Int((seconds / total * 100).rounded())) }
    let flexTotal = entries.reduce(0) { $0 + percent($1.value) }
    Card {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          Text("Ангиллаар").textRole(.cardTitle)
          Spacer(minLength: 8)
          Text("Нийт \(Format.duration(total))").textRole(.caption)
        }
        GeometryReader { geo in
          let width = geo.size.width - CGFloat(max(entries.count - 1, 0)) * 2
          HStack(spacing: 2) {
            ForEach(entries, id: \.key) { entry in
              Rectangle()
                .fill(entry.key.chartColor)
                .frame(width: width * CGFloat(percent(entry.value)) / CGFloat(flexTotal))
            }
          }
        }
        .frame(height: 14)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .accessibilityElement()
        .accessibilityLabel(entries.map { "\($0.key.label) \(percent($0.value))%" }.joined(separator: ", "))
        ForEach(entries, id: \.key) { entry in
          HStack(spacing: 10) {
            Circle().fill(entry.key.chartColor).frame(width: 10, height: 10)
            Text(entry.key.label).textRole(.rowTitle, size: 14)
            Spacer(minLength: 0)
            Text(Format.duration(entry.value)).textRole(.rowTitle, size: 13)
            Text("\(percent(entry.value))%").textRole(.caption).frame(width: 40, alignment: .trailing)
          }
        }
      }
    }
  }
}

private struct TopAppsCard: View {
  let summary: WeekSummary

  var body: some View {
    let days = Double(summary.days.count)
    Card(padding: EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)) {
      VStack(alignment: .leading, spacing: 0) {
        Text("Энэ 7 хоногт")
          .textRole(.cardTitle)
          .padding(EdgeInsets(top: 12, leading: 18, bottom: 6, trailing: 18))
        ForEach(summary.topApps) { app in
          HStack(spacing: 12) {
            AppIcon(token: app.token, id: app.id, name: app.name, size: 36)
            VStack(alignment: .leading, spacing: 2) {
              Text(app.name).textRole(.rowTitle).lineLimit(1)
              Text("Өдөрт дунджаар \(Format.duration(app.screenTime / days))").textRole(.caption)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
              Text(Format.duration(app.screenTime)).textRole(.rowTitle, size: 14)
              if let change = app.change {
                Text("\(Format.change(change)) өмнөхөөс")
                  .font(Typeface.onest(12, .semibold))
                  .foregroundStyle(change > 0 ? Palette.warmText : Palette.muted)
              }
            }
          }
          .padding(.horizontal, 18)
          .padding(.vertical, 10)
          .accessibilityElement(children: .combine)
        }
      }
    }
  }
}
