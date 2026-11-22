# ADR-009: CEL-based Kyverno policies

- **Status:** Accepted
- **Date:** 2026-11-21
- **Deciders:** project owner and implementation agent

## Context

The platform uses Kyverno to enforce pod standards in the `app-*` namespaces.
The first draft used the familiar `kyverno.io/v1` `ClusterPolicy` resources with
`validate.pattern` rules. Two facts forced a change:

1. The pinned Kyverno CLI is 1.20.0. That release removed *execution* of the
   legacy `kyverno.io/v1` policy types: `kyverno apply` rejects them with an
   explicit migration error pointing at the CEL policy types.
2. Verified command output:
   `kyverno apply gitops/platform/kyverno-policies/` failed with
   "Kyverno v1.20 removed execution of legacy kyverno.io policy types"; after
   rewriting the same five rules as `ValidatingPolicy`, the same CLI reported
   `pass: 5, fail: 0, warn: 0, error: 0, skip: 0` against the sample pod.

A policy that cannot be tested locally would leave `make check` green by
accident, so the policy API must match the pinned toolchain.

## Decision

Write all admission policies as `policies.kyverno.io/v1` `ValidatingPolicy`
resources with CEL expressions, matching Kyverno 1.20+. Use
`validationActions: ["Deny"]` for the rules we want to enforce and keep the
namespace scope in `matchConditions` so platform namespaces are unaffected.

The policies are validated offline in `make gitops-validate` with
`kyverno apply ... -r apps/api/tests/fixtures/sample-pod.yaml`. That command is
a hard gate: no `|| true`.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| Keep `ClusterPolicy` and pin an older Kyverno CLI (1.13.x) | The old CLI download is large and repeatedly timed out on this network; it would also pin us to a deprecated policy API. |
| Keep `ClusterPolicy` and skip local policy validation | Violates "verify, don't guess" and would hide policy regressions. |
| Use OPA/Gatekeeper instead | Adds another admission controller and a second policy language; Kyverno is already the fixed decision in `AGENTS.md`. |

## Consequences

- Policy tests run with the same CLI version that matches the platform chart.
- CEL expressions are more verbose than `validate.pattern`, but they are typed,
  reviewable and checked before they reach the cluster.
- Kubeconform has no schema for `ValidatingPolicy`, so
  `make gitops-validate` skips that kind explicitly; Kyverno's own parser is the
  authoritative check for those resources.
- A future Kyverno major upgrade must re-run the policy tests before the chart
  version is bumped in `docs/VERSIONS.md`.

## References

- https://kyverno.io/docs/migration/migrating-from-validate-to-validatingpolicies/
- https://kyverno.io/docs/writing-policies/validate-cel/
- `gitops/platform/kyverno-policies/`
- `docs/VERSIONS.md`
