"""Application configuration loaded from environment variables."""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime settings for the API service."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    service_name: str = "platformbox-api"
    environment: str = "dev"
    log_level: str = "INFO"
    host: str = "0.0.0.0"
    port: int = 8000

    database_url: str = "postgresql+psycopg://app:app@localhost:5432/app"
    redis_url: str = "redis://localhost:6379/0"

    # Readiness probe timeouts.
    db_timeout_seconds: float = 2.0
    redis_timeout_seconds: float = 2.0


settings = Settings()
