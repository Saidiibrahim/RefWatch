import { z } from "zod";

const warningCodes = [
  "ambiguity", "duplicate_entry", "unreadable_text", "team_name_mismatch",
  "unsupported_role", "missing_name", "non_integer_shirt_number", "refusal",
  "incomplete_response", "dropped_entry",
] as const;

type Warning = { code: typeof warningCodes[number]; message: string };
type RecordValue = Record<string, unknown>;
const MAX_IMAGE_URL_BYTES = 8 * 1024 * 1024;
const MAX_AGGREGATE_IMAGE_BYTES = 24 * 1024 * 1024;
export const MAX_MATCH_SHEET_REQUEST_BYTES = 25 * 1024 * 1024;

export const matchSheetClientRequest = z.object({
  side: z.enum(["home", "away"]),
  expected_team_name: z.string().max(200).nullable().optional(),
  expectedTeamName: z.string().max(200).nullable().optional(),
  images: z.array(z.object({
    type: z.literal("input_image").optional(),
    image_url: z.string().min(1).max(MAX_IMAGE_URL_BYTES),
    detail: z.enum(["auto", "low", "high", "original"]).optional(),
    filename: z.string().max(255).optional(),
  })).min(1).max(6),
}).superRefine((value, context) => {
  const aggregateBytes = value.images.reduce((total, image) => total + image.image_url.length, 0);
  if (aggregateBytes > MAX_AGGREGATE_IMAGE_BYTES) context.addIssue({ code: "custom", path: ["images"], message: "Combined image payload exceeds 24 MiB" });
}).transform((value) => ({
  side: value.side,
  expected_team_name: normalizeString(value.expected_team_name ?? value.expectedTeamName),
  images: value.images,
}));

const warningSchema = {
  type: "object", additionalProperties: false,
  properties: { code: { type: "string", enum: warningCodes }, message: { type: "string", maxLength: 500 } },
  required: ["code", "message"],
} as const;
const playerSchema = {
  type: "object", additionalProperties: false,
  properties: { displayName: { type: "string", maxLength: 200 }, shirtNumber: { type: ["integer", "null"] }, position: { type: ["string", "null"], maxLength: 100 }, notes: { type: ["string", "null"], maxLength: 500 } },
  required: ["displayName", "shirtNumber", "position", "notes"],
} as const;
const staffSchema = {
  type: "object", additionalProperties: false,
  properties: { displayName: { type: "string", maxLength: 200 }, roleLabel: { type: ["string", "null"], maxLength: 100 }, notes: { type: ["string", "null"], maxLength: 500 }, category: { type: "string", enum: ["staff", "otherMember"] } },
  required: ["displayName", "roleLabel", "notes", "category"],
} as const;
const outputSchema = {
  type: "object", additionalProperties: false,
  properties: {
    extractedTeamName: { type: ["string", "null"], maxLength: 200 },
    warnings: { type: "array", maxItems: 50, items: warningSchema },
    parsedSheet: { type: "object", additionalProperties: false, properties: {
      starters: { type: "array", maxItems: 25, items: playerSchema }, substitutes: { type: "array", maxItems: 25, items: playerSchema },
      staff: { type: "array", maxItems: 20, items: staffSchema }, otherMembers: { type: "array", maxItems: 20, items: staffSchema },
    }, required: ["starters", "substitutes", "staff", "otherMembers"] },
  }, required: ["extractedTeamName", "warnings", "parsedSheet"],
} as const;

export function buildOpenAIRequest(input: z.infer<typeof matchSheetClientRequest>) {
  const prompt = [
    "Parse a football team match sheet from referee-provided screenshots.",
    `These screenshots belong to the ${input.side} side of a scheduled match.`,
    input.expected_team_name
      ? `Expected team name: ${input.expected_team_name}. If the visible team name differs, still extract the sheet and emit a team_name_mismatch warning.`
      : "No expected team name was supplied. Extract the visible team name when present.",
    "Return JSON that matches the schema exactly.",
    "Only include people that are explicitly visible in the screenshots.",
    "Do not infer unseen rows, names, numbers, or staff roles.",
    "Preserve the visible order when the source makes it clear.",
    "Use the starters array for the starting eleven or listed starting players.",
    "Use substitutes for the bench, reserve, or substitution list.",
    "Use staff for coaching staff and medical staff.",
    "Use otherMembers for non-player roles that are present but do not fit staff.",
    "If a person has no readable name, omit them and emit a missing_name warning.",
    "If a shirt number is unreadable or non-integer, set shirtNumber to null and emit a non_integer_shirt_number warning.",
    "Emit warnings for ambiguity, duplicates, unreadable text, unsupported roles, and team-name mismatch.",
    "Keep notes short and factual. Do not speculate.",
  ].join("\n");
  return {
    model: "gpt-5.4", stream: false, store: false, max_output_tokens: 8_000,
    input: [{ role: "user", content: [
      { type: "input_text", text: prompt },
      ...input.images.map((image) => ({ type: "input_image", image_url: image.image_url, detail: image.detail ?? "auto" })),
    ] }],
    text: { format: { type: "json_schema", name: "match_sheet_parse", strict: true, schema: outputSchema } },
  };
}

export function parseOpenAIResult(raw: unknown, expectedTeamName: string | null | undefined, now = new Date()) {
  if (!isRecord(raw)) throw new Error("OpenAI returned an invalid JSON payload.");
  const status = raw.status === "incomplete" ? "incomplete" : "completed";
  const parts = Array.isArray(raw.output)
    ? raw.output.flatMap((item) => isRecord(item) && Array.isArray(item.content) ? item.content : [])
    : [];
  const refusal = parts.find((part) => isRecord(part) && part.type === "refusal");
  if (isRecord(refusal)) {
    return emptyResult("refused", [{ code: "refusal", message: normalizeString(refusal.refusal) ?? "The parser refused to process the screenshots." }], now);
  }
  const directText = normalizeString(raw.output_text);
  const outputText = parts
    .filter((part): part is RecordValue => isRecord(part) && part.type === "output_text")
    .map((part) => normalizeString(part.text))
    .filter((text): text is string => text !== null)
    .join("");
  const text = directText ?? normalizeString(outputText);
  if (!text) {
    if (status === "incomplete") return emptyResult("incomplete", [{ code: "incomplete_response", message: "The parser stopped before producing a complete match sheet." }], now);
    throw new Error("OpenAI did not return a structured match-sheet payload.");
  }
  let parsed: unknown;
  try { parsed = JSON.parse(text); } catch { throw new Error("OpenAI returned malformed JSON for the match-sheet payload."); }
  const result = normalizeResult(parsed, expectedTeamName, status, now);
  if (status === "incomplete") result.warnings = dedupe([...result.warnings, { code: "incomplete_response", message: "The parser stopped before confirming the match sheet was complete." }]);
  return result;
}

function normalizeResult(raw: unknown, expectedTeamName: string | null | undefined, terminalStatus: "completed" | "incomplete", now: Date) {
  if (!isRecord(raw) || !isRecord(raw.parsedSheet)) throw new Error("Structured output is missing parsedSheet.");
  const extractedTeamName = normalizeString(raw.extractedTeamName);
  const warnings = normalizeWarnings(raw.warnings);
  const starters = normalizePlayers(raw.parsedSheet.starters, warnings);
  const substitutes = normalizePlayers(raw.parsedSheet.substitutes, warnings);
  const staff = normalizeStaff(raw.parsedSheet.staff, "staff", warnings);
  const otherMembers = normalizeStaff(raw.parsedSheet.otherMembers, "otherMember", warnings);
  if (expectedTeamName && extractedTeamName && !namesMatch(expectedTeamName, extractedTeamName)) {
    warnings.push({ code: "team_name_mismatch", message: `The screenshots appear to belong to ${extractedTeamName}, not ${expectedTeamName}.` });
  }
  return {
    parsedSheet: { sourceTeamName: extractedTeamName, status: "draft", starters, substitutes, staff, otherMembers, updatedAt: now.toISOString() },
    warnings: dedupe(warnings), extractedTeamName, terminalStatus,
  };
}

function normalizePlayers(raw: unknown, warnings: Warning[]) {
  if (!Array.isArray(raw)) return [];
  return raw.flatMap((entry, index) => {
    if (!isRecord(entry)) {
      warnings.push({ code: "dropped_entry", message: `Dropped an invalid player entry at row ${index + 1}.` });
      return [];
    }
    const displayName = normalizeString(entry.displayName);
    if (!displayName) {
      warnings.push({ code: "missing_name", message: `Dropped a player row without a readable name at row ${index + 1}.` });
      return [];
    }
    const shirtNumber = typeof entry.shirtNumber === "number" && Number.isInteger(entry.shirtNumber) ? entry.shirtNumber : null;
    if (entry.shirtNumber != null && shirtNumber == null) warnings.push({ code: "non_integer_shirt_number", message: `Player ${displayName} had a non-integer shirt number and it was cleared.` });
    return [{ displayName, shirtNumber, position: normalizeString(entry.position), notes: normalizeString(entry.notes), sortOrder: index }];
  });
}

function normalizeStaff(raw: unknown, category: "staff" | "otherMember", warnings: Warning[]) {
  if (!Array.isArray(raw)) return [];
  return raw.flatMap((entry, index) => {
    if (!isRecord(entry)) {
      warnings.push({ code: "dropped_entry", message: `Dropped an invalid staff entry at row ${index + 1}.` });
      return [];
    }
    const displayName = normalizeString(entry.displayName);
    if (!displayName) {
      warnings.push({ code: "missing_name", message: `Dropped a staff row without a readable name at row ${index + 1}.` });
      return [];
    }
    if ((entry.category === "staff" || entry.category === "otherMember") && entry.category !== category) warnings.push({ code: "unsupported_role", message: `Moved ${displayName} into ${category === "staff" ? "staff" : "other members"} to keep the parsed sheet consistent.` });
    return [{ displayName, roleLabel: normalizeString(entry.roleLabel), notes: normalizeString(entry.notes), sortOrder: index, category }];
  });
}

function normalizeWarnings(raw: unknown): Warning[] {
  if (!Array.isArray(raw)) return [];
  return raw.flatMap((warning) => {
    if (!isRecord(warning) || !warningCodes.includes(warning.code as Warning["code"])) return [];
    const message = normalizeString(warning.message);
    return message ? [{ code: warning.code as Warning["code"], message }] : [];
  });
}

function emptyResult(terminalStatus: "incomplete" | "refused", warnings: Warning[], now: Date) {
  return { parsedSheet: { sourceTeamName: null, status: "draft", starters: [], substitutes: [], staff: [], otherMembers: [], updatedAt: now.toISOString() }, warnings: dedupe(warnings), extractedTeamName: null, terminalStatus };
}

function dedupe(warnings: Warning[]) {
  const seen = new Set<string>();
  return warnings.filter((warning) => { const key = `${warning.code}:${warning.message}`; if (seen.has(key)) return false; seen.add(key); return true; });
}
function normalizeString(value: unknown) { if (typeof value !== "string") return null; const trimmed = value.trim(); return trimmed || null; }
function namesMatch(left: string, right: string) { return left.trim().localeCompare(right.trim(), undefined, { sensitivity: "accent" }) === 0; }
function isRecord(value: unknown): value is RecordValue { return typeof value === "object" && value !== null && !Array.isArray(value); }
