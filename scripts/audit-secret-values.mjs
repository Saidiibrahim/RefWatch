#!/usr/bin/env node

import { lstat, readFile, readdir } from "node:fs/promises";
import path from "node:path";

const excludedNames = new Set([".git", ".projects", "node_modules", ".env", ".dev.vars"]);
const explicitEnvironmentNames = [
  "OPENAI_API_KEY",
  "DATABASE_URL",
  "PLANETSCALE_DATABASE_URL",
  "CLERK_SECRET_KEY",
  "CLERK_JWT_KEY",
  "CLERK_WEBHOOK_SIGNING_SECRET",
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "SUPABASE_SERVICE_ROLE_KEY",
];

const fingerprints = new Map();
for (const name of explicitEnvironmentNames) {
  const value = process.env[name];
  if (value && value.length >= 8) fingerprints.set(name, Buffer.from(value));
}

function collectClerkSecrets(value, trail = "CLERK_ENVIRONMENTS") {
  if (Array.isArray(value)) {
    value.forEach((item, index) => collectClerkSecrets(item, `${trail}.${index}`));
    return;
  }
  if (!value || typeof value !== "object") return;
  for (const [key, item] of Object.entries(value)) {
    const nextTrail = `${trail}.${key}`;
    if (typeof item === "string" && /(secret|jwt|webhook)/i.test(key) && item.length >= 8) {
      fingerprints.set(nextTrail, Buffer.from(item));
    } else {
      collectClerkSecrets(item, nextTrail);
    }
  }
}

if (process.env.CLERK_ENVIRONMENTS) {
  try {
    collectClerkSecrets(JSON.parse(process.env.CLERK_ENVIRONMENTS));
  } catch {
    console.error("CLERK_ENVIRONMENTS is present but invalid JSON");
    process.exitCode = 2;
  }
}

const hits = [];
let filesScanned = 0;
let buildSucceeded;

function scanBuffer(buffer, label) {
  filesScanned += 1;
  for (const [name, fingerprint] of fingerprints) {
    if (buffer.includes(fingerprint)) hits.push({ name, path: label });
  }
}

async function scanPath(target, displayRoot = target) {
  const stat = await lstat(target);
  if (stat.isSymbolicLink()) return;
  if (stat.isDirectory()) {
    for (const entry of await readdir(target, { withFileTypes: true })) {
      if (excludedNames.has(entry.name)) continue;
      await scanPath(path.join(target, entry.name), displayRoot);
    }
    return;
  }
  if (!stat.isFile()) return;
  scanBuffer(await readFile(target), path.relative(displayRoot, target) || path.basename(target));
}

const args = process.argv.slice(2);
if (args[0] === "--stdin") {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  const input = Buffer.concat(chunks);
  scanBuffer(input, args[1] ?? "stdin");
  if (args[1] === "xcodebuild-log") {
    buildSucceeded = input.includes(Buffer.from("** BUILD SUCCEEDED **"))
      || input.includes(Buffer.from("** TEST BUILD SUCCEEDED **"));
    if (!buildSucceeded) process.exitCode = 1;
  }
} else {
  const targets = args.length ? args : ["."];
  for (const target of targets) await scanPath(path.resolve(target));
}

console.log(JSON.stringify({ fingerprintsLoaded: fingerprints.size, filesScanned, hits, ...(buildSucceeded === undefined ? {} : { buildSucceeded }) }, null, 2));
if (hits.length) process.exitCode = 1;
