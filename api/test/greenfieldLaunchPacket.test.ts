import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { describe, expect, it } from "vitest";
import {
  greenfieldAcceptanceChecks,
  greenfieldAuthorizationArtifact,
  greenfieldAuthorizationDigest,
  greenfieldAuthorizationProfile,
  greenfieldEmptyMappingHash,
  greenfieldIdentityProfile,
  greenfieldIdentityReceiptDigest,
  greenfieldLaunchProfile,
  greenfieldRollbackProfile,
  historicalGreenfieldLaunchProfile,
  historicalGreenfieldRollbackProfile,
  cleanTargetReadback,
  productionClerk,
  productionDatabase,
  productionWorker,
  productionWorkerCustomDomain,
  reviewedDeterministicSeed,
  reviewedSchema,
  greenfieldCleanTargetTables,
  ledgerReadback,
  cutoverAcceptance,
  productionWorkerSecretNames,
  computeSanitizedReceiptSha256,
  computeStableWorkerBindingSha256,
  expectedProductionWorkerBindings,
  sanitizeWorkerVersionReadback,
  validateGreenfieldLaunchPacket as validateGreenfieldLaunchPacketWithRuntimeClock,
  validateHistoricalGreenfieldLaunchPacketV2,
} from "../scripts/greenfield-launch-packet.mjs";
import { productionRuntimeProvisioningTarget } from "../scripts/provision-production-runtime.mjs";

const digestA = "a".repeat(64);
const digestB = "b".repeat(64);
const candidateVersion = "0190f8f4-5914-7b6c-9d6a-469a29f92f21";
const acceptedVersion = "0190f8f4-5914-7b6c-9d6a-469a29f92f22";
const writeGuardVersion = "0190f8f4-5914-7b6c-9d6a-469a29f92f23";
const lastKnownGoodVersion = "0190f8f4-5914-7b6c-9d6a-469a29f92f24";
const lineageSourceWorkerVersion =
  "0190f8f4-5914-7b6c-9d6a-469a29f92f25";
const candidateScriptEtag = "c".repeat(64);
const deterministicValidationNow = new Date("2026-07-20T06:00:00Z");
const customDomainProviderId = "d".repeat(32);

function customDomainEdgeBinding(): any {
  return {
    kind: productionWorkerCustomDomain.kind,
    hostname: productionWorkerCustomDomain.hostname,
    provider_id: customDomainProviderId,
    worker_name: productionWorkerCustomDomain.workerName,
    tls_status: productionWorkerCustomDomain.tlsStatus,
    dns_management: productionWorkerCustomDomain.dnsManagement,
  };
}

function validateGreenfieldLaunchPacket(
  packet: unknown,
  options: { now?: Date } = { now: deterministicValidationNow },
) {
  return validateGreenfieldLaunchPacketWithRuntimeClock(packet, options);
}

function passedReceipt(
  receiptId: string,
  observedAtUTC: string,
  receiptKind: string,
): any {
  const receipt = {
    status: "passed",
    receipt_kind: receiptKind,
    receipt_id: receiptId,
    receipt_sha256: "",
    observed_at_utc: observedAtUTC,
    worker_version_id: acceptedVersion,
    clerk_instance_id: productionClerk.instanceId,
    database_branch_id: productionDatabase.branchId,
  };
  sealInlineReceipt(receipt, "receipt_sha256");
  return receipt;
}

function boundedWebhookReceipt(): any {
  const receipt = {
    status: "passed",
    receipt_kind: "acceptance:webhook_lifecycle",
    receipt_id: "acceptance-webhook_lifecycle",
    receipt_sha256: "",
    observed_at_utc: "2026-07-20T04:35:00Z",
    worker_version_id: acceptedVersion,
    clerk_instance_id: productionClerk.instanceId,
    database_branch_id: productionDatabase.branchId,
    delivery_source: "manual_signed_harness",
    endpoint_path: "/webhooks/clerk",
    version_override_header_name: cutoverAcceptance.overrideHeaderName,
    version_override_header_present: true,
    cutover_token_header_name: cutoverAcceptance.tokenHeaderName,
    cutover_token_header_present: true,
    valid_signature_status: "passed",
    invalid_signature_rejection_status: "passed",
  };
  sealInlineReceipt(receipt, "receipt_sha256");
  return receipt;
}

function sanitizedWorkerReadback(
  versionId: string,
  createdAtUTC: string,
  observedAtUTC: string,
  writeMode: string,
  onboardingMode: string,
): any {
  const receipt = {
    worker_version_id: versionId,
    created_at_utc: createdAtUTC,
    observed_at_utc: observedAtUTC,
    resources: {
      script: {
        etag: candidateScriptEtag,
        placement_mode: "smart",
        placement: { mode: "smart" },
      },
      script_runtime: {
        compatibility_date: "2026-07-14",
        compatibility_flags: ["nodejs_compat"],
        usage_model: "standard",
      },
      bindings: expectedProductionWorkerBindings(writeMode, onboardingMode),
    },
    readback_sha256: "",
  };
  sealInlineReceipt(receipt, "readback_sha256");
  return receipt;
}

function fallbackProbe(
  receiptId: string,
  observedAtUTC: string,
  versionId: string,
  deploymentId: string,
): any {
  const observedMillis = Date.parse(observedAtUTC);
  const deploymentObservedBeforeAtUTC =
    new Date(observedMillis - 10_000).toISOString();
  const deploymentObservedAfterAtUTC =
    new Date(observedMillis + 10_000).toISOString();
  const probe = {
    status: "passed",
    receipt_id: receiptId,
    receipt_sha256: "",
    observed_at_utc: observedAtUTC,
    worker_version_id: versionId,
    worker_name: productionWorker.name,
    environment: productionWorker.environment,
    versions_provider_readback_at_utc: "2026-07-20T04:06:00Z",
    deployment_id: deploymentId,
    deployment_provider_receipt_id: `provider-${deploymentId}`,
    deployment_provider_readback_sha256: "",
    deployment_observed_before_at_utc: deploymentObservedBeforeAtUTC,
    deployment_observed_after_at_utc: deploymentObservedAfterAtUTC,
    edge_binding: customDomainEdgeBinding(),
    conflicting_zone_route_count: 0,
    manual_dns_origin_present: false,
    traffic_percentage: 100,
    competing_version_count: 0,
    health_status: "passed",
    health_worker_version_id: versionId,
    readiness_status: "passed",
    readiness_worker_version_id: versionId,
    write_mode: "disabled",
    new_user_onboarding_mode: "disabled",
    write_denial_status: "retryable_denial",
    write_denial_http_status: 503,
    identity_mutation_count: 0,
    application_mutation_count: 0,
    clerk_instance_id: productionClerk.instanceId,
    database_branch_id: productionDatabase.branchId,
  };
  probe.deployment_provider_readback_sha256 =
    computeSanitizedReceiptSha256({
      receipt_id: probe.deployment_provider_receipt_id,
      deployment_id: probe.deployment_id,
      worker_version_id: probe.worker_version_id,
      edge_binding: probe.edge_binding,
      conflicting_zone_route_count: probe.conflicting_zone_route_count,
      manual_dns_origin_present: probe.manual_dns_origin_present,
      traffic_percentage: probe.traffic_percentage,
      competing_version_count: probe.competing_version_count,
      observed_before_at_utc: probe.deployment_observed_before_at_utc,
      observed_after_at_utc: probe.deployment_observed_after_at_utc,
    });
  sealInlineReceipt(probe, "receipt_sha256");
  return probe;
}

function sealInlineReceipt(value: any, digestField: string): void {
  const payload = Object.fromEntries(
    Object.entries(value).filter(([key]) => key !== digestField),
  );
  value[digestField] = computeSanitizedReceiptSha256(payload);
}

function sealSecretLineage(lineage: any): void {
  lineage.provider_version_history_receipt_sha256 =
    computeSanitizedReceiptSha256({
      receipt_id: lineage.provider_version_history_receipt_id,
      observed_at_utc: lineage.observed_at_utc,
      worker_name: productionWorker.name,
      environment: productionWorker.environment,
      source_worker_version_id: lineage.source_worker_version_id,
      source_worker_version_created_at_utc:
        lineage.source_worker_version_created_at_utc,
      candidate_worker_version_id: lineage.candidate_worker_version_id,
      candidate_worker_version_created_at_utc:
        lineage.candidate_worker_version_created_at_utc,
      candidate_inherited_from_worker_version_id:
        lineage.candidate_inherited_from_worker_version_id,
      accepted_worker_version_id: lineage.accepted_worker_version_id,
      accepted_worker_version_created_at_utc:
        lineage.accepted_worker_version_created_at_utc,
      accepted_inherited_from_worker_version_id:
        lineage.accepted_inherited_from_worker_version_id,
      required_secret_names: lineage.required_secret_names,
      unexpected_intervening_version_count:
        lineage.unexpected_intervening_version_count,
      intervening_secret_mutation_count:
        lineage.intervening_secret_mutation_count,
      upload_secret_override_count: lineage.upload_secret_override_count,
    });
  sealInlineReceipt(lineage, "receipt_sha256");
}

function validPacket(): any {
  const candidateReadback = sanitizedWorkerReadback(
    candidateVersion,
    "2026-07-20T04:02:00Z",
    "2026-07-20T04:04:00Z",
    "disabled",
    "disabled",
  );
  const acceptedReadback = sanitizedWorkerReadback(
    acceptedVersion,
    "2026-07-20T04:03:00Z",
    "2026-07-20T04:05:00Z",
    "enabled",
    "greenfield_bootstrap",
  );
  const stableBindingSha256 =
    computeStableWorkerBindingSha256(candidateReadback);
  const packet: any = {
    schema_version: 3,
    launch_profile: greenfieldLaunchProfile,
    status: "accepted",
    authorization: {
      profile: greenfieldAuthorizationProfile,
      decision_artifact: greenfieldAuthorizationArtifact,
      decision_sha256: greenfieldAuthorizationDigest,
    },
    clerk: {
      instance_id: productionClerk.instanceId,
      domain: productionClerk.domain,
      issuer: productionClerk.issuer,
      clean_user_count: 0,
      provider_readback_at_utc: "2026-07-20T03:02:00Z",
      provider_readback_sha256: "",
    },
    worker: {
      name: productionWorker.name,
      environment: productionWorker.environment,
      versions: {
        candidate_worker_version_id: candidateVersion,
        accepted_worker_version_id: acceptedVersion,
        write_guard_worker_version_id: writeGuardVersion,
        last_known_good_worker_version_id: lastKnownGoodVersion,
        candidate_worker_created_at_utc: "2026-07-20T04:02:00Z",
        accepted_worker_created_at_utc: "2026-07-20T04:03:00Z",
        candidate_script_etag: candidateScriptEtag,
        accepted_script_etag: candidateScriptEtag,
        candidate_stable_binding_sha256: stableBindingSha256,
        accepted_stable_binding_sha256: stableBindingSha256,
        candidate_sanitized_readback: candidateReadback,
        accepted_sanitized_readback: acceptedReadback,
      },
      secret_lineage: {
        status: "passed",
        receipt_kind: "worker_secret_lineage:sequential_inheritance",
        receipt_id: "worker-secret-lineage",
        receipt_sha256: "",
        observed_at_utc: "2026-07-20T04:05:30Z",
        installation_method:
          "wrangler_versions_secret_put_stdin_then_sequential_uploads",
        source_worker_version_id: lineageSourceWorkerVersion,
        source_worker_version_created_at_utc: "2026-07-20T04:01:30Z",
        candidate_worker_version_id: candidateVersion,
        candidate_worker_version_created_at_utc: "2026-07-20T04:02:00Z",
        candidate_inherited_from_worker_version_id:
          lineageSourceWorkerVersion,
        accepted_worker_version_id: acceptedVersion,
        accepted_worker_version_created_at_utc: "2026-07-20T04:03:00Z",
        accepted_inherited_from_worker_version_id: candidateVersion,
        required_secret_names: [...productionWorkerSecretNames],
        unexpected_intervening_version_count: 0,
        intervening_secret_mutation_count: 0,
        upload_secret_override_count: 0,
        non_echoing_installation_status: "passed",
        secret_values_recorded: false,
        operator_confirmation_status: "passed",
        provider_version_history_receipt_id:
          "provider-worker-version-history",
        provider_version_history_receipt_sha256: "",
      },
      provider_readback_at_utc: "2026-07-20T04:06:00Z",
      provider_readback_sha256: "",
    },
    database: {
      target: {
        organization: productionDatabase.organization,
        database: productionDatabase.database,
        branch: productionDatabase.branch,
        branch_id: productionDatabase.branchId,
        runtime_marker: productionDatabase.runtimeMarker,
        runtime_role_id: productionDatabase.runtimeRoleId,
        hyperdrive_id: productionDatabase.hyperdriveId,
      },
      schema: {
        status: "reviewed",
        migration_head: reviewedSchema.migrationHead,
        migration_count: reviewedSchema.migrationCount,
        repository_snapshot_path: reviewedSchema.repositorySnapshotPath,
        repository_snapshot_sha256: reviewedSchema.repositorySnapshotSha256,
        provider_query_path: reviewedSchema.providerQueryPath,
        provider_query_sha256: reviewedSchema.providerQuerySha256,
        provider_readback: {
          observed_at_utc: "2026-07-20T03:05:00Z",
          database_name: productionRuntimeProvisioningTarget.databaseName,
          database_branch_id: productionDatabase.branchId,
          runtime_marker: productionDatabase.runtimeMarker,
          migration_count: reviewedSchema.migrationCount,
          migration_head_id: reviewedSchema.migrationHeadId,
          migration_head_hash: reviewedSchema.migrationHeadHash,
          migration_history_md5: reviewedSchema.migrationHistoryMd5,
          public_table_count: reviewedSchema.publicTableCount,
          public_table_names_md5: reviewedSchema.publicTableNamesMd5,
          public_table_properties_count:
            reviewedSchema.publicTablePropertiesCount,
          public_table_properties_md5:
            reviewedSchema.publicTablePropertiesMd5,
          public_column_count: reviewedSchema.publicColumnCount,
          public_columns_md5: reviewedSchema.publicColumnsMd5,
          public_constraint_count: reviewedSchema.publicConstraintCount,
          public_constraints_md5: reviewedSchema.publicConstraintsMd5,
          public_index_count: reviewedSchema.publicIndexCount,
          public_indexes_md5: reviewedSchema.publicIndexesMd5,
          public_trigger_count: reviewedSchema.publicTriggerCount,
          public_triggers_md5: reviewedSchema.publicTriggersMd5,
          public_function_count: reviewedSchema.publicFunctionCount,
          public_functions_md5: reviewedSchema.publicFunctionsMd5,
          public_enum_label_count: reviewedSchema.publicEnumLabelCount,
          public_enum_labels_md5: reviewedSchema.publicEnumLabelsMd5,
          catalog_contract_md5: reviewedSchema.catalogContractMd5,
        },
        provider_receipt_sha256: "",
      },
      deterministic_seed: {
        status: "reviewed",
        repository_migration_path: reviewedDeterministicSeed.migrationPath,
        repository_migration_sha256: reviewedDeterministicSeed.migrationSha256,
        reference_competitions_count:
          reviewedDeterministicSeed.referenceCompetitionsCount,
        reference_competitions_business_md5:
          reviewedDeterministicSeed.referenceCompetitionsBusinessMd5,
        reference_teams_count: reviewedDeterministicSeed.referenceTeamsCount,
        reference_teams_business_md5:
          reviewedDeterministicSeed.referenceTeamsBusinessMd5,
        reference_disciplinary_codes_count: 0,
        reference_disciplinary_rules_count: 0,
        global_workout_presets_count: 0,
        provider_query_path: cleanTargetReadback.queryPath,
        provider_query_sha256: cleanTargetReadback.querySha256,
        database_branch_id: productionDatabase.branchId,
        runtime_marker: productionDatabase.runtimeMarker,
        provider_readback_at_utc: "2026-07-20T03:06:00Z",
        provider_readback_sha256: "",
      },
      clean_target_before_bootstrap: {
        query_path: cleanTargetReadback.queryPath,
        query_sha256: cleanTargetReadback.querySha256,
        database_branch_id: productionDatabase.branchId,
        runtime_marker: productionDatabase.runtimeMarker,
        provider_readback_at_utc: "2026-07-20T03:10:00Z",
        provider_readback_sha256: "",
        inventory: Object.fromEntries(
          greenfieldCleanTargetTables.map((table) => [table, 0]),
        ),
      },
    },
    identity_bootstrap: {
      reconciliation_profile: greenfieldIdentityProfile,
      receipt_digest: greenfieldIdentityReceiptDigest,
      authorization_digest: greenfieldAuthorizationDigest,
      mapping_hash: greenfieldEmptyMappingHash,
      legacy_mapping_count: 0,
      activated: true,
      activated_at_utc: "2026-07-20T04:00:00Z",
      activation_receipt_id: "identity-activation-readback-1",
      activation_receipt_sha256: "",
      activation_observed_at_utc: "2026-07-20T04:01:00Z",
      clerk_instance_id: productionClerk.instanceId,
      database_branch_id: productionDatabase.branchId,
    },
    ledger: {
      status: "inactive_with_optional_history",
      query_path: ledgerReadback.queryPath,
      query_sha256: ledgerReadback.querySha256,
      database_name: productionRuntimeProvisioningTarget.databaseName,
      database_branch_id: productionDatabase.branchId,
      runtime_marker: productionDatabase.runtimeMarker,
      total_epoch_count: 2,
      preparing_epoch_count: 0,
      open_epoch_count: 0,
      frozen_epoch_count: 1,
      archived_epoch_count: 1,
      capture_enforced_epoch_count: 0,
      entity_revision_count: 17,
      outbox_event_count: 12,
      outbox_delivery_count: 12,
      queue_consumer_count: 0,
      cron_consumer_count: 0,
      d1_consumer_count: 0,
      provider_readback_at_utc: "2026-07-20T03:15:00Z",
      provider_readback_sha256: "",
    },
    acceptance: {
      bounded_window: {
        started_at_utc: "2026-07-20T04:30:00Z",
        completed_at_utc: "2026-07-20T04:40:00Z",
        max_requests: 200,
        observed_requests: 73,
        max_test_identities: 3,
        observed_test_identities: 2,
        write_mode: "enabled",
        new_user_onboarding_mode: "greenfield_bootstrap",
        traffic_scope: "bounded_test_only",
        reconciliation_receipt_digest: greenfieldIdentityReceiptDigest,
        worker_version_id: acceptedVersion,
      },
      checks: Object.fromEntries(
        greenfieldAcceptanceChecks.map((name) => [
          name,
          name === "webhook_lifecycle"
            ? boundedWebhookReceipt()
            : passedReceipt(
                `acceptance-${name}`,
                "2026-07-20T04:35:00Z",
                `acceptance:${name}`,
              ),
        ]),
      ),
    },
    rollback: {
      validation_status: "passed",
      validated_at_utc: "2026-07-20T04:20:00Z",
      packet: {
        schema_version: 1,
        rollback_profile: greenfieldRollbackProfile,
        edge_binding: customDomainEdgeBinding(),
        conflicting_zone_route_count: 0,
        manual_dns_origin_present: false,
        status: "approved",
        owner: "cutover operator",
        approved_at_utc: "2026-07-20T03:55:00Z",
        window: {
          start_at_utc: "2026-07-20T04:00:00Z",
          end_at_utc: "2026-07-20T08:00:00Z",
        },
        trigger_thresholds: {
          auth_failure_rate_percent: 2,
          owner_scope_violations: 0,
          worker_5xx_rate_percent: 1,
          sync_backlog_oldest_seconds: 900,
          database_connection_utilization_percent: 80,
        },
        versions: {
          worker_name: productionWorker.name,
          environment: productionWorker.environment,
          candidate_worker_version_id: candidateVersion,
          accepted_worker_version_id: acceptedVersion,
          write_guard_worker_version_id: writeGuardVersion,
          last_known_good_worker_version_id: lastKnownGoodVersion,
          provider_readback_at_utc: "2026-07-20T04:06:00Z",
          write_guard_probe: fallbackProbe(
            "write-guard-probe",
            "2026-07-20T04:08:00Z",
            writeGuardVersion,
            "deployment-write-guard",
          ),
          last_known_good_probe: fallbackProbe(
            "last-known-good-probe",
            "2026-07-20T04:09:00Z",
            lastKnownGoodVersion,
            "deployment-last-known-good",
          ),
        },
        greenfield_recovery: {
          mode: "destructive_reset_reseed_recreate",
          steps: [
            "stop_production_traffic_and_writes",
            "route_to_write_guard_worker",
            "roll_back_worker_and_client",
            "reset_planetscale_application_state",
            "reseed_deterministic_reference_data",
            "recreate_test_identities",
            "rerun_greenfield_launch_acceptance",
          ],
          operator_instructions:
            "Stop traffic, route the guard, reset and reseed, recreate test identities, then rerun acceptance.",
          ledger_escrow_required: false,
          ledger_recovery_required: false,
          ledger_activation_required: false,
          supabase_reverse_import_required: false,
        },
        client_recovery_release: {
          marketing_version: "1.0",
          build: "100",
          distribution_status: "testflight_ready",
          operator_instructions:
            "Restore the reviewed recovery client before destructive relaunch.",
        },
      },
      packet_sha256: "",
    },
    physical_device_acceptance: {
      iphone_15_pro_max: passedReceipt(
        "device-iphone-15-pro-max",
        "2026-07-20T04:45:00Z",
        "physical_device:iphone_15_pro_max",
      ),
      apple_watch_series_9_45mm: passedReceipt(
        "device-watch-series-9-45mm",
        "2026-07-20T04:46:00Z",
        "physical_device:apple_watch_series_9_45mm",
      ),
      release_configuration: passedReceipt(
        "release-config-and-plist",
        "2026-07-20T04:47:00Z",
        "physical_device:release_configuration",
      ),
    },
    traffic_and_writes: {
      initial_candidate: {
        worker_version_id: candidateVersion,
        deployment_id: "deployment-a100-b0",
        edge_binding: customDomainEdgeBinding(),
        conflicting_zone_route_count: 0,
        manual_dns_origin_present: false,
        route_status: "write_disabled_route",
        version_weights: [
          { worker_version_id: candidateVersion, traffic_percentage: 100 },
          { worker_version_id: acceptedVersion, traffic_percentage: 0 },
        ],
        write_mode: "disabled",
        new_user_onboarding_mode: "disabled",
        verified_at_utc: "2026-07-20T04:12:00Z",
        provider_receipt_id: "candidate-write-disabled-readback",
        provider_receipt_sha256: "",
        clerk_instance_id: productionClerk.instanceId,
        database_branch_id: productionDatabase.branchId,
        workers_dev_enabled: false,
        preview_urls_enabled: false,
        health_status: "passed",
        health_worker_version_id: candidateVersion,
        readiness_status: "passed",
        readiness_worker_version_id: candidateVersion,
        missing_bearer_rejection_status: "passed",
        missing_bearer_http_status: 401,
        invalid_bearer_rejection_status: "passed",
        invalid_bearer_http_status: 401,
        write_denial_status: "retryable_denial",
        write_denial_http_status: 503,
        webhook_denial_status: "retryable_denial",
        webhook_denial_http_status: 503,
        identity_mutation_count: 0,
        application_mutation_count: 0,
      },
      bounded_acceptance_route: {
        worker_version_id: acceptedVersion,
        deployment_id: "deployment-a100-b0",
        edge_binding: customDomainEdgeBinding(),
        conflicting_zone_route_count: 0,
        manual_dns_origin_present: false,
        exposure_method: "version_override",
        override_header_name: "Cloudflare-Workers-Version-Overrides",
        override_header_value: `refwatch-api="${acceptedVersion}"`,
        access_control:
          "cloudflare_access_service_token_and_worker_cutover_token",
        access_application_id: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        access_policy_id: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        access_service_token_id: "cccccccccccccccccccccccccccccccc",
        access_path_pattern: "api.refwatch.ibby.ai/api/*",
        access_policy_action: "service_auth",
        access_allowed_service_token_count: 1,
        access_bypass_policy_count: 0,
        access_provider_readback_at_utc: "2026-07-20T04:24:00Z",
        access_provider_receipt_id: "access-policy-readback",
        access_provider_receipt_sha256: "",
        access_token_header_name: "X-RefWatch-Cutover-Token",
        access_token_secret_name: "CUTOVER_ACCEPTANCE_TOKEN",
        version_weights: [
          { worker_version_id: candidateVersion, traffic_percentage: 100 },
          { worker_version_id: acceptedVersion, traffic_percentage: 0 },
        ],
        write_mode: "enabled",
        new_user_onboarding_mode: "greenfield_bootstrap",
        reconciliation_receipt_digest: greenfieldIdentityReceiptDigest,
        workers_dev_enabled: false,
        preview_urls_enabled: false,
        missing_token_rejection_status: "passed",
        missing_token_http_status: 403,
        invalid_token_rejection_status: "passed",
        invalid_token_http_status: 403,
        enabled_at_utc: "2026-07-20T04:25:00Z",
        closed_disposition: "promoted_to_physical_acceptance",
        closed_at_utc: "2026-07-20T04:42:00Z",
        promoted_deployment_id: "deployment-b100",
        provider_receipt_id: "bounded-route-lifecycle",
        provider_receipt_sha256: "",
        clerk_instance_id: productionClerk.instanceId,
        database_branch_id: productionDatabase.branchId,
      },
      promoted_webhook_acceptance: {
        status: "passed",
        receipt_kind: "promoted_webhook:clerk_lifecycle",
        receipt_id: "promoted-clerk-webhook-lifecycle",
        receipt_sha256: "",
        observed_at_utc: "2026-07-20T04:42:15Z",
        worker_version_id: acceptedVersion,
        deployment_id: "deployment-b100",
        edge_binding: customDomainEdgeBinding(),
        conflicting_zone_route_count: 0,
        manual_dns_origin_present: false,
        endpoint_path: "/webhooks/clerk",
        version_override_header_present: false,
        cutover_token_header_present: false,
        api_access_policy_status: "active_service_auth",
        provider_source: "clerk_production_instance",
        subscribed_event_types: [
          "user.created",
          "user.updated",
          "user.deleted",
        ],
        provider_delivery_status: "passed",
        valid_signature_status: "passed",
        create_status: "passed",
        update_status: "passed",
        delete_status: "passed",
        retry_idempotency_status: "passed",
        delete_wins_status: "passed",
        final_test_identity_count: 0,
        final_application_row_count: 0,
        clerk_instance_id: productionClerk.instanceId,
        database_branch_id: productionDatabase.branchId,
      },
      accepted_cutover: {
        routed_worker_version_id: acceptedVersion,
        deployment_id: "deployment-b100",
        edge_binding: customDomainEdgeBinding(),
        conflicting_zone_route_count: 0,
        manual_dns_origin_present: false,
        route_status: "production_active",
        version_weights: [
          { worker_version_id: acceptedVersion, traffic_percentage: 100 },
        ],
        traffic_percentage: 100,
        competing_version_count: 0,
        workers_dev_enabled: false,
        preview_urls_enabled: false,
        write_mode: "enabled",
        new_user_onboarding_mode: "greenfield_bootstrap",
        traffic_scope: "production",
        reconciliation_receipt_digest: greenfieldIdentityReceiptDigest,
        enabled_at_utc: "2026-07-20T04:42:00Z",
        deployment_history_receipt_id: "deployment-history",
        deployment_history_receipt_sha256: "",
        deployment_history_observed_at_utc: "2026-07-20T04:43:00Z",
        bounded_access_status: "removed",
        bounded_access_removed_at_utc: "2026-07-20T04:42:30Z",
        bounded_access_removal_receipt_id: "access-removal",
        bounded_access_removal_receipt_sha256: "",
        production_accepted_at_utc: "2026-07-20T04:50:00Z",
        observation_status: "passed",
        observation_receipt_id: "production-observation-window",
        observation_receipt_sha256: "",
        observation_completed_at_utc: "2026-07-20T05:00:00Z",
        clerk_instance_id: productionClerk.instanceId,
        database_branch_id: productionDatabase.branchId,
      },
    },
  };
  packet.final_ledger = structuredClone(packet.ledger);
  packet.final_ledger.provider_readback_at_utc = "2026-07-20T05:05:00Z";
  packet.final_ledger.provider_readback_sha256 = "";
  sealInlineReceipt(packet.clerk, "provider_readback_sha256");
  sealSecretLineage(packet.worker.secret_lineage);
  sealInlineReceipt(packet.worker, "provider_readback_sha256");
  sealInlineReceipt(packet.database.schema, "provider_receipt_sha256");
  sealInlineReceipt(packet.database.deterministic_seed, "provider_readback_sha256");
  sealInlineReceipt(
    packet.database.clean_target_before_bootstrap,
    "provider_readback_sha256",
  );
  sealInlineReceipt(packet.identity_bootstrap, "activation_receipt_sha256");
  sealInlineReceipt(packet.ledger, "provider_readback_sha256");
  sealInlineReceipt(packet.final_ledger, "provider_readback_sha256");
  packet.rollback.packet_sha256 =
    computeSanitizedReceiptSha256(packet.rollback.packet);
  sealInlineReceipt(
    packet.traffic_and_writes.initial_candidate,
    "provider_receipt_sha256",
  );
  const boundedRoute =
    packet.traffic_and_writes.bounded_acceptance_route;
  boundedRoute.access_provider_receipt_sha256 =
    computeSanitizedReceiptSha256({
      receipt_id: boundedRoute.access_provider_receipt_id,
      observed_at_utc: boundedRoute.access_provider_readback_at_utc,
      application_id: boundedRoute.access_application_id,
      policy_id: boundedRoute.access_policy_id,
      service_token_id: boundedRoute.access_service_token_id,
      path_pattern: boundedRoute.access_path_pattern,
      policy_action: boundedRoute.access_policy_action,
      allowed_service_token_count:
        boundedRoute.access_allowed_service_token_count,
      bypass_policy_count: boundedRoute.access_bypass_policy_count,
    });
  sealInlineReceipt(
    boundedRoute,
    "provider_receipt_sha256",
  );
  sealInlineReceipt(
    packet.traffic_and_writes.promoted_webhook_acceptance,
    "receipt_sha256",
  );
  packet.traffic_and_writes.accepted_cutover.deployment_history_receipt_sha256 =
    computeSanitizedReceiptSha256({
      receipt_id:
        packet.traffic_and_writes.accepted_cutover
          .deployment_history_receipt_id,
      observed_at_utc:
        packet.traffic_and_writes.accepted_cutover
          .deployment_history_observed_at_utc,
      worker_name: packet.worker.name,
      edge_binding:
        packet.traffic_and_writes.accepted_cutover.edge_binding,
      initial_deployment_id:
        packet.traffic_and_writes.initial_candidate.deployment_id,
      promoted_deployment_id:
        packet.traffic_and_writes.accepted_cutover.deployment_id,
      candidate_worker_version_id: candidateVersion,
      accepted_worker_version_id: acceptedVersion,
      initial_candidate_percentage: 100,
      initial_accepted_percentage: 0,
      final_accepted_percentage: 100,
      final_competing_version_count: 0,
    });
  packet.traffic_and_writes.accepted_cutover
    .bounded_access_removal_receipt_sha256 =
      computeSanitizedReceiptSha256({
        receipt_id:
          packet.traffic_and_writes.accepted_cutover
            .bounded_access_removal_receipt_id,
        removed_at_utc:
          packet.traffic_and_writes.accepted_cutover
            .bounded_access_removed_at_utc,
        application_id:
          packet.traffic_and_writes.bounded_acceptance_route
            .access_application_id,
        policy_id:
          packet.traffic_and_writes.bounded_acceptance_route.access_policy_id,
        path_pattern:
          packet.traffic_and_writes.bounded_acceptance_route
            .access_path_pattern,
        status:
          packet.traffic_and_writes.accepted_cutover.bounded_access_status,
      });
  sealInlineReceipt(
    packet.traffic_and_writes.accepted_cutover,
    "observation_receipt_sha256",
  );
  return packet;
}

function clonePacket(): any {
  return structuredClone(validPacket());
}

function historicalV2Packet(): any {
  const packet = validPacket();
  packet.schema_version = 2;
  packet.launch_profile = historicalGreenfieldLaunchProfile;
  packet.rollback.packet.rollback_profile = historicalGreenfieldRollbackProfile;
  delete packet.rollback.packet.edge_binding;
  delete packet.rollback.packet.conflicting_zone_route_count;
  delete packet.rollback.packet.manual_dns_origin_present;

  function replaceCustomDomainWithRoute(value: any): void {
    delete value.edge_binding;
    delete value.conflicting_zone_route_count;
    delete value.manual_dns_origin_present;
    value.route_id = "route-production-api";
    value.hostname = productionWorker.hostname;
    value.route_pattern = productionWorker.routePattern;
  }

  for (const probe of [
    packet.rollback.packet.versions.write_guard_probe,
    packet.rollback.packet.versions.last_known_good_probe,
  ]) {
    replaceCustomDomainWithRoute(probe);
    probe.deployment_provider_readback_sha256 =
      computeSanitizedReceiptSha256({
        receipt_id: probe.deployment_provider_receipt_id,
        deployment_id: probe.deployment_id,
        worker_version_id: probe.worker_version_id,
        route_id: probe.route_id,
        hostname: probe.hostname,
        route_pattern: probe.route_pattern,
        traffic_percentage: probe.traffic_percentage,
        competing_version_count: probe.competing_version_count,
        observed_before_at_utc: probe.deployment_observed_before_at_utc,
        observed_after_at_utc: probe.deployment_observed_after_at_utc,
      });
    sealInlineReceipt(probe, "receipt_sha256");
  }
  packet.rollback.packet_sha256 =
    computeSanitizedReceiptSha256(packet.rollback.packet);

  const initial = packet.traffic_and_writes.initial_candidate;
  const bounded = packet.traffic_and_writes.bounded_acceptance_route;
  const promoted = packet.traffic_and_writes.promoted_webhook_acceptance;
  const accepted = packet.traffic_and_writes.accepted_cutover;
  replaceCustomDomainWithRoute(initial);
  replaceCustomDomainWithRoute(bounded);
  delete promoted.edge_binding;
  delete promoted.conflicting_zone_route_count;
  delete promoted.manual_dns_origin_present;
  replaceCustomDomainWithRoute(accepted);
  sealInlineReceipt(initial, "provider_receipt_sha256");
  sealInlineReceipt(bounded, "provider_receipt_sha256");
  sealInlineReceipt(promoted, "receipt_sha256");
  accepted.deployment_history_receipt_sha256 =
    computeSanitizedReceiptSha256({
      receipt_id: accepted.deployment_history_receipt_id,
      observed_at_utc: accepted.deployment_history_observed_at_utc,
      worker_name: packet.worker.name,
      route_id: accepted.route_id,
      initial_deployment_id: initial.deployment_id,
      promoted_deployment_id: accepted.deployment_id,
      candidate_worker_version_id: candidateVersion,
      accepted_worker_version_id: acceptedVersion,
      initial_candidate_percentage: 100,
      initial_accepted_percentage: 0,
      final_accepted_percentage: 100,
      final_competing_version_count: 0,
    });
  sealInlineReceipt(accepted, "observation_receipt_sha256");
  return packet;
}

describe("greenfield launch packet validation", () => {
  it("recomputes stable Worker lineage while normalizing only the two stage modes", () => {
    const disabledReadback = {
      resources: {
        script: {
          etag: candidateScriptEtag,
          placement_mode: "smart",
          placement: { mode: "smart" },
        },
        script_runtime: {
          compatibility_date: "2026-07-14",
          compatibility_flags: ["nodejs_compat"],
          usage_model: "standard",
        },
        bindings: [
          { name: "WRITE_MODE", type: "plain_text", text: "disabled" },
          {
            name: "NEW_USER_ONBOARDING_MODE",
            type: "plain_text",
            text: "disabled",
          },
          {
            name: "CLERK_INSTANCE_ID",
            type: "plain_text",
            text: productionClerk.instanceId,
          },
          { name: "CLERK_SECRET_KEY", type: "secret_text" },
          {
            name: "HYPERDRIVE",
            type: "hyperdrive",
            id: "920ca5b108034b2bb8700cf0201ac55f",
          },
          {
            name: "MUTATION_LEDGER",
            type: "d1",
            id: "6d1a7bbb-ea9d-47b2-ae77-44f992b9e3d2",
            database_id: "6d1a7bbb-ea9d-47b2-ae77-44f992b9e3d2",
          },
          {
            name: "MUTATION_LEDGER_QUEUE",
            type: "queue",
            queue_name: "refwatch-mutation-ledger-production",
          },
          { name: "CF_VERSION_METADATA", type: "version_metadata" },
        ],
      },
    };
    const enabledReadback = structuredClone(disabledReadback);
    enabledReadback.resources.bindings.find(
      (binding) => binding.name === "WRITE_MODE",
    )!.text = "enabled";
    enabledReadback.resources.bindings.find(
      (binding) => binding.name === "NEW_USER_ONBOARDING_MODE",
    )!.text = "greenfield_bootstrap";

    expect(computeStableWorkerBindingSha256(enabledReadback)).toBe(
      computeStableWorkerBindingSha256(disabledReadback),
    );

    enabledReadback.resources.bindings.find(
      (binding) => binding.name === "CLERK_INSTANCE_ID",
    )!.text = "ins_other";
    expect(computeStableWorkerBindingSha256(enabledReadback)).not.toBe(
      computeStableWorkerBindingSha256(disabledReadback),
    );
  });

  it("fails closed for an unsupported Worker binding in the lineage readback", () => {
    expect(() => computeStableWorkerBindingSha256({
      resources: {
        script: { etag: candidateScriptEtag },
        script_runtime: {
          compatibility_date: "2026-07-14",
          compatibility_flags: ["nodejs_compat"],
          usage_model: "standard",
        },
        bindings: [{ name: "UNKNOWN", type: "unsafe_provider_binding" }],
      },
    })).toThrow("Unsupported Worker binding type");
  });

  it("sanitizes raw Worker readbacks without persisting author metadata or secret values", () => {
    const raw = {
      id: candidateVersion,
      metadata: {
        created_on: "2026-07-20T04:02:00.123456Z",
        author_email: "operator@example.invalid",
        author_id: "person-id",
      },
      resources: {
        script: {
          etag: candidateScriptEtag,
          placement_mode: "smart",
          placement: { mode: "smart" },
          handlers: ["fetch"],
        },
        script_runtime: {
          compatibility_date: "2026-07-14",
          compatibility_flags: ["nodejs_compat"],
          usage_model: "standard",
        },
        bindings: expectedProductionWorkerBindings("disabled", "disabled"),
      },
    };

    const sanitized = sanitizeWorkerVersionReadback(
      raw,
      "2026-07-20T04:04:00Z",
    ) as any;
    expect(sanitized).not.toHaveProperty("metadata");
    expect(JSON.stringify(sanitized)).not.toContain("operator@example.invalid");
    expect(sanitized.created_at_utc).toBe("2026-07-20T04:02:00.123Z");
    expect(
      sanitized.resources.bindings
        .filter((binding: any) => binding.type === "secret_text")
        .every((binding: any) =>
          Object.keys(binding).sort().join(",") === "name,type"),
    ).toBe(true);

    const rawWithSecretValue = structuredClone(raw);
    const secretBinding = rawWithSecretValue.resources.bindings.find(
      (binding: any) => binding.type === "secret_text",
    ) as any;
    secretBinding.text = "must-never-persist";
    expect(() => sanitizeWorkerVersionReadback(
      rawWithSecretValue,
      "2026-07-20T04:04:00Z",
    )).toThrow("keys must exactly match the sanitized Worker readback contract");
  });

  it("pins the current reviewed schema, seed, and clean-target query bytes", async () => {
    async function repositorySha256(repositoryPath: string): Promise<string> {
      const bytes = await readFile(
        new URL(`../${repositoryPath.replace(/^api\//, "")}`, import.meta.url),
      );
      return createHash("sha256").update(bytes).digest("hex");
    }

    expect(Object.isFrozen(reviewedSchema)).toBe(true);
    expect(reviewedSchema).toMatchObject({
      migrationHead: "0017_ambiguous_hedge_knight",
      migrationCount: 18,
      repositorySnapshotPath:
        "api/src/db/migrations/meta/0017_snapshot.json",
      repositorySnapshotSha256:
        "0830ddcdde5afd629479f595fe3cc5c3e500491e5042428e50abed3209b9efb2",
      migrationHeadId: 18,
      migrationHeadHash:
        "14b9c6beb831b76dbefee22f8eb592bd8ea72974f33a0aaed5570550e78f07f9",
      migrationHistoryMd5: "f2f3ddf416d58b2d9a60749e41af11f7",
      publicColumnCount: 383,
      publicColumnsMd5: "5fa4e25bcf19d7caf1f9adcfb4879344",
      catalogContractMd5: "99dca5e8c11b8ec23debfb7c698a74d7",
    });
    await expect(
      repositorySha256(reviewedSchema.repositorySnapshotPath),
    ).resolves.toBe(reviewedSchema.repositorySnapshotSha256);
    await expect(
      repositorySha256(reviewedSchema.providerQueryPath),
    ).resolves.toBe(reviewedSchema.providerQuerySha256);
    await expect(
      repositorySha256(reviewedDeterministicSeed.migrationPath),
    ).resolves.toBe(reviewedDeterministicSeed.migrationSha256);
    await expect(
      repositorySha256(cleanTargetReadback.queryPath),
    ).resolves.toBe(cleanTargetReadback.querySha256);
    await expect(
      repositorySha256(ledgerReadback.queryPath),
    ).resolves.toBe(ledgerReadback.querySha256);
  });

  it("accepts the exact production-bound greenfield launch packet", () => {
    const result = validateGreenfieldLaunchPacket(validPacket());

    expect(result).toMatchObject({
      ok: true,
      errors: [],
      summary: {
        launchProfile: "greenfield_launch_v3",
        authorizationDigest: greenfieldAuthorizationDigest,
        clerkInstanceId: productionClerk.instanceId,
        workerName: "refwatch-api",
        workerEnvironment: "production",
        candidateWorkerVersionId: candidateVersion,
        acceptedWorkerVersionId: acceptedVersion,
        legacyMappingCount: 0,
        targetAppUserCount: 0,
        activeLedgerEpochCount: 0,
        acceptanceChecks: greenfieldAcceptanceChecks.length,
        physicalDeviceAcceptancePassed: true,
        writeMode: "enabled",
        readyForProductionTraffic: true,
      },
    });
  });

  it("accepts route-based v2 only through the explicit historical validator", () => {
    const packet = historicalV2Packet();

    expect(validateGreenfieldLaunchPacket(packet).errors).toContain(
      "launch_profile must be greenfield_launch_v3",
    );
    expect(
      validateHistoricalGreenfieldLaunchPacketV2(packet, {
        now: deterministicValidationNow,
      }),
    ).toMatchObject({
      ok: true,
      errors: [],
      summary: { launchProfile: "greenfield_launch_v2" },
    });
  });

  it.each([
    ["provider ID", "provider_id", "not-a-provider-id", "provider_id must be a Cloudflare provider identifier"],
    ["hostname", "hostname", "wrong.example.invalid", "hostname must be api.refwatch.ibby.ai"],
    ["kind", "kind", "zone_route", "kind must be custom_domain"],
    ["TLS", "tls_status", "pending", "tls_status must be active"],
    ["DNS management", "dns_management", "manual_dns", "dns_management must be cloudflare_worker_custom_domain"],
    ["Worker identity", "worker_name", "other-worker", "worker_name must be refwatch-api"],
  ])("rejects Custom Domain %s drift", (_label, field, value, errorSuffix) => {
    const packet = validPacket();
    packet.traffic_and_writes.initial_candidate.edge_binding[field] = value;
    sealInlineReceipt(
      packet.traffic_and_writes.initial_candidate,
      "provider_receipt_sha256",
    );

    expect(
      validateGreenfieldLaunchPacket(packet).errors.some((error) =>
        error.includes(errorSuffix)),
    ).toBe(true);
  });

  it("rejects a conflicting zone route, a manual DNS origin, and binding drift between stages", () => {
    const packet = validPacket();
    packet.traffic_and_writes.initial_candidate.conflicting_zone_route_count = 1;
    packet.traffic_and_writes.initial_candidate.manual_dns_origin_present = true;
    packet.traffic_and_writes.bounded_acceptance_route.edge_binding.provider_id =
      "e".repeat(32);

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "traffic_and_writes.initial_candidate.conflicting_zone_route_count must be zero",
    );
    expect(errors).toContain(
      "traffic_and_writes.initial_candidate.manual_dns_origin_present must be false",
    );
    expect(errors).toContain(
      "bounded acceptance must use the reviewed Custom Domain binding",
    );
  });

  it("rejects a final production observation after the validation clock", () => {
    const packet = validPacket();
    packet.traffic_and_writes.accepted_cutover.observation_completed_at_utc =
      "2026-07-20T06:01:00Z";
    sealInlineReceipt(
      packet.traffic_and_writes.accepted_cutover,
      "observation_receipt_sha256",
    );

    expect(validateGreenfieldLaunchPacket(packet).errors).toContain(
      "production traffic observation must not complete in the future",
    );
  });

  it.each([
    new Date("invalid"),
    "2026-07-20T06:00:00Z",
    1_774_246_400_000,
    null,
  ])("fails closed for invalid validation now input: %s", (now) => {
    const result = (
      validateGreenfieldLaunchPacketWithRuntimeClock as (
        packet: unknown,
        options: unknown,
      ) => ReturnType<typeof validateGreenfieldLaunchPacketWithRuntimeClock>
    )(validPacket(), { now });

    expect(result.ok).toBe(false);
    expect(result.errors).toContain(
      "validation options.now must be a valid Date",
    );
  });

  it.each([
    {
      label: "schema",
      mutate(packet: any) {
        packet.database.schema.provider_readback.observed_at_utc =
          packet.traffic_and_writes.initial_candidate.verified_at_utc;
        sealInlineReceipt(packet.database.schema, "provider_receipt_sha256");
      },
      error:
        "schema baseline must precede write-disabled candidate verification",
    },
    {
      label: "deterministic seed",
      mutate(packet: any) {
        packet.database.deterministic_seed.provider_readback_at_utc =
          packet.traffic_and_writes.initial_candidate.verified_at_utc;
        sealInlineReceipt(
          packet.database.deterministic_seed,
          "provider_readback_sha256",
        );
      },
      error:
        "deterministic seed baseline must precede write-disabled candidate verification",
    },
    {
      label: "clean target",
      mutate(packet: any) {
        packet.database.clean_target_before_bootstrap.provider_readback_at_utc =
          packet.traffic_and_writes.initial_candidate.verified_at_utc;
        sealInlineReceipt(
          packet.database.clean_target_before_bootstrap,
          "provider_readback_sha256",
        );
      },
      error:
        "clean target baseline must precede write-disabled candidate verification",
    },
    {
      label: "inactive ledger",
      mutate(packet: any) {
        packet.ledger.provider_readback_at_utc =
          packet.traffic_and_writes.initial_candidate.verified_at_utc;
        sealInlineReceipt(packet.ledger, "provider_readback_sha256");
      },
      error:
        "inactive ledger baseline must precede write-disabled candidate verification",
    },
    {
      label: "Clerk",
      mutate(packet: any) {
        packet.clerk.provider_readback_at_utc =
          packet.traffic_and_writes.initial_candidate.verified_at_utc;
        sealInlineReceipt(packet.clerk, "provider_readback_sha256");
      },
      error:
        "Clerk baseline must precede write-disabled candidate verification",
    },
    {
      label: "Worker",
      mutate(packet: any) {
        packet.worker.provider_readback_at_utc =
          packet.traffic_and_writes.initial_candidate.verified_at_utc;
        sealInlineReceipt(packet.worker, "provider_readback_sha256");
      },
      error:
        "Worker version readback must precede write-disabled candidate verification",
    },
  ])("rejects a $label baseline simultaneous with candidate verification", ({
    mutate,
    error,
  }) => {
    const packet = validPacket();
    mutate(packet);

    expect(validateGreenfieldLaunchPacket(packet).errors).toContain(error);
  });

  it.each([
    {
      label: "activation observation and candidate creation",
      mutate(packet: any) {
        packet.worker.versions.candidate_worker_created_at_utc =
          packet.identity_bootstrap.activation_observed_at_utc;
        sealInlineReceipt(packet.worker, "provider_readback_sha256");
      },
      error:
        "disabled candidate Worker creation must follow identity activation observation",
    },
    {
      label: "activation and activation observation",
      mutate(packet: any) {
        packet.identity_bootstrap.activation_observed_at_utc =
          packet.identity_bootstrap.activated_at_utc;
        sealInlineReceipt(
          packet.identity_bootstrap,
          "activation_receipt_sha256",
        );
      },
      error: "identity activation observation must occur after activation",
    },
    {
      label: "activation observation and acceptance start",
      mutate(packet: any) {
        packet.acceptance.bounded_window.started_at_utc =
          packet.identity_bootstrap.activation_observed_at_utc;
      },
      error:
        "bounded acceptance must begin after identity activation is observed",
    },
    {
      label: "acceptance start and completion",
      mutate(packet: any) {
        packet.acceptance.bounded_window.started_at_utc =
          packet.acceptance.bounded_window.completed_at_utc;
      },
      error: "acceptance bounded window completion must follow its start",
    },
    {
      label: "acceptance completion and device acceptance",
      mutate(packet: any) {
        packet.physical_device_acceptance.iphone_15_pro_max.observed_at_utc =
          packet.acceptance.bounded_window.completed_at_utc;
        sealInlineReceipt(
          packet.physical_device_acceptance.iphone_15_pro_max,
          "receipt_sha256",
        );
      },
      error:
        "physical_device_acceptance.iphone_15_pro_max.observed_at_utc must follow automated acceptance",
    },
    {
      label: "device acceptance and production acceptance",
      mutate(packet: any) {
        packet.traffic_and_writes.accepted_cutover.production_accepted_at_utc =
          packet.physical_device_acceptance.release_configuration.observed_at_utc;
        sealInlineReceipt(
          packet.traffic_and_writes.accepted_cutover,
          "observation_receipt_sha256",
        );
      },
      error:
        "production acceptance must follow release_configuration",
    },
    {
      label: "traffic enablement and observation completion",
      mutate(packet: any) {
        packet.traffic_and_writes.accepted_cutover.observation_completed_at_utc =
          packet.traffic_and_writes.accepted_cutover.production_accepted_at_utc;
        sealInlineReceipt(
          packet.traffic_and_writes.accepted_cutover,
          "observation_receipt_sha256",
        );
      },
      error:
        "production traffic observation must complete after production acceptance",
    },
    {
      label: "rollback validation and acceptance start",
      mutate(packet: any) {
        packet.rollback.validated_at_utc =
          packet.traffic_and_writes.bounded_acceptance_route.enabled_at_utc;
      },
      error:
        "greenfield rollback packet must be validated before bounded routing",
    },
  ])("rejects simultaneous major stages: $label", ({ mutate, error }) => {
    const packet = validPacket();
    mutate(packet);

    expect(validateGreenfieldLaunchPacket(packet).errors).toContain(error);
  });

  it("requires the rollback window to remain strictly open after validation now", () => {
    const packet = validPacket();
    packet.rollback.packet.window.end_at_utc =
      deterministicValidationNow.toISOString();
    packet.rollback.packet_sha256 =
      computeSanitizedReceiptSha256(packet.rollback.packet);

    expect(validateGreenfieldLaunchPacket(packet).errors).toContain(
      "greenfield rollback window must end after validation time",
    );
  });

  it("requires both fallback probes to follow the exact Worker-version readback", () => {
    const guardPacket = validPacket();
    const guardProbe = guardPacket.rollback.packet.versions.write_guard_probe;
    guardProbe.observed_at_utc =
      guardPacket.rollback.packet.versions.provider_readback_at_utc;
    sealInlineReceipt(guardProbe, "receipt_sha256");
    guardPacket.rollback.packet_sha256 =
      computeSanitizedReceiptSha256(guardPacket.rollback.packet);
    expect(validateGreenfieldLaunchPacket(guardPacket).errors).toContain(
      "rollback.packet: versions.write_guard_probe must follow the exact Worker-version readback",
    );

    const lkgPacket = validPacket();
    const lkgProbe =
      lkgPacket.rollback.packet.versions.last_known_good_probe;
    lkgProbe.observed_at_utc =
      lkgPacket.rollback.packet.versions.provider_readback_at_utc;
    sealInlineReceipt(lkgProbe, "receipt_sha256");
    lkgPacket.rollback.packet_sha256 =
      computeSanitizedReceiptSha256(lkgPacket.rollback.packet);
    expect(validateGreenfieldLaunchPacket(lkgPacket).errors).toContain(
      "rollback.packet: versions.last_known_good_probe must follow the exact Worker-version readback",
    );
  });

  it("requires sanitized Worker readbacks to follow version creation", () => {
    const packet = validPacket();
    packet.worker.versions.candidate_sanitized_readback.observed_at_utc =
      packet.worker.versions.candidate_worker_created_at_utc;
    sealInlineReceipt(
      packet.worker.versions.candidate_sanitized_readback,
      "readback_sha256",
    );
    sealInlineReceipt(packet.worker, "provider_readback_sha256");

    expect(validateGreenfieldLaunchPacket(packet).errors).toContain(
      "worker.versions.candidate_sanitized_readback.observed_at_utc must follow Worker version creation",
    );
  });

  it("requires a non-disclosing sequential secret-lineage receipt for Worker A and B", () => {
    const packet = validPacket();
    const lineage = packet.worker.secret_lineage;
    lineage.candidate_inherited_from_worker_version_id = writeGuardVersion;
    lineage.required_secret_names = [
      ...productionWorkerSecretNames,
      "UNREVIEWED_SECRET",
    ];
    lineage.intervening_secret_mutation_count = 1;
    lineage.upload_secret_override_count = 1;
    lineage.secret_values_recorded = true;
    sealSecretLineage(lineage);
    sealInlineReceipt(packet.worker, "provider_readback_sha256");

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "worker.secret_lineage must bind Worker A to the reviewed secret-source version",
    );
    expect(errors).toContain(
      "worker.secret_lineage.required_secret_names must exactly match the reviewed non-disclosing secret-name set",
    );
    expect(errors).toContain(
      "worker.secret_lineage.intervening_secret_mutation_count must be zero",
    );
    expect(errors).toContain(
      "worker.secret_lineage.upload_secret_override_count must be zero",
    );
    expect(errors).toContain(
      "worker.secret_lineage.secret_values_recorded must be false",
    );
  });

  it("rejects tampered or impossible Worker secret-lineage provenance", () => {
    const digestPacket = validPacket();
    digestPacket.worker.secret_lineage
      .provider_version_history_receipt_sha256 = "f".repeat(64);
    sealInlineReceipt(
      digestPacket.worker.secret_lineage,
      "receipt_sha256",
    );
    sealInlineReceipt(digestPacket.worker, "provider_readback_sha256");
    expect(validateGreenfieldLaunchPacket(digestPacket).errors).toContain(
      "worker.secret_lineage.provider_version_history_receipt_sha256 must match the canonical sanitized receipt payload",
    );

    const chronologyPacket = validPacket();
    chronologyPacket.worker.secret_lineage
      .source_worker_version_created_at_utc =
        chronologyPacket.worker.versions.candidate_worker_created_at_utc;
    sealSecretLineage(chronologyPacket.worker.secret_lineage);
    sealInlineReceipt(chronologyPacket.worker, "provider_readback_sha256");
    expect(validateGreenfieldLaunchPacket(chronologyPacket).errors).toContain(
      "worker.secret_lineage secret-source version must precede Worker A",
    );
  });

  it("binds both rollback probes to the reviewed Custom Domain", () => {
    const packet = validPacket();
    packet.rollback.packet.versions.write_guard_probe.edge_binding.provider_id =
      "e".repeat(32);
    sealInlineReceipt(
      packet.rollback.packet.versions.write_guard_probe,
      "receipt_sha256",
    );
    packet.rollback.packet_sha256 =
      computeSanitizedReceiptSha256(packet.rollback.packet);

    expect(validateGreenfieldLaunchPacket(packet).errors).toContain(
      "rollback packet and fallback probes must use the reviewed Custom Domain binding",
    );
  });

  it.each([
    ["omitted", undefined],
    ["unknown", "stateful_migration_v1"],
    ["identity-only", "greenfield_zero_legacy_v1"],
  ])("rejects an %s launch profile", (_label, launchProfile) => {
    const packet = clonePacket();
    packet.launch_profile = launchProfile;

    expect(validateGreenfieldLaunchPacket(packet).errors).toContain(
      "launch_profile must be greenfield_launch_v3",
    );
  });

  it("rejects mixed stateful-migration and greenfield claims", () => {
    const packet = clonePacket();
    packet.snapshot = { source: "supabase-secure-export" };
    packet.clerk_mappings = [];

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "greenfield launch packet must not contain stateful migration claims: snapshot, clerk_mappings",
    );
    expect(errors).toContain("packet keys must exactly match the greenfield launch contract");
  });

  it("binds authorization and Clerk provenance to the exact production decision", () => {
    const packet = clonePacket();
    packet.authorization.decision_sha256 = digestA;
    packet.clerk.instance_id = "ins_other";
    packet.clerk.domain = "example.com";
    packet.clerk.issuer = "https://clerk.example.com";

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "authorization.decision_sha256 must match the approved 2026-07-20 decision digest",
    );
    expect(errors).toContain("clerk.instance_id must identify the exact production Clerk instance");
    expect(errors).toContain("clerk.domain must identify the exact production Clerk domain");
    expect(errors).toContain("clerk.issuer must identify the exact production Clerk issuer");
  });

  it("binds the exact production Worker and four distinct provider versions", () => {
    const packet = clonePacket();
    packet.worker.name = "refwatch-api-production";
    packet.worker.environment = "staging";
    packet.worker.versions.write_guard_worker_version_id = candidateVersion;

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain("worker.name must be refwatch-api");
    expect(errors).toContain("worker.environment must be production");
    expect(errors).toContain(
      "disabled candidate, accepted candidate, write-guard, and last-known-good Worker versions must be distinct",
    );
  });

  it("requires identical code and stable bindings across disabled and accepted versions", () => {
    const packet = clonePacket();
    packet.worker.versions.accepted_worker_version_id = candidateVersion;
    packet.worker.versions.accepted_script_etag = "e".repeat(64);
    packet.worker.versions.accepted_stable_binding_sha256 = "f".repeat(64);

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "disabled candidate, accepted candidate, write-guard, and last-known-good Worker versions must be distinct",
    );
    expect(errors).toContain(
      "disabled and accepted candidate Worker versions must have the same script ETag",
    );
    expect(errors).toContain(
      "disabled and accepted candidate Worker versions must have the same stable-binding contract",
    );
  });

  it("rejects matching A/B readbacks when both use an unapproved production binding", () => {
    const packet = validPacket();
    for (const field of [
      "candidate_sanitized_readback",
      "accepted_sanitized_readback",
    ]) {
      const readback = packet.worker.versions[field];
      readback.resources.bindings.find(
        (binding: any) => binding.name === "ALLOW_UNMAPPED_CLERK_USERS",
      ).text = "true";
      sealInlineReceipt(readback, "readback_sha256");
    }
    const stable = computeStableWorkerBindingSha256(
      packet.worker.versions.candidate_sanitized_readback,
    );
    packet.worker.versions.candidate_stable_binding_sha256 = stable;
    packet.worker.versions.accepted_stable_binding_sha256 = stable;
    sealInlineReceipt(packet.worker, "provider_readback_sha256");

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "worker.versions.candidate_sanitized_readback bindings must exactly match the reviewed production binding contract",
    );
    expect(errors).toContain(
      "worker.versions.accepted_sanitized_readback bindings must exactly match the reviewed production binding contract",
    );
  });

  it("binds every sanitized Worker readback to its exact version and recomputed digest", () => {
    const packet = validPacket();
    packet.worker.versions.candidate_sanitized_readback.worker_version_id =
      acceptedVersion;
    packet.worker.versions.accepted_sanitized_readback.resources.script.etag =
      "f".repeat(64);

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "worker.versions.candidate_sanitized_readback.worker_version_id must match its Worker version",
    );
    expect(errors).toContain(
      "worker.versions.candidate_sanitized_readback.readback_sha256 must match the canonical sanitized receipt payload",
    );
    expect(errors).toContain(
      "worker.versions.accepted_sanitized_readback script ETag must match worker.versions",
    );
    expect(errors).toContain(
      "worker.versions.accepted_sanitized_readback stable-binding SHA-256 must be recomputed from its provider readback",
    );
  });

  it("pins the exact PlanetScale production branch and trusted clean-target query", () => {
    const packet = clonePacket();
    packet.database.target.organization = "other-org";
    packet.database.target.branch_id = "other-branch";
    packet.database.target.runtime_marker = "refwatch:production:other";
    packet.database.clean_target_before_bootstrap.query_path = "invented.sql";
    packet.database.clean_target_before_bootstrap.query_sha256 = digestA;
    delete packet.database.clean_target_before_bootstrap.inventory.ai_attachments;

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "database.target.organization must be ibrahim-aka-ajax",
    );
    expect(errors).toContain("database.target.branch_id must be w3g1f8vcbg34");
    expect(errors).toContain(
      "database.target.runtime_marker must identify the exact production branch",
    );
    expect(errors).toContain(
      "database.clean_target_before_bootstrap.query_path must identify the trusted readback query",
    );
    expect(errors).toContain(
      "database.clean_target_before_bootstrap.query_sha256 must match the trusted readback query",
    );
    expect(errors).toContain(
      "database.clean_target_before_bootstrap.inventory keys must exactly match the greenfield launch contract",
    );
  });

  it("separates the logical PlanetScale resource from the physical SQL catalog", () => {
    const packet = validPacket();
    expect(packet.database.target.database).toBe(productionDatabase.database);
    expect(packet.database.schema.provider_readback.database_name).toBe(
      productionRuntimeProvisioningTarget.databaseName,
    );
    expect(packet.ledger.database_name).toBe(
      productionRuntimeProvisioningTarget.databaseName,
    );

    packet.database.schema.provider_readback.database_name =
      productionDatabase.database;
    packet.ledger.database_name = productionDatabase.database;

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "database.schema provider readback must identify database postgres",
    );
    expect(errors).toContain("ledger.database_name must be postgres");
  });

  it("requires provider schema and deterministic seed readbacks to match reviewed sources", () => {
    const packet = clonePacket();
    packet.database.schema.status = "candidate";
    packet.database.schema.provider_readback.migration_head_hash = digestB;
    packet.database.schema.migration_head = "0015_bound_ledger_capture_envelope";
    packet.database.schema.migration_count = 16;
    packet.database.deterministic_seed.repository_migration_path = "invented.sql";
    packet.database.deterministic_seed.repository_migration_sha256 = digestA;
    packet.database.deterministic_seed.reference_teams_count = 55;

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain("database.schema.status must be reviewed");
    expect(errors).toContain(
      "database.schema provider migration_head_hash must match migration 0017_ambiguous_hedge_knight",
    );
    expect(errors).toContain(
      "database.schema.migration_head must be 0017_ambiguous_hedge_knight",
    );
    expect(errors).toContain(
      "database.schema.migration_count must be 18",
    );
    expect(errors).toContain(
      "database.deterministic_seed.repository_migration_path must identify migration 0002",
    );
    expect(errors).toContain(
      "database.deterministic_seed.repository_migration_sha256 must match migration 0002",
    );
    expect(errors).toContain(
      "database.deterministic_seed.reference_teams_count must be 54",
    );
  });

  it("validates provider schema evidence independently of the repository snapshot digest", () => {
    const packet = validPacket();
    expect(packet.database.schema.provider_receipt_sha256).not.toBe(
      reviewedSchema.repositorySnapshotSha256,
    );

    packet.database.schema.provider_readback.public_table_count = 35;
    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "database.schema provider public_table_count must be 36",
    );
    expect(errors).toContain(
      "database.schema.provider_receipt_sha256 must match the canonical sanitized receipt payload",
    );
  });

  it("rejects manual catalog drift with unchanged migration history and table names", () => {
    const driftCases = [
      ["public_table_properties_md5", "public table-properties contract"],
      ["public_columns_md5", "public column contract"],
      ["public_constraints_md5", "public constraint contract"],
      ["public_indexes_md5", "public index contract"],
      ["public_triggers_md5", "public trigger contract"],
      ["public_functions_md5", "public function contract"],
      ["public_enum_labels_md5", "public enum-label contract"],
      ["catalog_contract_md5", "complete catalog contract"],
    ] as const;

    for (const [field, label] of driftCases) {
      const packet = validPacket();
      packet.database.schema.provider_readback[field] = "0".repeat(32);

      const errors = validateGreenfieldLaunchPacket(packet).errors;
      expect(errors).toContain(
        `database.schema provider ${label} must match the reviewed catalog`,
      );
      expect(errors).toContain(
        "database.schema.provider_receipt_sha256 must match the canonical sanitized receipt payload",
      );
      expect(packet.database.schema.provider_readback.migration_count).toBe(
        reviewedSchema.migrationCount,
      );
      expect(packet.database.schema.provider_readback.public_table_count).toBe(36);
    }
  });

  it("rejects seed-count drift and bootstrap before a clean-target readback", () => {
    const packet = clonePacket();
    packet.database.deterministic_seed.reference_competitions_count = 0;
    packet.database.deterministic_seed.reference_teams_business_md5 = "0".repeat(32);
    packet.database.clean_target_before_bootstrap.provider_readback_at_utc =
      "2026-07-20T04:01:00Z";

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "database.deterministic_seed.reference_competitions_count must be 5",
    );
    expect(errors).toContain(
      "database.deterministic_seed.reference_teams_business_md5 must match the reviewed value",
    );
    expect(errors).toContain(
      "greenfield bootstrap activation must follow the clean-target readback",
    );
  });

  it("requires unreviewed global reference families to remain empty", () => {
    const packet = clonePacket();
    packet.database.deterministic_seed.reference_disciplinary_codes_count = 30;
    packet.database.deterministic_seed.reference_disciplinary_rules_count = 3;
    packet.database.deterministic_seed.global_workout_presets_count = 20;

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "database.deterministic_seed.reference_disciplinary_codes_count must be zero",
    );
    expect(errors).toContain(
      "database.deterministic_seed.reference_disciplinary_rules_count must be zero",
    );
    expect(errors).toContain(
      "database.deterministic_seed.global_workout_presets_count must be zero",
    );
  });

  it("rejects any unexpected pre-bootstrap identity or application state", () => {
    const packet = clonePacket();
    packet.clerk.clean_user_count = 1;
    packet.database.clean_target_before_bootstrap.inventory.app_users = 1;
    packet.database.clean_target_before_bootstrap.inventory.teams = 1;
    packet.database.clean_target_before_bootstrap.inventory.idempotency_keys = 1;
    packet.identity_bootstrap.legacy_mapping_count = 1;

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain("clerk.clean_user_count must be zero before bootstrap");
    for (const name of ["app_users", "teams", "idempotency_keys"]) {
      expect(errors).toContain(
        `database.clean_target_before_bootstrap.inventory.${name} must be zero`,
      );
    }
    expect(errors).toContain("identity_bootstrap.legacy_mapping_count must be zero");
  });

  it("requires the exact approved zero-legacy activation", () => {
    const packet = clonePacket();
    packet.identity_bootstrap.reconciliation_profile = "stateful_migration_v1";
    packet.identity_bootstrap.receipt_digest = digestA;
    packet.identity_bootstrap.authorization_digest = digestB;
    packet.identity_bootstrap.mapping_hash = digestA;
    packet.identity_bootstrap.activated = false;

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "identity_bootstrap.reconciliation_profile must be greenfield_zero_legacy_v1",
    );
    expect(errors).toContain(
      "identity_bootstrap.receipt_digest must match the approved zero-legacy receipt",
    );
    expect(errors).toContain(
      "identity_bootstrap.authorization_digest must match the approved greenfield decision",
    );
    expect(errors).toContain(
      "identity_bootstrap.mapping_hash must be the canonical empty mapping hash",
    );
    expect(errors).toContain("identity_bootstrap.activated must be true");
  });

  it("binds identity and bounded acceptance receipts to the correct stages, Clerk, and database", () => {
    const packet = clonePacket();
    packet.identity_bootstrap.activation_receipt_sha256 = "invalid";
    packet.identity_bootstrap.clerk_instance_id = "ins_other";
    packet.identity_bootstrap.database_branch_id = "other";
    packet.acceptance.bounded_window.write_mode = "disabled";
    packet.acceptance.bounded_window.new_user_onboarding_mode = "disabled";
    packet.acceptance.bounded_window.traffic_scope = "production";
    packet.acceptance.bounded_window.reconciliation_receipt_digest = digestA;
    packet.acceptance.bounded_window.worker_version_id = candidateVersion;
    packet.acceptance.checks.health.observed_at_utc = "2026-07-20T04:41:00Z";
    packet.acceptance.checks.health.worker_version_id = writeGuardVersion;

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "identity_bootstrap.activation_receipt_sha256 must be SHA-256",
    );
    expect(errors).toContain(
      "identity_bootstrap.clerk_instance_id must match the production Clerk instance",
    );
    expect(errors).toContain(
      "identity_bootstrap.database_branch_id must match the production database branch",
    );
    expect(errors).toContain(
      "acceptance.bounded_window.write_mode must be enabled",
    );
    expect(errors).toContain(
      "acceptance.bounded_window.new_user_onboarding_mode must be greenfield_bootstrap",
    );
    expect(errors).toContain(
      "acceptance.bounded_window.traffic_scope must be bounded_test_only",
    );
    expect(errors).toContain(
      "acceptance.bounded_window.reconciliation_receipt_digest must match the approved receipt",
    );
    expect(errors).toContain(
      "acceptance.bounded_window.worker_version_id must match the accepted Worker version",
    );
    expect(errors).toContain(
      "acceptance.checks.health.observed_at_utc must fall within the bounded window",
    );
    expect(errors).toContain(
      "acceptance.checks.health.worker_version_id must match the expected Worker version",
    );
  });

  it("binds automated and physical acceptance to the accepted Worker only", () => {
    const packet = clonePacket();
    packet.acceptance.checks.health.worker_version_id = candidateVersion;
    packet.physical_device_acceptance.iphone_15_pro_max.worker_version_id =
      writeGuardVersion;

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "acceptance.checks.health.worker_version_id must match the expected Worker version",
    );
    expect(errors).toContain(
      "physical_device_acceptance.iphone_15_pro_max.worker_version_id must match the expected Worker version",
    );
  });

  it("requires exact receipt kinds and unique IDs across every acceptance result", () => {
    const packet = validPacket();
    packet.acceptance.checks.api_me = structuredClone(
      packet.acceptance.checks.health,
    );
    packet.physical_device_acceptance.apple_watch_series_9_45mm =
      structuredClone(packet.physical_device_acceptance.iphone_15_pro_max);

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "acceptance.checks.api_me.receipt_kind must be acceptance:api_me",
    );
    expect(errors).toContain("acceptance check receipt IDs must be unique");
    expect(errors).toContain(
      "physical_device_acceptance.apple_watch_series_9_45mm.receipt_kind must be physical_device:apple_watch_series_9_45mm",
    );
    expect(errors).toContain(
      "automated, physical-device, and release receipt IDs must be unique",
    );
  });

  it("recomputes every sanitized receipt digest and rejects payload tampering", () => {
    const cases: Array<{
      mutate: (packet: any) => void;
      error: string;
    }> = [
      {
        mutate: (packet) => { packet.clerk.clean_user_count = 1; },
        error:
          "clerk.provider_readback_sha256 must match the canonical sanitized receipt payload",
      },
      {
        mutate: (packet) => { packet.worker.environment = "staging"; },
        error:
          "worker.provider_readback_sha256 must match the canonical sanitized receipt payload",
      },
      {
        mutate: (packet) => {
          packet.database.schema.provider_readback.migration_count = 16;
        },
        error:
          "database.schema.provider_receipt_sha256 must match the canonical sanitized receipt payload",
      },
      {
        mutate: (packet) => {
          packet.database.deterministic_seed.reference_teams_count = 55;
        },
        error:
          "database.deterministic_seed.provider_readback_sha256 must match the canonical sanitized receipt payload",
      },
      {
        mutate: (packet) => {
          packet.database.clean_target_before_bootstrap.inventory.app_users = 1;
        },
        error:
          "database.clean_target_before_bootstrap.provider_readback_sha256 must match the canonical sanitized receipt payload",
      },
      {
        mutate: (packet) => {
          packet.identity_bootstrap.activation_receipt_id = "tampered";
        },
        error:
          "identity_bootstrap.activation_receipt_sha256 must match the canonical sanitized receipt payload",
      },
      {
        mutate: (packet) => { packet.ledger.archived_epoch_count = 2; },
        error:
          "ledger.provider_readback_sha256 must match the canonical sanitized receipt payload",
      },
      {
        mutate: (packet) => {
          packet.acceptance.checks.health.receipt_id = "tampered";
        },
        error:
          "acceptance.checks.health.receipt_sha256 must match the canonical sanitized receipt payload",
      },
      {
        mutate: (packet) => {
          packet.rollback.packet.client_recovery_release.build = "tampered";
        },
        error:
          "rollback.packet_sha256 must match the canonical sanitized receipt payload",
      },
      {
        mutate: (packet) => {
          packet.rollback.packet.versions.write_guard_probe.receipt_id =
            "tampered";
        },
        error:
          "rollback.packet: versions.write_guard_probe.receipt_sha256 must match the canonical sanitized probe",
      },
      {
        mutate: (packet) => {
          packet.rollback.packet.versions.last_known_good_probe.receipt_id =
            "tampered";
        },
        error:
          "rollback.packet: versions.last_known_good_probe.receipt_sha256 must match the canonical sanitized probe",
      },
      {
        mutate: (packet) => {
          packet.physical_device_acceptance.iphone_15_pro_max.receipt_id =
            "tampered";
        },
        error:
          "physical_device_acceptance.iphone_15_pro_max.receipt_sha256 must match the canonical sanitized receipt payload",
      },
      {
        mutate: (packet) => {
          packet.traffic_and_writes.initial_candidate.provider_receipt_id =
            "tampered";
        },
        error:
          "traffic_and_writes.initial_candidate.provider_receipt_sha256 must match the canonical sanitized receipt payload",
      },
      {
        mutate: (packet) => {
          packet.traffic_and_writes.bounded_acceptance_route
            .provider_receipt_id = "tampered";
        },
        error:
          "traffic_and_writes.bounded_acceptance_route.provider_receipt_sha256 must match the canonical sanitized receipt payload",
      },
      {
        mutate: (packet) => {
          packet.traffic_and_writes.accepted_cutover.observation_receipt_id =
            "tampered";
        },
        error:
          "traffic_and_writes.accepted_cutover.observation_receipt_sha256 must match the canonical sanitized receipt payload",
      },
    ];

    for (const testCase of cases) {
      const packet = validPacket();
      testCase.mutate(packet);
      expect(validateGreenfieldLaunchPacket(packet).errors).toContain(
        testCase.error,
      );
    }
  });

  it("rejects missing or extra receipt payload fields even when an extra payload is rehashed", () => {
    const missing = validPacket();
    delete missing.acceptance.checks.health.receipt_sha256;
    expect(validateGreenfieldLaunchPacket(missing).errors).toContain(
      "acceptance.checks.health keys must exactly match the greenfield launch contract",
    );

    const extra = validPacket();
    extra.acceptance.checks.health.unreviewed = "extra";
    sealInlineReceipt(extra.acceptance.checks.health, "receipt_sha256");
    expect(validateGreenfieldLaunchPacket(extra).errors).toContain(
      "acceptance.checks.health keys must exactly match the greenfield launch contract",
    );
  });

  it("rejects any claim that the production ledger or a consumer is active", () => {
    const packet = clonePacket();
    Object.assign(packet.ledger, {
      status: "active",
      total_epoch_count: 4,
      preparing_epoch_count: 1,
      open_epoch_count: 1,
      capture_enforced_epoch_count: 1,
      queue_consumer_count: 1,
      cron_consumer_count: 1,
      d1_consumer_count: 1,
    });

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "ledger.status must be inactive_with_optional_history",
    );
    expect(errors).toContain("ledger.open_epoch_count must be zero");
    expect(errors).toContain(
      "ledger.preparing_epoch_count must be zero",
    );
    expect(errors).toContain(
      "ledger.capture_enforced_epoch_count must be zero",
    );
    expect(errors).toContain("ledger.queue_consumer_count must be zero");
    expect(errors).toContain("ledger.cron_consumer_count must be zero");
    expect(errors).toContain("ledger.d1_consumer_count must be zero");
  });

  it("allows classified inactive historical ledger rows without activating capture", () => {
    const packet = validPacket();
    Object.assign(packet.ledger, {
      total_epoch_count: 7,
      preparing_epoch_count: 0,
      open_epoch_count: 0,
      frozen_epoch_count: 2,
      archived_epoch_count: 5,
      capture_enforced_epoch_count: 0,
      entity_revision_count: 90,
      outbox_event_count: 70,
      outbox_delivery_count: 70,
    });
    Object.assign(packet.final_ledger, {
      total_epoch_count: 7,
      preparing_epoch_count: 0,
      open_epoch_count: 0,
      frozen_epoch_count: 2,
      archived_epoch_count: 5,
      capture_enforced_epoch_count: 0,
      entity_revision_count: 90,
      outbox_event_count: 70,
      outbox_delivery_count: 70,
    });
    sealInlineReceipt(packet.ledger, "provider_readback_sha256");
    sealInlineReceipt(packet.final_ledger, "provider_readback_sha256");

    expect(packet.database.clean_target_before_bootstrap.inventory).not.toHaveProperty(
      "mutation_ledger_epochs",
    );
    expect(validateGreenfieldLaunchPacket(packet)).toMatchObject({
      ok: true,
      summary: { activeLedgerEpochCount: 0 },
    });
  });

  it("requires provider baselines, activation, immutable versions, and disabled proof in order", () => {
    const afterCandidate = validPacket();
    afterCandidate.database.schema.provider_readback.observed_at_utc =
      afterCandidate.traffic_and_writes.initial_candidate.verified_at_utc;
    sealInlineReceipt(afterCandidate.database.schema, "provider_receipt_sha256");
    expect(validateGreenfieldLaunchPacket(afterCandidate).errors).toContain(
      "schema baseline must precede write-disabled candidate verification",
    );

    const afterBootstrap = validPacket();
    afterBootstrap.database.clean_target_before_bootstrap.provider_readback_at_utc =
      afterBootstrap.identity_bootstrap.activated_at_utc;
    sealInlineReceipt(
      afterBootstrap.database.clean_target_before_bootstrap,
      "provider_readback_sha256",
    );
    afterBootstrap.worker.versions.candidate_worker_created_at_utc =
      afterBootstrap.identity_bootstrap.activation_observed_at_utc;
    sealInlineReceipt(afterBootstrap.worker, "provider_readback_sha256");

    const errors = validateGreenfieldLaunchPacket(afterBootstrap).errors;
    expect(errors).toContain(
      "greenfield bootstrap activation must follow the clean-target readback",
    );
    expect(errors).toContain(
      "disabled candidate Worker creation must follow identity activation observation",
    );
  });

  it("requires every bounded health, auth, isolation, onboarding, and write check", () => {
    const packet = clonePacket();
    packet.acceptance.bounded_window.observed_requests = 201;
    packet.acceptance.bounded_window.observed_test_identities = 4;
    packet.acceptance.checks.tenant_isolation.status = "failed";
    delete packet.acceptance.checks.write_round_trip;

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "acceptance observed_requests must be positive and no greater than max_requests",
    );
    expect(errors).toContain(
      "acceptance observed_test_identities must be positive and no greater than max_test_identities",
    );
    expect(errors).toContain("acceptance.checks keys must exactly match the greenfield launch contract");
    expect(errors).toContain("acceptance.checks.tenant_isolation.status must be passed");
    expect(errors).toContain("acceptance.checks.write_round_trip.status must be passed");
  });

  it("requires the complete destructive reset, reseed, recreate rollback", () => {
    const packet = clonePacket();
    packet.rollback.packet.rollback_profile = "stateful_migration_v1";
    packet.rollback.packet.greenfield_recovery.ledger_recovery_required = true;
    packet.rollback.packet.greenfield_recovery.supabase_reverse_import_required =
      true;
    packet.rollback.packet.versions.accepted_worker_version_id =
      writeGuardVersion;
    packet.rollback.packet.versions.write_guard_worker_version_id =
      candidateVersion;
    packet.rollback.validation_status = "pending";
    packet.rollback.packet_sha256 = "invalid";

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "rollback.packet.rollback_profile must be greenfield_destructive_v3",
    );
    expect(errors).toContain("rollback.validation_status must be passed");
    expect(errors).toContain("rollback.packet_sha256 must be SHA-256");
    expect(errors).toContain(
      "rollback.packet.versions.accepted_worker_version_id must match the launch Worker version",
    );
    expect(errors).toContain(
      "rollback.packet.versions.write_guard_worker_version_id must match the launch Worker version",
    );
    expect(errors).toContain(
      "rollback.packet: stateful_migration_v1 must not include greenfield_recovery",
    );
  });

  it("fails closed when physical-device or release-configuration acceptance is incomplete", () => {
    const packet = clonePacket();
    packet.physical_device_acceptance.iphone_15_pro_max.status = "blocked_unavailable";
    packet.physical_device_acceptance.apple_watch_series_9_45mm.status = "pending";
    packet.physical_device_acceptance.release_configuration.status = "failed";

    const result = validateGreenfieldLaunchPacket(packet);
    expect(result.ok).toBe(false);
    expect(result.summary.physicalDeviceAcceptancePassed).toBe(false);
    expect(result.errors).toContain(
      "physical_device_acceptance.iphone_15_pro_max.status must be passed",
    );
    expect(result.errors).toContain(
      "physical_device_acceptance.apple_watch_series_9_45mm.status must be passed",
    );
    expect(result.errors).toContain(
      "physical_device_acceptance.release_configuration.status must be passed",
    );
  });

  it("enforces automated, physical, final-traffic, and observation ordering", () => {
    const packet = clonePacket();
    packet.physical_device_acceptance.iphone_15_pro_max.observed_at_utc =
      "2026-07-20T04:39:00Z";
    packet.traffic_and_writes.accepted_cutover.production_accepted_at_utc =
      "2026-07-20T04:46:00Z";
    packet.traffic_and_writes.accepted_cutover.observation_completed_at_utc =
      "2026-07-20T04:45:00Z";
    packet.traffic_and_writes.accepted_cutover.database_branch_id = "other";

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "physical_device_acceptance.iphone_15_pro_max.observed_at_utc must follow automated acceptance",
    );
    expect(errors).toContain(
      "production acceptance must follow apple_watch_series_9_45mm",
    );
    expect(errors).toContain(
      "production traffic observation must complete after production acceptance",
    );
    expect(errors).toContain(
      "accepted traffic observation must bind the production database branch",
    );
  });

  it("proves the initial candidate was write-disabled and rejects premature write enablement", () => {
    const packet = clonePacket();
    packet.traffic_and_writes.initial_candidate.write_mode = "enabled";
    packet.traffic_and_writes.initial_candidate.new_user_onboarding_mode =
      "greenfield_bootstrap";
    packet.traffic_and_writes.initial_candidate.route_status = "unrouted";
    packet.traffic_and_writes.initial_candidate.version_weights = [
      { worker_version_id: candidateVersion, traffic_percentage: 0 },
      { worker_version_id: acceptedVersion, traffic_percentage: 100 },
    ];
    packet.traffic_and_writes.initial_candidate.workers_dev_enabled = true;
    packet.traffic_and_writes.initial_candidate.preview_urls_enabled = true;
    packet.traffic_and_writes.accepted_cutover.enabled_at_utc =
      "2026-07-20T03:45:00Z";

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain("initial candidate WRITE_MODE must be disabled");
    expect(errors).toContain(
      "initial candidate NEW_USER_ONBOARDING_MODE must be disabled",
    );
    expect(errors).toContain(
      "initial candidate route_status must be write_disabled_route",
    );
    expect(errors).toContain(
      "initial deployment must route A at 100 percent and hold B at zero percent",
    );
    expect(errors).toContain("initial candidate Workers.dev must be disabled");
    expect(errors).toContain("initial candidate preview URLs must be disabled");
    expect(errors).toContain(
      "WRITE_MODE must be enabled after the greenfield bootstrap receipt is activated",
    );
    expect(errors).toContain(
      "Worker B must be promoted after bounded acceptance completes",
    );
  });

  it("rejects bounded acceptance that begins before bootstrap activation", () => {
    const packet = clonePacket();
    packet.acceptance.bounded_window.started_at_utc = "2026-07-20T03:59:00Z";

    expect(validateGreenfieldLaunchPacket(packet).errors).toContain(
      "bounded acceptance must begin after greenfield bootstrap activation",
    );
  });

  it("requires provider-bound protected B-at-zero routing before bounded acceptance", () => {
    const packet = validPacket();
    const bounded = packet.traffic_and_writes.bounded_acceptance_route;
    bounded.deployment_id = "unreviewed-deployment";
    bounded.version_weights[1].traffic_percentage = 1;
    bounded.access_control = "none";
    bounded.access_application_id = "";
    bounded.access_policy_action = "bypass";
    bounded.access_bypass_policy_count = 1;
    bounded.missing_token_http_status = 200;
    bounded.workers_dev_enabled = true;
    bounded.enabled_at_utc = packet.acceptance.bounded_window.started_at_utc;

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "bounded acceptance route must use the reviewed A=100/B=0 deployment",
    );
    expect(errors).toContain(
      "bounded acceptance must keep A at 100 percent and B at zero percent",
    );
    expect(errors).toContain(
      "bounded acceptance access_control must combine Cloudflare Access and the Worker cutover token",
    );
    expect(errors).toContain(
      "traffic_and_writes.bounded_acceptance_route.access_application_id is required",
    );
    expect(errors).toContain(
      "bounded acceptance Cloudflare Access policy action must be service_auth",
    );
    expect(errors).toContain(
      "bounded acceptance Cloudflare Access must have zero bypass policies",
    );
    expect(errors).toContain(
      "bounded acceptance must prove missing cutover-token rejection with 403",
    );
    expect(errors).toContain(
      "bounded acceptance must keep Workers.dev and preview URLs disabled",
    );
    expect(errors).toContain(
      "bounded acceptance window must start after its protected route is enabled",
    );
  });

  it("requires the bounded webhook receipt to prove the manual override and token path", () => {
    const sourcePacket = validPacket();
    sourcePacket.acceptance.checks.webhook_lifecycle.delivery_source =
      "clerk_production_instance";
    sealInlineReceipt(
      sourcePacket.acceptance.checks.webhook_lifecycle,
      "receipt_sha256",
    );
    expect(validateGreenfieldLaunchPacket(sourcePacket).errors).toContain(
      "acceptance.checks.webhook_lifecycle.delivery_source must be manual_signed_harness",
    );

    const overridePacket = validPacket();
    overridePacket.acceptance.checks.webhook_lifecycle
      .version_override_header_present = false;
    sealInlineReceipt(
      overridePacket.acceptance.checks.webhook_lifecycle,
      "receipt_sha256",
    );
    expect(validateGreenfieldLaunchPacket(overridePacket).errors).toContain(
      "acceptance.checks.webhook_lifecycle must prove the exact Worker version-override header was present",
    );

    const tokenPacket = validPacket();
    tokenPacket.acceptance.checks.webhook_lifecycle
      .cutover_token_header_present = false;
    sealInlineReceipt(
      tokenPacket.acceptance.checks.webhook_lifecycle,
      "receipt_sha256",
    );
    expect(validateGreenfieldLaunchPacket(tokenPacket).errors).toContain(
      "acceptance.checks.webhook_lifecycle must prove the exact Worker cutover-token header was present",
    );
  });

  it.each([
    {
      label: "non-production provider provenance",
      mutate(packet: any) {
        packet.traffic_and_writes.promoted_webhook_acceptance.provider_source =
          "manual_test_harness";
        sealInlineReceipt(
          packet.traffic_and_writes.promoted_webhook_acceptance,
          "receipt_sha256",
        );
      },
      error:
        "promoted webhook provider source must be the production Clerk instance",
    },
    {
      label: "version-override header claim",
      mutate(packet: any) {
        packet.traffic_and_writes.promoted_webhook_acceptance
          .version_override_header_present = true;
        sealInlineReceipt(
          packet.traffic_and_writes.promoted_webhook_acceptance,
          "receipt_sha256",
        );
      },
      error:
        "real Clerk provider delivery must not claim version-override or cutover-token headers",
    },
    {
      label: "failed provider delivery",
      mutate(packet: any) {
        packet.traffic_and_writes.promoted_webhook_acceptance
          .provider_delivery_status = "failed";
        sealInlineReceipt(
          packet.traffic_and_writes.promoted_webhook_acceptance,
          "receipt_sha256",
        );
      },
      error: "promoted webhook provider_delivery_status must be passed",
    },
    {
      label: "pre-promotion observation",
      mutate(packet: any) {
        packet.traffic_and_writes.promoted_webhook_acceptance.observed_at_utc =
          packet.traffic_and_writes.accepted_cutover.enabled_at_utc;
        sealInlineReceipt(
          packet.traffic_and_writes.promoted_webhook_acceptance,
          "receipt_sha256",
        );
      },
      error: "real Clerk provider delivery must follow Worker B promotion",
    },
    {
      label: "duplicate acceptance receipt",
      mutate(packet: any) {
        packet.traffic_and_writes.promoted_webhook_acceptance.receipt_id =
          packet.acceptance.checks.webhook_lifecycle.receipt_id;
        sealInlineReceipt(
          packet.traffic_and_writes.promoted_webhook_acceptance,
          "receipt_sha256",
        );
      },
      error:
        "promoted webhook receipt ID must be unique across acceptance receipts",
    },
  ])("rejects promoted webhook $label", ({ mutate, error }) => {
    const packet = validPacket();
    mutate(packet);

    expect(validateGreenfieldLaunchPacket(packet).errors).toContain(error);
  });

  it("rejects a tampered promoted-webhook receipt digest", () => {
    const packet = validPacket();
    packet.traffic_and_writes.promoted_webhook_acceptance.receipt_sha256 =
      "f".repeat(64);

    expect(validateGreenfieldLaunchPacket(packet).errors).toContain(
      "traffic_and_writes.promoted_webhook_acceptance.receipt_sha256 must match the canonical sanitized receipt payload",
    );
  });

  it("requires exact final B=100 deployment history and no alternate exposure", () => {
    const packet = validPacket();
    const accepted = packet.traffic_and_writes.accepted_cutover;
    accepted.edge_binding.hostname = "wrong.example.invalid";
    accepted.version_weights = [
      { worker_version_id: acceptedVersion, traffic_percentage: 1 },
      { worker_version_id: candidateVersion, traffic_percentage: 99 },
    ];
    accepted.traffic_percentage = 1;
    accepted.competing_version_count = 1;
    accepted.preview_urls_enabled = true;
    accepted.deployment_history_receipt_id = "tampered";
    accepted.bounded_access_status = "active";

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "traffic_and_writes.accepted_cutover.edge_binding.hostname must be api.refwatch.ibby.ai",
    );
    expect(errors).toContain(
      "accepted deployment must route only Worker B at 100 percent",
    );
    expect(errors).toContain(
      "accepted traffic must route Worker B at 100 percent with no competing version",
    );
    expect(errors).toContain(
      "accepted traffic must keep Workers.dev and preview URLs disabled",
    );
    expect(errors).toContain(
      "traffic_and_writes.accepted_cutover.deployment_history_receipt_sha256 must match the canonical sanitized receipt payload",
    );
    expect(errors).toContain(
      "accepted traffic must remove the bounded Cloudflare Access policy",
    );
    expect(errors).toContain(
      "traffic_and_writes.accepted_cutover.bounded_access_removal_receipt_sha256 must match the canonical sanitized receipt payload",
    );
  });

  it("requires a final post-observation inactive-ledger and zero-consumer readback", () => {
    const packet = validPacket();
    Object.assign(packet.final_ledger, {
      status: "active",
      total_epoch_count: 3,
      open_epoch_count: 1,
      frozen_epoch_count: 1,
      archived_epoch_count: 1,
      capture_enforced_epoch_count: 1,
      queue_consumer_count: 1,
      provider_readback_at_utc:
        packet.traffic_and_writes.accepted_cutover.observation_completed_at_utc,
    });

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "final_ledger.status must be inactive_with_optional_history",
    );
    expect(errors).toContain("final_ledger.open_epoch_count must be zero");
    expect(errors).toContain(
      "final_ledger.capture_enforced_epoch_count must be zero",
    );
    expect(errors).toContain("final_ledger.queue_consumer_count must be zero");
    expect(errors).toContain(
      "final inactive-ledger readback must follow the production observation",
    );
  });

  it("rejects normalized impossible UTC calendar dates", () => {
    const packet = validPacket();
    packet.clerk.provider_readback_at_utc = "2026-02-30T03:02:00Z";
    sealInlineReceipt(packet.clerk, "provider_readback_sha256");
    packet.rollback.packet.window.end_at_utc = "2026-02-30T08:00:00Z";
    packet.rollback.packet_sha256 =
      computeSanitizedReceiptSha256(packet.rollback.packet);

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain(
      "clerk.provider_readback_at_utc must be a strict UTC instant",
    );
    expect(errors).toContain(
      "rollback.packet: window.end_at_utc must be a strict UTC instant",
    );
  });

  it("rejects accepted traffic that is not explicitly routed and receipt-bound", () => {
    const packet = clonePacket();
    packet.traffic_and_writes.accepted_cutover.routed_worker_version_id =
      writeGuardVersion;
    packet.traffic_and_writes.accepted_cutover.route_status = "write_disabled_route";
    packet.traffic_and_writes.accepted_cutover.write_mode = "disabled";
    packet.traffic_and_writes.accepted_cutover.new_user_onboarding_mode = "disabled";
    packet.traffic_and_writes.accepted_cutover.reconciliation_receipt_digest =
      digestA;
    packet.traffic_and_writes.accepted_cutover.observation_status = "pending";

    const errors = validateGreenfieldLaunchPacket(packet).errors;
    expect(errors).toContain("accepted traffic must route the accepted Worker version");
    expect(errors).toContain("accepted route_status must be production_active");
    expect(errors).toContain("accepted WRITE_MODE must be enabled");
    expect(errors).toContain(
      "accepted NEW_USER_ONBOARDING_MODE must be greenfield_bootstrap",
    );
    expect(errors).toContain(
      "accepted traffic must bind the approved greenfield reconciliation receipt",
    );
    expect(errors).toContain("accepted traffic observation_status must be passed");
  });
});
