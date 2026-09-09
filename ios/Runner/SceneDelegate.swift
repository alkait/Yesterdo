import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  /// A tap that starts the app from cold hands its address over here,
  /// before Dart is listening, so the task is only held. Dart asks for it as
  /// it comes up.
  override func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    hold(connectionOptions.urlContexts)
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  /// A tap on an app already running comes here instead. The task is held
  /// the same way, and Dart is nudged to come and take it.
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    hold(URLContexts)
    AppDelegate.nudgeWidgetTap()
    super.scene(scene, openURLContexts: URLContexts)
  }

  /// Keeps the task named by `yesterdo://task/<day>:<key>`, and lets every
  /// other address by.
  private func hold(_ contexts: Set<UIOpenURLContext>) {
    for context in contexts {
      guard let payload = GlanceBridge.payload(from: context.url) else { continue }
      GlanceBridge.hold(payload)
    }
  }
}
