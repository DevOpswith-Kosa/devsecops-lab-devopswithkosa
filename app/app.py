"""kubenotes: a tiny notes API used to practise CI/CD and DevSecOps.

The code is deliberately small so you can focus on the pipeline around it.
The scenarios in ../scenarios/ break it on purpose (SQL injection, leaked
secrets, missing headers...) so you can watch the pipeline catch each one.
"""

import os
import sqlite3
from html import escape

from flask import Flask, g, jsonify, request

APP_VERSION = os.environ.get("APP_VERSION", "dev")
APP_ENV = os.environ.get("APP_ENV", "local")
# In Kubernetes /tmp is a writable emptyDir (the root FS is read-only), so a
# fixed path here is intentional, not an insecure temp file.
DB_PATH = os.environ.get("DB_PATH", "/tmp/notes.db")  # nosec B108
MAX_TITLE = 120
MAX_BODY = 2000

app = Flask(__name__)


# ---------------------------------------------------------------- database
def get_db() -> sqlite3.Connection:
    if "db" not in g:
        g.db = sqlite3.connect(DB_PATH)
        g.db.row_factory = sqlite3.Row
        g.db.execute(
            "CREATE TABLE IF NOT EXISTS notes ("
            " id INTEGER PRIMARY KEY AUTOINCREMENT,"
            " title TEXT NOT NULL,"
            " body TEXT NOT NULL DEFAULT '')"
        )
    return g.db


@app.teardown_appcontext
def close_db(_exc):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def search_notes(term: str) -> list[dict]:
    # Parameterised query: the database driver escapes `term` for us.
    rows = get_db().execute(
        "SELECT id, title, body FROM notes WHERE title LIKE ? ORDER BY id",
        (f"%{term}%",),
    ).fetchall()
    return [dict(r) for r in rows]


# ---------------------------------------------------------- security headers
@app.after_request
def security_headers(resp):
    resp.headers["Content-Security-Policy"] = (
        "default-src 'self'; frame-ancestors 'none'; form-action 'self'; base-uri 'self'"
    )
    resp.headers["X-Content-Type-Options"] = "nosniff"
    resp.headers["X-Frame-Options"] = "DENY"
    resp.headers["Referrer-Policy"] = "no-referrer"
    resp.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    resp.headers["Cross-Origin-Opener-Policy"] = "same-origin"
    resp.headers["Cross-Origin-Embedder-Policy"] = "require-corp"
    resp.headers["Cross-Origin-Resource-Policy"] = "same-origin"
    resp.headers["Cache-Control"] = "no-store"
    return resp


# ------------------------------------------------------------------- routes
@app.get("/")
def index():
    notes = search_notes("")
    items = "".join(
        f"<li><b>{escape(n['title'])}</b>: {escape(n['body'])}</li>" for n in notes
    )
    return (
        "<!doctype html><html lang='en'><head><meta charset='utf-8'>"
        "<title>kubenotes</title></head><body>"
        f"<h1>kubenotes</h1><p>version {escape(APP_VERSION)} ({escape(APP_ENV)})</p>"
        f"<ul>{items or '<li>No notes yet.</li>'}</ul>"
        "</body></html>"
    )


@app.get("/api/notes")
def list_notes():
    return jsonify(search_notes(request.args.get("q", "")))


@app.post("/api/notes")
def create_note():
    data = request.get_json(silent=True) or {}
    title = str(data.get("title", "")).strip()
    body = str(data.get("body", "")).strip()
    if not title or len(title) > MAX_TITLE or len(body) > MAX_BODY:
        return jsonify(error=f"title is required (max {MAX_TITLE}), body max {MAX_BODY}"), 400
    db = get_db()
    cur = db.execute("INSERT INTO notes (title, body) VALUES (?, ?)", (title, body))
    db.commit()
    return jsonify(id=cur.lastrowid, title=title, body=body), 201


@app.get("/healthz")
def healthz():
    return jsonify(status="ok")


@app.get("/readyz")
def readyz():
    get_db().execute("SELECT 1")
    return jsonify(status="ready")


@app.get("/version")
def version():
    return jsonify(version=APP_VERSION, env=APP_ENV)


if __name__ == "__main__":
    # Local development only. In the container gunicorn serves the app.
    app.run(host="127.0.0.1", port=8080)
