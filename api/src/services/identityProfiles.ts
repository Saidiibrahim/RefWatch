export const STATEFUL_RECONCILIATION_PROFILE = "stateful_migration_v1" as const;
export const GREENFIELD_RECONCILIATION_PROFILE = "greenfield_zero_legacy_v1" as const;

export const POST_RECONCILIATION_ONBOARDING_MODE = "post_reconciliation" as const;
export const GREENFIELD_ONBOARDING_MODE = "greenfield_bootstrap" as const;

export const GREENFIELD_AUTHORIZATION_PROFILE = "refwatch.greenfield-authorization.v1" as const;
export const GREENFIELD_AUTHORIZATION_DIGEST =
  "17e08fcf1fc61580c15f8957fcba5fc2ceb339df8332d8a937e0aa201ef65b9b" as const;
export const GREENFIELD_RECONCILIATION_RECEIPT_DIGEST =
  "27406b8d851d38a0e2bb79aa2176e45d2b085ba3c5e2c0b2a0e366cdaf0ddf18" as const;
export const EMPTY_IDENTITY_MAPPING_HASH =
  "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945" as const;

export const PRODUCTION_CLERK_INSTANCE_ID = "ins_3GWFGUd1rI6hx5lWlUxMYAkxdac" as const;
export const PRODUCTION_CLERK_ISSUER = "https://clerk.refwatch.ibby.ai" as const;
export const PRODUCTION_CLERK_DOMAIN = "refwatch.ibby.ai" as const;

export type ReconciliationProfile =
  | typeof STATEFUL_RECONCILIATION_PROFILE
  | typeof GREENFIELD_RECONCILIATION_PROFILE;

export type OnboardingMode =
  | typeof POST_RECONCILIATION_ONBOARDING_MODE
  | typeof GREENFIELD_ONBOARDING_MODE;

export function isExactProvenanceOnboardingMode(value: string | undefined): value is OnboardingMode {
  const normalized = value?.trim().toLowerCase();
  return normalized === POST_RECONCILIATION_ONBOARDING_MODE
    || normalized === GREENFIELD_ONBOARDING_MODE;
}

export const GREENFIELD_RECONCILIATION_CANONICAL_PAYLOAD = JSON.stringify({
  reconciliation_profile: GREENFIELD_RECONCILIATION_PROFILE,
  authorization_profile: GREENFIELD_AUTHORIZATION_PROFILE,
  authorization_digest: GREENFIELD_AUTHORIZATION_DIGEST,
  clerk_instance_id: PRODUCTION_CLERK_INSTANCE_ID,
  clerk_issuer: PRODUCTION_CLERK_ISSUER,
  clerk_domain: PRODUCTION_CLERK_DOMAIN,
  legacy_mapping_count: 0,
  excluded_auth_count: 0,
  mapping_hash: EMPTY_IDENTITY_MAPPING_HASH,
});

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
