"""Fabrique d'application Flask."""

from flask import Flask

from voix import __version__


def create_app() -> Flask:
    """Crée l'app API avec configuration minimale."""
    app = Flask(__name__)
    app.config["VOIX_VERSION"] = __version__

    @app.get("/api/health")
    def health() -> dict[str, str]:
        return {"status": "ok", "version": __version__}

    return app
