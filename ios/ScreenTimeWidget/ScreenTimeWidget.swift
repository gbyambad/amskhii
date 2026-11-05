import SwiftUI
import WidgetKit

/// Home- and lock-screen widget for schedules: the one blocking apps now, or
/// the next to start. iOS keeps usage numbers inside the Screen Time report,
/// so unlike Android's widgets this one can show only the rules, which the
/// app shares through the App Group (`SharedRules.schedules`).
@main
struct ScreenTimeWidgets: WidgetBundle {
  var body: some Widget {
    ScheduleWidget()
  }
}

struct ScheduleWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "ScheduleWidget", provider: ScheduleProvider()) { entry in
      ScheduleWidgetView(entry: entry)
    }
    .configurationDisplayName("Хуваарь")
    .description("Одоо ажиллаж буй эсвэл дараагийн хаалтын хуваарь")
    .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
  }
}

// MARK: - Timeline

struct ScheduleEntry: TimelineEntry {
  let date: Date
  let status: ScheduleStatus
}

enum ScheduleStatus {
  case active(SharedRules.Schedule, until: Date)
  case upcoming(SharedRules.Schedule, at: Date)
  case none

  /// Running schedules win, the one ending first; else the next to start.
  static func at(_ date: Date, in schedules: [SharedRules.Schedule]) -> ScheduleStatus {
    let windows = schedules.compactMap { schedule in schedule.window(around: date).map { (schedule, $0) } }
    if let running = windows.filter({ $0.1.start <= date }).min(by: { $0.1.end < $1.1.end }) {
      return .active(running.0, until: running.1.end)
    }
    if let next = windows.min(by: { $0.1.start < $1.1.start }) {
      return .upcoming(next.0, at: next.1.start)
    }
    return .none
  }

  static let sample = ScheduleStatus.upcoming(
    SharedRules.Schedule(
      id: "bedtime", name: "Амрах цаг", kind: "bedtime", startMinute: 23 * 60, endMinute: 7 * 60,
      weekdays: [1, 2, 3, 4, 5, 6, 7], enabled: true, appIds: nil
    ),
    at: Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
  )
}

struct ScheduleProvider: TimelineProvider {
  func placeholder(in context: Context) -> ScheduleEntry {
    ScheduleEntry(date: Date(), status: .sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
    let now = Date()
    completion(ScheduleEntry(date: now, status: context.isPreview ? .sample : .at(now, in: SharedRules.schedules)))
  }

  /// An entry at every start and end in the next day, so the widget flips on
  /// time with the app closed. The app reloads it whenever the rules change.
  func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
    let now = Date()
    let horizon = now.addingTimeInterval(24 * 60 * 60)
    let schedules = SharedRules.schedules
    var dates: Set<Date> = [now]
    for schedule in schedules {
      var cursor = now
      while let window = schedule.window(around: cursor), window.start <= horizon {
        if window.start > now { dates.insert(window.start) }
        dates.insert(window.end)
        cursor = window.end
      }
    }
    let entries = dates.filter { $0 <= horizon }.sorted().map { ScheduleEntry(date: $0, status: .at($0, in: schedules)) }
    completion(Timeline(entries: entries, policy: .after(horizon)))
  }
}

// MARK: - Views

struct ScheduleWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: ScheduleEntry

  var body: some View {
    switch family {
    case .accessoryRectangular: rectangular
    case .accessoryInline: inline
    default: small.widgetCard()
    }
  }

  /// The home-screen card, in the style of the app's schedule cards.
  private var small: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .center) {
        KindTile(kind: kind)
        Spacer(minLength: 4)
        Text(caption).font(Style.onest(12, .semibold)).foregroundStyle(captionColor).lineLimit(1)
      }
      Spacer(minLength: 8)
      switch entry.status {
      case .active(let schedule, let until):
        Text(schedule.name).font(Style.onest(15, .semibold)).foregroundStyle(Style.ink).lineLimit(2)
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(Style.clock(until)).font(Style.number(24)).foregroundStyle(Style.ink)
          Text("хүртэл").font(Style.onest(12, .medium)).foregroundStyle(Style.muted)
        }
        .padding(.top, 4)
      case .upcoming(let schedule, let at):
        Text(schedule.name).font(Style.onest(15, .semibold)).foregroundStyle(Style.ink).lineLimit(2)
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(Style.clock(at)).font(Style.number(24)).foregroundStyle(Style.ink)
          Text(Style.day(at)).font(Style.onest(12, .medium)).foregroundStyle(Style.muted)
        }
        .padding(.top, 4)
      case .none:
        Text("Хуваарь алга").font(Style.onest(15, .semibold)).foregroundStyle(Style.ink)
        Text("Амсхийд хуваарь нэмнэ үү").font(Style.onest(12, .medium)).foregroundStyle(Style.muted).padding(.top, 4)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }

  /// Lock screen: tinted by the system, so no colors of its own.
  private var rectangular: some View {
    VStack(alignment: .leading, spacing: 2) {
      switch entry.status {
      case .active(let schedule, let until):
        Label(schedule.name, systemImage: "lock.fill").font(.headline)
        Text("\(Style.clock(until)) хүртэл хаалттай")
      case .upcoming(let schedule, let at):
        Label(schedule.name, systemImage: KindTile.symbol(schedule.kind)).font(.headline)
        Text("\(Style.day(at)) \(Style.clock(at))-д эхэлнэ")
      case .none:
        Label("Хуваарь алга", systemImage: "clock").font(.headline)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .widgetAccentable()
    .lockScreenBackground()
  }

  @ViewBuilder private var inline: some View {
    switch entry.status {
    case .active(let schedule, let until):
      Label("\(schedule.name) · \(Style.clock(until)) хүртэл", systemImage: "lock.fill")
    case .upcoming(let schedule, let at):
      Label("\(schedule.name) · \(Style.clock(at))", systemImage: "clock")
    case .none:
      Label("Хуваарь алга", systemImage: "clock")
    }
  }

  private var kind: String? {
    switch entry.status {
    case .active(let schedule, _), .upcoming(let schedule, _): schedule.kind
    case .none: nil
    }
  }

  private var caption: String {
    switch entry.status {
    case .active: "Хаалттай"
    case .upcoming: "Дараагийн хаалт"
    case .none: "Хуваарь"
    }
  }

  private var captionColor: Color {
    if case .active = entry.status { return Style.warm }
    return Style.faint
  }
}

/// The schedule kind's icon and color, as in the app (`ScheduleKindVisuals`).
struct KindTile: View {
  let kind: String?

  static func symbol(_ kind: String?) -> String {
    switch kind {
    case "bedtime": "moon.fill"
    case "work": "briefcase.fill"
    case "family": "house.fill"
    default: "clock.fill"
    }
  }

  private var color: Color {
    switch kind {
    case "bedtime": Color(hex: 0x1C2335)
    case "work": Color(hex: 0x2F5A4A)
    case "family": Color(hex: 0xB4480A)
    default: Color(hex: 0x3550F0)
    }
  }

  var body: some View {
    Image(systemName: Self.symbol(kind))
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: 28, height: 28)
      .background(color, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
      .accessibilityHidden(true)
  }
}

// MARK: - Style

/// The app's palette and type (`lib/core/theme`, `ScreenTimeReport/Theme.swift`),
/// light and dark as on the design canvas's widget artboards.
enum Style {
  static let card = dynamic(0xFFFFFF, 0x171C28)
  static let ink = dynamic(0x12141A, 0xF3F5F9)
  static let muted = dynamic(0x5B6170, 0xA3ABBD)
  static let faint = dynamic(0x6B7180, 0x9098AB)
  static let warm = dynamic(0xB4480A, 0xFF9A5C)

  static func onest(_ size: CGFloat, _ weight: Font.Weight) -> Font {
    .custom(weight == .semibold ? "Onest-SemiBold" : "Onest-Medium", size: size)
  }

  /// Unbounded, for digits only: it has no Ө/Ү.
  static func number(_ size: CGFloat) -> Font { .custom("Unbounded-SemiBold", size: size) }

  static func clock(_ date: Date) -> String {
    let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
    return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
  }

  /// `Өнөөдөр`, `Маргааш`, else the weekday.
  static func day(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) { return "Өнөөдөр" }
    if calendar.isDateInTomorrow(date) { return "Маргааш" }
    let names = ["Даваа", "Мягмар", "Лхагва", "Пүрэв", "Баасан", "Бямба", "Ням"]
    return names[SharedRules.dartWeekday(calendar.component(.weekday, from: date)) - 1]
  }

  private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
    Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
  }
}

extension Color {
  init(hex: UInt32) { self.init(UIColor(hex: hex)) }
}

extension UIColor {
  convenience init(hex: UInt32) {
    self.init(
      red: CGFloat((hex >> 16) & 0xFF) / 255,
      green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255,
      alpha: 1
    )
  }
}

extension View {
  /// iOS 17 wants the background through `containerBackground` and adds its
  /// own margins; iOS 16 needs both by hand.
  @ViewBuilder func widgetCard() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(Style.card, for: .widget)
    } else {
      padding(16).background(Style.card)
    }
  }

  @ViewBuilder func lockScreenBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(.clear, for: .widget)
    } else {
      self
    }
  }
}
