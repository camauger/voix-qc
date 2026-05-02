"""Paramètres d'exécution chargés depuis l'environnement."""

from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configuration Voix (préfixe d'environnement VOIX_)."""

    model_config = SettingsConfigDict(
        env_prefix="VOIX_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    db_path: Path = Field(default=Path("./data/voix.db"))
    database_url: str | None = Field(
        default=None,
        description="URL Postgres (ex. Neon). Vide = SQLite via db_path.",
    )
    cache_dir: Path = Field(default=Path("./data/cache"))
    user_agent: str = Field(default="Voix.qc bot")
    rate_limit_seconds: float = Field(default=2.0)
    api_host: str = Field(default="127.0.0.1")
    api_port: int = Field(default=8080)
    public_api_base_url: str = Field(default="http://127.0.0.1:8080")


def get_settings() -> Settings:
    """Retourne les paramètres (pattern compatible injection/tests)."""
    return Settings()
