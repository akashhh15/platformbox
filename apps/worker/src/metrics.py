"""Prometheus metrics for the background worker."""

from prometheus_client import Counter, Gauge, Histogram

from config import settings

QUEUE_DEPTH = Gauge(
    "platformbox_worker_queue_depth",
    "Number of jobs waiting in the worker queue.",
    ["queue"],
)
JOBS_TOTAL = Counter(
    "platformbox_worker_jobs_total",
    "Number of worker jobs processed.",
    ["queue", "result"],
)
JOB_DURATION_SECONDS = Histogram(
    "platformbox_worker_job_duration_seconds",
    "Time spent processing a worker job.",
    ["queue"],
    buckets=(0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, 30),
)

# Register the configured queue up front so dashboards show zero values before
# the first successful Redis poll rather than showing no series at all.
QUEUE_DEPTH.labels(settings.job_queue).set(0)
JOBS_TOTAL.labels(settings.job_queue, "success").inc(0)
JOBS_TOTAL.labels(settings.job_queue, "invalid_json").inc(0)
JOB_DURATION_SECONDS.labels(settings.job_queue)
