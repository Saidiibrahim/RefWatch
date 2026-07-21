import { readFile } from "node:fs/promises";
import { Pool } from "pg";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import {
  productionDatabase,
  reviewedSchema,
} from "../scripts/greenfield-launch-packet.mjs";

const databaseURL = validatedLocalDatabaseURL();
const pool = new Pool({ connectionString: databaseURL, max: 2 });
const localSourceSchema = {
  ...reviewedSchema,
  migrationCount: 18,
  migrationHeadId: 18,
  migrationHeadHash: "14b9c6beb831b76dbefee22f8eb592bd8ea72974f33a0aaed5570550e78f07f9",
  migrationHistoryMd5: "f2f3ddf416d58b2d9a60749e41af11f7",
  publicColumnCount: 383,
  publicColumnsMd5: "5fa4e25bcf19d7caf1f9adcfb4879344",
  catalogContractMd5: "99dca5e8c11b8ec23debfb7c698a74d7",
} as const;

beforeAll(async () => {
  await pool.query(
    `insert into runtime_database_markers (marker, branch_id, environment)
     values ($1, $2, 'production')
     on conflict (marker) do update
       set branch_id = excluded.branch_id,
           environment = excluded.environment`,
    [productionDatabase.runtimeMarker, productionDatabase.branchId],
  );
});

afterAll(async () => {
  await pool.end();
});

describe("greenfield provider schema readback against disposable local PostgreSQL", () => {
  it("matches the reviewed migration and complete public catalog contract", async () => {
    const query = await readFile(
      new URL("../scripts/greenfield-schema-readback.sql", import.meta.url),
      "utf8",
    );
    const result = await pool.query(query);
    const readback = result.rows[0]?.greenfield_schema_readback;

    expect(readback).toMatchObject({
      database_name: "refwatch_greenfield_integration",
      database_branch_id: productionDatabase.branchId,
      runtime_marker: productionDatabase.runtimeMarker,
      migration_count: localSourceSchema.migrationCount,
      migration_head_id: localSourceSchema.migrationHeadId,
      migration_head_hash: localSourceSchema.migrationHeadHash,
      migration_history_md5: localSourceSchema.migrationHistoryMd5,
      public_table_count: reviewedSchema.publicTableCount,
      public_table_names_md5: reviewedSchema.publicTableNamesMd5,
      public_table_properties_count:
        reviewedSchema.publicTablePropertiesCount,
      public_table_properties_md5: reviewedSchema.publicTablePropertiesMd5,
      public_column_count: localSourceSchema.publicColumnCount,
      public_columns_md5: localSourceSchema.publicColumnsMd5,
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
      catalog_contract_md5: localSourceSchema.catalogContractMd5,
    });
    expect(readback.observed_at_utc).toMatch(
      /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/,
    );
  });
});

function validatedLocalDatabaseURL(): string {
  if (process.env.REFWATCH_ALLOW_LOCAL_DATABASE_TESTS !== "1") {
    throw new Error("Local database integration tests require the explicit local-test gate");
  }
  const value = process.env.REFWATCH_LOCAL_DATABASE_URL;
  if (!value) throw new Error("REFWATCH_LOCAL_DATABASE_URL is required");
  const parsed = new URL(value);
  if (!["127.0.0.1", "localhost", "::1"].includes(parsed.hostname)) {
    throw new Error("Local database integration tests require a loopback database");
  }
  return value;
}
