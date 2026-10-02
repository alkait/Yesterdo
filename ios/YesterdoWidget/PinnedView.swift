import SwiftUI
import WidgetKit

/// The Pinned widget in each of its shapes.
///
/// Every shape draws the same thing: the tasks pinned on the day being
/// drawn, in the app's order, and nothing else. Which those are is the
/// app's to say; a done task has let go of its pin and never arrives.
struct PinnedView: View {
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme

  let entry: GlanceEntry

  private var accent: Color {
    let hex = scheme == .dark ? entry.glance.accentDark : entry.glance.accentLight
    return Color(hex: hex) ?? .primary
  }

  private var pinned: [GlancePin] { entry.glance.pinned(on: entry.date) }

  /// Tapping opens the app on the first pinned task. A shape that lists
  /// several gives each row its own address on top of this one.
  private var address: URL? { pinned.first.flatMap(addressOf) }

  var body: some View {
    shape.widgetURL(address)
  }

  @ViewBuilder
  private var shape: some View {
    switch family {
    case .accessoryInline:
      Text(pinned.first?.title ?? nothingPinned)
    case .accessoryCircular:
      ZStack {
        AccessoryWidgetBackground()
        VStack(spacing: 0) {
          Image(systemName: "pin.fill").font(.system(size: 11))
          Text("\(pinned.count)").font(.system(size: 18, weight: .semibold))
        }
      }
      .glanceBackground(plain: true)
    case .accessoryRectangular:
      PinnedList(entry: entry, pinned: pinned, accent: nil, rows: 3)
        .glanceBackground(plain: true)
    case .systemMedium:
      PinnedList(entry: entry, pinned: pinned, accent: accent, rows: 4)
        .glanceBackground(plain: false)
    default:
      PinnedList(entry: entry, pinned: pinned, accent: accent, rows: 3)
        .glanceBackground(plain: false)
    }
  }
}

/// The pinned tasks, one to a row, as many as the shape has room for. The
/// words take the whole width, and with rows to spare they run on to a
/// second line or more rather than being cut short. On
/// the Home Screen it is headed by the day and each task takes the accent's
/// pin; on the Lock Screen, with no accent, the rows stand alone.
struct PinnedList: View {
  let entry: GlanceEntry
  let pinned: [GlancePin]
  let accent: Color?
  let rows: Int

  /// How many lines each task may run to: the rows going spare, shared out.
  private var lines: Int { max(1, rows / max(1, pinned.count)) }

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      if accent != nil {
        HStack {
          Text(dayLabel(entry.date)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
          Spacer()
          if let more = moreLabel(pinned.count, shown: rows) {
            Text(more).font(.caption2).foregroundStyle(.secondary)
          }
        }
      }
      if pinned.isEmpty {
        Spacer(minLength: 0)
        Text(nothingPinned).font(.headline)
        Spacer(minLength: 0)
      } else {
        // Each row opens its own task; the space around them opens the
        // first, through the widget's own address.
        ForEach(pinned.prefix(rows)) { pin in
          Link(destination: addressOf(pin) ?? fallbackAddress) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
              Image(systemName: "pin.fill")
                .font(.system(size: 9))
                .foregroundStyle(accent ?? Color.primary)
              Text(pin.title).font(.subheadline).lineLimit(lines)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
              if let due = pin.due {
                Text(timeLabel(due))
                  .font(.caption2).foregroundStyle(accent ?? Color.secondary)
                  .fixedSize()
              }
            }
          }
        }
        Spacer(minLength: 0)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

/// What the widget says on a day with no pins.
let nothingPinned = "Nothing pinned"

func addressOf(_ pin: GlancePin) -> URL? {
  URL(string: "yesterdo://task/\(pin.payload)")
}
