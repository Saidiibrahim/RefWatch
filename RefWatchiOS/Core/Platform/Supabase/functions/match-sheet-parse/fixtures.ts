import type { MatchSheetParseClientRequest, MatchSheetParseResult } from "./contract.ts";

export const exampleParseRequest: MatchSheetParseClientRequest = {
  side: "home",
  expectedTeamName: "Metro FC",
  images: [
    {
      type: "input_image",
      image_url: "data:image/jpeg;base64,AAA=",
      detail: "high",
      filename: "sheet-1.jpg",
    },
    {
      type: "input_image",
      image_url: "data:image/jpeg;base64,BBB=",
      detail: "high",
      filename: "sheet-2.jpg",
    },
  ],
};

export const exampleOpenAIResponse = {
  status: "completed",
  output: [
    {
      type: "message",
      role: "assistant",
      content: [
        {
          type: "output_text",
          text: JSON.stringify({
            extractedTeamName: "Metro FC",
            warnings: [
              {
                code: "ambiguity",
                message: "One bench player name was partially obscured but still readable.",
              },
            ],
            parsedSheet: {
              starters: [
                {
                  displayName: "Alex Striker",
                  shirtNumber: 9,
                  position: "FW",
                  notes: null,
                },
                {
                  displayName: "Jordan Midfield",
                  shirtNumber: 8,
                  position: "CM",
                  notes: "Captain",
                },
              ],
              substitutes: [
                {
                  displayName: "Riley Bench",
                  shirtNumber: null,
                  position: null,
                  notes: "Number unreadable",
                },
              ],
              staff: [
                {
                  displayName: "Taylor Coach",
                  roleLabel: "Head Coach",
                  notes: null,
                  category: "staff",
                },
                {
                  displayName: "Morgan Physio",
                  roleLabel: "Physio",
                  notes: null,
                  category: "staff",
                },
              ],
              otherMembers: [
                {
                  displayName: "Casey Analyst",
                  roleLabel: "Analyst",
                  notes: null,
                  category: "otherMember",
                },
              ],
            },
          }),
        },
      ],
    },
  ],
};

export const exampleNormalizedResult: MatchSheetParseResult = {
  parsedSheet: {
    sourceTeamName: "Metro FC",
    status: "draft",
    starters: [
      {
        displayName: "Alex Striker",
        shirtNumber: 9,
        position: "FW",
        notes: null,
        sortOrder: 0,
      },
      {
        displayName: "Jordan Midfield",
        shirtNumber: 8,
        position: "CM",
        notes: "Captain",
        sortOrder: 1,
      },
    ],
    substitutes: [
      {
        displayName: "Riley Bench",
        shirtNumber: null,
        position: null,
        notes: "Number unreadable",
        sortOrder: 0,
      },
    ],
    staff: [
      {
        displayName: "Taylor Coach",
        roleLabel: "Head Coach",
        notes: null,
        sortOrder: 0,
        category: "staff",
      },
      {
        displayName: "Morgan Physio",
        roleLabel: "Physio",
        notes: null,
        sortOrder: 1,
        category: "staff",
      },
    ],
    otherMembers: [
      {
        displayName: "Casey Analyst",
        roleLabel: "Analyst",
        notes: null,
        sortOrder: 0,
        category: "otherMember",
      },
    ],
    updatedAt: "2026-03-27T00:00:00.000Z",
  },
  warnings: [
    {
      code: "ambiguity",
      message: "One bench player name was partially obscured but still readable.",
    },
  ],
  extractedTeamName: "Metro FC",
  terminalStatus: "completed",
};
