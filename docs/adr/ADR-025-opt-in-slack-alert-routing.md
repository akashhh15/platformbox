# ADR-025: Opt-in Slack alert routing with a null fallback

- **Status:** Accepted
- **Date:** 2026-11-25
- **Deciders:** project owner and implementation agent

## Context

Alertmanager needs to send actionable alerts to Slack on a configured cluster,
but the local-first demo must work with no webhook and no AWS account. A Slack
webhook is a secret and must never be committed. The pinned Prometheus Operator
(part of kube-prometheus-stack 65.8.1) can generate Alertmanager configuration
from `AlertmanagerConfig` resources that reference a Secret in the same
namespace. By default it only applies an `AlertmanagerConfig` to alerts from
its own namespace; custom rules emit alerts from several namespaces.

## Decision

1. kube-prometheus-stack keeps its default configuration with a `null`
   receiver. This is the fallback on kind and on any cluster without Slack.
2. Prometheus Operator is configured with
   `alertmanagerConfigMatcherStrategy.type: None` so the Slack route sees
   alerts from all namespaces.
3. An ApplicationSet generates the Slack Application only for registered EKS
   cluster Secrets that carry both `platformbox.io/target: eks` and
   `platformbox.io/slack-alerting: "true"`. The local kind cluster has no such
   Secret and therefore receives no Slack resources.
4. The gated Application deploys an `ExternalSecret` named `alertmanager-slack`
   in `monitoring`, reading the JSON property `webhook_url` from the AWS
   Secrets Manager secret `platformbox/alertmanager`. The human creates that
   secret; no URL is stored in Git.
5. An `AlertmanagerConfig` in `monitoring` routes `critical` and `warning`
   alerts to Slack and references the webhook through the generated Secret.
   The operator requires the Secret key to exist, which is why this path is
   gated rather than always deployed.

## Alternatives considered

- **Commit an Alertmanager configuration with a placeholder webhook.** Rejected
  because `amtool check-config` correctly rejects an unresolved URL and a
  missing secret would break Alertmanager config generation on kind.
- **Use an optional Secret reference.** Rejected: Prometheus Operator 0.77.2
  does not treat a missing `apiURL` Secret as optional; it fails config
  generation.
- **Deploy Slack everywhere and rely on an empty channel.** Rejected because it
  makes the zero-cost local demo depend on a secret that does not exist.
- **Store the webhook in a Helm value.** Rejected because values would end up
  in Git or in an Application manifest.

## Consequences

- kind needs no Slack configuration and still has a valid Alertmanager config.
- Enabling Slack requires two explicit cluster labels and one AWS Secrets
  Manager entry, all documented in `docs/SETUP.md`.
- The Secret name and property are a documented contract. Changing them means
  editing the gated manifests, not the chart values.
- Alert routing is not exercised end to end offline; the gating and manifest
  shape are validated, while the real webhook remains a human task.
