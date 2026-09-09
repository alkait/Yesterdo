import Foundation
import WidgetKit

/// The app's half of the widgets: it writes what they draw, and holds on to
/// a tap until Dart comes to take it.
enum GlanceBridge {
  /// `yesterdo://task/<day>:<key>`, the address a tapped widget opens.
  static let scheme = "yesterdo"
  static let taskHost = "task"

  /// Hands the widgets a whole glance and asks the system to redraw them.
  static func show(_ json: String) {
    GlanceFile.write(json)
    WidgetCenter.shared.reloadAllTimelines()
  }

  /// The task a tapped widget asked for, waiting to be taken. Kept here
  /// rather than pushed at Dart, since a tap can land before the engine is
  /// listening.
  private static var pending: String?

  static func hold(_ payload: String) { pending = payload }

  /// Hands the waiting task over once. A tap is never answered twice.
  static func take() -> String? {
    defer { pending = nil }
    return pending
  }

  /// The `day:key` a widget's address carries, or nothing for an address
  /// that is not one of ours.
  static func payload(from url: URL) -> String? {
    guard url.scheme == scheme, url.host == taskHost else { return nil }
    let path = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
    return path.isEmpty ? nil : path
  }
}
