import { EventEmitter } from "node:events";
import { describe, expect, it, vi } from "vitest";
import {
  createProductionMigration0017Receipt,
  executeProductionMigration0017,
  loadProductionMigration0017Sources,
  productionMigration0017Command,
  productionMigration0017Contract,
  productionMigration0017Gate,
  renderProductionMigration0017SQL,
  runProductionMigration0017CLI,
  runProductionMigration0017Session,
  validateProductionMigration0017Readback,
  validateProductionMigration0017Sources,
  type ProductionMigration0017Source,
} from "../scripts/apply-production-migration-0017.mjs";
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
  reviewedSchema,
} from "../scripts/greenfield-launch-packet.mjs";

const receiptMarker = "REFWATCH_PRODUCTION_MIGRATION_0017_RECEIPT:";
const readyMarker = "REFWATCH_PRODUCTION_MIGRATION_0017_READY";
const committedMarker = "REFWATCH_PRODUCTION_MIGRATION_0017_COMMITTED";

describe("production migration 0017 helper", () => {
  it("pins every reviewed repository source and exact target snapshot", async () => {
    const source = await loadProductionMigration0017Sources();

    expect(source.tableNames).toHaveLength(36);
    expect(source.tableNames).toContain("public.app_users");
    expect(source.tableNames).toContain("public.identity_reconciliation_receipts");
    expect(source.tableNames).toContain("public.mutation_ledger_epochs");
    expect(source.migrationHistoryRows).toHaveLength(18);
    expect(source.migrationHistoryRows[0]).toMatchObject({ id: 1 });
    expect(source.migrationHistoryRows.at(-1)).toEqual({
      id: 18,
      hash: productionMigration0017Contract.target.fileSha256,
      created_at: productionMigration0017Contract.target.journalTimestamp,
    });
    expect(source.targetMigrationSQL).toBe(
      'ALTER TABLE "app_users" ADD COLUMN "clerk_profile_updated_at" timestamp with time zone;',
    );
  });

  it("fails source-only validation for drift in every pinned source class", async () => {
    const source = rawSource(await loadProductionMigration0017Sources());
    for (const key of Object.keys(source) as Array<keyof ProductionMigration0017Source>) {
      expect(() => validateProductionMigration0017Sources({
        ...source,
        [key]: `${source[key]}\n`,
      }), key).toThrow();
    }
  });

  it("renders one pre-commit transaction with all-table locks and verbatim conditional SQL", async () => {
    const source = await loadProductionMigration0017Sources();
    const sql = renderProductionMigration0017SQL(source);

    expect(sql.match(/^BEGIN ISOLATION LEVEL SERIALIZABLE;$/gmu)).toHaveLength(1);
    expect(sql.match(/^COMMIT;$/gmu)).toBeNull();
    expect(sql).toContain('SET LOCAL ROLE "postgres";');
    expect(sql).toContain("IN SHARE ROW EXCLUSIVE MODE;");
    for (const tableName of source.tableNames) {
      const [schema, table] = tableName.split(".");
      expect(sql).toContain(`"${schema}"."${table}"`);
    }
    expect(sql).toContain(source.targetMigrationSQL);
    expect(sql).toContain("\\if :refwatch_migration_0017_should_apply");
    expect(sql).toContain("VALUES (\n  18,");
    expect(sql).toContain('ALTER SEQUENCE "drizzle"."__drizzle_migrations_id_seq"\n  RESTART WITH 19;');
    expect(sql).toContain("sequence_last_value = 18");
    expect(sql).toContain("sequence_last_value = 17");
    expect(sql).toContain("sequence_is_called IS FALSE");
    expect(sql).toContain("sequence_is_called IS TRUE");
    expect(sql).toContain("'idempotent_retry'");
    expect(sql).toContain("public_column_count");
    expect(sql).toContain("5fa4e25bcf19d7caf1f9adcfb4879344");
    expect(sql).toContain("99dca5e8c11b8ec23debfb7c698a74d7");
    expect(sql).toContain(
      productionMigration0017Contract.previous.fullHistorySha256,
    );
    expect(sql).toContain(
      productionMigration0017Contract.target.fullHistorySha256,
    );
    expect(sql).toContain("pg_get_serial_sequence");
    expect(sql).toContain("dependency.deptype = 'a'");
    expect(sql).toContain(
      "nextval(''drizzle.__drizzle_migrations_id_seq''::regclass)",
    );
    expect(sql).toContain(greenfieldIdentityReceiptDigest);
    expect(sql).toContain(productionClerk.instanceId);
  });

  it("uses fixed pscale arguments, stdin SQL, and a hardened environment", async () => {
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
        productionMigration0017Contract.target.fileSha256,
      );
      expect(specification.sql).toContain(
        productionMigration0017Contract.target.fileSha256,
      );
      expect(specification.environment).toMatchObject({
        PSCALE_ALLOW_NONINTERACTIVE_SHELL: "1",
        PSQLRC: "/dev/null",
        PSQL_HISTORY: "/dev/null",
      });
      expect(specification.environment.PGOPTIONS).toBeUndefined();
      return validateBeforeCommit(validReadback());
    });

    const receipt = await executeProductionMigration0017({
      runSession,
      environment: {
        [productionMigration0017Gate]: "1",
        PGOPTIONS: "-c session_replication_role=replica",
      },
    });
    expect(runSession).toHaveBeenCalledOnce();
    expect(receipt).toMatchObject({ status: "committed", operation: "applied" });
    expect(receipt.receipt_sha256).toMatch(/^[0-9a-f]{64}$/u);
  });

  it("validates the receipt before COMMIT and accepts an exact retry receipt", async () => {
    const child = fakeChild();
    const specification = {
      command: "pscale",
      args: productionMigration0017Command.args,
      sql: "BEGIN;",
      environment: {},
    };
    const pending = runProductionMigration0017Session(
      specification,
      validateProductionMigration0017Readback,
      { spawnImpl: vi.fn(() => child as never), timeoutMs: 2_000 },
    );
    expect(child.stdin.write).toHaveBeenCalledWith("BEGIN;\n");
    expect(child.stdin.end).not.toHaveBeenCalled();
    child.stdout.emit("data", Buffer.from(
      `${receiptMarker}${JSON.stringify(validReadback("idempotent_retry"))}\n${readyMarker}\n`,
    ));
    expect(child.stdin.end).toHaveBeenCalledWith(
      `COMMIT;\n\\echo ${committedMarker}\n\\quit\n`,
    );
    child.stdout.emit("data", Buffer.from(`${committedMarker}\n`));
    child.emit("close", 0);
    await expect(pending).resolves.toMatchObject({ operation: "idempotent_retry" });
  });

  it("rolls back malformed provider output and never echoes captured provider text", async () => {
    const child = fakeChild();
    const pending = runProductionMigration0017Session(
      {
        command: "pscale",
        args: productionMigration0017Command.args,
        sql: "BEGIN;",
        environment: {},
      },
      validateProductionMigration0017Readback,
      { spawnImpl: vi.fn(() => child as never), timeoutMs: 2_000 },
    );
    child.stderr.emit("data", Buffer.from("CHILD_STDERR_SECRET_MARKER"));
    child.stdout.emit("data", Buffer.from(
      `${receiptMarker}{CHILD_STDOUT_SECRET_MARKER}\n`,
    ));
    expect(child.stdin.end).toHaveBeenCalledWith("ROLLBACK;\n\\quit\n");
    child.emit("close", 1);
    await expect(pending).rejects.toThrow("Production migration 0017 execution failed");
    await pending.catch((error: Error) => {
      expect(error.message).not.toContain("SECRET_MARKER");
    });
  });

  it("fails closed on timeout without disclosing buffered provider output", async () => {
    const child = fakeChild();
    const pending = runProductionMigration0017Session(
      {
        command: "pscale",
        args: productionMigration0017Command.args,
        sql: "BEGIN;",
        environment: {},
      },
      validateProductionMigration0017Readback,
      {
        spawnImpl: vi.fn(() => child as never),
        timeoutMs: 10,
        killGraceMs: 1,
      },
    );
    child.stdout.emit("data", Buffer.from("BUFFERED_STDOUT_SECRET_MARKER"));
    child.stderr.emit("data", Buffer.from("BUFFERED_STDERR_SECRET_MARKER"));
    await new Promise((resolve) => setTimeout(resolve, 50));
    expect(child.stdin.end).not.toHaveBeenCalled();
    expect(child.kill).toHaveBeenCalledWith("SIGTERM");
    expect(child.kill).toHaveBeenCalledWith("SIGKILL");
    child.emit("close", 1);
    await expect(pending).rejects.toThrow(
      "Production migration 0017 execution failed",
    );
    await pending.catch((error: Error) => {
      expect(error.message).not.toContain("SECRET_MARKER");
    });
  });

  it("fails closed when either provider output stream exceeds the byte cap", async () => {
    for (const streamName of ["stdout", "stderr"] as const) {
      const child = fakeChild();
      const pending = runProductionMigration0017Session(
        {
          command: "pscale",
          args: productionMigration0017Command.args,
          sql: "BEGIN;",
          environment: {},
        },
        validateProductionMigration0017Readback,
        {
          spawnImpl: vi.fn(() => child as never),
          timeoutMs: 2_000,
          maxOutputBytes: 8,
        },
      );
      child[streamName].emit("data", Buffer.from("OVER_LIMIT_SECRET_MARKER"));
      expect(child.stdin.end, streamName).toHaveBeenCalledWith(
        "ROLLBACK;\n\\quit\n",
      );
      child.emit("close", 1);
      await expect(pending, streamName).rejects.toThrow(
        "Production migration 0017 execution failed",
      );
    }
  });

  it("rejects duplicate receipt, READY, and COMMITTED protocol markers", async () => {
    const cases = [
      {
        name: "receipt",
        output: `${receiptMarker}${JSON.stringify(validReadback())}\n${receiptMarker}${JSON.stringify(validReadback())}\n`,
        exitCode: 1,
      },
      {
        name: "ready",
        output: `${receiptMarker}${JSON.stringify(validReadback())}\n${readyMarker}\n${readyMarker}\n`,
        exitCode: 1,
      },
      {
        name: "committed",
        output: `${receiptMarker}${JSON.stringify(validReadback())}\n${readyMarker}\n${committedMarker}\n${committedMarker}\n`,
        exitCode: 0,
      },
    ];
    for (const testCase of cases) {
      const child = fakeChild();
      const pending = runProductionMigration0017Session(
        {
          command: "pscale",
          args: productionMigration0017Command.args,
          sql: "BEGIN;",
          environment: {},
        },
        validateProductionMigration0017Readback,
        { spawnImpl: vi.fn(() => child as never), timeoutMs: 2_000 },
      );
      child.stdout.emit("data", Buffer.from(testCase.output));
      child.emit("close", testCase.exitCode);
      await expect(pending, testCase.name).rejects.toThrow(
        "Production migration 0017 execution failed",
      );
    }
  });

  it("rejects a lost post-COMMIT sentinel and permits an exact retry", async () => {
    const child = fakeChild();
    const pending = runProductionMigration0017Session(
      {
        command: "pscale",
        args: productionMigration0017Command.args,
        sql: "BEGIN;",
        environment: {},
      },
      validateProductionMigration0017Readback,
      { spawnImpl: vi.fn(() => child as never), timeoutMs: 2_000 },
    );
    child.stdout.emit("data", Buffer.from(
      `${receiptMarker}${JSON.stringify(validReadback())}\n${readyMarker}\n`,
    ));
    expect(child.stdin.end).toHaveBeenCalledWith(
      `COMMIT;\n\\echo ${committedMarker}\n\\quit\n`,
    );
    child.emit("close", 0);
    await expect(pending).rejects.toThrow(
      "Production migration 0017 execution failed",
    );

    const retryChild = fakeChild();
    const retry = runProductionMigration0017Session(
      {
        command: "pscale",
        args: productionMigration0017Command.args,
        sql: "BEGIN;",
        environment: {},
      },
      validateProductionMigration0017Readback,
      { spawnImpl: vi.fn(() => retryChild as never), timeoutMs: 2_000 },
    );
    retryChild.stdout.emit("data", Buffer.from(
      `${receiptMarker}${JSON.stringify(validReadback("idempotent_retry"))}\n${readyMarker}\n`,
    ));
    retryChild.stdout.emit("data", Buffer.from(`${committedMarker}\n`));
    retryChild.emit("close", 0);
    await expect(retry).resolves.toMatchObject({
      operation: "idempotent_retry",
    });
  });

  it("rejects malformed readback shapes and computes a stable canonical SHA", () => {
    expect(() => validateProductionMigration0017Readback({
      ...validReadback(),
      unexpected: true,
    })).toThrow();
    expect(() => validateProductionMigration0017Readback({
      ...validReadback(),
      verified_state: {
        ...validReadback().verified_state,
        history_sequence: {
          ...validReadback().verified_state.history_sequence,
          last_value: 18,
        },
      },
    })).toThrow();
    expect(() => validateProductionMigration0017Readback({
      ...validReadback(),
      identity_receipt: {
        ...validReadback().identity_receipt,
        id: "not-a-uuid",
      },
    })).toThrow();
    expect(() => validateProductionMigration0017Readback({
      ...validReadback(),
      verified_state: {
        ...validReadback().verified_state,
        migration_history: {
          ...validReadback().verified_state.migration_history,
          full_history_sha256: "0".repeat(64),
        },
      },
    })).toThrow();
    expect(() => validateProductionMigration0017Readback({
      ...validReadback(),
      verified_state: {
        ...validReadback().verified_state,
        migration_history_catalog: {
          ...validReadback().verified_state.migration_history_catalog,
          serial_sequence: null,
        },
      },
    })).toThrow();

    const first = createProductionMigration0017Receipt(validReadback());
    const second = createProductionMigration0017Receipt(
      JSON.parse(JSON.stringify(validReadback())),
    );
    expect(first).toEqual(second);
    expect(first.receipt_sha256).toMatch(/^[0-9a-f]{64}$/u);
  });

  it("keeps execution impossible by default and makes --check source-only", async () => {
    const execute = vi.fn(async () => validReadback());
    const checkSources = vi.fn(async () => undefined);
    const stdout = vi.fn();
    const stderr = vi.fn();

    expect(await runProductionMigration0017CLI({
      args: [], environment: {}, execute, checkSources,
      writeStdout: stdout, writeStderr: stderr,
    })).toBe(2);
    expect(await runProductionMigration0017CLI({
      args: ["--execute"], environment: {}, execute, checkSources,
      writeStdout: stdout, writeStderr: stderr,
    })).toBe(2);
    expect(execute).not.toHaveBeenCalled();

    expect(await runProductionMigration0017CLI({
      args: ["--check"], environment: {}, execute, checkSources,
      writeStdout: stdout, writeStderr: stderr,
    })).toBe(0);
    expect(checkSources).toHaveBeenCalledOnce();
    expect(execute).not.toHaveBeenCalled();
  });

  it("keeps the exported execution path behind the same technical gate", async () => {
    const runSession = vi.fn();
    await expect(executeProductionMigration0017({
      runSession,
      environment: {},
    })).rejects.toThrow("gate is closed");
    expect(runSession).not.toHaveBeenCalled();
  });

  it("emits only a generic CLI error when provider failure text is sensitive", async () => {
    const stdout = vi.fn();
    const stderr = vi.fn();
    const status = await runProductionMigration0017CLI({
      args: ["--execute"],
      environment: { [productionMigration0017Gate]: "1" },
      execute: vi.fn(async () => {
        throw new Error("CHILD_STDOUT_SECRET CHILD_STDERR_SECRET");
      }),
      writeStdout: stdout,
      writeStderr: stderr,
    });
    expect(status).toBe(1);
    expect(stdout).not.toHaveBeenCalled();
    expect(stderr).toHaveBeenCalledOnce();
    expect(stderr.mock.calls[0]?.[0]).not.toContain("CHILD_");
  });
});

function rawSource(
  source: Awaited<ReturnType<typeof loadProductionMigration0017Sources>>,
): ProductionMigration0017Source {
  return {
    schemaReadbackSQL: source.schemaReadbackSQL,
    cleanTargetReadbackSQL: source.cleanTargetReadbackSQL,
    ledgerReadbackSQL: source.ledgerReadbackSQL,
    deterministicSeedMigrationSQL: source.deterministicSeedMigrationSQL,
    migrationJournalJSON: source.migrationJournalJSON,
    migrationHistoryContractJSON: source.migrationHistoryContractJSON,
    previousMigrationSQL: source.previousMigrationSQL,
    targetMigrationSQL: source.targetMigrationSQL,
    targetSnapshotJSON: source.targetSnapshotJSON,
  };
}

function validReadback(
  operation: "applied" | "idempotent_retry" = "applied",
) {
  const cleanTargetInventory = Object.fromEntries(
    greenfieldCleanTargetTables.map((name) => [name, 0]),
  );
  cleanTargetInventory.identity_reconciliation_receipts = 1;
  cleanTargetInventory.identity_reconciliation_activations = 1;
  const timestamp = "2026-07-21T03:38:21.452Z";
  return {
    schema_version: 1,
    receipt_type: "refwatch_production_migration_0017",
    status: "validated_pending_commit",
    operation,
    provider_command: {
      command: "pscale",
      arguments: [...productionMigration0017Command.args],
      sql_transport: "stdin",
    },
    production_target: {
      organization: productionDatabase.organization,
      logical_database: productionDatabase.database,
      postgres_database: "postgres",
      branch: productionDatabase.branch,
      branch_id: productionDatabase.branchId,
      runtime_marker: productionDatabase.runtimeMarker,
      stable_role: "postgres",
    },
    source_contract: {
      schema_readback_path: reviewedSchema.providerQueryPath,
      schema_readback_sha256: reviewedSchema.providerQuerySha256,
      clean_target_readback_path: cleanTargetReadback.queryPath,
      clean_target_readback_sha256: cleanTargetReadback.querySha256,
      ledger_readback_path: ledgerReadback.queryPath,
      ledger_readback_sha256: ledgerReadback.querySha256,
      seed_migration_path: reviewedDeterministicSeed.migrationPath,
      seed_migration_sha256: reviewedDeterministicSeed.migrationSha256,
      migration_journal_path: productionMigration0017Contract.journalPath,
      migration_journal_sha256: productionMigration0017Contract.journalSha256,
      previous_migration: productionMigration0017Contract.previous.tag,
      previous_migration_sha256: productionMigration0017Contract.previous.fileSha256,
      previous_full_history_sha256:
        productionMigration0017Contract.previous.fullHistorySha256,
      target_migration: productionMigration0017Contract.target.tag,
      target_migration_sha256: productionMigration0017Contract.target.fileSha256,
      target_full_history_sha256:
        productionMigration0017Contract.target.fullHistorySha256,
      target_snapshot_path: reviewedSchema.repositorySnapshotPath,
      target_snapshot_sha256: reviewedSchema.repositorySnapshotSha256,
    },
    verified_state: {
      schema: schemaReadback(),
      migration_history: {
        migration_count: 18,
        head_id: 18,
        head_hash: productionMigration0017Contract.target.fileSha256,
        head_created_at: productionMigration0017Contract.target.journalTimestamp,
        history_md5: productionMigration0017Contract.target.migrationHistoryMd5,
        full_history_sha256:
          productionMigration0017Contract.target.fullHistorySha256,
      },
      migration_history_catalog: {
        table_owner: "postgres",
        sequence_owner: "postgres",
        columns: [
          {
            column_name: "id",
            ordinal_position: 1,
            data_type: "integer",
            not_null: true,
            default_expression:
              "nextval('drizzle.__drizzle_migrations_id_seq'::regclass)",
          },
          {
            column_name: "hash",
            ordinal_position: 2,
            data_type: "text",
            not_null: true,
            default_expression: null,
          },
          {
            column_name: "created_at",
            ordinal_position: 3,
            data_type: "bigint",
            not_null: false,
            default_expression: null,
          },
        ],
        primary_key: {
          constraint_name: "__drizzle_migrations_pkey",
          definition: "PRIMARY KEY (id)",
          key_attnums: [1],
        },
        serial_sequence: "drizzle.__drizzle_migrations_id_seq",
        owned_by_dependency: {
          dependency_type: "a",
          sequence_schema: "drizzle",
          sequence_name: "__drizzle_migrations_id_seq",
          table_schema: "drizzle",
          table_name: "__drizzle_migrations",
          column_name: "id",
        },
      },
      history_sequence: {
        data_type: "integer",
        start_value: 1,
        minimum_value: 1,
        maximum_value: 2_147_483_647,
        increment_by: 1,
        cache_size: 1,
        cycle: false,
        last_value: 19,
        is_called: false,
        next_value: 19,
      },
      target_column: {
        table_schema: "public",
        table_name: "app_users",
        column_name: "clerk_profile_updated_at",
        data_type: "timestamp with time zone",
        udt_schema: "pg_catalog",
        udt_name: "timestamptz",
        nullable: true,
        column_default: null,
        table_owner: "postgres",
      },
      deterministic_seed: {
        reference_competitions_count: 5,
        reference_competitions_business_md5:
          reviewedDeterministicSeed.referenceCompetitionsBusinessMd5,
        reference_teams_count: 54,
        reference_teams_business_md5:
          reviewedDeterministicSeed.referenceTeamsBusinessMd5,
        reference_disciplinary_codes_count: 0,
        reference_disciplinary_rules_count: 0,
        global_workout_presets_count: 0,
      },
      clean_target_inventory: cleanTargetInventory,
      ledger: {
        database_name: "postgres",
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
      id: "428de9fc-1e6d-44a5-85a6-cbc0d15b7008",
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

function schemaReadback() {
  return {
    database_name: "postgres",
    runtime_marker: productionDatabase.runtimeMarker,
    database_branch_id: productionDatabase.branchId,
    migration_count: reviewedSchema.migrationCount,
    migration_head_id: reviewedSchema.migrationHeadId,
    migration_head_hash: reviewedSchema.migrationHeadHash,
    migration_history_md5: reviewedSchema.migrationHistoryMd5,
    public_table_count: reviewedSchema.publicTableCount,
    public_table_names_md5: reviewedSchema.publicTableNamesMd5,
    public_table_properties_count: reviewedSchema.publicTablePropertiesCount,
    public_table_properties_md5: reviewedSchema.publicTablePropertiesMd5,
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
