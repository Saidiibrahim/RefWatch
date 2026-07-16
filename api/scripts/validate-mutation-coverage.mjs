import { readFile, readdir } from "node:fs/promises";
import { join, relative } from "node:path";
import ts from "typescript";

const root = new URL("..", import.meta.url).pathname;
const schemaSource = await readFile(join(root, "src/db/schema.ts"), "utf8");
const migrationDirectory = join(root, "src/db/migrations");
const migrationFiles = (await readdir(migrationDirectory)).filter((name) => name.endsWith(".sql")).sort();
const migrationSource = (await Promise.all(migrationFiles.map((name) => readFile(join(migrationDirectory, name), "utf8")))).join("\n");

const schemaTables = new Set([...schemaSource.matchAll(/pgTable\("([a-z0-9_]+)"/g)].map((match) => match[1]));
const capturedTables = new Set([...migrationSource.matchAll(/CREATE TRIGGER [^\n]+_mutation_capture[^\n]+ ON ([a-z0-9_]+)/g)].map((match) => match[1]));
const expectedCapturedTables = new Set([
  "ai_attachments", "ai_messages", "ai_threads", "ai_usage_daily", "app_users",
  "clerk_user_deletion_tombstones", "competitions", "match_assessments", "match_events",
  "match_metrics", "match_periods", "matches", "pages", "scheduled_matches", "team_members",
  "team_officials", "team_tags", "teams", "user_devices", "venues", "workout_presets", "workout_sessions",
]);
const excludedTables = new Set([
  "identity_reconciliation_receipts",
  "identity_reconciliation_activations",
  "identity_reconciliation_legacy_mappings",
  "reference_competitions",
  "reference_teams",
  "reference_disciplinary_codes",
  "reference_disciplinary_rules",
  "idempotency_keys",
  "mutation_ledger_epochs",
  "mutation_entity_revisions",
  "mutation_outbox_events",
  "mutation_outbox_deliveries",
  "runtime_database_markers",
]);

const overlap = [...capturedTables].filter((table) => excludedTables.has(table));
const unclassified = [...schemaTables].filter((table) => !capturedTables.has(table) && !excludedTables.has(table));
const unknown = [...capturedTables, ...excludedTables].filter((table) => !schemaTables.has(table));
const missingCaptureTriggers = [...expectedCapturedTables].filter((table) => !capturedTables.has(table));
const unexpectedCaptureTriggers = [...capturedTables].filter((table) => !expectedCapturedTables.has(table));

const sourceFiles = await walk(join(root, "src"));
const discoveredWriters = [];
for (const file of sourceFiles.filter((name) => name.endsWith(".ts"))) {
  const source = await readFile(file, "utf8");
  if (/\.(?:insert|update|delete)\(/.test(source)) discoveredWriters.push(relative(root, file));
}
const includedWriters = new Set([
  "src/routes/library.ts",
  "src/routes/matchAssessments.ts",
  "src/routes/matches.ts",
  "src/routes/scheduledMatches.ts",
  "src/services/userOnboarding.ts",
  "src/webhooks/clerk.ts",
]);
const controlPlaneWriters = new Set([
  "src/services/mutationLedger.ts",
  "src/services/mutationLedgerDelivery.ts",
]);
const unclassifiedWriters = discoveredWriters.filter((file) => !includedWriters.has(file) && !controlPlaneWriters.has(file));
const missingWriters = [...includedWriters, ...controlPlaneWriters].filter((file) => !discoveredWriters.includes(file));

const wrapperFailures = [];
const transactionReceiverFailures = [];
for (const file of includedWriters) {
  const source = await readFile(join(root, file), "utf8");
  if (!source.includes("withMutation") && !source.includes("runMutation")) wrapperFailures.push(file);
  const sourceFile = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS);
  const visit = (node) => {
    const routeDelete = ts.isCallExpression(node) && ts.isPropertyAccessExpression(node.expression)
      && node.expression.name.text === "delete" && ts.isStringLiteralLike(node.arguments[0]);
    if (ts.isCallExpression(node) && ts.isPropertyAccessExpression(node.expression)
      && new Set(["insert", "update", "delete"]).has(node.expression.name.text)
      && !routeDelete && node.expression.expression.getText(sourceFile) !== "tx") {
      const position = sourceFile.getLineAndCharacterOfPosition(node.getStart(sourceFile));
      transactionReceiverFailures.push(`${file}:${position.line + 1}:${node.expression.expression.getText(sourceFile)}`);
    }
    ts.forEachChild(node, visit);
  };
  visit(sourceFile);
}

const errors = [
  overlap.length ? `captured/excluded table overlap: ${overlap.join(", ")}` : null,
  unclassified.length ? `unclassified schema tables: ${unclassified.join(", ")}` : null,
  unknown.length ? `unknown classified tables: ${unknown.join(", ")}` : null,
  missingCaptureTriggers.length ? `missing expected capture triggers: ${missingCaptureTriggers.join(", ")}` : null,
  unexpectedCaptureTriggers.length ? `unexpected capture triggers: ${unexpectedCaptureTriggers.join(", ")}` : null,
  unclassifiedWriters.length ? `unclassified writer files: ${unclassifiedWriters.join(", ")}` : null,
  missingWriters.length ? `classified files without DML: ${missingWriters.join(", ")}` : null,
  wrapperFailures.length ? `included writers without mutation wrapper: ${wrapperFailures.join(", ")}` : null,
  transactionReceiverFailures.length ? `included DML not issued through tx: ${transactionReceiverFailures.join(", ")}` : null,
].filter(Boolean);

const summary = {
  schema_tables: schemaTables.size,
  trigger_captured_tables: capturedTables.size,
  explicitly_excluded_tables: excludedTables.size,
  included_writer_files: includedWriters.size,
  control_plane_writer_files: controlPlaneWriters.size,
};
if (errors.length) {
  console.error(JSON.stringify({ ok: false, errors, summary }, null, 2));
  process.exitCode = 1;
} else {
  console.log(JSON.stringify({ ok: true, summary }, null, 2));
}

async function walk(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await walk(path));
    else files.push(path);
  }
  return files;
}
