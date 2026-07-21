import type { Readable } from "node:stream";
import type { EventEmitter } from "node:events";
import type {
  ProductionClerkWebhookPreparationReceipt,
  ProductionClerkWebhookSecretCallbackInput,
} from "./prepare-production-clerk-webhook.mjs";
import type {
  ProductionGreenfieldWorkerLineageReceipt,
  ProductionGreenfieldWorkerLineageSecretMaterial,
} from "./prepare-production-greenfield-worker-lineage.mjs";

export type ProductionGreenfieldCutoverSanitizedReceipt = Readonly<
  Record<string, unknown>
>;

export interface ProductionGreenfieldCutoverReview {
  role: "code_operational_risk" | "docs_evidence_consistency";
  verdict: "NO FINDINGS";
  artifact_sha256: string;
  reviewed_at_utc: string;
}

export interface ProductionGreenfieldCutoverReviewQuorum {
  action: "continue";
  checkpoint_sha256: string;
  reviews: readonly ProductionGreenfieldCutoverReview[];
}

export interface ProductionGreenfieldCutoverProviderGuardReceipt {
  schema_version: 1;
  receipt_type: "refwatch_production_greenfield_cutover_provider_guard";
  status: "passed";
  observed_at_utc: string;
  checkpoint_sha256: string;
  clerk_webhook_preparation_receipt_sha256: string;
  worker_lineage_receipt_sha256: string;
  clerk_guard: Readonly<{
    observed_at_utc: string;
    clerk_application_id: string;
    clerk_instance_id: string;
    user_count: 0;
    svix_application_id: string;
    endpoint_inventory_count: 1;
    endpoint_id: string;
    endpoint_uid: string;
    endpoint_url: string;
    endpoint_description: "RefWatch production Clerk lifecycle";
    event_types: readonly string[];
    disabled: true;
    header_count: 0;
    sensitive_header_name_count: 0;
    transformation_enabled: false;
    transformation_present: false;
  }>;
  worker_guard: Readonly<{
    observed_at_utc: string;
    deployment_id: string;
    sole_worker_version_id: string;
    deployment_version_count: 1;
    sole_traffic_percentage: 100;
    secret_names: readonly string[];
    secret_count: 6;
    route_mutation_count: 0;
    access_mutation_count: 0;
  }>;
  receipt_sha256: string;
}

export interface ProductionGreenfieldCutoverContinuationInput {
  checkpoint: ProductionGreenfieldCutoverSanitizedReceipt;
  clerkWebhookPreparationReceipt: ProductionClerkWebhookPreparationReceipt;
  workerLineageReceipt: ProductionGreenfieldWorkerLineageReceipt;
  reviewQuorum: ProductionGreenfieldCutoverReviewQuorum;
  providerGuard: ProductionGreenfieldCutoverProviderGuardReceipt;
  secretMaterial: ProductionGreenfieldWorkerLineageSecretMaterial;
  signal: AbortSignal;
}

export interface ProductionGreenfieldCutoverProviderGuardInput {
  checkpoint: ProductionGreenfieldCutoverSanitizedReceipt;
  clerkWebhookPreparationReceipt: ProductionClerkWebhookPreparationReceipt;
  workerLineageReceipt: ProductionGreenfieldWorkerLineageReceipt;
  reviewQuorum: ProductionGreenfieldCutoverReviewQuorum;
  signal: AbortSignal;
}

export const productionGreenfieldCutoverGate: string;
export const productionGreenfieldCutoverCrashClassification: Readonly<{
  phase: "post_lineage_before_bounded_acceptance";
  resumability: "non_resumable";
  required_recovery: "reviewed_relineage_with_new_cutover_token";
  reason: "memory_only_cutover_token_is_not_provider_readable";
}>;

export function normalizeProductionGreenfieldWorkerLineageSource(
  value: string | NodeJS.ArrayBufferView,
): Buffer;

export function validateProductionGreenfieldCutoverLineageSources(value: {
  helper: string | NodeJS.ArrayBufferView;
  declaration: string | NodeJS.ArrayBufferView;
}): Readonly<{
  normalizedHelperSha256: string;
  declarationSha256: string;
}>;

export function loadProductionGreenfieldCutoverSources(): Promise<Readonly<{
  orchestrator_sha256: string;
  declaration_sha256: string;
  clerk_helper_sha256: string;
  clerk_helper_declaration_sha256: string;
  worker_lineage_helper_sha256: string;
  worker_lineage_helper_normalized_sha256: string;
  worker_lineage_helper_declaration_sha256: string;
  clerk_lock_contract_sha256: string;
  clerk_launch_packet_sha256: string;
  worker_lineage_manifest_sha256: string;
  worker_lineage_manifest_file_count: number;
  source_contract_sha256: string;
}>>;

export function generateProductionGreenfieldCutoverToken(options?: {
  randomBytes?: (size: number) => Buffer;
}): Buffer;

export function executeProductionGreenfieldCutover<T>(options?: {
  environment?: NodeJS.ProcessEnv;
  input?: Readable | AsyncIterable<Uint8Array | string>;
  loadSources?: () => Promise<Readonly<Record<string, unknown>>>;
  withClerkWebhookSecret?: <R>(
    consumer: (
      input: ProductionClerkWebhookSecretCallbackInput,
    ) => Promise<R> | R,
    options?: { environment?: NodeJS.ProcessEnv },
  ) => Promise<R>;
  withLineageLease?: <R>(
    consumer: (execute: (options: {
      clerkWebhookPreparationReceipt: ProductionClerkWebhookPreparationReceipt;
      secretMaterial: ProductionGreenfieldWorkerLineageSecretMaterial;
      signal?: AbortSignal;
    }) => Promise<ProductionGreenfieldWorkerLineageReceipt>) => Promise<R> | R,
    options?: { environment?: NodeJS.ProcessEnv },
  ) => Promise<R>;
  emitCheckpoint?: (value: string) => Promise<unknown> | unknown;
  recheckProviderGuards?: (
    input: ProductionGreenfieldCutoverProviderGuardInput,
  ) => Promise<ProductionGreenfieldCutoverProviderGuardReceipt>;
  continueCutover?: (
    input: ProductionGreenfieldCutoverContinuationInput,
  ) => Promise<T>;
  randomBytes?: (size: number) => Buffer;
  now?: () => Date | string | number;
  signalSource?: Pick<EventEmitter, "on" | "off">;
}): Promise<T>;

export function readProductionGreenfieldCutoverReviewQuorum(
  input: AsyncIterable<Uint8Array | string>,
  checkpoint: ProductionGreenfieldCutoverSanitizedReceipt,
  options?: { signal?: AbortSignal },
): Promise<Readonly<ProductionGreenfieldCutoverReviewQuorum>>;

export function runProductionGreenfieldCutoverCLI(options?: {
  args?: readonly string[];
  environment?: NodeJS.ProcessEnv;
  input?: Readable;
  writeStdout?: (value: string) => unknown;
  writeStderr?: (value: string) => unknown;
  checkSources?: () => Promise<unknown>;
  execute?: () => Promise<unknown>;
}): Promise<number>;
