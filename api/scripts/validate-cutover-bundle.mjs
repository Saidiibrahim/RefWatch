#!/usr/bin/env node

import { readFile } from "node:fs/promises";
import { validateCutoverBundle } from "./cutover-bundle.mjs";

const path = process.argv[2];
if (!path) {
  console.error("Usage: node scripts/validate-cutover-bundle.mjs <access-controlled-bundle.json>");
  process.exit(2);
}

const bundle = JSON.parse(await readFile(path, "utf8"));
const result = validateCutoverBundle(bundle);
console.log(JSON.stringify(result.summary, null, 2));
if (!result.ok) {
  for (const error of result.errors) console.error(`- ${error}`);
  process.exit(1);
}
console.log("Cutover bundle validation passed.");
