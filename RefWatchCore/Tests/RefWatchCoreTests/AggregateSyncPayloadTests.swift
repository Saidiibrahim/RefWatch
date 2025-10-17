//
//  AggregateSyncPayloadTests.swift
//  RefWatchCoreTests
//

import XCTest
@testable import RefWatchCore

final class AggregateSyncPayloadTests: XCTestCase {
    func testSnapshotRoundTrip() throws {
        let encoder = AggregateSyncCoding.makeEncoder()
        let decoder = AggregateSyncCoding.makeDecoder()
        let now = Date(timeIntervalSince1970: 1_735_000_000)
        let settings = AggregateSnapshotPayload.Settings(
            connectivityStatus: .reachable,
            lastSuccessfulSupabaseSync: now.addingTimeInterval(-180),
            requiresBackfill: false
        )

        let team = AggregateSnapshotPayload.Team(
            id: UUID(),
            ownerSupabaseId: "owner",
            lastModifiedAt: now.addingTimeInterval(-60),
            remoteUpdatedAt: now.addingTimeInterval(-120),
            name: "Refzone FC",
            shortName: "RFC",
            division: "Premier",
            primaryColorHex: "#FF0000",
            secondaryColorHex: "#00FF00",
            players: [
                .init(id: UUID(), name: "Player 1", number: 10, position: "FW", notes: nil),
                .init(id: UUID(), name: "Player 2", number: nil, position: nil, notes: "Captain")
            ],
            officials: [
                .init(id: UUID(), name: "Coach 1", roleRaw: "coach", phone: nil, email: "coach@example.com")
            ]
        )

        let competition = AggregateSnapshotPayload.Competition(
            id: UUID(),
            ownerSupabaseId: "owner",
            lastModifiedAt: now.addingTimeInterval(-200),
            remoteUpdatedAt: now.addingTimeInterval(-220),
            name: "League",
            level: "A"
        )

        let venue = AggregateSnapshotPayload.Venue(
            id: UUID(),
            ownerSupabaseId: "owner",
            lastModifiedAt: now.addingTimeInterval(-300),
            remoteUpdatedAt: now.addingTimeInterval(-320),
            name: "Stadium",
            city: "City",
            country: "Country",
            latitude: 45.1,
            longitude: -75.0
        )

        let schedule = AggregateSnapshotPayload.Schedule(
            id: UUID(),
            ownerSupabaseId: "owner",
            lastModifiedAt: now.addingTimeInterval(-400),
            remoteUpdatedAt: now.addingTimeInterval(-420),
            homeName: "Home",
            awayName: "Away",
            kickoff: now.addingTimeInterval(3600),
            competition: "League",
            notes: "Semi-final",
            statusRaw: "scheduled",
            sourceDeviceId: "watch"
        )

        let chunk = AggregateSnapshotPayload.ChunkMetadata(index: 0, count: 1)
        let snapshot = AggregateSnapshotPayload(
            generatedAt: now,
            lastSyncedAt: now.addingTimeInterval(-600),
            acknowledgedChangeIds: [UUID()],
            chunk: chunk,
            settings: settings,
            teams: [team],
            venues: [venue],
            competitions: [competition],
            schedules: [schedule]
        )

        let data = try encoder.encode(snapshot)
        let decoded = try decoder.decode(AggregateSnapshotPayload.self, from: data)
        XCTAssertEqual(decoded, snapshot)
    }

    func testDeltaPayloadRoundTrip() throws {
        struct StubTeam: Codable, Equatable {
            var id: UUID
            var name: String
        }

        let teamPayload = StubTeam(id: UUID(), name: "Watch Team")
        let encoder = AggregateSyncCoding.makeEncoder()
        let decoder = AggregateSyncCoding.makeDecoder()
        let payloadData = try encoder.encode(teamPayload)
        let envelope = AggregateDeltaEnvelope(
            id: UUID(),
            entity: .team,
            action: .update,
            payload: payloadData,
            modifiedAt: Date(),
            origin: .watch,
            dependencies: [UUID()],
            requiresSnapshotRefresh: true
        )

        let encoded = try encoder.encode(envelope)
        let decoded = try decoder.decode(AggregateDeltaEnvelope.self, from: encoded)
        XCTAssertEqual(decoded, envelope)

        let decodedPayload: StubTeam = try decoded.decodePayload(as: StubTeam.self, using: decoder)
        XCTAssertEqual(decodedPayload, teamPayload)
    }

    func testManualSyncStatusRoundTrip() throws {
        let message = ManualSyncStatusMessage(
            reachable: true,
            queued: 3,
            queuedDeltas: 2,
            pendingSnapshotChunks: 1,
            lastSnapshot: Date(timeIntervalSince1970: 1_735_000_000)
        )

        let encoder = AggregateSyncCoding.makeEncoder()
        let decoder = AggregateSyncCoding.makeDecoder()
        let data = try encoder.encode(message)
        let decoded = try decoder.decode(ManualSyncStatusMessage.self, from: data)
        XCTAssertEqual(decoded, message)
    }

    func testManualSyncRequestRoundTrip() throws {
        let request = ManualSyncRequestMessage(reason: .manual)
        let encoder = AggregateSyncCoding.makeEncoder()
        let decoder = AggregateSyncCoding.makeDecoder()
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(ManualSyncRequestMessage.self, from: data)
        XCTAssertEqual(decoded, request)
    }

    func testDecodePayloadThrowsOnMissingData() {
        let envelope = AggregateDeltaEnvelope(
            id: UUID(),
            entity: .venue,
            action: .delete,
            payload: nil,
            modifiedAt: Date(),
            origin: .watch
        )

        XCTAssertThrowsError(try envelope.decodePayload(as: String.self)) { error in
            guard case AggregateSyncPayloadError.missingPayload = error else {
                return XCTFail("Expected missingPayload error")
            }
        }
    }
}
