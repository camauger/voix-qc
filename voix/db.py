"""Connexion BD et migrations — SQLite par défaut ; Postgres Neon en prod."""

from pathlib import Path

from voix.config import Settings


def ensure_sqlite_path(path: Path) -> None:
    """Crée le répertoire parent si la BD est un fichier local."""
    path.parent.mkdir(parents=True, exist_ok=True)


def resolve_backend(settings: Settings) -> str:
    """Indique le backend actif ('postgres' ou 'sqlite') pour logs/tests."""
    if settings.database_url:
        return "postgres"
    return "sqlite"
