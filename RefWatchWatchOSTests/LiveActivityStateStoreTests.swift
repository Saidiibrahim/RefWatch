import Testing
@testable import RefWatch_Watch_App

struct LiveActivityStateStoreTests {
  @Test
  func test_encodeDecode_roundTrip() async throws {
    let now = Date()
    let state = LiveActivityState(
      version: 1,
      matchIdentifier: UUID().uuidString,
      homeAbbr: "HOM",
      awayAbbr: "AWA",
      homeScore: 1,
      awayScore: 0,
      periodLabel: "First Half",
      isPaused: false,
      isInStoppage: false,
      periodStart: now.addingTimeInterval(-600),
      expectedPeriodEnd: now.addingTimeInterval(600),
      elapsedAtPause: nil,
      stoppageAccumulated: 30,
      lastUpdated: now
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(state)
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(LiveActivityState.self, from: data)
    #expect(decoded == state)
  }

  @Test
  func test_store_roundTrip() async throws {
    // Use a dedicated test suite to avoid touching real app group in CI
    let suite = "group.refzone.shared.tests"
    let store = LiveActivityStateStore(suiteName: suite)
    let now = Date()

    let state = LiveActivityState(
      version: 1,
      matchIdentifier: "test-123",
      homeAbbr: "HOM",
      awayAbbr: "AWA",
      homeScore: 2,
      awayScore: 2,
      periodLabel: "Second Half",
      isPaused: true,
      isInStoppage: true,
      periodStart: now.addingTimeInterval(-1200),
      expectedPeriodEnd: nil,
      elapsedAtPause: 1234,
      stoppageAccumulated: 42,
      lastUpdated: now
    )

    store.write(state)
    let read = store.read()
    #expect(read == state)

    store.clear()
    #expect(store.read() == nil)
  }
}
