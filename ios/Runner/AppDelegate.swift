import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var privacyView: UIView?
  private var secureField: UITextField?
  private var screenSecurityEnabled = false
  private var screenChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    setSecureFileProtection()

    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "secure_player/screen_security",
        binaryMessenger: controller.binaryMessenger
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

    return launched
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
    return UIApplication.shared.windows.first(where: { $0.isKeyWindow })
      ?? UIApplication.shared.windows.first
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

  // Marks the app window as secure so its contents are excluded from
  // screenshots, screen recordings and the app-switcher snapshot — the iOS
  // equivalent of Android's FLAG_SECURE.
  private func applySecureField() {
    guard secureField == nil, let window = keyWindow() else { return }
    let field = UITextField()
    field.isSecureTextEntry = true
    field.isUserInteractionEnabled = false
    field.translatesAutoresizingMaskIntoConstraints = false
    window.addSubview(field)
    NSLayoutConstraint.activate([
      field.centerXAnchor.constraint(equalTo: window.centerXAnchor),
      field.centerYAnchor.constraint(equalTo: window.centerYAnchor),
    ])
    window.layer.superlayer?.addSublayer(field.layer)
    field.layer.sublayers?.first?.addSublayer(window.layer)
    secureField = field
  }

  private func removeSecureField() {
    secureField?.removeFromSuperview()
    secureField = nil
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

  // MARK: - App-switcher privacy shield

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    showPrivacyView()
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    showPrivacyView()
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    hidePrivacyView()
  }

  private func showPrivacyView() {
    guard let window = keyWindow() else { return }
    if privacyView != nil { return }

    let view = UIView(frame: window.bounds)
    view.backgroundColor = UIColor(red: 0x0A/255.0, green: 0x0A/255.0, blue: 0x1F/255.0, alpha: 1.0)
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    let badge = UIView()
    badge.translatesAutoresizingMaskIntoConstraints = false
    badge.layer.cornerRadius = 28
    badge.layer.masksToBounds = true

    let gradient = CAGradientLayer()
    gradient.colors = [
      UIColor(red: 0x41/255.0, green: 0x58/255.0, blue: 0xD0/255.0, alpha: 1.0).cgColor,
      UIColor(red: 0xC8/255.0, green: 0x50/255.0, blue: 0xC0/255.0, alpha: 1.0).cgColor,
      UIColor(red: 0xFF/255.0, green: 0xCC/255.0, blue: 0x70/255.0, alpha: 1.0).cgColor
    ]
    gradient.startPoint = CGPoint(x: 0, y: 0)
    gradient.endPoint = CGPoint(x: 1, y: 1)
    gradient.frame = CGRect(x: 0, y: 0, width: 110, height: 110)
    badge.layer.insertSublayer(gradient, at: 0)

    if #available(iOS 13.0, *) {
      let icon = UIImageView(image: UIImage(systemName: "shield.fill"))
      icon.tintColor = .white
      icon.contentMode = .scaleAspectFit
      icon.translatesAutoresizingMaskIntoConstraints = false
      badge.addSubview(icon)
      NSLayoutConstraint.activate([
        icon.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
        icon.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
        icon.widthAnchor.constraint(equalToConstant: 60),
        icon.heightAnchor.constraint(equalToConstant: 60),
      ])
    }

    view.addSubview(badge)
    NSLayoutConstraint.activate([
      badge.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      badge.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      badge.widthAnchor.constraint(equalToConstant: 110),
      badge.heightAnchor.constraint(equalToConstant: 110),
    ])

    window.addSubview(view)
    privacyView = view
  }

  private func hidePrivacyView() {
    privacyView?.removeFromSuperview()
    privacyView = nil
  }
}
