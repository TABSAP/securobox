import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    setSecureFileProtection()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Called once the implicit FlutterEngine (created by the storyboard's
  // FlutterViewController) is ready. Under the UIScene lifecycle the window and
  // root view controller no longer exist in didFinishLaunchingWithOptions, so
  // generated plugins are registered here.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
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
}
