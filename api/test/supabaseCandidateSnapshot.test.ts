import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { sourceTables } from "../scripts/cutover-bundle.mjs";

const sql = readFileSync(new URL("../scripts/supabase-candidate-snapshot.sql", import.meta.url), "utf8");

describe("Supabase candidate snapshot SQL", () => {
  it("pins one read-only repeatable-read candidate transaction", () => {
    expect(sql).toContain("BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;");
    expect(sql).toContain("SET LOCAL timezone = 'UTC';");
    expect(sql).toContain("SET LOCAL statement_timeout = '45s';");
    expect(sql).toContain("'status', 'candidate'");
    expect(sql).toContain("'final', false");
    expect(sql).toContain("'eligible_for_import', false");
    expect(sql).toContain("'writes_quiesced', false");
    expect(sql).toContain("'final_export_complete', false");
    expect(sql.trimEnd().endsWith("COMMIT;")).toBe(true);
  });

  it("uses the exact 39-table allowlist for catalog gating and row digests", () => {
    const expectedBlock = sql.slice(sql.indexOf("expected_tables(table_name)"), sql.indexOf("actual_tables AS"));
    const expectedTables = [...expectedBlock.matchAll(/\('([a-z_]+)'\)/g)].map((match) => match[1]);
    expect(expectedTables).toEqual(sourceTables);
    expect(new Set(expectedTables).size).toBe(39);

    for (const table of sourceTables) {
      expect(sql).toContain(`FROM public.${table} t`);
    }
    expect(sql).toContain("SELECT table_name FROM expected_tables\n        EXCEPT\n        SELECT table_name FROM actual_tables");
    expect(sql).toContain("SELECT table_name FROM actual_tables\n        EXCEPT\n        SELECT table_name FROM expected_tables");
    expect(sql).toContain("'catalog_guard', 1 / g.exact::int");
    expect(sql).not.toContain("WHERE exact");
  });

  it("hashes minimized auth fields without selecting credentials or metadata blobs", () => {
    for (const allowed of [
      "'id', id::text", "'email', lower(email)", "'provider', provider",
      "'provider_id', provider_id", "'deleted_at', deleted_at",
    ]) expect(sql).toContain(allowed);

    for (const forbidden of [
      "encrypted_password", "confirmation_token", "recovery_token",
      "email_change_token", "phone_change_token", "reauthentication_token",
      "raw_app_meta_data", "raw_user_meta_data", "identity_data",
    ]) expect(sql).not.toContain(forbidden);
    expect(sql).toContain("'auth_sensitive_fields_exported', false");
  });

  it("publishes only counts and digests, with schema and RLS contracts", () => {
    expect(sql).not.toMatch(/jsonb_agg\(to_jsonb\(t\)/);
    expect(sql).toContain("'public_data_contract_sha256'");
    expect(sql).toContain("'schema_contract_sha256'");
    expect(sql).toContain("'rls_contract_sha256'");
    expect(sql).toContain("'auth_user_ids_sha256'");
    expect(sql).toContain("'public_user_ids_sha256'");
    expect(sql).toContain("'rls_bypass_qualification'");
  });
});
