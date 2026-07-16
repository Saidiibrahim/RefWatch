import { drizzle, type NodePgDatabase } from "drizzle-orm/node-postgres";
import { Client } from "pg";
import * as schema from "./schema";
import type { Env } from "../types";

export interface DatabaseConnection {
  client: Client;
  db: NodePgDatabase<typeof schema>;
  close(): Promise<void>;
}

export async function connectDatabase(env: Env): Promise<DatabaseConnection> {
  const pinnedEnvironment = env.REFWATCH_ENV === "rehearsal" || env.REFWATCH_ENV === "production";
  if (pinnedEnvironment && !env.HYPERDRIVE?.connectionString) {
    throw new Error(`${env.REFWATCH_ENV} database access requires Hyperdrive`);
  }
  const connectionString = env.HYPERDRIVE?.connectionString ?? env.DATABASE_URL;
  if (!connectionString) throw new Error("Missing HYPERDRIVE binding or DATABASE_URL");
  const client = new Client({ connectionString });
  await client.connect();
  if (pinnedEnvironment) await verifyPinnedDatabase(client, env);
  return {
    client,
    db: drizzle(client, { schema }),
    close: async () => client.end(),
  };
}

async function verifyPinnedDatabase(client: Client, env: Env): Promise<void> {
  const expectedMarker = env.EXPECTED_DATABASE_MARKER?.trim();
  const expectedBranchId = env.EXPECTED_DATABASE_BRANCH_ID?.trim();
  const expectedRoleId = env.EXPECTED_DATABASE_ROLE_ID?.trim();
  if (!expectedMarker || !expectedBranchId || !expectedRoleId || !env.REFWATCH_ENV) {
    throw new Error("Pinned database identity bindings are incomplete");
  }
  const result = await client.query<{
    marker: string;
    branch_id: string;
    environment: string;
    current_user: string;
  }>(`
    select marker.marker, marker.branch_id, marker.environment, current_user
    from runtime_database_markers marker
    where marker.marker = $1
  `, [expectedMarker]);
  const row = result.rows[0];
  if (!row || result.rowCount !== 1 || row.branch_id !== expectedBranchId || row.environment !== env.REFWATCH_ENV) {
    throw new Error("Database marker does not match the deployed environment");
  }
  if (row.current_user !== `pscale_api_${expectedRoleId}`) {
    throw new Error("Database role does not match the deployed environment");
  }
}
