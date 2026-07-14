//
//  JournalRemoteContract.swift
//  RefWatchiOS
//
//  Network layer for syncing journal assessments with Supabase.
//

import Foundation
import RefWatchCore

protocol JournalRemoteServing {
  func fetchAssessments(ownerId: UUID, updatedAfter: Date?) async throws -> [JournalRemoteContract.RemoteAssessment]
  func syncAssessment(_ request: JournalRemoteContract.AssessmentRequest) async throws -> JournalRemoteContract.SyncResult
  func deleteAssessment(id: UUID) async throws
}

struct JournalRemoteContract {
  struct RemoteAssessment: Equatable, Sendable {
    let id: UUID
    let matchId: UUID
    let ownerId: UUID
    let rating: Int?
    let overall: String?
    let wentWell: String?
    let toImprove: String?
    let createdAt: Date
    let updatedAt: Date
  }

  struct AssessmentRequest: Equatable, Sendable {
    let id: UUID
    let matchId: UUID
    let ownerId: UUID
    let rating: Int?
    let overall: String?
    let wentWell: String?
    let toImprove: String?
    let createdAt: Date
    let updatedAt: Date
  }

  struct SyncResult: Equatable, Sendable {
    let updatedAt: Date
  }

  enum APIError: Error, Equatable, Sendable {
    case unsupportedClient
    case invalidResponse
  }

}
