# Worker service

Background worker for the Platform in a Box demo application. Consumes jobs from
a Redis list and exposes health, readiness and metrics endpoints.

## Endpoints

- `GET /` - service metadata and processed count
- `GET /health` - liveness probe
- `GET /ready` - readiness probe (checks Redis)
- `GET /metrics` - Prometheus metrics
- `GET /stats` - worker statistics

## Configuration

| Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | `postgresql+psycopg://app:app@localhost:5432/app` | Postgres connection string |
| `REDIS_URL` | `redis://localhost:6379/0` | Redis connection string |
| `JOB_QUEUE` | `platformbox:jobs` | Redis list used as the job queue |
| `POLL_INTERVAL_SECONDS` | `1.0` | Idle poll interval |
| `LOG_LEVEL` | `INFO` | Logging level |

## Local development

```bash
cd apps/worker
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
PYTHONPATH=src uvicorn main:app --reload --port 8001
```

## Tests

```bash
cd apps/worker
PYTHONPATH=src pytest -q
```

## Docker

```bash
docker build -t platformbox-worker:dev apps/worker
docker run --rm -p 8001:8001 platformbox-worker:dev
```
