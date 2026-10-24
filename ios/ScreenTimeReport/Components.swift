import FamilyControls
import ManagedSettings
import SwiftUI

/// Scrolling page body with the design's 16px gutters and gaps.
struct ReportScroll<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) { content }
        .padding(EdgeInsets(top: 24, leading: 16, bottom: 24, trailing: 16))
    }
    .background(Palette.ground)
  }
}

struct ScreenHeader: View {
  let caption: String
  let title: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(caption).font(Typeface.onest(13, .medium)).foregroundStyle(Palette.muted)
      Text(title).textRole(.screenTitle).accessibilityAddTraits(.isHeader)
    }
    .padding(.horizontal, 4)
  }
}

struct Card<Content: View>: View {
  var padding = EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
  @ViewBuilder let content: Content

  var body: some View {
    content
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
  }
}

struct StatChip: View {
  let label: String
  var systemImage: String?
  var background = Palette.segment
  var foreground = Palette.ink

  var body: some View {
    HStack(spacing: 4) {
      if let systemImage {
        Image(systemName: systemImage).font(.system(size: 11, weight: .bold))
      }
      Text(label).font(Typeface.onest(12, .semibold)).lineLimit(1)
    }
    .foregroundStyle(foreground)
    .padding(.horizontal, 10)
    .frame(height: 28)
    .background(background, in: Capsule())
  }
}

struct ProgressTrack: View {
  /// 0...1; values outside are clamped.
  let value: Double
  var color = Palette.accent
  var height: CGFloat = 6

  var body: some View {
    Capsule()
      .fill(Palette.track)
      .frame(height: height)
      .overlay(alignment: .leading) {
        GeometryReader { geo in
          Capsule().fill(color).frame(width: geo.size.width * min(max(value, 0), 1))
        }
      }
      .accessibilityHidden(true)
  }
}

/// 24 hourly bars with a 00–24 axis; hours after `currentHour` stay empty.
struct HourlyBarChart: View {
  let values: [Double]
  let currentHour: Int
  var height: CGFloat = 64
  let colorFor: (Int) -> Color

  var body: some View {
    let maxValue = values.max() ?? 0
    VStack(spacing: 6) {
      HStack(alignment: .bottom, spacing: 3) {
        ForEach(values.indices, id: \.self) { hour in
          let fraction = hour > currentHour || maxValue == 0 ? 0 : values[hour] / maxValue
          RoundedRectangle(cornerRadius: 3)
            .fill(hour > currentHour || values[hour] == 0 ? Palette.line : colorFor(hour))
            .frame(height: max(3, fraction * height))
            .frame(maxWidth: .infinity)
        }
      }
      .frame(height: height, alignment: .bottom)
      HStack {
        ForEach(["00", "06", "12", "18", "24"], id: \.self) { label in
          Text(label).font(Typeface.onest(11, .medium)).foregroundStyle(Palette.faint)
          if label != "24" { Spacer() }
        }
      }
    }
  }
}

/// Light segmented control: the selected option is a raised white pill.
struct SegmentedPills<Value: Hashable>: View {
  let options: [(Value, String)]
  @Binding var selected: Value

  var body: some View {
    HStack(spacing: 4) {
      ForEach(options, id: \.0) { value, label in
        let isSelected = value == selected
        Button { selected = value } label: {
          Text(label)
            .font(Typeface.onest(13, .semibold))
            .foregroundStyle(isSelected ? Palette.ink : Palette.muted)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background {
              if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                  .fill(Palette.surface)
                  .shadow(color: Palette.ink.opacity(0.15), radius: 1.5, y: 1)
              }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
      }
    }
    .padding(4)
    .background(Palette.segment, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

/// White round − / + button.
struct RoundIconButton: View {
  let systemImage: String
  let label: String
  let action: (() -> Void)?

  var body: some View {
    Button { action?() } label: {
      Image(systemName: systemImage)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(Palette.ink.opacity(action == nil ? 0.3 : 1))
        .frame(width: 44, height: 44)
        .background(Palette.surface, in: Circle())
        .overlay(Circle().strokeBorder(Palette.line))
    }
    .buttonStyle(.plain)
    .disabled(action == nil)
    .accessibilityLabel(label)
  }
}

struct StepperRow: View {
  let label: String
  let value: String
  let onDecrement: (() -> Void)?
  let onIncrement: (() -> Void)?
  let decrementLabel: String
  let incrementLabel: String

  var body: some View {
    HStack(spacing: 0) {
      Text(label).textRole(.body)
      Spacer()
      RoundIconButton(systemImage: "minus", label: decrementLabel, action: onDecrement)
      Text(value).numeric(16).frame(width: 80)
      RoundIconButton(systemImage: "plus", label: incrementLabel, action: onIncrement)
    }
  }
}

/// The app's icon from Screen Time, else a letter tile.
struct AppIcon: View {
  let token: ApplicationToken?
  let id: String
  let name: String
  var size: CGFloat = 40

  var body: some View {
    Group {
      if let token {
        Label(token)
          .labelStyle(.iconOnly)
          .font(.system(size: size * 0.9))
      } else {
        Text(name.prefix(1))
          .font(.system(size: size * 0.42, weight: .bold))
          .foregroundStyle(.white)
          .frame(width: size, height: size)
          .background(tileColor, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
      }
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }

  /// Stable across launches, unlike `hashValue`.
  private var tileColor: Color {
    Palette.tiles[id.unicodeScalars.reduce(0) { $0 + Int($1.value) } % Palette.tiles.count]
  }
}
