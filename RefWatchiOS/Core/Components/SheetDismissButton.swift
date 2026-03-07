//
//  SheetDismissButton.swift
//  RefWatchiOS
//
//  Standardised dismiss button for sheet toolbars.
//

import SwiftUI

struct SheetDismissButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: self.action) {
      Image(systemName: "xmark.circle.fill")
        .foregroundStyle(.secondary)
    }
    .accessibilityLabel("Dismiss")
  }
}
