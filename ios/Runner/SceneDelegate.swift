import Flutter
import UIKit

/// Scene delegate for the UIScene lifecycle (required by upcoming iOS versions).
///
/// Subclasses Flutter's `FlutterSceneDelegate` so Flutter continues to own the
/// window and engine wiring. We only reinstate the app-switcher privacy shield
/// that previously lived in `AppDelegate`'s now-deprecated app-lifecycle
/// callbacks (`applicationWillResignActive` / `applicationDidEnterBackground` /
/// `applicationDidBecomeActive`), which the system no longer delivers once a
/// scene manifest is present.
class SceneDelegate: FlutterSceneDelegate {
  private var privacyView: UIView?

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    showPrivacyView()
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    super.sceneDidEnterBackground(scene)
    showPrivacyView()
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    hidePrivacyView()
  }

  // MARK: - App-switcher privacy shield

  private func showPrivacyView() {
    guard let window = window else { return }
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
