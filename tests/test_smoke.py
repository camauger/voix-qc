"""Tests minimaux de présence."""

from voix import __version__
from voix.api.app import create_app


def test_version_is_semantic_placeholder() -> None:
    assert __version__ == "0.1.0"


def test_health_endpoint() -> None:
    app = create_app()
    client = app.test_client()
    res = client.get("/api/health")
    assert res.status_code == 200
    assert res.json["status"] == "ok"
