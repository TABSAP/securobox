import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var privacyView: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    showPrivacyView()
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    showPrivacyView()
  }

  override func applicationWillEnterForeground(_ application: UIApplication) {
    super.applicationWillEnterForeground(application)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    hidePrivacyView()
  }

  private func showPrivacyView() {
    guard let window = UIApplication.shared.windows.first else { return }
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
