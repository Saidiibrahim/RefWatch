//
//  UIApplication+TopViewController.swift
//  RefZoneiOS
//
//  Convenience helpers to resolve the top-most view controller for presenting
//  authentication flows that rely on UIKit presenters.
//

import UIKit

extension UIApplication {
  /// Finds the top-most view controller for presenting authentication flows that require UIKit.
  static func topViewController(base: UIViewController? = UIApplication.activeWindow?.rootViewController) -> UIViewController? {
    if let nav = base as? UINavigationController {
      return topViewController(base: nav.visibleViewController)
    }
    if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
      return topViewController(base: selected)
    }
    if let presented = base?.presentedViewController {
      return topViewController(base: presented)
    }
    return base
  }

  /// Returns the current key window so coordinators can derive a presentation anchor.
  static var activeWindow: UIWindow? {
    UIApplication.shared
      .connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
  }
}
