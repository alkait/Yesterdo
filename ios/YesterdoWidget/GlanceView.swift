import SwiftUI
import WidgetKit

/// The widget in each of its shapes.
///
/// Every shape draws the same thing: the tasks calling for attention at the
/// moment being drawn, and nothing else. What is due later in the day, what
/// has no time, what is done and what was waved away all stay off it.
struct GlanceView: View {
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme

  let entry: GlanceEntry

  private var accent: Color {
    let hex = scheme == .dark ? entry.glance.accentDark : entry.glance.accentLight
    return Color(hex: hex) ?? .primary
  }

  private var calling: [GlanceTask] { entry.glance.calling(at: entry.date) }

  /// Tapping opens the app on the task in front, the same address a
  /// notification hands over. With nothing calling there is nothing to open
  /// on, so the app opens as it usually would. A shape that lists several
  /// gives each row its own address on top of this one.
  private var address: URL? { calling.first.flatMap(addressOf) }

  var body: some View {
    shape.widgetURL(address)
  }

  @ViewBuilder
  private var shape: some View {
    switch family {
    case .accessoryInline:
      InlineGlance(entry: entry, calling: calling)
    case .accessoryCircular:
      CircularGlance(calling: calling)
        .glanceBackground(plain: true)
    case .accessoryRectangular:
      RectangularGlance(entry: entry, calling: calling)
        .glanceBackground(plain: true)
    case .systemMedium:
      MediumGlance(entry: entry, calling: calling, accent: accent)
        .glanceBackground(plain: false)
    default:
      SmallGlance(entry: entry, calling: calling, accent: accent)
        .glanceBackground(plain: false)
    }
  }
}

/// One line on the Lock Screen: when it was due and the words, and nothing
/// else fits.
struct InlineGlance: View {
  let entry: GlanceEntry
  let calling: [GlanceTask]

  var body: some View {
    if let task = calling.first {
      Text("\(whenLabel(task.due, drawnAt: entry.date)) \(task.title)")
    } else {
      Text(nothingDue)
    }
  }
}

/// The little round one: how many are calling, or a tick when none are.
struct CircularGlance: View {
  let calling: [GlanceTask]

  var body: some View {
    ZStack {
      AccessoryWidgetBackground()
      if calling.isEmpty {
        Image(systemName: "checkmark").font(.system(size: 18, weight: .semibold))
      } else {
        VStack(spacing: 0) {
          Image(systemName: "bell.fill").font(.system(size: 11))
          Text("\(calling.count)").font(.system(size: 18, weight: .semibold))
        }
      }
    }
  }
}

/// The wide one on the Lock Screen, which is the one that keeps a due task
/// in front of you: the task calling, when it was due, and how many more are
/// waiting behind it.
struct RectangularGlance: View {
  let entry: GlanceEntry
  let calling: [GlanceTask]

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      if let task = calling.first {
        HStack(spacing: 3) {
          Image(systemName: "bell.fill").font(.system(size: 10))
          Text(task.title).font(.headline).lineLimit(1)
        }
        Text(detail(for: task, of: calling.count, drawnAt: entry.date))
          .font(.caption2).lineLimit(1)
      } else {
        Text(nothingDue).font(.headline)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

/// The small square on the Home Screen: the day, the task calling, and how
/// many more are behind it.
struct SmallGlance: View {
  let entry: GlanceEntry
  let calling: [GlanceTask]
  let accent: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(dayLabel(entry.date)).font(.caption2).foregroundStyle(.secondary)
      Spacer(minLength: 0)
      if let task = calling.first {
        Text(dueLabel(task.due, drawnAt: entry.date))
          .font(.caption)
          .foregroundStyle(accent)
        Text(task.title).font(.headline).lineLimit(3)
      } else {
        Text(nothingDue).font(.headline)
      }
      Spacer(minLength: 0)
      if let more = moreLabel(calling.count, shown: 1) {
        Text(more).font(.caption2).foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

/// The wide one on the Home Screen: every task calling, earliest first, as
/// many as the shape has room for.
struct MediumGlance: View {
  let entry: GlanceEntry
  let calling: [GlanceTask]
  let accent: Color

  static let rows = 4

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack {
        Text(dayLabel(entry.date)).font(.caption2).foregroundStyle(.secondary)
        Spacer()
        if let more = moreLabel(calling.count, shown: Self.rows) {
          Text(more).font(.caption2).foregroundStyle(.secondary)
        }
      }
      if calling.isEmpty {
        Spacer(minLength: 0)
        Text(nothingDue).font(.headline)
        Spacer(minLength: 0)
      } else {
        // Each row opens its own task; the space around them opens the
        // first, through the widget's own address.
        ForEach(calling.prefix(Self.rows)) { task in
          Link(destination: addressOf(task) ?? fallbackAddress) {
            HStack(spacing: 6) {
              Circle().fill(accent).frame(width: 6, height: 6)
              Text(task.title).font(.subheadline).lineLimit(1)
              Spacer(minLength: 4)
              Text(whenLabel(task.due, drawnAt: entry.date))
                .font(.caption2).foregroundStyle(accent)
            }
          }
        }
        Spacer(minLength: 0)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

/// What a widget says with nothing calling. It is not "nothing to do": the
/// day may be full, and none of it due yet.
let nothingDue = "Nothing due"

/// Where a tap on a task lands: the app, on that task, by the same payload
/// a notification carries.
func addressOf(_ task: GlanceTask) -> URL? {
  URL(string: "yesterdo://task/\(task.payload)")
}

/// The app, on nothing in particular, for a payload that will not make an
/// address. It never should, but a Link has to point somewhere.
let fallbackAddress = URL(string: "yesterdo://")!

/// `Due 9:30 AM`, and `· 2 more` when others are waiting behind it.
private func detail(for task: GlanceTask, of count: Int, drawnAt now: Date) -> String {
  let when = dueLabel(task.due, drawnAt: now)
  guard let more = moreLabel(count, shown: 1) else { return when }
  return "\(when) · \(more)"
}

/// Which day a task is due, seen from the day being drawn. A widget can
/// show a task left calling from an earlier day, so the time alone would
/// mislead: the day is said whenever it is not the one being drawn.
private enum DueDay {
  case today, yesterday, tomorrow
  case other(String)

  init(_ due: Date, drawnAt now: Date) {
    let calendar = Calendar.current
    let days =
      calendar.dateComponents(
        [.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: due)
      ).day ?? 0
    switch days {
    case 0: self = .today
    case -1: self = .yesterday
    case 1: self = .tomorrow
    default: self = .other(shortDateFormatter.string(from: due))
    }
  }
}

/// `9:30 AM` on the day itself; `Yesterday 9:30 AM`, `Tomorrow 9:30 AM` or
/// `Sep 14 9:30 AM` otherwise.
func whenLabel(_ due: Date, drawnAt now: Date) -> String {
  let time = timeLabel(due)
  switch DueDay(due, drawnAt: now) {
  case .today: return time
  case .yesterday: return "Yesterday \(time)"
  case .tomorrow: return "Tomorrow \(time)"
  case .other(let date): return "\(date) \(time)"
  }
}

/// `Due 9:30 AM` on the day itself; `Due yesterday, 9:30 AM`, `Due tomorrow,
/// 9:30 AM` or `Due Sep 14, 9:30 AM` otherwise.
func dueLabel(_ due: Date, drawnAt now: Date) -> String {
  let time = timeLabel(due)
  switch DueDay(due, drawnAt: now) {
  case .today: return "Due \(time)"
  case .yesterday: return "Due yesterday, \(time)"
  case .tomorrow: return "Due tomorrow, \(time)"
  case .other(let date): return "Due \(date), \(time)"
  }
}

/// `2 more`, or nothing when everything calling is already on show.
private func moreLabel(_ count: Int, shown: Int) -> String? {
  count > shown ? "\(count - shown) more" : nil
}

private let timeFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.timeStyle = .short
  formatter.dateStyle = .none
  return formatter
}()

/// `Sep 14`, in the order the locale puts them.
private let shortDateFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.setLocalizedDateFormatFromTemplate("MMMd")
  return formatter
}()

private let dayFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
  return formatter
}()

/// `9:30 AM`, or `09:30` where the clock is set that way. The system's own
/// setting decides, as it does in the app.
func timeLabel(_ date: Date) -> String { timeFormatter.string(from: date) }

func dayLabel(_ date: Date) -> String { dayFormatter.string(from: date) }

extension Color {
  /// `#RRGGBB`, which is how the app hands its accent over.
  init?(hex: String) {
    var digits = hex
    if digits.hasPrefix("#") { digits.removeFirst() }
    guard digits.count == 6, let value = Int(digits, radix: 16) else { return nil }
    self.init(
      .sRGB,
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255)
  }
}

extension View {
  /// From iOS 17 a widget must name its own background. A Lock Screen one
  /// has none of its own; a Home Screen one takes the system's.
  @ViewBuilder
  func glanceBackground(plain: Bool) -> some View {
    if #available(iOS 17.0, *) {
      if plain {
        containerBackground(.clear, for: .widget)
      } else {
        containerBackground(.background, for: .widget)
      }
    } else {
      padding(plain ? 0 : 12)
    }
  }
}
