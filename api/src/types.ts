import type { NodePgDatabase } from "drizzle-orm/node-postgres";
import type { Client } from "pg";
import type * as schema from "./db/schema";

export interface HyperdriveBinding {
  connectionString: string;
}

export interface Env {
  CLERK_SECRET_KEY: string;
  CLERK_PUBLISHABLE_KEY: string;
  CLERK_JWT_KEY?: string;
  CLERK_WEBHOOK_SIGNING_SECRET: string;
  DATABASE_URL?: string;
  HYPERDRIVE?: HyperdriveBinding;
  OPENAI_API_KEY: string;
  REFWATCH_ENV?: string;
  /// Emergency rollback control. A version uploaded with `disabled` rejects all
  /// API and webhook mutations while leaving health and authenticated reads available.
  WRITE_MODE?: string;
  /// Keep false through legacy identity reconciliation. Enable only after all existing
  /// Clerk subjects are mapped to their preserved app_users UUIDs.
  ALLOW_UNMAPPED_CLERK_USERS?: string;
}

export interface AuthenticatedIdentity {
  clerkUserId: string;
  appUserId: string;
  email?: string;
  displayName?: string;
}

export interface Variables {
  auth: AuthenticatedIdentity;
  db: NodePgDatabase<typeof schema>;
  dbClient: Client;
}
