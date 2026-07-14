# Clerk Provider Status — 2026-07-14

Read back with the repository-mandated Stripe Projects CLI. No `.projects` or
environment file was inspected.

```sh
stripe projects status
stripe projects env
```

Sanitized results:

- Project: `refwatch`
- Project ID: `project_61V2218LBxf7Nz6b016TcwSJPC8S1spUXB9QI1HhwT8q`
- Clerk provider: linked
- Clerk service: `auth`, hobby/free
- Plan: `clerk-plan`, hobby/free
- Managed environment groups: `clerk-auth`, `clerk-plan`
- CLI confirmed all environment values were redacted

Secure `CLERK_ENVIRONMENTS` metadata readback confirmed a development instance
is present while production credentials are absent and `production_domain` is
null. No credential value was displayed or retained. The development keys were
installed as staging Worker secrets only. A production domain decision,
production instance/native-app configuration, and fresh managed-provider
readback remain required before identity import.

## Managed-Service Recheck

At `2026-07-14T07:21:09Z`, the repository-mandated Stripe Projects CLI was run
again with `llm-context`, JSON status, and redacted environment listing:

- the Clerk provider, `clerk-auth` service, and `clerk-plan` all remain
  `complete`;
- the managed service configuration still contains only `app_name: refwatch`,
  with no production-domain configuration;
- the environment command displayed names with values redacted; no credential
  value was printed, retained, or inspected.

The refreshed Clerk guidance confirms that production credentials are created
only after a `production_domain` is supplied. Provider linkage therefore
remains healthy, but it does not satisfy the production-instance, domain/DNS,
native-app, webhook, or identity-mapping gates.
