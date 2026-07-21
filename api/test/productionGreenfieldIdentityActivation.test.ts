import { EventEmitter } from "node:events";
import { describe, expect, it, vi } from "vitest";
import {
  createProductionGreenfieldIdentityActivationReceipt,
  executeProductionGreenfieldIdentityActivation,
  loadProductionGreenfieldIdentityActivationSources,
  productionGreenfieldIdentityActivationCommand,
  productionGreenfieldIdentityActivationGate,
  renderProductionGreenfieldIdentityActivationSQL,
  runProductionGreenfieldIdentityActivationCLI,
  runProductionGreenfieldIdentityActivationSession,
  validateProductionGreenfieldIdentityActivationReadback,
  validateProductionGreenfieldIdentityActivationSources,
  type ProductionGreenfieldIdentityActivationSource,
} from "../scripts/activate-production-greenfield-identity.mjs";
import {
  cleanTargetReadback,
  greenfieldAuthorizationDigest,
  greenfieldAuthorizationProfile,
  greenfieldCleanTargetTables,
  greenfieldEmptyMappingHash,
  greenfieldIdentityProfile,
  greenfieldIdentityReceiptDigest,
  ledgerReadback,
  productionClerk,
  productionDatabase,
  reviewedDeterministicSeed,
  reviewedSchema0016,
} from "../scripts/greenfield-launch-packet.mjs";
import { productionMigration0016Contract } from "../scripts/apply-production-migration-0016.mjs";
import { productionRuntimeProvisioningTarget } from "../scripts/provision-production-runtime.mjs";

const receiptMarker = "REFWATCH_GREENFIELD_IDENTITY_RECEIPT:";
const readyMarker = "REFWATCH_GREENFIELD_IDENTITY_READY";
const committedMarker = "REFWATCH_GREENFIELD_IDENTITY_COMMITTED";

describe("production greenfield identity activation helper", () => {
  it("loads and pins every reviewed repository source", async () => {
    const source = await loadProductionGreenfieldIdentityActivationSources();

    expect(Object.isFrozen(reviewedSchema0016)).toBe(true);
    expect(reviewedSchema0016).toMatchObject({
      migrationHead: "0016_careless_steel_serpent",
      migrationCount: 17,
      repositorySnapshotPath:
        "api/src/db/migrations/meta/0016_snapshot.json",
      migrationHeadId: 17,
      publicColumnCount: 382,
    });
    expect(source.tableNames).toHaveLength(reviewedSchema0016.publicTableCount);
    expect(source.tableNames).toContain("public.app_users");
    expect(source.tableNames).toContain("public.reference_competitions");
    expect(source.tableNames).toContain("public.runtime_database_markers");
    expect(source.tableNames).toContain("public.mutation_ledger_epochs");
    expect(source.tableNames).toContain(
      "public.identity_reconciliation_receipts",
    );
  });

  it("fails closed for drift in each reviewed source class", async () => {
    const input = rawSource(
      await loadProductionGreenfieldIdentityActivationSources(),
    );
    const digestDriftCases: Array<keyof ProductionGreenfieldIdentityActivationSource> = [
      "schemaReadbackSQL",
      "cleanTargetReadbackSQL",
      "ledgerReadbackSQL",
      "deterministicSeedMigrationSQL",
      "migrationSnapshotJSON",
      "previousMigrationSQL",
      "targetMigrationSQL",
    ];

    for (const key of digestDriftCases) {
      expect(() => validateProductionGreenfieldIdentityActivationSources({
        ...input,
        [key]: `${input[key]}\n`,
      }), key).toThrow();
    }
    const journal = JSON.parse(input.migrationJournalJSON);
    journal.entries[0].tag = "0000_semantic_drift";
    expect(() => validateProductionGreenfieldIdentityActivationSources({
      ...input,
      migrationJournalJSON: JSON.stringify(journal),
    })).toThrow("Production migration journal source digest does not match");
  });

  it("renders a pre-commit transaction that locks all reviewed tables before the advisory lock", async () => {
    const source = await loadProductionGreenfieldIdentityActivationSources();
    const sql = renderProductionGreenfieldIdentityActivationSQL(source);

    expect(sql.match(/^BEGIN ISOLATION LEVEL SERIALIZABLE;$/gmu)).toHaveLength(1);
    expect(sql.match(/^COMMIT;$/gmu)).toBeNull();
    expect(sql).toContain('SET LOCAL ROLE "postgres";');
    expect(sql).toContain("SET LOCAL search_path = pg_catalog, public;");
    expect(sql).toContain("current_setting('session_replication_role') <> 'origin'");
    expect(sql).toContain("sequence_last_value = 18");
    expect(sql).toContain("sequence_last_value = 17");
    expect(sql).toContain("sequence_is_called IS TRUE");
    expect(sql).toContain('"drizzle"."__drizzle_migrations"');
    for (const tableName of source.tableNames) {
      const [schema, table] = tableName.split(".");
      expect(sql).toContain(`"${schema}"."${table}"`);
    }
    expect(sql.indexOf("LOCK TABLE")).toBeLessThan(
      sql.indexOf("pg_advisory_xact_lock"),
    );
    expect(sql).toContain("IN SHARE ROW EXCLUSIVE MODE;");
    expect(sql).toContain(greenfieldIdentityReceiptDigest);
    expect(sql).toContain(greenfieldAuthorizationDigest);
    expect(sql).toContain(greenfieldEmptyMappingHash);
    expect(sql).toContain(productionClerk.instanceId);
    expect(sql).toContain("refwatch_activation_post_clean_readback");
  });

  it("uses only fixed pscale arguments, hardened environment, and stdin SQL", async () => {
    const runSession = vi.fn(async (specification, validateBeforeCommit) => {
      expect(specification.command).toBe("pscale");
      expect(specification.args).toEqual([
        "shell",
        "refwatch",
        "main",
        "--org",
        "ibrahim-aka-ajax",
        "--role",
        "admin",
        "--no-color",
      ]);
      expect(specification.args.join(" ")).not.toContain(
        greenfieldIdentityReceiptDigest,
      );
      expect(specification.sql).toContain(greenfieldIdentityReceiptDigest);
      expect(specification.environment).toMatchObject({
        PSCALE_ALLOW_NONINTERACTIVE_SHELL: "1",
        PSQLRC: "/dev/null",
        PSQL_HISTORY: "/dev/null",
      });
      expect(specification.environment.PGOPTIONS).toBeUndefined();
      return validateBeforeCommit(validReadback());
    });

    const receipt = await executeProductionGreenfieldIdentityActivation({
      runSession,
      environment: {
        [productionGreenfieldIdentityActivationGate]: "1",
        PGOPTIONS: "-c session_replication_role=replica",
      },
    });

    expect(runSession).toHaveBeenCalledOnce();
    expect(receipt.status).toBe("committed");
    expect(receipt.receipt_sha256).toMatch(/^[0-9a-f]{64}$/u);
  });

  it("does not permit COMMIT until the exact receipt is validated", async () => {
    const child = fakeChild();
    const specification = {
      command: "pscale",
      args: productionGreenfieldIdentityActivationCommand.args,
      sql: "BEGIN;\nSELECT 1;",
      environment: {},
    };
    const promise = runProductionGreenfieldIdentityActivationSession(
      specification,
      validateProductionGreenfieldIdentityActivationReadback,
      {
        spawnImpl: vi.fn(() => child as never),
        timeoutMs: 2_000,
      },
    );

    expect(child.stdin.write).toHaveBeenCalledWith(
      `${specification.sql}\n`,
    );
    expect(child.stdin.end).not.toHaveBeenCalled();
    child.stdout.emit(
      "data",
      Buffer.from(
        `${receiptMarker}${JSON.stringify(validReadback())}\n${readyMarker}\n`,
      ),
    );
    expect(child.stdin.end).toHaveBeenCalledWith(
      `COMMIT;\n\\echo ${committedMarker}\n\\quit\n`,
    );
    child.stdout.emit("data", Buffer.from(`${committedMarker}\n`));
    child.emit("close", 0);

    await expect(promise).resolves.toMatchObject({
      status: "validated_pending_commit",
    });
  });

  it("rolls back malformed provider output without echoing captured output", async () => {
    const child = fakeChild();
    const promise = runProductionGreenfieldIdentityActivationSession(
      {
        command: "pscale",
        args: productionGreenfieldIdentityActivationCommand.args,
        sql: "BEGIN;",
        environment: {},
      },
      validateProductionGreenfieldIdentityActivationReadback,
      {
        spawnImpl: vi.fn(() => child as never),
        timeoutMs: 2_000,
      },
    );
    child.stderr.emit(
      "data",
      Buffer.from("CHILD_STDERR_CREDENTIAL_MARKER"),
    );
    child.stdout.emit(
      "data",
      Buffer.from(`${receiptMarker}{CHILD_STDOUT_CREDENTIAL_MARKER}\n`),
    );
    expect(child.stdin.end).toHaveBeenCalledWith("ROLLBACK;\n\\quit\n");
    child.emit("close", 1);

    await expect(promise).rejects.toThrow(
      "Production greenfield identity activation execution failed",
    );
    await promise.catch((error: Error) => {
      expect(error.message).not.toContain("CHILD_STDOUT_CREDENTIAL_MARKER");
      expect(error.message).not.toContain("CHILD_STDERR_CREDENTIAL_MARKER");
    });
  });

  it("fails ambiguously after a lost commit sentinel and permits exact retry", async () => {
    const firstChild = fakeChild();
    const first = runProductionGreenfieldIdentityActivationSession(
      {
        command: "pscale",
        args: productionGreenfieldIdentityActivationCommand.args,
        sql: "BEGIN;",
        environment: {},
      },
      validateProductionGreenfieldIdentityActivationReadback,
      { spawnImpl: vi.fn(() => firstChild as never), timeoutMs: 2_000 },
    );
    firstChild.stdout.emit(
      "data",
      Buffer.from(
        `${receiptMarker}${JSON.stringify(validReadback())}\n${readyMarker}\n`,
      ),
    );
    firstChild.emit("close", 0);
    await expect(first).rejects.toThrow(
      "Production greenfield identity activation execution failed",
    );

    const retryChild = fakeChild();
    const retry = runProductionGreenfieldIdentityActivationSession(
      {
        command: "pscale",
        args: productionGreenfieldIdentityActivationCommand.args,
        sql: "BEGIN;",
        environment: {},
      },
      validateProductionGreenfieldIdentityActivationReadback,
      { spawnImpl: vi.fn(() => retryChild as never), timeoutMs: 2_000 },
    );
    retryChild.stdout.emit(
      "data",
      Buffer.from(
        `${receiptMarker}${JSON.stringify(validReadback("idempotent_retry"))}\n${readyMarker}\n`,
      ),
    );
    retryChild.stdout.emit("data", Buffer.from(`${committedMarker}\n`));
    retryChild.emit("close", 0);
    await expect(retry).resolves.toMatchObject({
      operation: "idempotent_retry",
    });
  });

  it("terminates timeout and output-limit paths with only a generic failure", async () => {
    const timeoutChild = fakeChild();
    const timedOut = runProductionGreenfieldIdentityActivationSession(
      {
        command: "pscale",
        args: productionGreenfieldIdentityActivationCommand.args,
        sql: "BEGIN;",
        environment: {},
      },
      validateProductionGreenfieldIdentityActivationReadback,
      {
        spawnImpl: vi.fn(() => timeoutChild as never),
        timeoutMs: 5,
        killGraceMs: 5,
      },
    );
    setTimeout(() => timeoutChild.emit("close", null), 15);
    await expect(timedOut).rejects.toThrow(
      "Production greenfield identity activation execution failed",
    );
    expect(timeoutChild.kill).toHaveBeenCalled();

    const overflowChild = fakeChild();
    const overflow = runProductionGreenfieldIdentityActivationSession(
      {
        command: "pscale",
        args: productionGreenfieldIdentityActivationCommand.args,
        sql: "BEGIN;",
        environment: {},
      },
      validateProductionGreenfieldIdentityActivationReadback,
      {
        spawnImpl: vi.fn(() => overflowChild as never),
        timeoutMs: 2_000,
        maxOutputBytes: 16,
      },
    );
    overflowChild.stdout.emit("data", Buffer.from("x".repeat(17)));
    overflowChild.emit("close", 1);
    await expect(overflow).rejects.toThrow(
      "Production greenfield identity activation execution failed",
    );
  });

  it("rejects wrong keys, types, UUIDs, timestamps, and ledger state", () => {
    expect(() => validateProductionGreenfieldIdentityActivationReadback({
      ...validReadback(),
      unexpected: true,
    })).toThrow();
    expect(() => validateProductionGreenfieldIdentityActivationReadback({
      ...validReadback(),
      schema_version: "1",
    })).toThrow();
    expect(() => validateProductionGreenfieldIdentityActivationReadback({
      ...validReadback(),
      identity_receipt: {
        ...validReadback().identity_receipt,
        id: "not-a-uuid",
      },
    })).toThrow();
    expect(() => validateProductionGreenfieldIdentityActivationReadback({
      ...validReadback(),
      identity_receipt: {
        ...validReadback().identity_receipt,
        reviewed_at_utc: "not-a-timestamp",
      },
    })).toThrow();
    const readback = validReadback();
    expect(() => validateProductionGreenfieldIdentityActivationReadback({
      ...readback,
      verified_state: {
        ...readback.verified_state,
        ledger: {
          ...readback.verified_state.ledger,
          open_epoch_count: 1,
          total_epoch_count: 1,
        },
      },
    })).toThrow();
    expect(() => validateProductionGreenfieldIdentityActivationReadback({
      ...readback,
      verified_state: {
        ...readback.verified_state,
        history_sequence: {
          ...readback.verified_state.history_sequence,
          cache_size: 2,
        },
      },
    })).toThrow();
    expect(() => validateProductionGreenfieldIdentityActivationReadback({
      ...readback,
      verified_state: {
        ...readback.verified_state,
        history_sequence: {
          ...readback.verified_state.history_sequence,
          last_value: 18,
          is_called: true,
        },
      },
    })).toThrow();
  });

  it("computes a deterministic canonical SHA-256 over the committed receipt", () => {
    const first = createProductionGreenfieldIdentityActivationReceipt(
      validReadback(),
    );
    const second = createProductionGreenfieldIdentityActivationReceipt(
      JSON.parse(JSON.stringify(validReadback())),
    );

    expect(first).toEqual(second);
    expect(first.receipt_sha256).toMatch(/^[0-9a-f]{64}$/u);
  });

  it("keeps production impossible by default and makes check source-only", async () => {
    const execute = vi.fn(async () => validReadback());
    const checkSources = vi.fn(async () => undefined);
    const stdout = vi.fn();
    const stderr = vi.fn();

    expect(await runProductionGreenfieldIdentityActivationCLI({
      args: [],
      environment: {},
      execute,
      checkSources,
      writeStdout: stdout,
      writeStderr: stderr,
    })).toBe(2);
    expect(await runProductionGreenfieldIdentityActivationCLI({
      args: ["--execute"],
      environment: {},
      execute,
      checkSources,
      writeStdout: stdout,
      writeStderr: stderr,
    })).toBe(2);
    expect(execute).not.toHaveBeenCalled();

    expect(await runProductionGreenfieldIdentityActivationCLI({
      args: ["--check"],
      environment: {},
      execute,
      checkSources,
      writeStdout: stdout,
      writeStderr: stderr,
    })).toBe(0);
    expect(checkSources).toHaveBeenCalledOnce();
    expect(execute).not.toHaveBeenCalled();

    expect(await runProductionGreenfieldIdentityActivationCLI({
      args: ["--execute"],
      environment: {
        [productionGreenfieldIdentityActivationGate]: "1",
      },
      execute: vi.fn(async () => ({
        ...validReadback(),
        status: "committed",
        receipt_sha256: "0".repeat(64),
      })),
      writeStdout: stdout,
      writeStderr: stderr,
    })).toBe(0);
  });

  it("keeps the exported execution function behind the same technical gate", async () => {
    const runSession = vi.fn();

    await expect(executeProductionGreenfieldIdentityActivation({
      runSession,
      environment: {},
    })).rejects.toThrow("gate is closed");
    expect(runSession).not.toHaveBeenCalled();
  });

  it("emits only a generic CLI failure when provider text is sensitive", async () => {
    const stdout = vi.fn();
    const stderr = vi.fn();
    const exitCode = await runProductionGreenfieldIdentityActivationCLI({
      args: ["--execute"],
      environment: {
        [productionGreenfieldIdentityActivationGate]: "1",
      },
      execute: vi.fn(async () => {
        throw new Error(
          "CHILD_STDOUT_CREDENTIAL_MARKER CHILD_STDERR_CREDENTIAL_MARKER",
        );
      }),
      writeStdout: stdout,
      writeStderr: stderr,
    });

    expect(exitCode).toBe(1);
    expect(stdout).not.toHaveBeenCalled();
    expect(stderr).toHaveBeenCalledOnce();
    expect(stderr.mock.calls[0]?.[0]).not.toContain("CREDENTIAL_MARKER");
  });
});

function rawSource(
  source: Awaited<ReturnType<
    typeof loadProductionGreenfieldIdentityActivationSources
  >>,
): ProductionGreenfieldIdentityActivationSource {
  return {
    schemaReadbackSQL: source.schemaReadbackSQL,
    cleanTargetReadbackSQL: source.cleanTargetReadbackSQL,
    ledgerReadbackSQL: source.ledgerReadbackSQL,
    deterministicSeedMigrationSQL: source.deterministicSeedMigrationSQL,
    migrationSnapshotJSON: source.migrationSnapshotJSON,
    migrationJournalJSON: source.migrationJournalJSON,
    previousMigrationSQL: source.previousMigrationSQL,
    targetMigrationSQL: source.targetMigrationSQL,
  };
}

function validReadback(operation = "activated") {
  const cleanTargetInventory = Object.fromEntries(
    greenfieldCleanTargetTables.map((name) => [name, 0]),
  );
  cleanTargetInventory.identity_reconciliation_receipts = 1;
  cleanTargetInventory.identity_reconciliation_activations = 1;
  const timestamp = "2026-07-21T01:02:03.456Z";
  return {
    schema_version: 1,
    receipt_type: "refwatch_production_greenfield_identity_activation",
    status: "validated_pending_commit",
    operation,
    provider_command: {
      command: "pscale",
      arguments: [...productionGreenfieldIdentityActivationCommand.args],
      sql_transport: "stdin",
    },
    production_target: {
      organization: productionDatabase.organization,
      logical_database: productionDatabase.database,
      postgres_database: productionRuntimeProvisioningTarget.databaseName,
      branch: productionDatabase.branch,
      branch_id: productionDatabase.branchId,
      runtime_marker: productionDatabase.runtimeMarker,
      stable_role: productionMigration0016Contract.stableOwner,
    },
    source_contract: {
      schema_readback_path: reviewedSchema0016.providerQueryPath,
      schema_readback_sha256: reviewedSchema0016.providerQuerySha256,
      clean_target_readback_path: cleanTargetReadback.queryPath,
      clean_target_readback_sha256: cleanTargetReadback.querySha256,
      ledger_readback_path: ledgerReadback.queryPath,
      ledger_readback_sha256: ledgerReadback.querySha256,
      seed_migration_path: reviewedDeterministicSeed.migrationPath,
      seed_migration_sha256: reviewedDeterministicSeed.migrationSha256,
      migration_snapshot_path: reviewedSchema0016.repositorySnapshotPath,
      migration_snapshot_sha256: reviewedSchema0016.repositorySnapshotSha256,
      migration_journal_path: productionMigration0016Contract.journalPath,
      migration_journal_sha256: productionMigration0016Contract.journalSha256,
      migration_head: reviewedSchema0016.migrationHead,
      migration_count: reviewedSchema0016.migrationCount,
      migration_head_hash: reviewedSchema0016.migrationHeadHash,
    },
    verified_state: {
      schema: {
        database_name: productionRuntimeProvisioningTarget.databaseName,
        runtime_marker: productionDatabase.runtimeMarker,
        database_branch_id: productionDatabase.branchId,
        migration_count: reviewedSchema0016.migrationCount,
        migration_head_id: reviewedSchema0016.migrationHeadId,
        migration_head_hash: reviewedSchema0016.migrationHeadHash,
        migration_history_md5: reviewedSchema0016.migrationHistoryMd5,
        public_table_count: reviewedSchema0016.publicTableCount,
        public_table_names_md5: reviewedSchema0016.publicTableNamesMd5,
        public_table_properties_count:
          reviewedSchema0016.publicTablePropertiesCount,
        public_table_properties_md5:
          reviewedSchema0016.publicTablePropertiesMd5,
        public_column_count: reviewedSchema0016.publicColumnCount,
        public_columns_md5: reviewedSchema0016.publicColumnsMd5,
        public_constraint_count: reviewedSchema0016.publicConstraintCount,
        public_constraints_md5: reviewedSchema0016.publicConstraintsMd5,
        public_index_count: reviewedSchema0016.publicIndexCount,
        public_indexes_md5: reviewedSchema0016.publicIndexesMd5,
        public_trigger_count: reviewedSchema0016.publicTriggerCount,
        public_triggers_md5: reviewedSchema0016.publicTriggersMd5,
        public_function_count: reviewedSchema0016.publicFunctionCount,
        public_functions_md5: reviewedSchema0016.publicFunctionsMd5,
        public_enum_label_count: reviewedSchema0016.publicEnumLabelCount,
        public_enum_labels_md5: reviewedSchema0016.publicEnumLabelsMd5,
        catalog_contract_md5: reviewedSchema0016.catalogContractMd5,
      },
      history_sequence: {
        data_type: productionMigration0016Contract.historySequence.dataType,
        start_value: productionMigration0016Contract.historySequence.startValue,
        minimum_value:
          productionMigration0016Contract.historySequence.minimumValue,
        maximum_value:
          productionMigration0016Contract.historySequence.maximumValue,
        increment_by:
          productionMigration0016Contract.historySequence.incrementBy,
        cache_size: productionMigration0016Contract.historySequence.cacheSize,
        cycle: productionMigration0016Contract.historySequence.cycle,
        last_value:
          productionMigration0016Contract.historySequence.targetRestartWith,
        is_called: productionMigration0016Contract.historySequence.targetIsCalled,
        next_value:
          productionMigration0016Contract.historySequence.targetRestartWith,
      },
      deterministic_seed: {
        reference_competitions_count:
          reviewedDeterministicSeed.referenceCompetitionsCount,
        reference_competitions_business_md5:
          reviewedDeterministicSeed.referenceCompetitionsBusinessMd5,
        reference_teams_count: reviewedDeterministicSeed.referenceTeamsCount,
        reference_teams_business_md5:
          reviewedDeterministicSeed.referenceTeamsBusinessMd5,
        reference_disciplinary_codes_count:
          reviewedDeterministicSeed.referenceDisciplinaryCodesCount,
        reference_disciplinary_rules_count:
          reviewedDeterministicSeed.referenceDisciplinaryRulesCount,
        global_workout_presets_count:
          reviewedDeterministicSeed.globalWorkoutPresetsCount,
      },
      clean_target_inventory: cleanTargetInventory,
      ledger: {
        database_name: productionRuntimeProvisioningTarget.databaseName,
        database_branch_id: productionDatabase.branchId,
        runtime_marker: productionDatabase.runtimeMarker,
        total_epoch_count: 0,
        preparing_epoch_count: 0,
        open_epoch_count: 0,
        frozen_epoch_count: 0,
        archived_epoch_count: 0,
        capture_enforced_epoch_count: 0,
        entity_revision_count: 0,
        outbox_event_count: 0,
        outbox_delivery_count: 0,
      },
    },
    identity_receipt: {
      id: "00000000-0000-4000-8000-000000000001",
      receipt_digest: greenfieldIdentityReceiptDigest,
      clerk_instance_id: productionClerk.instanceId,
      reconciliation_profile: greenfieldIdentityProfile,
      authorization_profile: greenfieldAuthorizationProfile,
      authorization_digest: greenfieldAuthorizationDigest,
      clerk_issuer: productionClerk.issuer,
      clerk_domain: productionClerk.domain,
      snapshot_captured_at_utc: timestamp,
      legacy_mapping_count: 0,
      excluded_auth_count: 0,
      mapping_hash: greenfieldEmptyMappingHash,
      status: "verified",
      reviewed_at_utc: timestamp,
      activated_at_utc: timestamp,
    },
    identity_activation: {
      receipt_digest: greenfieldIdentityReceiptDigest,
      clerk_instance_id: productionClerk.instanceId,
      activated_at_utc: timestamp,
    },
  };
}

function fakeChild() {
  const child = new EventEmitter() as EventEmitter & {
    stdin: EventEmitter & {
      writable: boolean;
      write: ReturnType<typeof vi.fn>;
      end: ReturnType<typeof vi.fn>;
    };
    stdout: EventEmitter;
    stderr: EventEmitter;
    kill: ReturnType<typeof vi.fn>;
  };
  child.stdin = Object.assign(new EventEmitter(), {
    writable: true,
    write: vi.fn(() => true),
    end: vi.fn(() => undefined),
  });
  child.stdout = new EventEmitter();
  child.stderr = new EventEmitter();
  child.kill = vi.fn(() => true);
  return child;
}
