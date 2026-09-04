import AVFoundation
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Kept while a preview plays; a released player falls silent at once.
  private var previewPlayer: AVAudioPlayer?

  private let images = ImageBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Notification taps arrive here first and are forwarded to the plugin,
    // so it can hand the tapped task to the app.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // The few things only the device can do, reached from Dart through
    // `MethodChannelDeviceBridge`.
    let channel = FlutterMethodChannel(
      name: "remindme/device", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "setAppIcon":
        self?.setAppIcon(named: call.arguments as? String, result: result)
      case "previewSound":
        self?.previewSound(file: call.arguments as? String, result: result)
      case "imagesDirectory":
        result(ImageBridge.directory.path)
      case "pickImage":
        self?.images.pick(call.arguments as? String ?? "library") { name in result(name) }
      case "pasteImage":
        result(ImageBridge.paste())
      case "deleteImage":
        if let name = call.arguments as? String { ImageBridge.delete(name) }
        result(nil)
      case "openUrl":
        if let raw = call.arguments as? String, let url = URL(string: raw) {
          UIApplication.shared.open(url)
        }
        result(nil)
      case "notificationPermission":
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          let status: String
          switch settings.authorizationStatus {
          case .notDetermined: status = "notAsked"
          case .denied: status = "denied"
          default: status = "granted"
          }
          DispatchQueue.main.async { result(status) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// A nil name puts the primary icon back. Asking for the icon already
  /// showing is skipped, since the system would put up its alert anyway.
  private func setAppIcon(named name: String?, result: @escaping FlutterResult) {
    guard UIApplication.shared.supportsAlternateIcons,
      UIApplication.shared.alternateIconName != name
    else {
      result(nil)
      return
    }
    UIApplication.shared.setAlternateIconName(name) { error in
      if let error = error {
        result(FlutterError(code: "icon", message: error.localizedDescription, details: nil))
      } else {
        result(nil)
      }
    }
  }

  /// Plays a bundled reminder sound once. A nil file is the system's own
  /// notification sound, which plays through the notification centre alone.
  private func previewSound(file: String?, result: @escaping FlutterResult) {
    previewPlayer?.stop()
    guard let file = file, let url = Bundle.main.url(forResource: file, withExtension: nil)
    else {
      AudioServicesPlaySystemSound(1007)
      result(nil)
      return
    }
    do {
      try AVAudioSession.sharedInstance().setCategory(.ambient)
      try AVAudioSession.sharedInstance().setActive(true)
      previewPlayer = try AVAudioPlayer(contentsOf: url)
      previewPlayer?.play()
      result(nil)
    } catch {
      result(FlutterError(code: "sound", message: error.localizedDescription, details: nil))
    }
  }
}
