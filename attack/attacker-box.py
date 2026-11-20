# Minimal "exfiltration endpoint". Any GET/POST is logged and its body saved
# to attack/loot/. Runs on 127.0.0.1 only. Part of the KubeAcademy DevSecOps
# attack lab -- a target for YOUR data on YOUR machine, nothing more.
import os, time
from http.server import BaseHTTPRequestHandler, HTTPServer

LOOT = os.environ.get("LOOT", "loot")
PORT = int(os.environ.get("PORT", "9000"))


class H(BaseHTTPRequestHandler):
    def _save(self, method):
        n = int(self.headers.get("Content-Length", 0) or 0)
        body = self.rfile.read(n) if n else b""
        stamp = time.strftime("%Y%m%d-%H%M%S")
        safe = self.path.strip("/").replace("/", "_") or "root"
        path = os.path.join(LOOT, f"{stamp}-{safe}.txt")
        with open(path, "wb") as f:
            f.write(body or self.path.encode())
        print(f"[{stamp}] {method} {self.path}  ({len(body)} bytes) -> {path}", flush=True)
        self.send_response(200); self.end_headers(); self.wfile.write(b"ok\n")

    def do_POST(self): self._save("POST")
    def do_GET(self): self._save("GET")
    def log_message(self, *a): pass


if __name__ == "__main__":
    print(f"attacker box on 127.0.0.1:{PORT}, loot -> {LOOT}/", flush=True)
    HTTPServer(("127.0.0.1", PORT), H).serve_forever()
