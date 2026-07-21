import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { afterEach, describe, expect, it } from "vitest";

const rollbackCli = fileURLToPath(
  new URL("../scripts/validate-rollback-packet.mjs", import.meta.url),
);
const greenfieldCli = fileURLToPath(
  new URL("../scripts/validate-greenfield-launch-packet.mjs", import.meta.url),
);
const temporaryDirectories: string[] = [];

function temporaryPacket(name: string, contents: string) {
  const directory = mkdtempSync(join(tmpdir(), "refwatch-validator-cli-"));
  temporaryDirectories.push(directory);
  const path = join(directory, name);
  writeFileSync(path, contents, { mode: 0o600 });
  return path;
}

function missingTemporaryPacket(name: string) {
  const directory = mkdtempSync(join(tmpdir(), "refwatch-validator-cli-"));
  temporaryDirectories.push(directory);
  return join(directory, name);
}

function runValidator(script: string, packetPath: string) {
  return spawnSync(process.execPath, [script, packetPath], {
    encoding: "utf8",
  });
}

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

describe("packet validator CLIs", () => {
  it("reports rollback JSON read/parse failures without echoing input or paths", () => {
    const packetPath = temporaryPacket(
      "rollback-secret-marker.json",
      '{"secret_marker":"ROLLBACK_SECRET_MARKER"',
    );
    const result = runValidator(rollbackCli, packetPath);

    expect(result.status).toBe(2);
    expect(result.stdout).toBe("");
    expect(result.stderr).toBe("Rollback packet must be a readable JSON file\n");
    expect(result.stderr).not.toContain("ROLLBACK_SECRET_MARKER");
    expect(result.stderr).not.toContain(packetPath);
  });

  it("reports rollback read failures without echoing the requested path", () => {
    const packetPath = missingTemporaryPacket("ROLLBACK_PATH_MARKER.json");
    const result = runValidator(rollbackCli, packetPath);

    expect(result.status).toBe(2);
    expect(result.stdout).toBe("");
    expect(result.stderr).toBe("Rollback packet must be a readable JSON file\n");
    expect(result.stderr).not.toContain("ROLLBACK_PATH_MARKER");
    expect(result.stderr).not.toContain(packetPath);
  });

  it("does not print unvalidated greenfield summary values on validation failure", () => {
    const packetPath = temporaryPacket(
      "greenfield-invalid.json",
      JSON.stringify({
        owner: "GREENFIELD_OWNER_MARKER",
        clerk: { instance_id: "GREENFIELD_INSTANCE_MARKER" },
        worker: { name: "GREENFIELD_WORKER_MARKER" },
      }),
    );
    const result = runValidator(greenfieldCli, packetPath);

    expect(result.status).toBe(1);
    expect(result.stdout).toBe("");
    expect(result.stderr).toContain("- schema_version must be 3");
    expect(result.stderr).not.toContain("GREENFIELD_OWNER_MARKER");
    expect(result.stderr).not.toContain("GREENFIELD_INSTANCE_MARKER");
    expect(result.stderr).not.toContain("GREENFIELD_WORKER_MARKER");
  });

  it("does not echo an invalid Worker-binding value from a greenfield packet", () => {
    const marker = "SENSITIVE_WORKER_BINDING_VALUE_MARKER";
    const packetPath = temporaryPacket(
      "greenfield-binding-marker.json",
      JSON.stringify({
        schema_version: 3,
        launch_profile: "greenfield_launch_v3",
        worker: {
          versions: {
            candidate_sanitized_readback: {
              resources: {
                bindings: [{ name: "UNKNOWN", type: marker }],
              },
            },
          },
        },
      }),
    );
    const result = runValidator(greenfieldCli, packetPath);

    expect(result.status).toBe(1);
    expect(result.stdout).toBe("");
    expect(result.stderr).toContain(
      "bindings are not a safe sanitized provider readback",
    );
    expect(result.stderr).not.toContain(marker);
  });
});
