//
//  SubstitutionFlowSupportTests.swift
//  RefWatch Watch AppTests
//

import Testing
@testable import RefWatch_Watch_App

struct SubstitutionFlowSupportTests {

  @Test func testSelectionSummary_whenEmpty_returnsDefaultCopy() async throws {
    let summary = SubstitutionFlowSupport.selectionSummary(for: [])
    #expect(summary == "Select player")
  }

  @Test func testSelectionSummary_whenSelectionsExist_returnsCommaSeparatedNumbersOnly() async throws {
    let selections = [
      SubstitutionSelection(number: 12, name: "Alex"),
      SubstitutionSelection(number: 16, name: "Jamie"),
    ]

    let summary = SubstitutionFlowSupport.selectionSummary(for: selections)

    #expect(summary == "12, 16")
  }

  @Test func testSelectionSummary_whenNumberMissing_usesQuestionMark() async throws {
    let selections = [
      SubstitutionSelection(number: nil, name: "Alex"),
      SubstitutionSelection(number: 7, name: "Jamie"),
    ]

    let summary = SubstitutionFlowSupport.selectionSummary(for: selections)

    #expect(summary == "?, 7")
  }

  @Test func testConfirmationSummary_whenNamesExist_returnsNumbersOnly() async throws {
    let summary = SubstitutionFlowSupport.confirmationSummary(
      playerOff: SubstitutionSelection(number: 2, name: "Alexandria Johnson-Smith"),
      playerOn: SubstitutionSelection(number: 12, name: "Eleanor Whitmore"))

    #expect(summary == "2 -> 12")
  }

  @Test func testConfirmationSummary_whenNumberMissing_usesQuestionMark() async throws {
    let summary = SubstitutionFlowSupport.confirmationSummary(
      playerOff: SubstitutionSelection(number: nil, name: "Alex"),
      playerOn: SubstitutionSelection(number: 7, name: "Jamie"))

    #expect(summary == "? -> 7")
  }

  @Test func testAppendManualSelection_whenUnique_appendsInOrder() async throws {
    var selections = [SubstitutionSelection(number: 12, name: nil)]

    let didAppend = SubstitutionFlowSupport.appendManualSelection(number: 16, to: &selections)

    #expect(didAppend)
    #expect(selections.map(\.number) == [12, 16])
  }

  @Test func testAppendManualSelection_whenDuplicate_rejectsNumber() async throws {
    var selections = [SubstitutionSelection(number: 12, name: nil)]

    let didAppend = SubstitutionFlowSupport.appendManualSelection(number: 12, to: &selections)

    #expect(didAppend == false)
    #expect(selections.map(\.number) == [12])
  }

  @Test func testRemoveMostRecentSelection_popsLatestCommittedNumber() async throws {
    var selections = [
      SubstitutionSelection(number: 12, name: nil),
      SubstitutionSelection(number: 16, name: nil),
      SubstitutionSelection(number: 18, name: nil),
    ]

    SubstitutionFlowSupport.removeMostRecentSelection(from: &selections)

    #expect(selections.map(\.number) == [12, 16])
  }

  @Test func testRemoveMostRecentSelection_canRepeatUntilEmpty() async throws {
    var selections = [
      SubstitutionSelection(number: 12, name: nil),
      SubstitutionSelection(number: 16, name: nil),
    ]

    SubstitutionFlowSupport.removeMostRecentSelection(from: &selections)
    #expect(selections.map(\.number) == [12])

    SubstitutionFlowSupport.removeMostRecentSelection(from: &selections)
    #expect(selections.isEmpty)

    SubstitutionFlowSupport.removeMostRecentSelection(from: &selections)
    #expect(selections.isEmpty)
  }

  @Test func testCanSubmit_requiresEqualNonZeroCounts() async throws {
    let offSelections = [
      SubstitutionSelection(number: 4, name: nil),
      SubstitutionSelection(number: 7, name: nil),
    ]
    let onSelections = [
      SubstitutionSelection(number: 12, name: nil),
      SubstitutionSelection(number: 15, name: nil),
    ]

    #expect(SubstitutionFlowSupport.canSubmit(playersOff: offSelections, playersOn: onSelections))
    #expect(SubstitutionFlowSupport.canSubmit(playersOff: offSelections, playersOn: []) == false)
    #expect(SubstitutionFlowSupport.canSubmit(playersOff: [], playersOn: onSelections) == false)
    #expect(
      SubstitutionFlowSupport.canSubmit(
        playersOff: [SubstitutionSelection(number: 4, name: nil)],
        playersOn: onSelections) == false)
  }

  @Test func testShouldRequireConfirmation_onlyForSinglePairWhenEnabled() async throws {
    #expect(
      SubstitutionFlowSupport.shouldRequireConfirmation(
        confirmSubstitutions: true,
        pairCount: 1))
    #expect(
      SubstitutionFlowSupport.shouldRequireConfirmation(
        confirmSubstitutions: true,
        pairCount: 2) == false)
    #expect(
      SubstitutionFlowSupport.shouldRequireConfirmation(
        confirmSubstitutions: false,
        pairCount: 1) == false)
  }

  @Test func testNumericKeypadBackspace_removesTypedDigitsUntilEmpty() async throws {
    var input = "16"

    let firstRemoved = NumericKeypadSupport.applyBackspace(to: &input)
    #expect(firstRemoved)
    #expect(input == "1")

    let secondRemoved = NumericKeypadSupport.applyBackspace(to: &input)
    #expect(secondRemoved)
    #expect(input.isEmpty)

    let thirdRemoved = NumericKeypadSupport.applyBackspace(to: &input)
    #expect(thirdRemoved == false)
    #expect(input.isEmpty)
  }
}
