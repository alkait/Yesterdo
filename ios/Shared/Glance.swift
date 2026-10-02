import Foundation

/// What the app hands the widgets: the tasks that can call, the pinned ones
/// of today and tomorrow, and the
/// accent of the look the app is drawn in, in both brightnesses.
///
/// The app writes the whole thing after every change. The widgets only ever
/// read it, and never work anything out about a repeat rule for themselves.
struct Glance: Codable {
  var accentLight: String
  var accentDark: String
  var tasks: [GlanceTask]

  /// Missing from a file written before there were pins.
  var pinned: [GlancePin]?

  static let empty = Glance(
    accentLight: "#000000", accentDark: "#FFFFFF", tasks: [], pinned: [])
}

/// One pinned task. It has no moment of its own: it is drawn for the whole
/// of its day.
struct GlancePin: Codable, Identifiable {
  var key: String
  var payload: String
  var title: String

  /// Milliseconds at the moment its day begins.
  var dayAt: Double

  /// Milliseconds at its due moment, or nothing for a task with no time.
  var dueAt: Double?

  var id: String { payload }
  var day: Date { Date(timeIntervalSince1970: dayAt / 1000) }
  var due: Date? { dueAt.map { Date(timeIntervalSince1970: $0 / 1000) } }
}

/// One task, with only what a widget can draw.
///
/// The app hands over none but the tasks that can call for attention, so
/// there is nothing here about being done or waved away: such a task never
/// arrives.
struct GlanceTask: Codable, Identifiable {
  var key: String

  /// The day and key a tapped widget hands back, the same as a
  /// notification's.
  var payload: String
  var title: String

  /// Milliseconds at the moment it starts calling for attention. Worked out
  /// by the app, which is the one place that decides what calling means.
  var callsAt: Double

  /// Milliseconds at its due moment, which is the time shown.
  var dueAt: Double

  var id: String { payload }
  var due: Date { Date(timeIntervalSince1970: dueAt / 1000) }
  var calls: Date { Date(timeIntervalSince1970: callsAt / 1000) }

  /// Whether it is calling at a given moment. Its moment has come, and the
  /// app would not have sent it if there were any other reason to keep quiet.
  func isCalling(at now: Date) -> Bool { calls <= now }
}

/// The one file the app and the widgets share, in the group container both
/// can reach. Nothing leaves the device.
enum GlanceFile {
  static let group = "group.com.alkait.yesterdo"
  static let name = "glance.json"

  static var url: URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: group)?
      .appendingPathComponent(name)
  }

  /// What was last written, or an empty glance when nothing has been: a
  /// fresh install, or a container the system will not hand over.
  static func read() -> Glance {
    guard let url = url,
      let data = try? Data(contentsOf: url),
      let glance = try? JSONDecoder().decode(Glance.self, from: data)
    else { return .empty }
    return glance
  }

  static func write(_ json: String) {
    guard let url = url, let data = json.data(using: .utf8) else { return }
    try? data.write(to: url, options: .atomic)
  }
}

extension Glance {
  /// The tasks calling for attention at a moment, earliest first.
  ///
  /// This is the whole of what a widget draws. The widget is for what is due
  /// now, not a list of the day, so anything whose moment has not come is
  /// held back until it has. Days are not filtered on: a task left calling
  /// from yesterday is still calling today, which is the point of it.
  func calling(at date: Date) -> [GlanceTask] {
    tasks
      .filter { $0.isCalling(at: date) }
      .sorted { $0.due < $1.due }
  }

  /// The tasks pinned on the day a moment falls on, in the app's order.
  /// Tomorrow's ride along in the file, so the day turns over on its own.
  func pinned(on date: Date) -> [GlancePin] {
    (pinned ?? []).filter { Calendar.current.isDate($0.day, inSameDayAs: date) }
  }
}
