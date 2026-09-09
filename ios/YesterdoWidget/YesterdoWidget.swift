import SwiftUI
import WidgetKit

/// One moment the widget is drawn at. The whole glance rides along, and the
/// view works out what is calling from the moment alone, so a task falls due
/// on the Lock Screen without the app running.
struct GlanceEntry: TimelineEntry {
  let date: Date
  let glance: Glance
}

struct GlanceProvider: TimelineProvider {
  /// How far ahead a due moment is worth an entry of its own.
  static let ahead: TimeInterval = 36 * 3600

  /// The most entries in one timeline.
  static let cap = 40

  func placeholder(in context: Context) -> GlanceEntry {
    GlanceEntry(date: Date(), glance: .empty)
  }

  func getSnapshot(in context: Context, completion: @escaping (GlanceEntry) -> Void) {
    completion(GlanceEntry(date: Date(), glance: GlanceFile.read()))
  }

  /// An entry now, one at each due moment to come, and one at midnight, so
  /// the day turns over on its own. Nothing here asks the app anything.
  func getTimeline(in context: Context, completion: @escaping (Timeline<GlanceEntry>) -> Void) {
    let glance = GlanceFile.read()
    let now = Date()
    var moments: Set<Date> = [now]

    for task in glance.tasks {
      guard let due = task.due, due > now, due < now.addingTimeInterval(Self.ahead) else { continue }
      moments.insert(due)
    }
    if let midnight = Calendar.current.nextDate(
      after: now, matching: DateComponents(hour: 0, minute: 0, second: 0),
      matchingPolicy: .nextTime)
    {
      moments.insert(midnight)
    }

    let entries = moments.sorted().prefix(Self.cap).map {
      GlanceEntry(date: $0, glance: glance)
    }
    completion(Timeline(entries: Array(entries), policy: .atEnd))
  }
}

struct YesterdoWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "YesterdoWidget", provider: GlanceProvider()) { entry in
      GlanceView(entry: entry)
    }
    .configurationDisplayName("Due today")
    .description("What is due, and what is left of the day.")
    .supportedFamilies([
      .accessoryRectangular, .accessoryInline, .accessoryCircular,
      .systemSmall, .systemMedium,
    ])
  }
}

@main
struct YesterdoWidgetBundle: WidgetBundle {
  var body: some Widget { YesterdoWidget() }
}
