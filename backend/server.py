"""Dependency-free Cloud Club API starter. Run with `python server.py`."""

import json
import os
import re
import threading
import time
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

from auth import AccountStore, AuthError
from social import SocialStore


class AuthLimiter:
    """Bound memory and password-hashing work for this single-server app."""
    def __init__(self):
        self.lock = threading.Lock()
        self.attempts = {}

    def check(self, address):
        now = time.monotonic()
        with self.lock:
            self.attempts = {
                key: values for key, values in self.attempts.items()
                if values and values[-1] > now - 60
            }
            if address not in self.attempts and len(self.attempts) >= 1000:
                raise AuthError(429, "Too many requests. Try again in a minute.")
            values = self.attempts.setdefault(address, deque())
            while values and values[0] <= now - 60:
                values.popleft()
            if len(values) >= 10:
                raise AuthError(429, "Too many attempts. Try again in a minute.")
            values.append(now)


class CloudClubHandler(BaseHTTPRequestHandler):
    def bearer_token(self):
        value = self.headers.get("Authorization", "")
        return value[7:] if value.startswith("Bearer ") else ""

    def do_GET(self):
        path = urlsplit(self.path).path
        if path in ('/feed', '/profile', '/profile/posts'):
            try:
                user = self.server.accounts.current_user(self.bearer_token())
                if path == '/profile':
                    self.send_json(200, self.server.social.profile(user))
                else:
                    query = parse_qs(urlsplit(self.path).query)
                    try:
                        before = int(query.get('before', ['0'])[0])
                    except ValueError:
                        raise AuthError(400, 'Invalid page cursor.') from None
                    self.send_json(200, self.server.social.feed(user, before, path == '/profile/posts'))
            except AuthError as error:
                self.send_json(error.status, {'error': str(error)})
        elif path == "/health":
            self.send_json(200, {"status": "ok", "service": "cloud-club-api"})
        elif urlsplit(self.path).path == "/auth/me":
            try:
                self.send_json(200, {"user": self.server.accounts.current_user(self.bearer_token())})
            except AuthError as error:
                self.send_json(error.status, {"error": str(error)})
        else:
            self.send_json(404, {"error": "Not found"})

    def do_OPTIONS(self):
        self.send_json(200, {})

    def do_POST(self):
        path = urlsplit(self.path).path
        if path in ('/posts', '/profile') or re.fullmatch(r'/posts/\d+/(like|best|delete)', path):
            self.social_post(path)
            return
        if path not in ("/auth/signup", "/auth/login", "/auth/logout"):
            self.send_json(404, {"error": "Not found"})
            return
        try:
            origin = self.headers.get("Origin")
            if origin and origin != self.server.allowed_origin:
                raise AuthError(403, "Origin is not allowed.")
            if path == "/auth/logout":
                self.server.accounts.logout(self.bearer_token())
                self.send_json(200, {"message": "Logged out."})
                return
            self.server.auth_limiter.check(self.client_address[0])
            if self.headers.get_content_type() != "application/json":
                raise AuthError(415, "Send application/json.")
            try:
                length = int(self.headers.get("Content-Length", "0"))
            except ValueError:
                raise AuthError(400, "Invalid request length.") from None
            if not 0 < length <= 4096:
                raise AuthError(413, "Request must be between 1 and 4096 bytes.")
            try:
                data = json.loads(self.rfile.read(length))
            except (ValueError, UnicodeError):
                raise AuthError(400, "Invalid JSON.") from None
            if not isinstance(data, dict):
                raise AuthError(400, "Send a JSON object.")
            if path == "/auth/signup":
                self.send_json(201, self.server.accounts.signup(data))
            else:
                self.send_json(200, self.server.accounts.login(data))
        except AuthError as error:
            self.send_json(error.status, {"error": str(error)})

    def social_post(self, path):
        try:
            origin = self.headers.get('Origin')
            if origin and origin != self.server.allowed_origin:
                raise AuthError(403, 'Origin is not allowed.')
            user = self.server.accounts.current_user(self.bearer_token())
            if self.headers.get_content_type() != 'application/json':
                raise AuthError(415, 'Send application/json.')
            try:
                length = int(self.headers.get('Content-Length', '0'))
            except ValueError:
                raise AuthError(400, 'Invalid request length.') from None
            if not 0 < length <= 7_100_000:
                raise AuthError(413, 'Choose a photo under 5 MB.')
            try:
                data = json.loads(self.rfile.read(length))
            except (ValueError, UnicodeError):
                raise AuthError(400, 'Invalid JSON.') from None
            if not isinstance(data, dict):
                raise AuthError(400, 'Send a JSON object.')
            if path == '/posts':
                self.send_json(201, self.server.social.post(user, data))
            elif path == '/profile':
                self.send_json(200, self.server.social.update_profile(user, data))
            else:
                _, _, post_id, action = path.split('/')
                self.send_json(200, self.server.social.action(user, int(post_id), action, data))
        except AuthError as error:
            self.send_json(error.status, {'error': str(error)})

    def send_json(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        origin = self.headers.get("Origin")
        if origin and origin == getattr(self.server, "allowed_origin", None):
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")
            self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()
        self.wfile.write(body)


def create_server(host, port, database_path=None):
    server = ThreadingHTTPServer((host, port), CloudClubHandler)
    server.accounts = AccountStore(database_path or os.environ.get(
        "AUTH_DATABASE", str(Path(__file__).parent / "data" / "accounts.sqlite3")
    ))
    server.auth_limiter = AuthLimiter()
    server.social = SocialStore(server.accounts)
    server.allowed_origin = os.environ.get("WEB_ORIGIN", "http://localhost:8080")
    return server


if __name__ == "__main__":
    host = os.environ.get("HOST", "127.0.0.1")
    port = int(os.environ.get("PORT", "8000"))
    server = create_server(host, port)
    print(f"Cloud Club API listening on http://{host}:{port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
