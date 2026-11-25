# Saved Loki queries

**Purpose.** These LogQL queries are the starting points for the Phase 7 log
investigations. They are saved as documentation so they can be reviewed with
the manifests; Grafana's Loki datasource is installed with uid `loki` by
`gitops/platform/logging.yaml`.

**How to verify.** Start the platform with `make local-up`, deploy the apps with
`make local-smoke`, port-forward Grafana, open **Explore**, select the Loki
datasource, and paste a query. The labels and parsed fields below are produced
by the pinned Promtail pipeline in `gitops/platform/logging.yaml`; change the
query, not the application log format, if a field is missing.

## Structured fields

The API and worker configure `python-json-logger` with these static fields on
every JSON line:

| Field | Example | Source |
|---|---|---|
| `timestamp` | `2026-11-25T10:00:00Z` | renamed from `asctime` |
| `level` | `INFO`, `WARNING`, `ERROR` | renamed from `levelname` |
| `name` | `api.main` | Python logger name |
| `message` | `starting platformbox-api` | log message |
| `service` | `platformbox-api` | `settings.service_name` |
| `environment` | `dev` | `settings.environment` |
| `version` | `0.1.0` | `settings.service_version` |

Promtail parses the JSON line and promotes `level`, `service`, `environment`
and `version` to Loki labels. Kubernetes labels such as `namespace`, `app`,
`pod` and `container` come from the standard Promtail pipeline.

## API errors

Fastest query when most logs are structured JSON:

```logql
{namespace="app-dev", app="api", level="ERROR"}
```

Equivalent query that parses the line explicitly, useful when checking the
pipeline itself:

```logql
{namespace="app-dev", app="api"} |= "ERROR" | json | level = "ERROR"
```

Replace `app-dev` with `app-staging` or `app-prod` as needed.

## Worker failures

```logql
{namespace="app-dev", app="worker"} |= "ERROR" | json | level = "ERROR"
```

Invalid JSON jobs are logged as warnings by the worker loop:

```logql
{namespace="app-dev", app="worker"} |= "job is not valid JSON"
```

## Rollout events

Argo Rollouts controller logs are text, not JSON, so use a line filter rather
than assuming parsed fields:

```logql
{namespace="argo-rollouts"} |= "Aborted"
```

Successful promotions can be inspected with:

```logql
{namespace="argo-rollouts"} |= "promoted"
```

## Correlating a release version

Because `version` is promoted to a label, a regression can be scoped to one
image version:

```logql
{namespace=~"app-(dev|staging|prod)", app="api", version="0.1.0", level="ERROR"}
```

Use the API RED dashboard's version series and the `rollouts-pod-template-hash`
series to identify the version before running this query.
