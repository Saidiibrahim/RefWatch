//
//  SupabaseJournalAPI.swift
//  RefWatchiOS
//
//  Network layer for syncing journal assessments with Supabase.
//

import Foundation
import RefWatchCore
import Supabase

protocol SupabaseJournalServing {
    func fetchAssessments(ownerId: UUID, updatedAfter: Date?) async throws -> [SupabaseJournalAPI.RemoteAssessment]
    func syncAssessment(_ request: SupabaseJournalAPI.AssessmentRequest) async throws -> SupabaseJournalAPI.SyncResult
    func deleteAssessment(id: UUID) async throws
}

struct SupabaseJournalAPI: SupabaseJournalServing {
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

    private let clientProvider: SupabaseClientProviding
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let isoFormatter: ISO8601DateFormatter

    init(
        clientProvider: SupabaseClientProviding = SupabaseClientProvider.shared,
        decoder: JSONDecoder = SupabaseJournalAPI.makeDecoder(),
        encoder: JSONEncoder = SupabaseJournalAPI.makeEncoder(),
        isoFormatter: ISO8601DateFormatter = SupabaseJournalAPI.makeISOFormatter()
    ) {
        self.clientProvider = clientProvider
        self.decoder = decoder
        self.encoder = encoder
        self.isoFormatter = isoFormatter
    }

    func fetchAssessments(ownerId: UUID, updatedAfter: Date?) async throws -> [RemoteAssessment] {
        let client = try await clientProvider.authorizedClient()
        guard let supabaseClient = client as? SupabaseClient else {
            throw APIError.unsupportedClient
        }

        var filters: [SupabaseQueryFilter] = [
            .equals("owner_id", value: ownerId.uuidString)
        ]
        if let updatedAfter {
            let value = isoFormatter.string(from: updatedAfter)
            filters.append(.greaterThan("updated_at", value: value))
        }

        let rows: [AssessmentRowDTO] = try await supabaseClient.fetchRows(
            from: "match_assessments",
            select: "id, match_id, owner_id, rating, overall, went_well, to_improve, created_at, updated_at",
            filters: filters,
            orderBy: "updated_at",
            ascending: true,
            limit: 0,
            decoder: decoder
        )

        return rows.map { row in
            RemoteAssessment(
                id: row.id,
                matchId: row.matchId,
                ownerId: row.ownerId,
                rating: row.rating,
                overall: row.overall,
                wentWell: row.wentWell,
                toImprove: row.toImprove,
                createdAt: row.createdAt,
                updatedAt: row.updatedAt
            )
        }
    }

    func syncAssessment(_ request: AssessmentRequest) async throws -> SyncResult {
        let client = try await clientProvider.authorizedClient()
        guard let supabaseClient = client as? SupabaseClient else {
            throw APIError.unsupportedClient
        }

        let payload = AssessmentUpsertDTO(
            id: request.id,
            matchId: request.matchId,
            ownerId: request.ownerId,
            rating: request.rating,
            overall: request.overall,
            wentWell: request.wentWell,
            toImprove: request.toImprove,
            createdAt: request.createdAt,
            updatedAt: request.updatedAt
        )

        let response: [AssessmentResponseDTO] = try await supabaseClient.upsertRows(
            into: "match_assessments",
            payload: payload,
            onConflict: "id",
            decoder: decoder
        )

        guard let first = response.first else {
            throw APIError.invalidResponse
        }

        return SyncResult(updatedAt: first.updatedAt)
    }

    func deleteAssessment(id: UUID) async throws {
        let client = try await clientProvider.authorizedClient()
        guard let supabaseClient = client as? SupabaseClient else {
            throw APIError.unsupportedClient
        }

        _ = try await supabaseClient
            .from("match_assessments")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

private extension SupabaseJournalAPI {
    static func makeDecoder() -> JSONDecoder {
        SupabaseJSONDecoderFactory.makeDecoder()
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeISOFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}

// MARK: - DTOs

private struct AssessmentRowDTO: Decodable, Sendable {
    let id: UUID
    let matchId: UUID
    let ownerId: UUID
    let rating: Int?
    let overall: String?
    let wentWell: String?
    let toImprove: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case matchId = "match_id"
        case ownerId = "owner_id"
        case rating
        case overall
        case wentWell = "went_well"
        case toImprove = "to_improve"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct AssessmentUpsertDTO: Encodable, Sendable {
    let id: UUID
    let matchId: UUID
    let ownerId: UUID
    let rating: Int?
    let overall: String?
    let wentWell: String?
    let toImprove: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case matchId = "match_id"
        case ownerId = "owner_id"
        case rating
        case overall
        case wentWell = "went_well"
        case toImprove = "to_improve"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct AssessmentResponseDTO: Decodable, Sendable {
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case updatedAt = "updated_at"
    }
}
