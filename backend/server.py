"""Dependency-free Cloud Club API starter. Run with `python server.py`."""

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit


class CloudClubHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if urlsplit(self.path).path == "/health":
            self.send_json(200, {"status": "ok", "service": "cloud-club-api"})
        else:
            self.send_json(404, {"error": "Not found"})

    def send_json(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    host = os.environ.get("HOST", "127.0.0.1")
    port = int(os.environ.get("PORT", "8000"))
    server = ThreadingHTTPServer((host, port), CloudClubHandler)
    print(f"Cloud Club API listening on http://{host}:{port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
