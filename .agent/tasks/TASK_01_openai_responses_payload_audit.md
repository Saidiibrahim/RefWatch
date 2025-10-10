---
task_id: 01
plan_id: openai_responses_migration
plan_file: ../plans/PLAN_openai_responses_migration.md
title: Audit current implementation and define input mapping
phase: Phase 1 - Data Model & Request Construction
created: 2025-10-09
status: Ready
priority: High
estimated_minutes: 90
dependencies: []
tags: [api, design, documentation, audit]
---

## Objective
Analyze the current `OpenAIAssistantService.swift` implementation and define the exact mapping from Chat Completions format to Responses API format.

## Current Implementation Details

### Request Payload (Chat Completions)
```swift
[
  "model": "gpt-4o-mini",
  "stream": true,
  "messages": [
    {"role": "system", "content": "You are RefWatch's helpful..."},
    {"role": "user", "content": "Hello"},
    {"role": "assistant", "content": "Hi there!"},
    {"role": "user", "content": "How are you?"}
  ]
]
```

### Target Payload (Responses API)
```swift
[
  "model": "gpt-4o-mini",
  "stream": true,
  "instructions": "You are RefWatch's helpful...",
  "input": [
    {"role": "user", "content": "Hello"},
    {"role": "assistant", "content": "Hi there!"},
    {"role": "user", "content": "How are you?"}
  ]
]
```

## Key Mapping Rules

### 1. System Prompt Extraction
- **Current**: First message with `role: "system"`
- **Target**: Top-level `instructions` field
- **Implementation**: Extract system prompt before building `input` array

### 2. Message Array Transformation
- **Current**: `messages` array includes system message
- **Target**: `input` array excludes system message (moved to `instructions`)
- **Roles**: Keep `user` and `assistant` roles unchanged

### 3. Optional Parameters
Document these for future use (not implemented in Phase 1):
- `previous_response_id`: For stateful conversations
- `metadata`: For request tracking
- `max_output_tokens`: Token limit control
- `temperature`, `top_p`: Sampling parameters (currently defaults)

## Validation Rules
- System prompt must not be empty
- Input array must have at least one message after system extraction
- All messages must have valid `role` (`user` or `assistant`)
- All messages must have non-empty `content`

## Deliverables
1. **Design document** (inline or in this file) with:
   - Exact transformation algorithm
   - Edge case handling (empty history, missing system prompt)
   - Validation rules
2. **Code comments** outlining the mapping for Task 02 implementation
3. **Examples** of valid request payloads for testing

## Edge Cases to Consider
- **Empty chat history**: Only system prompt, no user messages yet
- **Missing system prompt**: Use default or return error?
- **Mixed role order**: Validate alternating user/assistant pattern?
- **Long messages**: Handle truncation strategy

## Acceptance Criteria
✅ Clear mapping rules documented
✅ Edge cases identified and resolution defined
✅ Validation rules specified
✅ Examples created for common scenarios

