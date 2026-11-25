"""Application configuration loaded from environment variables."""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime settings for the worker service."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    service_name: str = "platformbox-worker"
    service_version: str = "0.1.0"
    environment: str = "dev"
    log_level: str = "INFO"
    host: str = "0.0.0.0"
    port: int = 8001

    database_url: str = "postgresql+psycopg://app:app@localhost:5432/app"
    redis_url: str = "redis://localhost:6379/0"

    job_queue: str = "platformbox:jobs"
    poll_interval_seconds: float = 1.0


settings = Settings()
