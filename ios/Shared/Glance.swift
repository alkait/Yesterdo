import Foundation

/// What the app hands the widgets: the tasks of today and tomorrow, and the
/// accent of the look the app is drawn in, in both brightnesses.
///
/// The app writes the whole thing after every change. The widgets only ever
/// read it, and never work anything out about a repeat rule for themselves.
struct Glance: Codable {
  var accentLight: String
  var accentDark: String
  var tasks: [GlanceTask]

  static let empty = Glance(accentLight: "#000000", accentDark: "#FFFFFF", tasks: [])
}

/// One task, with only what a widget can draw.
struct GlanceTask: Codable, Identifiable {
  var key: String

  /// The day and key a tapped widget hands back, the same as a
  /// notification's.
  var payload: String
  var title: String

  /// Milliseconds at midnight of its day, local time.
  var dayStart: Double

  /// Milliseconds at its due moment, or nothing for a task with no time.
  var dueAt: Double?
  var done: Bool

  /// Waved away for the day: it keeps its time but stops asking.
  var dismissed: Bool

  var id: String { payload }
  var day: Date { Date(timeIntervalSince1970: dayStart / 1000) }
  var due: Date? { dueAt.map { Date(timeIntervalSince1970: $0 / 1000) } }

  /// Whether it is calling for attention: its moment has come, it is still
  /// open, and nobody has waved it away. The same rule the app's cards use.
  func isCalling(at now: Date) -> Bool {
    guard let due = due, !done, !dismissed else { return false }
    return due <= now
  }
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
  /// now, not a list of the day, so a task with no time, one whose moment has
  /// not come, one already done and one waved away are all alike to it:
  /// nothing to show. The day is not filtered on either, since a task cannot
  /// call before its own moment.
  func calling(at date: Date) -> [GlanceTask] {
    tasks
      .filter { $0.isCalling(at: date) }
      .sorted { ($0.due ?? .distantPast) < ($1.due ?? .distantPast) }
  }
}
