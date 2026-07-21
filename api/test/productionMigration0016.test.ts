import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import type {
  SpawnSyncOptionsWithStringEncoding,
  SpawnSyncReturns,
} from "node:child_process";
import { describe, expect, it, vi } from "vitest";
import {
  executeProductionMigration0016,
  loadProductionMigration0016Contract,
  productionMigration0016Contract,
  renderProductionMigration0016,
  validateProductionMigration0016Sources,
  type ProductionMigration0016Source,
} from "../scripts/apply-production-migration-0016.mjs";

const journalPath = fileURLToPath(
  new URL("../src/db/migrations/meta/_journal.json", import.meta.url),
);
const previousMigrationPath = fileURLToPath(
  new URL("../src/db/migrations/0015_bound_ledger_capture_envelope.sql", import.meta.url),
);
const targetMigrationPath = fileURLToPath(
  new URL("../src/db/migrations/0016_careless_steel_serpent.sql", import.meta.url),
);

async function source(): Promise<ProductionMigration0016Source> {
  const [journalText, previousMigrationSql, targetMigrationSql] =
    await Promise.all([
      readFile(journalPath, "utf8"),
      readFile(previousMigrationPath, "utf8"),
      readFile(targetMigrationPath, "utf8"),
    ]);
  return { journalText, previousMigrationSql, targetMigrationSql };
}

describe("production migration 0016 delivery helper", () => {
  it("pins the exact source digests and journal timestamp", async () => {
    const validated = await loadProductionMigration0016Contract();

    expect(validated).toMatchObject({
      journalSha256: productionMigration0016Contract.journalSha256,
      previousMigrationSha256:
        productionMigration0016Contract.previous.fileSha256,
      targetMigrationSha256:
        productionMigration0016Contract.target.fileSha256,
      targetJournalTimestamp:
        productionMigration0016Contract.target.journalTimestamp,
    });
  });

  it("renders one fail-closed psql transaction with verbatim migration SQL", async () => {
    const input = await source();
    const rendered = renderProductionMigration0016(input);

    expect(rendered.startsWith("\\set ON_ERROR_STOP on\nBEGIN;\n")).toBe(true);
    expect(rendered.endsWith("COMMIT;\n")).toBe(true);
    expect(rendered.match(/^BEGIN;$/gmu)).toHaveLength(1);
    expect(rendered.match(/^COMMIT;$/gmu)).toHaveLength(1);
    expect(rendered).toContain('SET LOCAL ROLE "postgres";');
    expect(rendered).toContain(
      "LOCK TABLE drizzle.__drizzle_migrations IN EXCLUSIVE MODE;",
    );
    expect(rendered).toContain(input.targetMigrationSql);
    expect(rendered).toContain(
      productionMigration0016Contract.previous.fileSha256,
    );
    expect(rendered).toContain(
      productionMigration0016Contract.target.fileSha256,
    );
    expect(rendered).toContain(
      String(productionMigration0016Contract.target.journalTimestamp),
    );
    expect(rendered).toContain(
      productionMigration0016Contract.target.migrationHistoryMd5,
    );
    expect(rendered).toContain(
      `INSERT INTO drizzle.__drizzle_migrations ("id", "hash", "created_at")`,
    );
    expect(rendered).toContain(
      `ALTER SEQUENCE "drizzle"."__drizzle_migrations_id_seq"\n  RESTART WITH 18;`,
    );
    expect(rendered).toContain(
      "production migration 0015 history sequence precondition failed",
    );
    expect(rendered).toContain(
      "production migration 0016 history sequence postcondition failed",
    );
    expect(rendered).toContain("production public object ownership postcondition failed");
  });

  it("rejects modified migration sources before rendering SQL", async () => {
    const input = await source();

    expect(() => validateProductionMigration0016Sources({
      ...input,
      targetMigrationSql: `${input.targetMigrationSql}\nselect 1;\n`,
    })).toThrow("Production migration 0016 source digest does not match");
    expect(() => validateProductionMigration0016Sources({
      ...input,
      previousMigrationSql: `${input.previousMigrationSql}\n`,
    })).toThrow("Production migration 0015 source digest does not match");
  });

  it("accepts the reviewed 0017 successor but rejects journal drift and later migrations", async () => {
    const input = await source();
    const timestampDrift = JSON.parse(input.journalText);
    timestampDrift.entries[16].when += 1;
    expect(() => validateProductionMigration0016Sources({
      ...input,
      journalText: JSON.stringify(timestampDrift),
    })).toThrow("Production migration journal source digest does not match");

    const successorDrift = JSON.parse(input.journalText);
    successorDrift.entries[17].when += 1;
    expect(() => validateProductionMigration0016Sources({
      ...input,
      journalText: JSON.stringify(successorDrift),
    })).toThrow("Production migration journal source digest does not match");

    const laterMigration = JSON.parse(input.journalText);
    laterMigration.entries.push({
      idx: 18,
      version: "7",
      when: productionMigration0016Contract.successor.journalTimestamp + 1,
      tag: "0018_unreviewed",
      breakpoints: true,
    });
    expect(() => validateProductionMigration0016Sources({
      ...input,
      journalText: JSON.stringify(laterMigration),
    })).toThrow("Production migration journal source digest does not match");
  });

  it("passes SQL only through stdin to fixed pscale production arguments", async () => {
    const spawn = vi.fn(() => successfulSpawnResult());

    await executeProductionMigration0016({ spawnSyncImpl: spawn });

    expect(spawn).toHaveBeenCalledOnce();
    const [command, args, options] = spawn.mock.calls.at(0) as unknown as [
      string,
      string[],
      SpawnSyncOptionsWithStringEncoding & { input: string },
    ];
    expect(command).toBe("pscale");
    expect(args).toEqual([
      "shell",
      "refwatch",
      "main",
      "--org",
      "ibrahim-aka-ajax",
      "--role",
      "admin",
      "--no-color",
    ]);
    expect(args.join(" ")).not.toContain(
      productionMigration0016Contract.target.fileSha256,
    );
    expect(options.input).toContain(
      productionMigration0016Contract.target.fileSha256,
    );
    expect(options.stdio).toEqual(["pipe", "pipe", "pipe"]);
    expect(options.env).toMatchObject({
      PSCALE_ALLOW_NONINTERACTIVE_SHELL: "1",
      PSQLRC: "/dev/null",
      PSQL_HISTORY: "/dev/null",
    });
  });

  it("does not disclose captured child output when execution fails", async () => {
    const spawn = vi.fn(() => ({
      ...successfulSpawnResult(),
      status: 1,
      stdout: "CHILD_STDOUT_CREDENTIAL_MARKER",
      stderr: "CHILD_STDERR_CREDENTIAL_MARKER",
    }));

    await expect(
      executeProductionMigration0016({ spawnSyncImpl: spawn }),
    ).rejects.toThrow("Production migration 0016 execution failed");
  });
});

function successfulSpawnResult(): SpawnSyncReturns<string> {
  return {
    pid: 1,
    output: [null, "", ""],
    stdout: "",
    stderr: "",
    status: 0,
    signal: null,
  };
}
