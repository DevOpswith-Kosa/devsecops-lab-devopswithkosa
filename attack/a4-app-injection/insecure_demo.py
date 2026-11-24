"""ARMED application vulnerabilities for Part 2, Lab A4 (OWASP A03: Injection).

This file is deliberately NOT part of the baseline app. It lives under attack/
so the Part 3 scanners stay GREEN until you choose to plant it. When you "arm"
Lab A4 you copy this next to app.py and set INSECURE_MODE=1; app.py then calls
register() and these two insecure routes come alive.

Every line marked (!) is a classic application bug. Part 3 removes this whole
file -- and Semgrep/Bandit (`make scan-sast`) flag both sinks the moment it sits
in app/, which is the shift-left lesson.
"""

import subprocess  # nosec B404 - the whole point of this demo is a shell sink

from flask import Response, jsonify, request


def register(app, get_db):
    @app.get("/admin/diag")
    def admin_diag():
        # (!) COMMAND INJECTION (RCE). The attacker-controlled `host` goes
        #     straight into a shell. A ';' ends the ping and starts any command
        #     -- which then reads whatever the pod can read: the mounted
        #     ServiceAccount token, env vars, files. OWASP A03.
        #       curl '.../admin/diag?host=;cat /var/run/secrets/.../token'
        host = request.args.get("host", "localhost")
        proc = subprocess.run(  # noqa: S602  (intentional)
            f"ping -c1 {host}",
            shell=True,
            capture_output=True,
            text=True,
            timeout=10,
        )
        return Response((proc.stdout or "") + (proc.stderr or ""), mimetype="text/plain")

    @app.get("/api/search")
    def insecure_search():
        # (!) SQL INJECTION. `q` is formatted straight into the SQL string, so
        #     a quote breaks out of the literal and the rest of the query is the
        #     attacker's. OWASP A03.
        #       curl ".../api/search?q=' OR '1'='1"
        #       curl ".../api/search?q=' UNION SELECT 1,name,sql FROM sqlite_master--"
        q = request.args.get("q", "")
        sql = (
            "SELECT id, title, body FROM notes "
            f"WHERE title LIKE '%{q}%' ORDER BY id"
        )
        rows = get_db().execute(sql).fetchall()
        return jsonify([dict(r) for r in rows])
