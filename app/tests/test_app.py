import importlib
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


@pytest.fixture()
def client(tmp_path, monkeypatch):
    monkeypatch.setenv("DB_PATH", str(tmp_path / "notes.db"))
    import app as app_module

    importlib.reload(app_module)  # pick up DB_PATH
    app_module.app.config.update(TESTING=True)
    return app_module.app.test_client()


def test_health(client):
    assert client.get("/healthz").json == {"status": "ok"}
    assert client.get("/readyz").json == {"status": "ready"}


def test_create_and_list(client):
    r = client.post("/api/notes", json={"title": "hello", "body": "world"})
    assert r.status_code == 201
    assert client.get("/api/notes").json[0]["title"] == "hello"


def test_search_filters(client):
    client.post("/api/notes", json={"title": "kubernetes"})
    client.post("/api/notes", json={"title": "docker"})
    titles = [n["title"] for n in client.get("/api/notes?q=kube").json]
    assert titles == ["kubernetes"]


def test_search_is_not_injectable(client):
    client.post("/api/notes", json={"title": "secret"})
    # A classic injection payload must be treated as text, not SQL.
    assert client.get("/api/notes?q=' OR '1'='1").json == []


def test_validation(client):
    assert client.post("/api/notes", json={}).status_code == 400
    assert client.post("/api/notes", json={"title": "x" * 500}).status_code == 400


def test_html_is_escaped(client):
    client.post("/api/notes", json={"title": "<script>alert(1)</script>"})
    page = client.get("/").get_data(as_text=True)
    assert "<script>alert(1)</script>" not in page
    assert "&lt;script&gt;" in page


def test_security_headers(client):
    h = client.get("/").headers
    assert "frame-ancestors 'none'" in h["Content-Security-Policy"]
    assert h["X-Content-Type-Options"] == "nosniff"
    assert h["X-Frame-Options"] == "DENY"
    assert h["Cross-Origin-Embedder-Policy"] == "require-corp"


def test_insecure_routes_off_by_default(client):
    # The Lab A4 debug/search routes must NOT exist in the baseline app, no
    # matter the env flag -- they only come alive when insecure_demo.py is armed.
    assert client.get("/admin/diag?host=localhost").status_code == 404
    assert client.get("/api/search?q=x").status_code == 404
