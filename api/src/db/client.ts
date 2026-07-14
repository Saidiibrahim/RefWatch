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
  const connectionString = env.HYPERDRIVE?.connectionString ?? env.DATABASE_URL;
  if (!connectionString) throw new Error("Missing HYPERDRIVE binding or DATABASE_URL");
  const client = new Client({ connectionString });
  await client.connect();
  return {
    client,
    db: drizzle(client, { schema }),
    close: async () => client.end(),
  };
}
