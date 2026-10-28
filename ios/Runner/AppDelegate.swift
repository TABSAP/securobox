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

    for name in ["vault", "vault_decoy"] {
      let vaultURL = docsURL.appendingPathComponent(name, isDirectory: true)
      try? fm.createDirectory(at: vaultURL, withIntermediateDirectories: true)
      try? (vaultURL as NSURL).setResourceValue(
        true,
        forKey: .isExcludedFromBackupKey
      )
      if let enumerator = fm.enumerator(at: vaultURL, includingPropertiesForKeys: nil) {
        for case let url as URL in enumerator {
          try? (url as NSURL).setResourceValue(
            true,
            forKey: .isExcludedFromBackupKey
          )
        }
      }
    }

    if let libraryURL = fm.urls(for: .libraryDirectory, in: .userDomainMask).first {
      let preferencesURL = libraryURL.appendingPathComponent("Preferences", isDirectory: true)
      try? fm.createDirectory(at: preferencesURL, withIntermediateDirectories: true)
      try? (preferencesURL as NSURL).setResourceValue(
        true,
        forKey: .isExcludedFromBackupKey
      )
      if let enumerator = fm.enumerator(at: preferencesURL, includingPropertiesForKeys: nil) {
        for case let url as URL in enumerator {
          try? (url as NSURL).setResourceValue(
            true,
            forKey: .isExcludedFromBackupKey
          )
        }
      }
    }
  }
}
