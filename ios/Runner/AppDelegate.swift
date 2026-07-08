import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var secureField: UITextField?
  private weak var securedHostView: UIView?
  private var screenSecurityEnabled = false
  private var screenChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    setSecureFileProtection()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleScreenshot),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleCaptureChange),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Called once the implicit FlutterEngine (created by the storyboard's
  // FlutterViewController) is ready. Under the UIScene lifecycle the window and
  // root view controller no longer exist in didFinishLaunchingWithOptions, so
  // plugin registration and application-level method channels are set up here.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "secure_player/screen_security",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "setSecure":
        let on = (call.arguments as? Bool) ?? false
        self?.setScreenSecure(on)
        result(nil)
      case "isCaptured":
        result(UIScreen.main.isCaptured)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    screenChannel = channel
  }

  private func setSecureFileProtection() {
    let fm = FileManager.default
    guard let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
    do {
      try (docsURL as NSURL).setResourceValue(
        URLFileProtection.completeUntilFirstUserAuthentication,
        forKey: .fileProtectionKey
      )
    } catch {}

    if let enumerator = fm.enumerator(at: docsURL, includingPropertiesForKeys: nil) {
      for case let url as URL in enumerator {
        try? (url as NSURL).setResourceValue(
          URLFileProtection.completeUntilFirstUserAuthentication,
          forKey: .fileProtectionKey
        )
      }
    }
  }

  // MARK: - Screen capture protection

  private func keyWindow() -> UIWindow? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    return windows.first(where: { $0.isKeyWindow }) ?? windows.first
  }

  private func setScreenSecure(_ enabled: Bool) {
    screenSecurityEnabled = enabled
    DispatchQueue.main.async {
      if enabled {
        self.applySecureField()
      } else {
        self.removeSecureField()
      }
    }
  }

  // Marks the app content as secure so it is excluded from screenshots, screen
  // recordings and the app-switcher snapshot — the iOS equivalent of Android's
  // FLAG_SECURE. The trick reparents the host view's layer into the hidden
  // secure canvas of an `isSecureTextEntry` UITextField, so the content still
  // renders full-screen but the system refuses to capture it.
  //
  // It MUST be applied to a full-size subview (the root view controller's
  // view), not the UIWindow: a window's layer has no superlayer, so anchoring
  // the trick there collapses all content into the text field's tiny frame.
  private func applySecureField() {
    guard secureField == nil,
          let hostView = keyWindow()?.rootViewController?.view else { return }
    let field = UITextField()
    field.isSecureTextEntry = true
    field.isUserInteractionEnabled = false
    field.translatesAutoresizingMaskIntoConstraints = false
    hostView.addSubview(field)
    NSLayoutConstraint.activate([
      field.centerXAnchor.constraint(equalTo: hostView.centerXAnchor),
      field.centerYAnchor.constraint(equalTo: hostView.centerYAnchor),
    ])
    hostView.layer.superlayer?.addSublayer(field.layer)
    field.layer.sublayers?.last?.addSublayer(hostView.layer)
    secureField = field
    securedHostView = hostView
  }

  private func removeSecureField() {
    // Restore the host view's layer to the window before tearing down the
    // field, otherwise removing the field would also remove the content layer
    // that was reparented beneath it.
    if let hostView = securedHostView, let window = hostView.window {
      window.layer.addSublayer(hostView.layer)
    }
    secureField?.removeFromSuperview()
    secureField = nil
    securedHostView = nil
  }

  @objc private func handleScreenshot() {
    if screenSecurityEnabled {
      screenChannel?.invokeMethod("onScreenshot", arguments: nil)
    }
  }

  @objc private func handleCaptureChange() {
    // Re-assert protection when a screen recording starts.
    if screenSecurityEnabled && UIScreen.main.isCaptured {
      DispatchQueue.main.async { self.applySecureField() }
    }
    screenChannel?.invokeMethod("onCaptureChange", arguments: UIScreen.main.isCaptured)
  }
}
