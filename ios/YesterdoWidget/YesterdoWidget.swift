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
  /// How far ahead a task falling due is worth an entry of its own.
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

    for task in glance.tasks where task.calls > now {
      guard task.calls < now.addingTimeInterval(Self.ahead) else { continue }
      moments.insert(task.calls)
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

/// The tasks calling for attention: their time has come and nobody has
/// answered.
struct DueNowWidget: Widget {
  var body: some WidgetConfiguration {
    // The kind is the name it was first shipped under. Changing it would
    // take the widget off every screen it has been put on.
    StaticConfiguration(kind: "YesterdoWidget", provider: GlanceProvider()) { entry in
      GlanceView(entry: entry)
    }
    .configurationDisplayName("Due now")
    .description("Tasks whose time has come and are still waiting.")
    .supportedFamilies(glanceFamilies)
  }
}

/// The tasks pinned to the head of the day.
struct PinnedWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "PinnedWidget", provider: GlanceProvider()) { entry in
      PinnedView(entry: entry)
    }
    .configurationDisplayName("Pinned")
    .description("The tasks pinned to the top of today.")
    .supportedFamilies(glanceFamilies)
  }
}

private let glanceFamilies: [WidgetFamily] = [
  .accessoryRectangular, .accessoryInline, .accessoryCircular,
  .systemSmall, .systemMedium,
]

@main
struct YesterdoWidgetBundle: WidgetBundle {
  var body: some Widget {
    DueNowWidget()
    PinnedWidget()
  }
}
