import { describe, expect, it } from "vitest";
import { computeSanitizedReceiptSha256 } from "../scripts/greenfield-launch-packet.mjs";
import {
  validateHistoricalGreenfieldRollbackPacketV2,
  validateRollbackPacket,
} from "../scripts/rollback-packet.mjs";

const customDomainProviderId = "d".repeat(32);

function customDomainEdgeBinding() {
  return {
    kind: "custom_domain",
    hostname: "api.refwatch.ibby.ai",
    provider_id: customDomainProviderId,
    worker_name: "refwatch-api",
    tls_status: "active",
    dns_management: "cloudflare_worker_custom_domain",
  };
}

const greenfieldRecoverySteps = [
  "stop_production_traffic_and_writes",
  "route_to_write_guard_worker",
  "roll_back_worker_and_client",
  "reset_planetscale_application_state",
  "reseed_deterministic_reference_data",
  "recreate_test_identities",
  "rerun_greenfield_launch_acceptance",
];

function sealFallbackProbe(probe: any): void {
  probe.deployment_provider_readback_sha256 =
    computeSanitizedReceiptSha256({
      receipt_id: probe.deployment_provider_receipt_id,
      deployment_id: probe.deployment_id,
      worker_version_id: probe.worker_version_id,
      ...(probe.edge_binding
        ? {
            edge_binding: probe.edge_binding,
            conflicting_zone_route_count:
              probe.conflicting_zone_route_count,
            manual_dns_origin_present: probe.manual_dns_origin_present,
          }
        : {
            route_id: probe.route_id,
            hostname: probe.hostname,
            route_pattern: probe.route_pattern,
          }),
      traffic_percentage: probe.traffic_percentage,
      competing_version_count: probe.competing_version_count,
      observed_before_at_utc: probe.deployment_observed_before_at_utc,
      observed_after_at_utc: probe.deployment_observed_after_at_utc,
    });
  probe.receipt_sha256 = computeSanitizedReceiptSha256(
    Object.fromEntries(
      Object.entries(probe).filter(([key]) => key !== "receipt_sha256"),
    ),
  );
}

function validStatefulPacket() {
  return {
    schema_version: 1,
    rollback_profile: "stateful_migration_v1",
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
      worker_name: "refwatch-api",
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

function validGreenfieldPacket() {
  const packet = validStatefulPacket();
  delete (packet as Partial<typeof packet>).write_ledger;
  return {
    ...packet,
    rollback_profile: "greenfield_destructive_v1",
    greenfield_recovery: {
      mode: "destructive_reset_reseed_recreate",
      steps: [...greenfieldRecoverySteps],
      operator_instructions: "Stop traffic, route the guard, reset and reseed, recreate test identities, then rerun acceptance.",
      ledger_escrow_required: false,
      ledger_recovery_required: false,
      ledger_activation_required: false,
      supabase_reverse_import_required: false,
    },
  };
}

function validHistoricalGreenfieldV2Packet() {
  const packet = validGreenfieldPacket();
  function fallbackProbe(
    receiptId: string,
    observedAtUTC: string,
    workerVersionId: string,
    deploymentId: string,
  ) {
    const observedMillis = Date.parse(observedAtUTC);
    const probe = {
      status: "passed",
      receipt_id: receiptId,
      receipt_sha256: "",
      observed_at_utc: observedAtUTC,
      worker_version_id: workerVersionId,
      worker_name: "refwatch-api",
      environment: "production",
      versions_provider_readback_at_utc: "2026-07-14T00:30:00Z",
      deployment_id: deploymentId,
      deployment_provider_receipt_id: `provider-${deploymentId}`,
      deployment_provider_readback_sha256: "",
      deployment_observed_before_at_utc:
        new Date(observedMillis - 10_000).toISOString(),
      deployment_observed_after_at_utc:
        new Date(observedMillis + 10_000).toISOString(),
      route_id: "route-production-api",
      hostname: "api.refwatch.ibby.ai",
      route_pattern: "api.refwatch.ibby.ai/*",
      traffic_percentage: 100,
      competing_version_count: 0,
      health_status: "passed",
      health_worker_version_id: workerVersionId,
      readiness_status: "passed",
      readiness_worker_version_id: workerVersionId,
      write_mode: "disabled",
      new_user_onboarding_mode: "disabled",
      write_denial_status: "retryable_denial",
      write_denial_http_status: 503,
      identity_mutation_count: 0,
      application_mutation_count: 0,
      clerk_instance_id: "ins_3GWFGUd1rI6hx5lWlUxMYAkxdac",
      database_branch_id: "w3g1f8vcbg34",
    };
    sealFallbackProbe(probe);
    return probe;
  }
  const acceptedVersion = "44444444-4444-4444-8444-444444444444";
  return {
    ...packet,
    rollback_profile: "greenfield_destructive_v2",
    window: {
      start_at_utc: "2026-07-14T00:31:00Z",
      end_at_utc: packet.window.end_at_utc,
    },
    versions: {
      worker_name: packet.versions.worker_name,
      environment: packet.versions.environment,
      candidate_worker_version_id: packet.versions.candidate_worker_version_id,
      accepted_worker_version_id: acceptedVersion,
      last_known_good_worker_version_id:
        packet.versions.last_known_good_worker_version_id,
      write_guard_worker_version_id:
        packet.versions.write_guard_worker_version_id,
      provider_readback_at_utc: packet.versions.provider_readback_at_utc,
      write_guard_probe: fallbackProbe(
        "guard-probe-v2",
        "2026-07-14T00:35:00Z",
        packet.versions.write_guard_worker_version_id,
        "deployment-guard",
      ),
      last_known_good_probe: fallbackProbe(
        "last-known-good-probe-v2",
        "2026-07-14T00:36:00Z",
        packet.versions.last_known_good_worker_version_id,
        "deployment-lkg",
      ),
    },
  };
}

function validGreenfieldV3Packet() {
  const packet = validHistoricalGreenfieldV2Packet() as any;
  packet.rollback_profile = "greenfield_destructive_v3";
  packet.edge_binding = customDomainEdgeBinding();
  packet.conflicting_zone_route_count = 0;
  packet.manual_dns_origin_present = false;
  for (const probe of [
    packet.versions.write_guard_probe,
    packet.versions.last_known_good_probe,
  ]) {
    delete probe.route_id;
    delete probe.hostname;
    delete probe.route_pattern;
    probe.edge_binding = customDomainEdgeBinding();
    probe.conflicting_zone_route_count = 0;
    probe.manual_dns_origin_present = false;
    sealFallbackProbe(probe);
  }
  return packet;
}

describe("rollback packet validation", () => {
  it("accepts a complete approved stateful migration packet", () => {
    expect(validateRollbackPacket(validStatefulPacket(), { now: new Date("2026-07-14T00:45:00Z") })).toMatchObject({
      ok: true,
      errors: [],
      summary: {
        rollbackProfile: "stateful_migration_v1",
        workerName: "refwatch-api",
        recoveryMode: "stateful_ledger_recovery",
      },
    });
  });

  it("preserves greenfield_destructive_v1 without an accepted version or last-known-good probe", () => {
    const packet = validGreenfieldPacket();
    expect(packet.versions).not.toHaveProperty("accepted_worker_version_id");
    expect(packet.versions).not.toHaveProperty("last_known_good_probe_receipt_id");
    expect(validateRollbackPacket(packet, { now: new Date("2026-07-14T00:45:00Z") })).toMatchObject({
      ok: true,
      errors: [],
      summary: {
        rollbackProfile: "greenfield_destructive_v1",
        workerName: "refwatch-api",
        recoveryMode: "destructive_reset_reseed_recreate",
      },
    });
  });

  it("accepts greenfield_destructive_v3 with one exact Custom Domain binding", () => {
    expect(validateRollbackPacket(validGreenfieldV3Packet(), { now: new Date("2026-07-14T00:45:00Z") })).toMatchObject({
      ok: true,
      errors: [],
      summary: {
        rollbackProfile: "greenfield_destructive_v3",
        workerName: "refwatch-api",
        recoveryMode: "destructive_reset_reseed_recreate",
      },
    });
  });

  it("accepts route-based v2 only through the explicit historical validator", () => {
    const packet = validHistoricalGreenfieldV2Packet();
    expect(validateRollbackPacket(packet, {
      now: new Date("2026-07-14T00:45:00Z"),
    }).errors).toContain(
      "rollback_profile must be stateful_migration_v1, greenfield_destructive_v1, or greenfield_destructive_v3",
    );
    expect(validateHistoricalGreenfieldRollbackPacketV2(packet, {
      now: new Date("2026-07-14T00:45:00Z"),
    })).toMatchObject({
      ok: true,
      errors: [],
      summary: { rollbackProfile: "greenfield_destructive_v2" },
    });
  });

  it("rejects a draft, unsafe owner threshold, and unavailable client recovery", () => {
    const packet = validStatefulPacket();
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
    const packet = validStatefulPacket();
    packet.versions.write_guard_worker_version_id = packet.versions.last_known_good_worker_version_id;
    packet.write_ledger.fields = ["request_id"];
    const result = validateRollbackPacket(packet, { now: new Date("2026-07-14T00:45:00Z") });
    expect(result.ok).toBe(false);
    expect(result.errors).toContain("candidate, last-known-good, and write-guard versions must be distinct");
    expect(result.errors).toContain("write_ledger.fields must include worker_version_id");
  });

  it("requires a bounded forward-moving observation window", () => {
    const packet = validStatefulPacket();
    packet.window.end_at_utc = packet.window.start_at_utc;
    expect(validateRollbackPacket(packet, { now: new Date("2026-07-14T00:45:00Z") }).errors).toContain("rollback window end must be after start");
  });

  it("rejects stale, non-UTC, and impossible operational claims", () => {
    const packet = validStatefulPacket();
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

  it("preserves profile-less legacy packets as stateful_migration_v1", () => {
    const packet = validStatefulPacket();
    delete (packet as Partial<typeof packet>).rollback_profile;
    expect(validateRollbackPacket(packet, { now: new Date("2026-07-14T00:45:00Z") })).toMatchObject({
      ok: true,
      errors: [],
      summary: {
        rollbackProfile: "stateful_migration_v1",
        recoveryMode: "stateful_ledger_recovery",
      },
    });
  });

  it("rejects an unknown explicit rollback profile", () => {
    const unknown = validStatefulPacket();
    unknown.rollback_profile = "greenfield";
    expect(validateRollbackPacket(unknown, { now: new Date("2026-07-14T00:45:00Z") }).errors).toContain(
      "rollback_profile must be stateful_migration_v1, greenfield_destructive_v1, or greenfield_destructive_v3",
    );
  });

  it("does not infer the greenfield profile from greenfield-only fields", () => {
    const packet = validGreenfieldPacket();
    delete (packet as Partial<typeof packet>).rollback_profile;
    const result = validateRollbackPacket(packet, { now: new Date("2026-07-14T00:45:00Z") });
    expect(result.ok).toBe(false);
    expect(result.summary.rollbackProfile).toBe("stateful_migration_v1");
    expect(result.errors).toContain("stateful_migration_v1 must not include greenfield_recovery");
  });

  it("rejects mixed stateful and greenfield recovery claims", () => {
    const stateful = {
      ...validStatefulPacket(),
      greenfield_recovery: validGreenfieldPacket().greenfield_recovery,
    };
    expect(validateRollbackPacket(stateful, { now: new Date("2026-07-14T00:45:00Z") }).errors).toContain(
      "stateful_migration_v1 must not include greenfield_recovery",
    );

    const greenfield = {
      ...validGreenfieldPacket(),
      write_ledger: validStatefulPacket().write_ledger,
    };
    expect(validateRollbackPacket(greenfield, { now: new Date("2026-07-14T00:45:00Z") }).errors).toContain(
      "greenfield_destructive_v1 must not include write_ledger",
    );

    const greenfieldV3 = {
      ...validGreenfieldV3Packet(),
      write_ledger: validStatefulPacket().write_ledger,
    };
    expect(validateRollbackPacket(greenfieldV3, { now: new Date("2026-07-14T00:45:00Z") }).errors).toContain(
      "greenfield_destructive_v3 must not include write_ledger",
    );
  });

  it.each([
    ["candidate_worker_version_id", "accepted_worker_version_id"],
    ["candidate_worker_version_id", "last_known_good_worker_version_id"],
    ["candidate_worker_version_id", "write_guard_worker_version_id"],
    ["accepted_worker_version_id", "last_known_good_worker_version_id"],
    ["accepted_worker_version_id", "write_guard_worker_version_id"],
    ["last_known_good_worker_version_id", "write_guard_worker_version_id"],
  ] as const)("requires v3 %s and %s to be distinct", (left, right) => {
    const packet = validGreenfieldV3Packet();
    packet.versions[right] = packet.versions[left];
    expect(validateRollbackPacket(packet, { now: new Date("2026-07-14T00:45:00Z") }).errors).toContain(
      "candidate, accepted, last-known-good, and write-guard versions must be distinct",
    );
  });

  it("requires the v3 accepted version and both rollback probe receipts", () => {
    const packet = validGreenfieldV3Packet();
    packet.versions.accepted_worker_version_id = "";
    packet.versions.write_guard_probe.receipt_id = "";
    packet.versions.last_known_good_probe.receipt_id = "";
    const result = validateRollbackPacket(packet, { now: new Date("2026-07-14T00:45:00Z") });
    expect(result.errors).toContain("versions.accepted_worker_version_id must be a Worker version UUID");
    expect(result.errors).toContain("versions.write_guard_probe.receipt_id is required");
    expect(result.errors).toContain(
      "versions.last_known_good_probe.receipt_id is required",
    );
  });

  it("enforces exact v3 top-level, window, threshold, version, and client keys", () => {
    const packet = validGreenfieldV3Packet() as any;
    packet.unreviewed_secret = "must-not-be-accepted";
    packet.window.extra = true;
    packet.trigger_thresholds.extra = 1;
    packet.versions.extra = "unreviewed";
    packet.client_recovery_release.extra = "unreviewed";

    const errors = validateRollbackPacket(packet, {
      now: new Date("2026-07-14T00:45:00Z"),
    }).errors;
    expect(errors).toContain(
      "greenfield_destructive_v3 top-level keys must exactly match the v3 rollback contract",
    );
    expect(errors).toContain(
      "greenfield_destructive_v3 window keys must exactly match the v3 rollback contract",
    );
    expect(errors).toContain(
      "greenfield_destructive_v3 trigger_thresholds keys must exactly match the v3 rollback contract",
    );
    expect(errors).toContain(
      "greenfield_destructive_v3 versions keys must exactly match the v3 rollback contract",
    );
    expect(errors).toContain(
      "greenfield_destructive_v3 client_recovery_release keys must exactly match the v3 rollback contract",
    );
  });

  it("requires operationally safe, provider-bound, distinct fallback probes", () => {
    const packet = validGreenfieldV3Packet();
    const guard = packet.versions.write_guard_probe;
    guard.health_status = "failed";
    guard.write_mode = "enabled";
    guard.write_denial_http_status = 200;
    guard.identity_mutation_count = 1;
    guard.health_worker_version_id =
      packet.versions.last_known_good_worker_version_id;
    packet.versions.last_known_good_probe.receipt_id = guard.receipt_id;
    packet.versions.last_known_good_probe.deployment_id = guard.deployment_id;

    const errors = validateRollbackPacket(packet, {
      now: new Date("2026-07-14T00:45:00Z"),
    }).errors;
    expect(errors).toContain(
      "versions.write_guard_probe.health_status must be passed",
    );
    expect(errors).toContain(
      "versions.write_guard_probe.write_mode must be disabled",
    );
    expect(errors).toContain(
      "versions.write_guard_probe must prove retryable write denial with HTTP 503",
    );
    expect(errors).toContain(
      "versions.write_guard_probe must prove zero identity and application mutations",
    );
    expect(errors).toContain(
      "versions.write_guard_probe.health_worker_version_id must report the fallback Worker version",
    );
    expect(errors).toContain(
      "greenfield v3 fallback probe receipt IDs must be distinct",
    );
    expect(errors).toContain(
      "greenfield v3 fallback probe deployment IDs must be distinct",
    );
  });

  it("requires completed in-window, ordered fallback deployment readbacks", () => {
    const futurePacket = validGreenfieldV3Packet();
    futurePacket.versions.last_known_good_probe.deployment_observed_after_at_utc =
      "2026-07-14T00:46:00Z";
    sealFallbackProbe(futurePacket.versions.last_known_good_probe);
    expect(
      validateRollbackPacket(futurePacket, {
        now: new Date("2026-07-14T00:45:00Z"),
      }).errors,
    ).toContain(
      "versions.last_known_good_probe provider-bracketed proof must complete by validation time",
    );

    const outsideWindowPacket = validGreenfieldV3Packet();
    outsideWindowPacket.window.start_at_utc = "2026-07-14T00:35:00Z";
    expect(
      validateRollbackPacket(outsideWindowPacket, {
        now: new Date("2026-07-14T00:45:00Z"),
      }).errors,
    ).toContain(
      "versions.write_guard_probe provider-bracketed proof must occur inside the rollback window",
    );

    const overlappingPacket = validGreenfieldV3Packet();
    overlappingPacket.versions.write_guard_probe
      .deployment_observed_after_at_utc = "2026-07-14T00:36:00Z";
    sealFallbackProbe(overlappingPacket.versions.write_guard_probe);
    expect(
      validateRollbackPacket(overlappingPacket, {
        now: new Date("2026-07-14T00:45:00Z"),
      }).errors,
    ).toContain(
      "write-guard provider readback must complete before the last-known-good provider readback begins",
    );
  });

  it("requires fallback probes to share one Custom Domain and distinct provider receipts", () => {
    const packet = validGreenfieldV3Packet();
    packet.versions.last_known_good_probe.edge_binding.provider_id = "e".repeat(32);
    packet.versions.last_known_good_probe.deployment_provider_receipt_id =
      packet.versions.write_guard_probe.deployment_provider_receipt_id;
    sealFallbackProbe(packet.versions.last_known_good_probe);

    const errors = validateRollbackPacket(packet, {
      now: new Date("2026-07-14T00:45:00Z"),
    }).errors;
    expect(errors).toContain(
      "greenfield v3 rollback and fallback probes must use the same Custom Domain binding",
    );
    expect(errors).toContain(
      "greenfield v3 fallback provider receipt IDs must be distinct",
    );
  });

  it.each([
    ["provider ID", "provider_id", "not-a-provider-id", "provider_id must be a Cloudflare provider identifier"],
    ["hostname", "hostname", "wrong.example.invalid", "hostname must be api.refwatch.ibby.ai"],
    ["kind", "kind", "zone_route", "kind must be custom_domain"],
    ["TLS", "tls_status", "pending", "tls_status must be active"],
    ["DNS management", "dns_management", "manual_dns", "dns_management must be cloudflare_worker_custom_domain"],
    ["Worker identity", "worker_name", "other-worker", "worker_name must be refwatch-api"],
  ])("rejects rollback Custom Domain %s drift", (_label, field, value, errorSuffix) => {
    const packet = validGreenfieldV3Packet();
    packet.edge_binding[field] = value;

    expect(validateRollbackPacket(packet, {
      now: new Date("2026-07-14T00:45:00Z"),
    }).errors.some((error) => error.includes(errorSuffix))).toBe(true);
  });

  it("rejects conflicting zone routes and a manual DNS origin in fallback proofs", () => {
    const packet = validGreenfieldV3Packet();
    packet.versions.write_guard_probe.conflicting_zone_route_count = 1;
    packet.versions.last_known_good_probe.manual_dns_origin_present = true;

    const errors = validateRollbackPacket(packet, {
      now: new Date("2026-07-14T00:45:00Z"),
    }).errors;
    expect(errors).toContain(
      "versions.write_guard_probe.conflicting_zone_route_count must be zero",
    );
    expect(errors).toContain(
      "versions.last_known_good_probe.manual_dns_origin_present must be false",
    );
  });

  it("rejects a future aggregate Worker-version readback", () => {
    const packet = validGreenfieldV3Packet();
    packet.versions.provider_readback_at_utc = "2026-07-14T00:46:00Z";
    packet.versions.write_guard_probe.versions_provider_readback_at_utc =
      packet.versions.provider_readback_at_utc;
    packet.versions.last_known_good_probe.versions_provider_readback_at_utc =
      packet.versions.provider_readback_at_utc;
    sealFallbackProbe(packet.versions.write_guard_probe);
    sealFallbackProbe(packet.versions.last_known_good_probe);

    expect(
      validateRollbackPacket(packet, {
        now: new Date("2026-07-14T00:45:00Z"),
      }).errors,
    ).toContain("versions.provider_readback_at_utc must not be in the future");
  });

  it("rejects impossible UTC calendar dates in active v3 packets", () => {
    const packet = validGreenfieldV3Packet();
    packet.window.end_at_utc = "2026-02-30T01:00:00Z";
    packet.versions.write_guard_probe.observed_at_utc =
      "2026-02-30T00:35:00Z";

    const errors = validateRollbackPacket(packet, {
      now: new Date("2026-07-14T00:45:00Z"),
    }).errors;
    expect(errors).toContain(
      "window.end_at_utc must be a strict UTC instant",
    );
    expect(errors).toContain(
      "versions.write_guard_probe.observed_at_utc must be a strict UTC instant",
    );
  });

  it("requires the exact ordered greenfield recovery sequence", () => {
    const packet = validGreenfieldPacket();
    packet.greenfield_recovery.steps = greenfieldRecoverySteps.slice(1);
    const result = validateRollbackPacket(packet, { now: new Date("2026-07-14T00:45:00Z") });
    expect(result.errors).toContain("greenfield_recovery.steps must exactly match the approved destructive recovery sequence");
  });

  it.each([
    "ledger_escrow_required",
    "ledger_recovery_required",
    "ledger_activation_required",
    "supabase_reverse_import_required",
  ] as const)("requires greenfield_recovery.%s to be false", (field) => {
    const packet = validGreenfieldPacket();
    packet.greenfield_recovery[field] = true;
    expect(validateRollbackPacket(packet, { now: new Date("2026-07-14T00:45:00Z") }).errors).toContain(
      `greenfield_recovery.${field} must be false`,
    );
  });

  it("requires the exact greenfield recovery key set", () => {
    const packet = validGreenfieldPacket();
    const recoveryWithUnknownClaim = packet.greenfield_recovery as typeof packet.greenfield_recovery & {
      preserve_supabase_rows?: boolean;
    };
    recoveryWithUnknownClaim.preserve_supabase_rows = false;
    expect(validateRollbackPacket(packet, { now: new Date("2026-07-14T00:45:00Z") }).errors).toContain(
      "greenfield_recovery keys must exactly match the greenfield destructive recovery contract",
    );
  });

  it("rejects the obsolete production Worker name", () => {
    const packet = validGreenfieldPacket();
    packet.versions.worker_name = "refwatch-api-production";
    expect(validateRollbackPacket(packet, { now: new Date("2026-07-14T00:45:00Z") }).errors).toContain(
      "versions.worker_name must be refwatch-api",
    );
  });
});
