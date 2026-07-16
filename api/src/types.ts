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
  /// Emergency rollback control. A version uploaded with `disabled` rejects all
  /// API and webhook mutations while leaving health and authenticated reads available.
  WRITE_MODE?: string;
  /// Keep false through legacy identity reconciliation. Enable only after all existing
  /// Clerk subjects are mapped to their preserved app_users UUIDs. Deprecated: this
  /// flag never authorizes production user creation.
  ALLOW_UNMAPPED_CLERK_USERS?: string;
  /// Exact post-cutover mode. New app-user creation remains closed for every other value.
  NEW_USER_ONBOARDING_MODE?: string;
  /// SHA-256 receipt emitted by the reviewed final cutover bundle and inserted into
  /// identity_reconciliation_receipts only after the legacy mapping import succeeds.
  IDENTITY_RECONCILIATION_RECEIPT?: string;
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
