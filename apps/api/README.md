# API service

FastAPI service for the Platform in a Box demo application.

## Endpoints

- `GET /` - service metadata
- `GET /health` - liveness probe
- `GET /ready` - readiness probe (checks Postgres and Redis)
- `GET /metrics` - Prometheus metrics
- `GET /items` - list items
- `POST /items` - create an item
- `GET /items/{id}` - fetch an item
- `POST /chaos/fail` - return HTTP 503 on demand when fault injection is enabled (404 otherwise)

## Configuration

All settings come from environment variables (see `src/config.py`):

| Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | `postgresql+psycopg://app:app@localhost:5432/app` | Postgres connection string |
| `REDIS_URL` | `redis://localhost:6379/0` | Redis connection string |
| `LOG_LEVEL` | `INFO` | Logging level |
| `SERVICE_NAME` | `platformbox-api` | Service name in logs |
| `ENVIRONMENT` | `dev` | Environment name |
| `FAULT_INJECTION_ENABLED` | `false` | Enable `POST /chaos/fail` for chaos experiments |

## Local development

```bash
cd apps/api
python -m venv .venv && source .venv/bin/activate  # or .venv\Scripts\activate on Windows
pip install -r requirements-dev.txt
PYTHONPATH=src uvicorn main:app --reload
```

## Tests

```bash
cd apps/api
PYTHONPATH=src pytest -q
```

## Docker

```bash
docker build -t platformbox-api:dev apps/api
docker run --rm -p 8000:8000 platformbox-api:dev
```
