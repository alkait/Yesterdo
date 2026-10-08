import AVFoundation
import CloudKit
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Kept while a preview plays; a released player falls silent at once.
  private var previewPlayer: AVAudioPlayer?

  private let images = ImageBridge()
  private let cloud = CloudBridge()

  /// The channel into Dart, kept so a tapped widget can be announced. There
  /// is one engine, so one channel is all there is to hold.
  private static var channel: FlutterMethodChannel?

  /// The cloud's own channel, kept so a silent push can say another device
  /// has written.
  private static var cloudChannel: FlutterMethodChannel?

  /// Tells Dart a widget has been tapped, so it comes and takes it. Dropped
  /// harmlessly when nothing is listening yet; Dart asks at launch too.
  static func nudgeWidgetTap() {
    DispatchQueue.main.async { channel?.invokeMethod("widgetTapped", arguments: nil) }
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Notification taps arrive here first and are forwarded to the plugin,
    // so it can hand the tapped task to the app.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    // Silent pushes from CloudKit say when another device has written.
    // They need no permission from the user, only a registration.
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// `FlutterAppDelegate` tells UIKit it does not answer to the remote
  /// notification method unless a plugin claims it, so the override below
  /// would never be called. It is claimed here instead.
  override func responds(to aSelector: Selector!) -> Bool {
    if aSelector
      == #selector(
        UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:))
    {
      return true
    }
    return super.responds(to: aSelector)
  }

  /// A silent push from CloudKit: another device has written, so Dart is
  /// told to go and pull. Given a few seconds to do so before the system
  /// is told the work is done. Anything else goes on to the plugins.
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if let note = CKNotification(fromRemoteNotificationDictionary: userInfo),
      note.subscriptionID == CloudBridge.subscriptionId
    {
      AppDelegate.cloudChannel?.invokeMethod("changed", arguments: nil)
      DispatchQueue.main.asyncAfter(deadline: .now() + 8) { completionHandler(.newData) }
      return
    }
    super.application(
      application, didReceiveRemoteNotification: userInfo,
      fetchCompletionHandler: completionHandler)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // The few things only the device can do, reached from Dart through
    // `MethodChannelDeviceBridge`.
    let channel = FlutterMethodChannel(
      name: "remindme/device", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    AppDelegate.channel = channel
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "setAppIcon":
        self?.setAppIcon(named: call.arguments as? String, result: result)
      case "setBadge":
        self?.setBadge(call.arguments as? Int ?? 0, result: result)
      case "previewSound", "playSound":
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
      case "showOnWidgets":
        if let json = call.arguments as? String { GlanceBridge.show(json) }
        result(nil)
      case "takeTappedTask":
        result(GlanceBridge.take())
      case "appVersion":
        result(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
      case "openUrl":
        if let raw = call.arguments as? String, let url = URL(string: raw) {
          UIApplication.shared.open(url)
        }
        result(nil)
      case "share":
        self?.share(call.arguments as? String ?? "", result: result)
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

    // The cloud, reached from Dart through `MethodChannelCloudTransport`.
    let cloudChannel = FlutterMethodChannel(
      name: "remindme/cloud", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    AppDelegate.cloudChannel = cloudChannel
    cloudChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let cloud = self?.cloud else {
        result(nil)
        return
      }
      Task {
        switch call.method {
        case "available":
          let answer = await cloud.available()
          DispatchQueue.main.async { result(answer) }
        case "pull":
          do {
            let answer = try await cloud.pull(token: call.arguments as? String)
            DispatchQueue.main.async { result(answer) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "cloud", message: error.localizedDescription, details: nil))
            }
          }
        case "push":
          do {
            try await cloud.push(call.arguments as? [String: Any] ?? [:])
            DispatchQueue.main.async { result(nil) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "cloud", message: error.localizedDescription, details: nil))
            }
          }
        default:
          DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
        }
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

  /// Numbers the icon. The system shows a badge only once notifications
  /// were allowed, and only with the badge among what was allowed; an app
  /// allowed before badges were asked for is granted them here without a
  /// prompt, since the system never asks twice. Never asked, nothing is
  /// done: the question is put when a reminder is first chosen, not here.
  /// Puts words up on the system's share sheet, over whatever is in front.
  /// On an iPad the sheet is a popover and has to be told where to point,
  /// so it is anchored to the middle of the screen with no arrow.
  private func share(_ text: String, result: @escaping FlutterResult) {
    let root = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?
      .rootViewController
    guard let root else { result(nil); return }
    var front = root
    while let presented = front.presentedViewController { front = presented }
    let sheet = UIActivityViewController(activityItems: [text], applicationActivities: nil)
    if let popover = sheet.popoverPresentationController {
      popover.sourceView = front.view
      popover.sourceRect = CGRect(
        x: front.view.bounds.midX, y: front.view.bounds.midY, width: 0, height: 0)
      popover.permittedArrowDirections = []
    }
    front.present(sheet, animated: true)
    result(nil)
  }

  private func setBadge(_ count: Int, result: @escaping FlutterResult) {
    let centre = UNUserNotificationCenter.current()
    centre.getNotificationSettings { settings in
      let apply = {
        DispatchQueue.main.async {
          UIApplication.shared.applicationIconBadgeNumber = count
          result(nil)
        }
      }
      switch settings.authorizationStatus {
      case .notDetermined, .denied:
        DispatchQueue.main.async { result(nil) }
      default:
        if settings.badgeSetting == .enabled {
          apply()
        } else {
          centre.requestAuthorization(options: [.badge]) { _, _ in apply() }
        }
      }
    }
  }

  /// Plays a bundled sound once: a reminder sound to be heard before it is
  /// chosen, or the done sound. A nil file is the system's own notification
  /// sound, which plays through the notification centre alone.
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
