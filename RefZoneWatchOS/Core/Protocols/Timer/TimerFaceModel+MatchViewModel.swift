// TimerFaceModel+MatchViewModel.swift
// Exposes MatchViewModel to timer faces via read-only state and minimal actions

import Foundation
import RefWatchCore

extension MatchViewModel: TimerFaceModelState, TimerFaceModelActions {}

