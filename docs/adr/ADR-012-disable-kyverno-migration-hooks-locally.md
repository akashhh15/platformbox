# ADR-012: Disable Kyverno upgrade hooks in the local demo

- Status: Accepted
- Date: 2026-11-21

## Context

Kyverno chart 3.10.0 renders two Helm hooks that only matter during upgrades:

- `upgrade.legacyPolicyCheck` — checks for deprecated `kyverno.io` policies.
- `migration` — runs `kyverno-cli` to migrate old CRD versions after an upgrade.

Argo CD performs a `helm upgrade` on every Application sync, so both hooks run
even though `make local-up` always starts from an empty cluster. On this network
the migration hook stalled in `ContainerCreating` while pulling
`reg.kyverno.io/kyverno/kyverno-cli:v1.20.0`; Argo CD then reported the sync as
`Running | waiting for completion of hook batch/Job/kyverno-migrate-resources`.

Disabling only `legacyPolicyCheck` was insufficient — that is a different
hook. The correct chart value is `migration.enabled=false`.

## Decision

`gitops/platform/kyverno.yaml` sets both:

```yaml
upgrade:
  legacyPolicyCheck:
    enabled: false
migration:
  enabled: false
```

This is valid because the local cluster is disposable and contains only the
CEL `ValidatingPolicy` resources created by this repository. There are no old
CRD versions or legacy policies to migrate.

## Alternatives considered

- **Preload `kyverno-cli`** — fixes the pull on this machine but keeps a hook
  that does no useful work on every sync. Rejected.
- **Leave hooks enabled and wait** — makes local bootstrap depend on a slow
  registry and leaves Argo CD syncs stuck. Rejected.
- **Disable hooks only at runtime with `kubectl patch`** — would be reverted by
  self-heal and would not survive a fresh clone. Rejected.

## Consequences

- Argo CD no longer waits for a migration Job on a fresh local cluster.
- The hook images do not need to be preloaded by `scripts/preload-images.sh`.
- This setting is local-first only. If an existing cluster is upgraded from an
  older Kyverno release, re-enable `migration` explicitly, complete the
  migration, then disable it again.
