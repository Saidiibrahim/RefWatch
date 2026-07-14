import { readFile } from "node:fs/promises";
import { validateRollbackPacket } from "./rollback-packet.mjs";

const path = process.argv[2];
if (!path) {
  console.error("Usage: npm run rollback:validate -- <packet.json>");
  process.exit(2);
}

const packet = JSON.parse(await readFile(path, "utf8"));
const result = validateRollbackPacket(packet);
if (!result.ok) {
  for (const error of result.errors) console.error(`- ${error}`);
  process.exit(1);
}
console.log(JSON.stringify(result.summary, null, 2));
