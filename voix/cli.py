"""Interface en ligne de commande Voix.qc."""

from __future__ import annotations

import typer

from voix import __version__
from voix.config import get_settings
from voix.db import ensure_sqlite_path

app = typer.Typer(no_args_is_help=True, help="Voix.qc — pipeline et API.")


@app.command()
def version() -> None:
    """Affiche la version du paquet."""
    typer.echo(__version__)


@app.command()
def serve(
    host: str | None = typer.Option(None, help="Hôte (défaut: config)."),
    port: int | None = typer.Option(None, help="Port (défaut: config)."),
) -> None:
    """Démarre l'API Flask en mode développement."""
    from voix.api.app import create_app

    s = get_settings()
    h = host or s.api_host
    p = port or s.api_port
    flask_app = create_app()
    flask_app.run(host=h, port=p, debug=True)


db_app = typer.Typer(no_args_is_help=True, help="Gestion de la base de données.")
app.add_typer(db_app, name="db")


@db_app.command("init")
def db_init() -> None:
    """Prépare les fichiers locaux et applique les migrations SQLite."""
    s = get_settings()
    if not s.database_url:
        ensure_sqlite_path(s.db_path)
    typer.echo("BD : migrations SQL à appliquer depuis migrations/ (TODO).")


if __name__ == "__main__":
    app()
