import { describe, expect, it } from "vitest";
import { matchBundleInput } from "../src/routes/matches";
import { buildOpenAIRequest, matchSheetClientRequest, parseOpenAIResult } from "../src/routes/matchSheetContract";
import { readBoundedJson } from "../src/routes/matchSheetParse";

const id = "0190f8f4-5914-7b6c-9d6a-469a29f92f2a";

describe("match ingest contract", () => {
  it("accepts legacy owner fields without treating them as authoritative", () => {
    const result = matchBundleInput.safeParse({
      match: { id, owner_id: "a-clerk-id-is-not-an-owner", completed_at: "2026-07-14T00:00:00.000Z", number_of_periods: 2, home_team_name: "Home", away_team_name: "Away", penalty_initial_rounds: 5, home_score: 1, away_score: 0 },
      periods: [], events: [], metrics: null,
    });
    expect(result.success).toBe(true);
    if (result.success) expect(result.data.match.owner_id).toBe("a-clerk-id-is-not-an-owner");
  });

  it("rejects malformed nested records", () => {
    const result = matchBundleInput.safeParse({ match: { id, completed_at: "not-a-date" }, periods: [{}] });
    expect(result.success).toBe(false);
  });

  it("preserves optional event team references", () => {
    const result = matchBundleInput.safeParse({
      match: { id, completed_at: "2026-07-14T00:00:00.000Z", number_of_periods: 2, home_team_name: "Home", away_team_name: "Away", penalty_initial_rounds: 5, home_score: 1, away_score: 0 },
      events: [{
        id,
        match_id: id,
        occurred_at: "2026-07-14T00:00:00.000Z",
        period_index: 1,
        clock_seconds: 10,
        match_time_label: "00:10",
        event_type: "goal",
        team_id: "0190f8f4-5914-7b6c-9d6a-469a29f92f2b",
        team_member_id: "0190f8f4-5914-7b6c-9d6a-469a29f92f2c",
      }],
    });
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.events[0]?.team_id).toBe("0190f8f4-5914-7b6c-9d6a-469a29f92f2b");
      expect(result.data.events[0]?.team_member_id).toBe("0190f8f4-5914-7b6c-9d6a-469a29f92f2c");
    }
  });

  it("bounds the number of events accepted in one ingest bundle", () => {
    const base = {
      id,
      match_id: id,
      occurred_at: "2026-07-14T00:00:00.000Z",
      period_index: 0,
      clock_seconds: 0,
      match_time_label: "0:00",
      event_type: "goal",
    };
    const result = matchBundleInput.safeParse({
      match: { id, completed_at: "2026-07-14T00:00:00.000Z", number_of_periods: 2, home_team_name: "Home", away_team_name: "Away", penalty_initial_rounds: 5, home_score: 1, away_score: 0 },
      periods: [],
      events: Array.from({ length: 501 }, () => base),
      metrics: null,
    });
    expect(result.success).toBe(false);
  });
});

describe("match-sheet parser contract", () => {
  it("keeps OpenAI credentials out of the generated request body", () => {
    const parsed = matchSheetClientRequest.parse({ side: "home", expectedTeamName: " Ref FC ", images: [{ image_url: "data:image/jpeg;base64,AA==" }] });
    const request = buildOpenAIRequest(parsed);
    expect(JSON.stringify(request)).not.toContain("OPENAI_API_KEY");
    expect(request.store).toBe(false);
    expect(request.stream).toBe(false);
    expect(request.max_output_tokens).toBe(8_000);
    expect(request.text.format.name).toBe("match_sheet_parse");
    expect(JSON.stringify(request)).toContain("Expected team name: Ref FC");
  });

  it("normalizes structured output into the Swift response contract", () => {
    const result = parseOpenAIResult({ status: "completed", output_text: JSON.stringify({ extractedTeamName: "Ref FC", warnings: [], parsedSheet: { starters: [{ displayName: "A", shirtNumber: 1, position: null, notes: null }], substitutes: [], staff: [], otherMembers: [] } }) }, "Ref FC");
    expect(result.terminalStatus).toBe("completed");
    expect(result.parsedSheet.status).toBe("draft");
    expect(result.parsedSheet.starters[0]).toMatchObject({ displayName: "A", sortOrder: 0 });
  });

  it("retains the legacy trimming, warning, and dropped-row behavior", () => {
    const now = new Date("2026-07-14T00:00:00.000Z");
    const result = parseOpenAIResult({ status: "completed", output: [{ content: [{ type: "output_text", text: JSON.stringify({
      extractedTeamName: " Other FC ",
      warnings: [{ code: "ambiguity", message: " unclear " }, { code: "unknown", message: "drop" }],
      parsedSheet: {
        starters: [{ displayName: " Alex ", shirtNumber: 9.5, position: " FW ", notes: " " }, { displayName: " ", shirtNumber: 2, position: null, notes: null }],
        substitutes: [],
        staff: [{ displayName: " Pat ", roleLabel: " Coach ", notes: null, category: "otherMember" }],
        otherMembers: [],
      },
    }) }] }] }, "Ref FC", now);
    expect(result.parsedSheet.updatedAt).toBe(now.toISOString());
    expect(result.parsedSheet.starters).toEqual([{ displayName: "Alex", shirtNumber: null, position: "FW", notes: null, sortOrder: 0 }]);
    expect(result.parsedSheet.staff[0]).toMatchObject({ displayName: "Pat", roleLabel: "Coach", category: "staff" });
    expect(result.warnings.map((warning) => warning.code)).toEqual(expect.arrayContaining(["ambiguity", "non_integer_shirt_number", "missing_name", "unsupported_role", "team_name_mismatch"]));
    expect(result.warnings.some((warning) => String(warning.code) === "unknown")).toBe(false);
  });

  it("returns explicit refusal and incomplete terminal contracts", () => {
    const now = new Date("2026-07-14T00:00:00.000Z");
    const refused = parseOpenAIResult({ output: [{ content: [{ type: "refusal", refusal: " Cannot parse " }] }] }, null, now);
    expect(refused).toMatchObject({ terminalStatus: "refused", warnings: [{ code: "refusal", message: "Cannot parse" }] });
    const incomplete = parseOpenAIResult({ status: "incomplete", output: [] }, null, now);
    expect(incomplete).toMatchObject({ terminalStatus: "incomplete", warnings: [{ code: "incomplete_response" }] });
  });

  it("bounds match-sheet strings and aggregate image payloads", () => {
    expect(matchSheetClientRequest.safeParse({ side: "home", expected_team_name: "x".repeat(201), images: [{ image_url: "data:x" }] }).success).toBe(false);
    const image = "x".repeat(5 * 1024 * 1024);
    expect(matchSheetClientRequest.safeParse({ side: "home", images: Array.from({ length: 5 }, () => ({ image_url: image })) }).success).toBe(false);
  });

  it("stops reading a request body at the byte ceiling", async () => {
    const request = new Request("https://example.test", { method: "POST", body: "123456" });
    await expect(readBoundedJson(request, 5)).rejects.toThrow();
  });
});
