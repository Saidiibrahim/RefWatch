export const MATCH_SHEET_PARSE_MODEL = "gpt-5.4";
export const MATCH_SHEET_PARSE_MAX_IMAGES = 6;

export type MatchSheetSide = "home" | "away";
export type MatchSheetImageDetail = "auto" | "low" | "high" | "original";
export type MatchSheetImportWarningCode =
  | "ambiguity"
  | "duplicate_entry"
  | "unreadable_text"
  | "team_name_mismatch"
  | "unsupported_role"
  | "missing_name"
  | "non_integer_shirt_number"
  | "refusal"
  | "incomplete_response"
  | "dropped_entry";

export type MatchSheetParseTerminalStatus = "completed" | "incomplete" | "refused";

export interface MatchSheetParseImageInput {
  type?: "input_image";
  image_url: string;
  detail?: MatchSheetImageDetail;
  filename?: string;
}

export interface MatchSheetParseClientRequest {
  side: MatchSheetSide;
  expectedTeamName: string | null;
  images: MatchSheetParseImageInput[];
}

export interface MatchSheetImportWarning {
  code: MatchSheetImportWarningCode;
  message: string;
}

export interface MatchSheetPlayerEntryJSON {
  displayName: string;
  shirtNumber?: number | null;
  position?: string | null;
  notes?: string | null;
  sortOrder: number;
}

export interface MatchSheetStaffEntryJSON {
  displayName: string;
  roleLabel?: string | null;
  notes?: string | null;
  sortOrder: number;
  category: "staff" | "otherMember";
}

export interface MatchSheetParseSheetJSON {
  sourceTeamName: string | null;
  status: "draft";
  starters: MatchSheetPlayerEntryJSON[];
  substitutes: MatchSheetPlayerEntryJSON[];
  staff: MatchSheetStaffEntryJSON[];
  otherMembers: MatchSheetStaffEntryJSON[];
  updatedAt: string;
}

export interface MatchSheetParseResult {
  parsedSheet: MatchSheetParseSheetJSON;
  warnings: MatchSheetImportWarning[];
  extractedTeamName: string | null;
  terminalStatus: MatchSheetParseTerminalStatus;
}

type JsonRecord = Record<string, unknown>;

export const MATCH_SHEET_WARNING_CODES: MatchSheetImportWarningCode[] = [
  "ambiguity",
  "duplicate_entry",
  "unreadable_text",
  "team_name_mismatch",
  "unsupported_role",
  "missing_name",
  "non_integer_shirt_number",
  "refusal",
  "incomplete_response",
  "dropped_entry",
];

const assistantWarningSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    code: {
      type: "string",
      enum: MATCH_SHEET_WARNING_CODES,
    },
    message: {
      type: "string",
    },
  },
  required: ["code", "message"],
} as const;

const assistantPlayerSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    displayName: { type: "string" },
    shirtNumber: {
      type: ["integer", "null"],
    },
    position: {
      type: ["string", "null"],
    },
    notes: {
      type: ["string", "null"],
    },
  },
  required: ["displayName", "shirtNumber", "position", "notes"],
} as const;

const assistantStaffSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    displayName: { type: "string" },
    roleLabel: {
      type: ["string", "null"],
    },
    notes: {
      type: ["string", "null"],
    },
    category: {
      type: "string",
      enum: ["staff", "otherMember"],
    },
  },
  required: ["displayName", "roleLabel", "notes", "category"],
} as const;

export const MATCH_SHEET_PARSE_OUTPUT_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    extractedTeamName: {
      type: ["string", "null"],
    },
    warnings: {
      type: "array",
      items: assistantWarningSchema,
    },
    parsedSheet: {
      type: "object",
      additionalProperties: false,
      properties: {
        starters: {
          type: "array",
          items: assistantPlayerSchema,
        },
        substitutes: {
          type: "array",
          items: assistantPlayerSchema,
        },
        staff: {
          type: "array",
          items: assistantStaffSchema,
        },
        otherMembers: {
          type: "array",
          items: assistantStaffSchema,
        },
      },
      required: ["starters", "substitutes", "staff", "otherMembers"],
    },
  },
  required: ["extractedTeamName", "warnings", "parsedSheet"],
} as const;

export function parseMatchSheetParseClientRequest(payload: unknown): MatchSheetParseClientRequest {
  if (isRecord(payload) === false) {
    throw new Error("Request body must be a JSON object.");
  }

  const side = readSide(payload.side);
  const expectedTeamName = normalizeString(payload.expectedTeamName ?? payload.expected_team_name);
  const images = Array.isArray(payload.images)
    ? payload.images.map((item, index) => normalizeImageInput(item, index))
    : [];

  if (images.length == 0) {
    throw new Error("At least one screenshot is required.");
  }

  if (images.length > MATCH_SHEET_PARSE_MAX_IMAGES) {
    throw new Error(`A maximum of ${MATCH_SHEET_PARSE_MAX_IMAGES} screenshots can be imported at once.`);
  }

  return {
    side,
    expectedTeamName,
    images,
  };
}

export function buildMatchSheetParseResponsesRequest(
  request: MatchSheetParseClientRequest,
): JsonRecord {
  const promptLines = [
    "Parse a football team match sheet from referee-provided screenshots.",
    `These screenshots belong to the ${request.side} side of a scheduled match.`,
    request.expectedTeamName
      ? `Expected team name: ${request.expectedTeamName}. If the visible team name differs, still extract the sheet and emit a team_name_mismatch warning.`
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
  ];

  return {
    model: MATCH_SHEET_PARSE_MODEL,
    stream: false,
    store: false,
    input: [
      {
        role: "user",
        content: [
          {
            type: "input_text",
            text: promptLines.join("\n"),
          },
          ...request.images.map((image) => ({
            type: "input_image",
            image_url: image.image_url,
            detail: image.detail ?? "auto",
          })),
        ],
      },
    ],
    text: {
      format: {
        type: "json_schema",
        name: "match_sheet_parse",
        strict: true,
        schema: MATCH_SHEET_PARSE_OUTPUT_SCHEMA,
      },
    },
  };
}

export function parseOpenAIResponsesResult(
  responsePayload: unknown,
  expectedTeamName: string | null,
  now: Date = new Date(),
): MatchSheetParseResult {
  if (isRecord(responsePayload) === false) {
    throw new Error("OpenAI returned an invalid JSON payload.");
  }

  const responseStatus = normalizeTerminalStatus(responsePayload.status);
  const outputItems = Array.isArray(responsePayload.output) ? responsePayload.output : [];
  const refusalText = findRefusal(outputItems);
  if (refusalText) {
    return emptyParseResult("refused", now, [
      {
        code: "refusal",
        message: refusalText,
      },
    ]);
  }

  const rawOutputText = findOutputText(outputItems);
  if (rawOutputText == null) {
    if (responseStatus == "incomplete") {
      return emptyParseResult("incomplete", now, [
        {
          code: "incomplete_response",
          message: "The parser stopped before producing a complete match sheet.",
        },
      ]);
    }
    throw new Error("OpenAI did not return a structured match-sheet payload.");
  }

  let rawStructuredPayload: unknown;
  try {
    rawStructuredPayload = JSON.parse(rawOutputText);
  } catch {
    throw new Error("OpenAI returned malformed JSON for the match-sheet payload.");
  }

  const normalized = normalizeMatchSheetParseResult(rawStructuredPayload, {
    now,
    terminalStatus: responseStatus,
    expectedTeamName,
  });

  if (responseStatus == "incomplete") {
    normalized.warnings = appendWarning(normalized.warnings, {
      code: "incomplete_response",
      message: "The parser stopped before confirming the match sheet was complete.",
    });
  }

  return normalized;
}

export function normalizeMatchSheetParseResult(
  rawPayload: unknown,
  options: {
    now?: Date;
    terminalStatus?: MatchSheetParseTerminalStatus;
    expectedTeamName?: string | null;
  } = {},
): MatchSheetParseResult {
  const now = options.now ?? new Date();
  const terminalStatus = options.terminalStatus ?? "completed";

  if (isRecord(rawPayload) === false) {
    throw new Error("Structured output must be a JSON object.");
  }

  const extractedTeamName = normalizeString(rawPayload.extractedTeamName);
  const warnings = normalizeWarnings(rawPayload.warnings);

  const parsedSheetPayload = rawPayload.parsedSheet;
  if (isRecord(parsedSheetPayload) === false) {
    throw new Error("Structured output is missing parsedSheet.");
  }

  const normalizedWarnings = [...warnings];
  const starters = normalizePlayers(parsedSheetPayload.starters, normalizedWarnings);
  const substitutes = normalizePlayers(parsedSheetPayload.substitutes, normalizedWarnings);
  const { staff, otherMembers } = normalizeStaffGroups(parsedSheetPayload, normalizedWarnings);

  if (options.expectedTeamName && extractedTeamName && namesMatch(options.expectedTeamName, extractedTeamName) == false) {
    normalizedWarnings.push({
      code: "team_name_mismatch",
      message: `The screenshots appear to belong to ${extractedTeamName}, not ${options.expectedTeamName}.`,
    });
  }

  return {
    parsedSheet: {
      sourceTeamName: extractedTeamName,
      status: "draft",
      starters,
      substitutes,
      staff,
      otherMembers,
      updatedAt: now.toISOString(),
    },
    warnings: dedupeWarnings(normalizedWarnings),
    extractedTeamName,
    terminalStatus,
  };
}

export function emptyParseResult(
  terminalStatus: MatchSheetParseTerminalStatus,
  now: Date = new Date(),
  warnings: MatchSheetImportWarning[] = [],
): MatchSheetParseResult {
  return {
    parsedSheet: {
      sourceTeamName: null,
      status: "draft",
      starters: [],
      substitutes: [],
      staff: [],
      otherMembers: [],
      updatedAt: now.toISOString(),
    },
    warnings: dedupeWarnings(warnings),
    extractedTeamName: null,
    terminalStatus,
  };
}

function normalizeImageInput(item: unknown, index: number): MatchSheetParseImageInput {
  if (isRecord(item) === false) {
    throw new Error(`images[${index}] must be an object.`);
  }

  const imageUrl = normalizeString(item.image_url);
  if (imageUrl == null) {
    throw new Error(`images[${index}] must include image_url.`);
  }

  return {
    type: "input_image",
    image_url: imageUrl,
    detail: readDetail(item.detail),
    filename: normalizeString(item.filename) ?? undefined,
  };
}

function normalizeWarnings(rawWarnings: unknown): MatchSheetImportWarning[] {
  if (Array.isArray(rawWarnings) === false) {
    return [];
  }

  return rawWarnings.flatMap((warning) => {
    if (isRecord(warning) === false) {
      return [];
    }

    const code = normalizeWarningCode(warning.code);
    const message = normalizeString(warning.message);
    if (code == null || message == null) {
      return [];
    }

    return [{ code, message }];
  });
}

function normalizePlayers(
  rawEntries: unknown,
  warnings: MatchSheetImportWarning[],
): MatchSheetPlayerEntryJSON[] {
  if (Array.isArray(rawEntries) === false) {
    return [];
  }

  return rawEntries.flatMap((entry, index) => {
    if (isRecord(entry) === false) {
      warnings.push({
        code: "dropped_entry",
        message: `Dropped an invalid player entry at row ${index + 1}.`,
      });
      return [];
    }

    const displayName = normalizeString(entry.displayName);
    if (displayName == null) {
      warnings.push({
        code: "missing_name",
        message: `Dropped a player row without a readable name at row ${index + 1}.`,
      });
      return [];
    }

    const shirtNumber = normalizeInteger(entry.shirtNumber);
    if (entry.shirtNumber !== undefined && entry.shirtNumber !== null && shirtNumber == null) {
      warnings.push({
        code: "non_integer_shirt_number",
        message: `Player ${displayName} had a non-integer shirt number and it was cleared.`,
      });
    }

    return [
      {
        displayName,
        shirtNumber,
        position: normalizeString(entry.position),
        notes: normalizeString(entry.notes),
        sortOrder: index,
      },
    ];
  });
}

function normalizeStaffGroups(
  rawSheet: JsonRecord,
  warnings: MatchSheetImportWarning[],
): { staff: MatchSheetStaffEntryJSON[]; otherMembers: MatchSheetStaffEntryJSON[] } {
  const normalizedStaff = normalizeStaffEntries(rawSheet.staff, "staff", warnings);
  const normalizedOther = normalizeStaffEntries(rawSheet.otherMembers, "otherMember", warnings);
  return {
    staff: normalizedStaff.map((entry, index) => ({ ...entry, category: "staff", sortOrder: index })),
    otherMembers: normalizedOther.map((entry, index) => ({ ...entry, category: "otherMember", sortOrder: index })),
  };
}

function normalizeStaffEntries(
  rawEntries: unknown,
  expectedCategory: "staff" | "otherMember",
  warnings: MatchSheetImportWarning[],
): MatchSheetStaffEntryJSON[] {
  if (Array.isArray(rawEntries) === false) {
    return [];
  }

  return rawEntries.flatMap((entry, index) => {
    if (isRecord(entry) === false) {
      warnings.push({
        code: "dropped_entry",
        message: `Dropped an invalid staff entry at row ${index + 1}.`,
      });
      return [];
    }

    const displayName = normalizeString(entry.displayName);
    if (displayName == null) {
      warnings.push({
        code: "missing_name",
        message: `Dropped a staff row without a readable name at row ${index + 1}.`,
      });
      return [];
    }

    const category = readStaffCategory(entry.category) ?? expectedCategory;
    if (category !== expectedCategory) {
      warnings.push({
        code: "unsupported_role",
        message: `Moved ${displayName} into ${expectedCategory == "staff" ? "staff" : "other members"} to keep the parsed sheet consistent.`,
      });
    }

    return [
      {
        displayName,
        roleLabel: normalizeString(entry.roleLabel),
        notes: normalizeString(entry.notes),
        sortOrder: index,
        category: expectedCategory,
      },
    ];
  });
}

function findRefusal(outputItems: unknown[]): string | null {
  for (const item of outputItems) {
    if (isRecord(item) === false || Array.isArray(item.content) === false) {
      continue;
    }
    for (const part of item.content) {
      if (isRecord(part) && part.type === "refusal") {
        return normalizeString(part.refusal) ?? "The parser refused to process the screenshots.";
      }
    }
  }
  return null;
}

function findOutputText(outputItems: unknown[]): string | null {
  for (const item of outputItems) {
    if (isRecord(item) === false || Array.isArray(item.content) === false) {
      continue;
    }
    const textParts = item.content
      .flatMap((part) => {
        if (isRecord(part) && part.type === "output_text") {
          const text = normalizeString(part.text);
          return text ? [text] : [];
        }
        return [];
      });
    if (textParts.length > 0) {
      return textParts.join("");
    }
  }
  return null;
}

function dedupeWarnings(warnings: MatchSheetImportWarning[]): MatchSheetImportWarning[] {
  const seen = new Set<string>();
  return warnings.filter((warning) => {
    const key = `${warning.code}:${warning.message}`;
    if (seen.has(key)) {
      return false;
    }
    seen.add(key);
    return true;
  });
}

function appendWarning(
  warnings: MatchSheetImportWarning[],
  warning: MatchSheetImportWarning,
): MatchSheetImportWarning[] {
  return dedupeWarnings([...warnings, warning]);
}

function normalizeTerminalStatus(status: unknown): MatchSheetParseTerminalStatus {
  return status === "incomplete" ? "incomplete" : "completed";
}

function readSide(value: unknown): MatchSheetSide {
  return value === "away" ? "away" : "home";
}

function readDetail(value: unknown): MatchSheetImageDetail | undefined {
  switch (value) {
  case "low":
  case "high":
  case "original":
    return value;
  case "auto":
    return "auto";
  default:
    return undefined;
  }
}

function readStaffCategory(value: unknown): "staff" | "otherMember" | null {
  if (value === "staff" || value === "otherMember") {
    return value;
  }
  return null;
}

function normalizeWarningCode(value: unknown): MatchSheetImportWarningCode | null {
  if (typeof value !== "string") {
    return null;
  }
  return MATCH_SHEET_WARNING_CODES.includes(value as MatchSheetImportWarningCode)
    ? (value as MatchSheetImportWarningCode)
    : null;
}

function normalizeString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeInteger(value: unknown): number | null {
  if (typeof value === "number" && Number.isInteger(value)) {
    return value;
  }
  return null;
}

function namesMatch(lhs: string, rhs: string): boolean {
  return lhs.trim().localeCompare(rhs.trim(), undefined, { sensitivity: "accent" }) === 0;
}

function isRecord(value: unknown): value is JsonRecord {
  return typeof value === "object" && value !== null && Array.isArray(value) === false;
}
