//
//  SupabaseIdentityService.swift
//  RefZoneiOS
//
//  Encapsulates the RPC call to `public.upsert_user_from_clerk`, returning the
//  Supabase user identifier that will serve as owner id for subsequent syncs.
//

import Foundation

struct SupabaseIdentityPayload: Encodable, Equatable {
  struct ClerkSnapshot: Encodable, Equatable {
    let id: String
    let firstName: String?
    let lastName: String?
    let username: String?
    let email: String?
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
      case id
      case firstName = "first_name"
      case lastName = "last_name"
      case username
      case email
      case imageUrl = "image_url"
    }
  }

  let clerkUserId: String
  let primaryEmail: String?
  let firstName: String?
  let lastName: String?
  let displayName: String?
  let imageUrl: String?
  let clerkLastSyncedAt: Date
  let clerkSnapshot: ClerkSnapshot

  enum CodingKeys: String, CodingKey {
    case clerkUserId = "clerk_user_id"
    case primaryEmail = "primary_email"
    case firstName = "first_name"
    case lastName = "last_name"
    case displayName = "display_name"
    case imageUrl = "image_url"
    case clerkLastSyncedAt = "clerk_last_synced_at"
    case clerkSnapshot = "clerk_snapshot"
  }
}

struct SupabaseIdentityServiceResponse: Equatable {
  let supabaseUserId: String
  let clerkUserId: String
  let primaryEmail: String?
  let displayName: String?
  let clerkLastSyncedAt: Date?
}

protocol SupabaseIdentityServicing {
  func upsertClerkUser(payload: SupabaseIdentityPayload) async throws -> SupabaseIdentityServiceResponse
}

final class SupabaseIdentityService: SupabaseIdentityServicing {
  private struct RPCPayload: Encodable {
    let payload: SupabaseIdentityPayload
  }

  private struct SupabaseUserDTO: Decodable {
    let id: UUID
    let clerkUserId: String
    let primaryEmail: String?
    let displayName: String?
    let clerkLastSyncedAt: Date?

    enum CodingKeys: String, CodingKey {
      case id
      case clerkUserId = "clerk_user_id"
      case primaryEmail = "primary_email"
      case displayName = "display_name"
      case clerkLastSyncedAt = "clerk_last_synced_at"
    }
  }

  private let clientProvider: SupabaseClientProviding
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(
    clientProvider: SupabaseClientProviding = SupabaseClientProvider.shared,
    encoder: JSONEncoder = SupabaseIdentityService.makeEncoder(),
    decoder: JSONDecoder = SupabaseIdentityService.makeDecoder()
  ) {
    self.clientProvider = clientProvider
    self.encoder = encoder
    self.decoder = decoder
  }

  func upsertClerkUser(payload: SupabaseIdentityPayload) async throws -> SupabaseIdentityServiceResponse {
    let client = try await clientProvider.authorizedClient()
    let rpcPayload = RPCPayload(payload: payload)

    let dto: SupabaseUserDTO = try await client.callRPC(
      "upsert_user_from_clerk",
      params: rpcPayload,
      encoder: encoder,
      decoder: decoder
    )

    return SupabaseIdentityServiceResponse(
      supabaseUserId: dto.id.uuidString,
      clerkUserId: dto.clerkUserId,
      primaryEmail: dto.primaryEmail ?? payload.primaryEmail,
      displayName: dto.displayName ?? payload.displayName,
      clerkLastSyncedAt: dto.clerkLastSyncedAt ?? payload.clerkLastSyncedAt
    )
  }

  private static func makeEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }

  private static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}
