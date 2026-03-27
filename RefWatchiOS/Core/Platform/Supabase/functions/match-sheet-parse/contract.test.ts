import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildMatchSheetParseResponsesRequest,
  normalizeMatchSheetParseResult,
  parseMatchSheetParseClientRequest,
  parseOpenAIResponsesResult,
} from "./contract.ts";
import {
  exampleNormalizedResult,
  exampleOpenAIResponse,
  exampleParseRequest,
} from "./fixtures.ts";

Deno.test("buildMatchSheetParseResponsesRequest preserves multiple input_image parts", () => {
  const request = buildMatchSheetParseResponsesRequest(exampleParseRequest);
  const input = request.input as Array<Record<string, unknown>>;
  const firstMessage = input[0];
  const content = firstMessage.content as Array<Record<string, unknown>>;

  assertEquals(request.stream, false);
  assertEquals(request.store, false);
  assertEquals(content[1].type, "input_image");
  assertEquals(content[2].type, "input_image");
  assertEquals(content[1].image_url, "data:image/jpeg;base64,AAA=");
  assertEquals(content[2].image_url, "data:image/jpeg;base64,BBB=");
});

Deno.test("buildMatchSheetParseResponsesRequest pins strict json schema output", () => {
  const request = buildMatchSheetParseResponsesRequest(exampleParseRequest);
  const text = request.text as Record<string, unknown>;
  const format = text.format as Record<string, unknown>;

  assertEquals(format.type, "json_schema");
  assertEquals(format.name, "match_sheet_parse");
  assertEquals(format.strict, true);
  assertEquals(
    Array.isArray(
      ((format.schema as Record<string, unknown>).properties as Record<string, unknown>).warnings
        ? []
        : [],
    ),
    true,
  );
});

Deno.test("normalizeMatchSheetParseResult trims fields and forces draft status", () => {
  const result = normalizeMatchSheetParseResult(
    {
      extractedTeamName: "  Metro FC  ",
      warnings: [],
      parsedSheet: {
        starters: [
          {
            displayName: "  Alex Striker ",
            shirtNumber: 9,
            position: " FW ",
            notes: "  Captain  ",
          },
        ],
        substitutes: [],
        staff: [
          {
            displayName: "  Taylor Coach ",
            roleLabel: "  Head Coach ",
            notes: " ",
            category: "staff",
          },
        ],
        otherMembers: [],
      },
    },
    {
      now: new Date("2026-03-27T00:00:00.000Z"),
      expectedTeamName: "Metro FC",
    },
  );

  assertEquals(result.parsedSheet.sourceTeamName, "Metro FC");
  assertEquals(result.parsedSheet.status, "draft");
  assertEquals(result.parsedSheet.starters[0].displayName, "Alex Striker");
  assertEquals(result.parsedSheet.starters[0].position, "FW");
  assertEquals(result.parsedSheet.starters[0].notes, "Captain");
  assertEquals(result.parsedSheet.staff[0].displayName, "Taylor Coach");
  assertEquals(result.parsedSheet.staff[0].roleLabel, "Head Coach");
});

Deno.test("parseOpenAIResponsesResult returns normalized parsed payload", () => {
  const result = parseOpenAIResponsesResult(
    exampleOpenAIResponse,
    "Metro FC",
    new Date("2026-03-27T00:00:00.000Z"),
  );

  assertEquals(result, exampleNormalizedResult);
});

Deno.test("parseMatchSheetParseClientRequest rejects missing screenshots", () => {
  assertThrows(
    () =>
      parseMatchSheetParseClientRequest({
        side: "home",
        expectedTeamName: "Metro FC",
        images: [],
      }),
    Error,
    "At least one screenshot is required.",
  );
});
