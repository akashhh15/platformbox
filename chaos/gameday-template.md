# Game day template

Copy this file for each exercise and keep the completed copy with the incident
or test evidence. Every field must be filled before the exercise starts;
observed values stay `TODO(measure)` until a human runs it.

## Exercise

- **Name:** `Game day 01 — API pod kill`
- **Date:** `TODO(measure)`
- **Operator:** `TODO(measure)`
- **Environment:** `app-dev` on `kind` (or an explicitly labelled dev EKS cluster)
- **Blast radius:** one API pod selected by `app.kubernetes.io/name: api`
- **Abort command:** `kubectl delete podchaos api-pod-kill-dev -n app-dev`

## Hypothesis

Killing one API pod does not breach the API SLO. The `api` PDB with
`maxUnavailable: 1` permits the eviction, the ReplicaSet creates a replacement,
and the service continues to answer requests.

## Steady state (before injection)

Record all four values before injecting the fault.

| Signal | Query or command | Expected | Observed |
|---|---|---|---|
| API availability, 5m | `api_availability_ratio_5m` (recording rule) | >= 0.995 | `TODO(measure)` |
| API p95, 5m | `api_latency_p95_5m` (recording rule) | <= 500 ms | `TODO(measure)` |
| Ready API pods | `kubectl -n app-dev get rollout api` | 4/4 ready | `TODO(measure)` |
| PDB allowed disruptions | `kubectl -n app-dev describe pdb api` | `DISRUPTIONS` 0 at rest | `TODO(measure)` |

## Injection

```bash
kubectl apply -f chaos/experiments/api-pod-kill.yaml
kubectl -n app-dev get pods -l app.kubernetes.io/name=api --watch
```

`pod-kill` is one-shot. Do not add a `duration`; Chaos Mesh ignores it for this
action.

## Expected behaviour

- One API pod terminates and the ReplicaSet starts a replacement.
- PDB ensures no second voluntary eviction while the first pod is unavailable.
- No `PlatformBoxApiAvailabilityFastBurn` alert fires.
- After replacement, all four replicas are ready and the SLO ratios recover.

## Observed behaviour

- **Time to detection:** `TODO(measure)`
- **Time to replacement pod Ready:** `TODO(measure)`
- **Minimum availability ratio during exercise:** `TODO(measure)`
- **Alerts fired:** `TODO(measure)`
- **Unexpected effects:** `TODO(measure)`

## Outcome

- **Hypothesis confirmed?** `TODO(measure)`
- **SLO breached?** `TODO(measure)`
- **Evidence links or screenshot paths:** `TODO(measure)`

## Fixes and follow-ups

- `TODO(measure):` record any configuration change required.
- `TODO(measure):` link the issue for each follow-up.
- `TODO(measure):` state whether the next run repeats this exercise unchanged.
