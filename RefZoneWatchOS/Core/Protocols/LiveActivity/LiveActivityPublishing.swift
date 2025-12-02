//
//  LiveActivityPublishing.swift
//  RefZoneWatchOS
//
//  Simple protocol to publish minimal, versioned state used by the
//  watchOS Smart Stack widget. Keep platform-specific details behind
//  the conforming types.
//

import Foundation

// MARK: - LiveActivityPublishing

@MainActor
protocol LiveActivityPublishing {
  func start(state: LiveActivityState)
  func update(state: LiveActivityState)
  func end()
}
