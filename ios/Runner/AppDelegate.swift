import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let messenger = engineBridge.pluginRegistry
      .registrar(forPlugin: "ScreenCaptureGuard")?.messenger() {
      captureGuard = ScreenCaptureGuard(messenger: messenger)
    }
  }

  private var captureGuard: ScreenCaptureGuard?
}

/// Fair play while a running-session hand is on screen. iOS cannot block
/// screenshots, so while Dart asks for "secure" and the screen is being
/// recorded or mirrored, a black privacy view covers the whole app window.
final class ScreenCaptureGuard {
  private var secure = false
  private var overlay: UIView?

  init(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.finaltable.app/screen_capture", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setSecure" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any]
      self?.secure = (args?["secure"] as? Bool) ?? false
      self?.refresh()
      result(nil)
    }
    NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in self?.refresh() }
  }

  private var keyWindow: UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
  }

  private func refresh() {
    guard let window = keyWindow else { return }
    if secure && window.screen.isCaptured {
      if overlay == nil {
        let cover = UIView(frame: window.bounds)
        cover.backgroundColor = .black
        cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(cover)
        overlay = cover
      }
    } else {
      overlay?.removeFromSuperview()
      overlay = nil
    }
  }
}
