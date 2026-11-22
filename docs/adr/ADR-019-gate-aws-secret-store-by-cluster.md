# ADR-019: Gate the AWS secret store by target cluster

- **Status:** Accepted
- **Date:** 2026-11-22
- **Deciders:** project owner and implementation agent

## Context

The AWS application overlays reference a `ClusterSecretStore` named
`aws-secretsmanager`. PR #10 added that store to the root `platform`
Kustomization so it would exist on EKS. The store authenticates through IRSA
using the ESO chart's `external-secrets` ServiceAccount. On the local `kind`
cluster there is no IRSA role annotation, so ESO reports
`InvalidProviderConfig` and the root Application becomes `Degraded`. That
breaks the local-first, zero-cost promise: a clean `make local-up` must end with
every Application `Synced`/`Healthy` without a human supplying AWS values.

ADR-015 already solves the same problem for environment Applications with a
cluster generator selector on `platformbox.io/target: eks`. The secret store
needs the same treatment.

## Decision

Move the store into its own Kustomization at
`gitops/platform/aws-secrets-store` and generate its Application with an
`ApplicationSet` whose cluster generator selects only clusters labelled
`platformbox.io/target: eks`. Remove the store from the root `platform`
Kustomization and add the new ApplicationSet instead. The local kind cluster
has no matching label, so no Application and no `ClusterSecretStore` are
created locally. On EKS, a human annotates the ESO ServiceAccount with the
Terraform IRSA role ARN before enabling the store.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| Leave the store in the root Kustomization and annotate a fake IRSA role locally | Still produces an invalid store; adds an AWS-shaped fake to the local demo |
| Add a Kustomize patch in the local overlay to delete the store | Deletes only the object, not the failed Application health; more fragile than not generating it |
| Configure a fake provider for the `aws-secretsmanager` name | ADR-016 already provides a separate local store; two stores with the same purpose is confusing |

## Consequences

- `make local-up` again ends with all Applications `Synced`/`Healthy`; the root
  Application no longer carries an AWS-only dependency.
- On EKS the store is installed automatically for every cluster labelled
  `platformbox.io/target: eks`, with no manual Kustomize edit.
- The store remains visible in Git and passes static validation; no secret
  value or role ARN is committed.
- Registering the EKS cluster and annotating the ESO ServiceAccount remain
  human tasks documented in `docs/SETUP.md`.
