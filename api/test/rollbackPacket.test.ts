import { describe, expect, it } from "vitest";
import { validateRollbackPacket } from "../scripts/rollback-packet.mjs";

function validPacket() {
  return {
    schema_version: 1,
    status: "approved",
    owner: "cutover operator",
    approved_at_utc: "2026-07-14T00:00:00Z",
    window: { start_at_utc: "2026-07-14T01:00:00Z", end_at_utc: "2026-07-16T01:00:00Z" },
    trigger_thresholds: {
      auth_failure_rate_percent: 2,
      owner_scope_violations: 0,
      worker_5xx_rate_percent: 1,
      sync_backlog_oldest_seconds: 900,
      database_connection_utilization_percent: 80,
    },
    versions: {
      worker_name: "refwatch-api-production",
      environment: "production",
      candidate_worker_version_id: "11111111-1111-4111-8111-111111111111",
      last_known_good_worker_version_id: "22222222-2222-4222-8222-222222222222",
      write_guard_worker_version_id: "33333333-3333-4333-8333-333333333333",
      provider_readback_at_utc: "2026-07-14T00:30:00Z",
      write_guard_probe_receipt_id: "guard-probe-1",
    },
    write_ledger: {
      location: "restricted://refwatch/cutover/write-ledger.jsonl",
      schema_version: 1,
      fields: [
        "schema_version", "event_id", "event_sequence", "epoch_id", "mutation_group_id",
        "group_ordinal", "entity_type", "entity_id", "entity_revision", "operation",
        "before", "after", "source_kind", "source_event_id", "request_id",
        "idempotency_key", "app_user_id", "method", "path", "actor_id",
        "worker_version_id", "captured_at_utc", "content_digest", "encryption_key_id",
      ],
      provider_readback_at_utc: "2026-07-14T00:30:00Z",
      probe_receipt_id: "ledger-probe-1",
    },
    client_recovery_release: {
      marketing_version: "0.8.2",
      build: "1",
      distribution_status: "testflight_ready",
      operator_instructions: "Promote the reviewed recovery build and notify the incident channel.",
    },
  };
}

describe("rollback packet validation", () => {
  it("accepts a complete approved packet", () => {
    expect(validateRollbackPacket(validPacket(), { now: new Date("2026-07-14T00:45:00Z") })).toMatchObject({ ok: true, errors: [] });
  });

  it("rejects a draft, unsafe owner threshold, and unavailable client recovery", () => {
    const packet = validPacket();
    packet.status = "draft";
    packet.trigger_thresholds.owner_scope_violations = 1;
    packet.client_recovery_release.distribution_status = "planned";
    const result = validateRollbackPacket(packet, { now: new Date("2026-07-14T00:45:00Z") });
    expect(result.ok).toBe(false);
    expect(result.errors).toContain("status must be approved");
    expect(result.errors).toContain("owner_scope_violations threshold must be zero");
    expect(result.errors).toContain("client recovery release must already be distributable");
  });

  it("requires distinct deployable Worker versions and the complete write ledger", () => {
    const packet = validPacket();
    packet.versions.write_guard_worker_version_id = packet.versions.last_known_good_worker_version_id;
    packet.write_ledger.fields = ["request_id"];
    const result = validateRollbackPacket(packet, { now: new Date("2026-07-14T00:45:00Z") });
    expect(result.ok).toBe(false);
    expect(result.errors).toContain("candidate, last-known-good, and write-guard versions must be distinct");
    expect(result.errors).toContain("write_ledger.fields must include worker_version_id");
  });

  it("requires a bounded forward-moving observation window", () => {
    const packet = validPacket();
    packet.window.end_at_utc = packet.window.start_at_utc;
    expect(validateRollbackPacket(packet, { now: new Date("2026-07-14T00:45:00Z") }).errors).toContain("rollback window end must be after start");
  });

  it("rejects stale, non-UTC, and impossible operational claims", () => {
    const packet = validPacket();
    packet.approved_at_utc = "2026-07-14";
    packet.window.end_at_utc = "2026-07-14T00:30:00Z";
    packet.trigger_thresholds.worker_5xx_rate_percent = 999;
    packet.write_ledger.location = "x";
    const result = validateRollbackPacket(packet, { now: new Date("2026-07-14T00:45:00Z") });
    expect(result.errors).toContain("approved_at_utc must be a strict UTC instant");
    expect(result.errors).toContain("rollback window must not already be expired");
    expect(result.errors).toContain("trigger_thresholds.worker_5xx_rate_percent must not exceed 100");
    expect(result.errors).toContain("write_ledger.location must use the restricted RefWatch namespace");
  });
});
