import type { NodePgDatabase } from "drizzle-orm/node-postgres";
import type { Client } from "pg";
import type * as schema from "./db/schema";

export interface HyperdriveBinding {
  connectionString: string;
}

export interface WorkerVersionMetadataBinding {
  id: string;
  tag?: string;
  timestamp?: string;
}

export interface Env {
  CLERK_SECRET_KEY: string;
  CLERK_PUBLISHABLE_KEY: string;
  CLERK_JWT_KEY?: string;
  CLERK_WEBHOOK_SIGNING_SECRET: string;
  DATABASE_URL?: string;
  HYPERDRIVE?: HyperdriveBinding;
  CF_VERSION_METADATA?: WorkerVersionMetadataBinding;
  /// Server-only bounded cutover credential. Never ship this value in a client.
  CUTOVER_ACCEPTANCE_TOKEN?: string;
  MUTATION_LEDGER?: D1Database;
  MUTATION_LEDGER_QUEUE?: Queue<{ eventId: string; leaseGeneration: number }>;
  MUTATION_LEDGER_ENCRYPTION_KEY?: string;
  MUTATION_LEDGER_ENCRYPTION_KEY_ID?: string;
  MUTATION_LEDGER_DECRYPTION_KEYRING?: string;
  MUTATION_LEDGER_DLQ_NAME?: string;
  OPENAI_API_KEY: string;
  REFWATCH_ENV?: string;
  EXPECTED_DATABASE_MARKER?: string;
  EXPECTED_DATABASE_BRANCH_ID?: string;
  EXPECTED_DATABASE_ROLE_ID?: string;
  /// Emergency rollback control. Only the exact normalized value `enabled` permits
  /// API and webhook mutations; missing or unknown values fail closed.
  WRITE_MODE?: string;
  /// Deprecated compatibility flag. It never authorizes production user creation.
  ALLOW_UNMAPPED_CLERK_USERS?: string;
  /// Exact stateful or greenfield onboarding mode. Every other value fails closed.
  NEW_USER_ONBOARDING_MODE?: string;
  /// SHA-256 receipt selected by the exact reconciliation profile.
  IDENTITY_RECONCILIATION_RECEIPT?: string;
  /// Non-secret SHA-256 pin for the greenfield authorization decision.
  IDENTITY_RECONCILIATION_AUTHORIZATION_DIGEST?: string;
  /// Exact Clerk production instance bound to the reconciliation receipt.
  CLERK_INSTANCE_ID?: string;
  /// Exact verified JWT issuer for the selected Clerk instance, including scheme.
  CLERK_ISSUER?: string;
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
