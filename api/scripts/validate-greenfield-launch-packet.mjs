#!/usr/bin/env node

import { readFile } from "node:fs/promises";
import { validateGreenfieldLaunchPacket } from "./greenfield-launch-packet.mjs";

const [packetPath] = process.argv.slice(2);
if (!packetPath) {
  console.error(
    "Usage: node scripts/validate-greenfield-launch-packet.mjs <greenfield-launch-packet.json>",
  );
  process.exit(2);
}

let packet;
try {
  packet = JSON.parse(await readFile(packetPath, "utf8"));
} catch {
  console.error("Greenfield launch packet must be a readable JSON file");
  process.exit(2);
}

const result = validateGreenfieldLaunchPacket(packet);
if (!result.ok) {
  for (const error of result.errors) console.error(`- ${error}`);
  process.exit(1);
}
console.log(JSON.stringify(result.summary, null, 2));
console.log("Greenfield production launch packet validation passed.");
