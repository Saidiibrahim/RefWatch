import Testing
@testable import RefZone_Watch_App

struct LiveActivityCommandStoreTests {
  @Test
  func test_writeThenConsume_roundTripsCommand() async throws {
    let suite = "group.refzone.shared.tests.\(UUID().uuidString)"
    let store = LiveActivityCommandStore(suiteName: suite)
    store.clear()

    let envelope = store.write(.pause)
    #expect(envelope.command == .pause)

    let consumed = store.consume()
    #expect(consumed?.command == .pause)
    #expect(store.consume() == nil)
  }

  @Test
  func test_clear_removesPersistedCommand() async throws {
    let suite = "group.refzone.shared.tests.\(UUID().uuidString)"
    let store = LiveActivityCommandStore(suiteName: suite)

    store.write(.resume)
    store.clear()

    #expect(store.consume() == nil)
  }
}
