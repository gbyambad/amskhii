import SwiftUI

/// Palette and type from the design canvas, mirroring `lib/core/theme`.
enum Palette {
  static let ground = Color(hex: 0xF3F4F7)
  static let surface = Color.white
  static let surfaceMuted = Color(hex: 0xF6F7F9)
  static let segment = Color(hex: 0xF1F2F6)

  static let ink = Color(hex: 0x12141A)
  static let muted = Color(hex: 0x5B6170)
  static let faint = Color(hex: 0x6B7180)

  static let track = Color(hex: 0xECEEF3)
  static let line = Color(hex: 0xE3E6EC)
  static let divider = Color(hex: 0xEEF0F4)
  static let inactive = Color(hex: 0x8A91A2)
  static let idleBar = Color(hex: 0xC9CEDA)

  static let accent = Color(hex: 0x3550F0)
  static let warm = Color(hex: 0xF06A1D)
  static let warmText = Color(hex: 0xB4480A)
  static let warmSurface = Color(hex: 0xFFF3EB)
  static let chat = Color(hex: 0x9AA7F5)

  /// Letter tiles for apps without an icon.
  static let tiles = [0x2B3A67, 0x3D2F6B, 0x2F5A4A, 0x7A2E1F, 0x6B2F4F].map { Color(hex: $0) }
}

extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255
    )
  }
}

/// Onest covers Mongolian Cyrillic; Unbounded is for numerals only, as it has
/// no Ө/Ү.
enum Typeface {
  static func onest(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    let name = switch weight {
    case .bold: "Onest-Bold"
    case .semibold: "Onest-SemiBold"
    case .medium: "Onest-Medium"
    default: "Onest-Regular"
    }
    return .custom(name, size: size)
  }
}

enum TextRole {
  case screenTitle, cardTitle, label, rowTitle, body, caption

  var size: CGFloat {
    switch self {
    case .screenTitle: 28
    case .cardTitle: 16
    case .label: 13
    case .rowTitle: 15
    case .body: 14
    case .caption: 12
    }
  }

  var weight: Font.Weight {
    switch self {
    case .screenTitle, .cardTitle: .bold
    case .label, .rowTitle: .semibold
    case .body, .caption: .medium
    }
  }

  var color: Color {
    switch self {
    case .screenTitle, .cardTitle, .rowTitle: Palette.ink
    case .label, .body, .caption: Palette.muted
    }
  }
}

extension View {
  /// `size` overrides the role's size, as `copyWith(fontSize:)` does in Dart.
  func textRole(_ role: TextRole, size: CGFloat? = nil) -> some View {
    font(Typeface.onest(size ?? role.size, role.weight))
      .foregroundStyle(role.color)
      .tracking(role == .screenTitle ? -0.3 : 0)
      .lineSpacing(role == .body ? 5 : 0)
  }

  /// Large numerals (`4ц 12м`, `87`).
  func numeric(_ size: CGFloat, color: Color = Palette.ink) -> some View {
    font(.custom("Unbounded-SemiBold", size: size))
      .tracking(-0.02 * size)
      .foregroundStyle(color)
  }
}

extension UsageCategory {
  var label: String {
    switch self {
    case .social: "Сошиал"
    case .video: "Видео"
    case .chat: "Чат"
    case .other: "Бусад"
    }
  }

  /// The four differ in lightness, not hue alone.
  var chartColor: Color {
    switch self {
    case .video: Palette.accent
    case .social: Palette.warm
    case .chat: Palette.chat
    case .other: Palette.idleBar
    }
  }
}

/// Mongolian copy, mirroring `lib/core/format.dart`.
enum Format {
  private static let weekdays = ["Даваа", "Мягмар", "Лхагва", "Пүрэв", "Баасан", "Бямба", "Ням"]
  private static let weekdaysShort = ["Да", "Мя", "Лх", "Пү", "Ба", "Бя", "Ня"]

  /// Monday first, as in the Dart helpers.
  private static func weekdayIndex(_ date: Date) -> Int {
    (Calendar.current.component(.weekday, from: date) + 5) % 7
  }

  static func weekdayName(_ date: Date) -> String { weekdays[weekdayIndex(date)] }

  static func weekdayShort(_ date: Date) -> String { weekdaysShort[weekdayIndex(date)] }

  /// `4ц 12м`, `1ц`, `6м`; under a minute of use reads `<1м`, not `0м`.
  static func duration(_ seconds: TimeInterval) -> String {
    if seconds > 0 && seconds < 60 { return "<1м" }
    let minutes = Int(seconds) / 60
    let hours = minutes / 60
    if hours == 0 { return "\(minutes)м" }
    return minutes % 60 == 0 ? "\(hours)ц" : "\(hours)ц \(minutes % 60)м"
  }

  /// `18 мин`, `<1 мин`.
  static func minutes(_ seconds: TimeInterval) -> String {
    if seconds > 0 && seconds < 60 { return "<1 мин" }
    return "\(Int(seconds) / 60) мин"
  }

  /// `09:00`; 24 is allowed so a range can end at midnight.
  static func hour(_ hour: Int) -> String { String(format: "%02d:00", hour) }

  /// `Баасан, 10-р сарын 23`.
  static func date(_ date: Date) -> String {
    let parts = Calendar.current.dateComponents([.month, .day], from: date)
    return "\(weekdayName(date)), \(parts.month!)-р сарын \(parts.day!)"
  }

  /// `10/17`.
  static func shortDate(_ date: Date) -> String {
    let parts = Calendar.current.dateComponents([.month, .day], from: date)
    return "\(parts.month!)/\(parts.day!)"
  }

  /// `+8%`, `−15%`.
  static func change(_ ratio: Double) -> String {
    let percent = Int((ratio * 100).rounded())
    return percent >= 0 ? "+\(percent)%" : "−\(abs(percent))%"
  }
}
