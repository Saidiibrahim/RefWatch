//
//  UIApplication+TopViewController.swift
//  RefZoneiOS
//
//  Convenience helpers to resolve the top-most view controller for presenting
//  authentication flows that rely on UIKit presenters.
//

import UIKit

extension UIApplication {
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

  static var activeWindow: UIWindow? {
    UIApplication.shared
      .connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
  }
}
