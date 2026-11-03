"""Exercise real HTTP requests, persisted accounts and session rejection."""

import http.client
import json
import tempfile
import threading
import time
import unittest
from pathlib import Path

from auth import AccountStore, AuthError
from server import AuthLimiter, create_server


class AuthenticationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "accounts.sqlite3"
        self.server = create_server("127.0.0.1", 0, self.path)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.stop)
        self.account = {"email": "sky@example.com", "password": "rainbow-cloud-123", "name": "Sky"}

    def stop(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=5)

    def request(self, method, path, data=None, token=None, origin=None):
        connection = http.client.HTTPConnection(*self.server.server_address, timeout=10)
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = "Bearer " + token
        if origin:
            headers["Origin"] = origin
        try:
            connection.request(method, path, json.dumps(data) if data is not None else None, headers)
            response = connection.getresponse()
            self.assertEqual(response.getheader("Cache-Control"), "no-store")
            return response.status, json.loads(response.read())
        finally:
            connection.close()

    def signup(self):
        status, body = self.request("POST", "/auth/signup", self.account)
        self.assertEqual(status, 201, body)
        return body["token"]

    def test_signup_login_me_and_logout(self):
        token = self.signup()
        status, body = self.request("GET", "/auth/me", token=token)
        self.assertEqual(status, 200)
        self.assertEqual(body["user"]["name"], "Sky")
        self.assertNotIn("password", body["user"])
        self.assertEqual(self.request("POST", "/auth/logout", {}, token)[0], 200)
        self.assertEqual(self.request("GET", "/auth/me", token=token)[0], 401)
        status, body = self.request("POST", "/auth/login", self.account)
        self.assertEqual(status, 200)
        self.assertNotEqual(body["token"], token)
        self.assertGreater(body["expires_at"], time.time())

    def test_passwords_are_hashed_and_accounts_survive_reopening(self):
        token = self.signup()
        store = AccountStore(self.path)
        with store.connect() as db:
            user = db.execute("SELECT * FROM users").fetchone()
            session = db.execute("SELECT * FROM sessions").fetchone()
        self.assertNotEqual(user["password_hash"], self.account["password"].encode())
        self.assertEqual(len(user["salt"]), 16)
        self.assertNotEqual(session["token_hash"], token)
        self.assertEqual(store.login(self.account)["user"]["email"], "sky@example.com")

    def test_duplicate_case_insensitive_email_and_incorrect_credentials(self):
        self.signup()
        duplicate = {**self.account, "email": " SKY@EXAMPLE.COM "}
        self.assertEqual(self.request("POST", "/auth/signup", duplicate)[0], 409)
        wrong = {**self.account, "password": "incorrect-password"}
        unknown = {**wrong, "email": "unknown@example.com"}
        self.assertEqual(self.request("POST", "/auth/login", wrong),
                         self.request("POST", "/auth/login", unknown))
        self.assertEqual(self.request("POST", "/auth/login", duplicate)[0], 200)

    def test_missing_invalid_and_expired_sessions_are_rejected(self):
        self.assertEqual(self.request("GET", "/auth/me")[0], 401)
        self.assertEqual(self.request("GET", "/auth/me", token="made-up-token")[0], 401)
        token = self.signup()
        with self.server.accounts.connect() as db:
            db.execute("UPDATE sessions SET expires_at = 0")
        self.assertEqual(self.request("GET", "/auth/me", token=token)[0], 401)

    def test_validation_and_untrusted_origin(self):
        for data in ({}, [], {**self.account, "password": "short"},
                     {**self.account, "email": "invalid"}, {**self.account, "name": " "}):
            self.assertEqual(self.request("POST", "/auth/signup", data)[0], 400)
        self.assertEqual(self.request("POST", "/auth/signup", self.account,
                                      origin="https://untrusted.example")[0], 403)

    def test_auth_attempts_are_rate_limited(self):
        limiter = AuthLimiter()
        for _ in range(10):
            limiter.check("127.0.0.1")
        with self.assertRaises(AuthError) as error:
            limiter.check("127.0.0.1")
        self.assertEqual(error.exception.status, 429)
        self.server.auth_limiter = limiter
        self.assertEqual(self.request("POST", "/auth/login", self.account)[0], 429)

    def test_preflight_and_oversized_body(self):
        self.assertEqual(self.request("OPTIONS", "/auth/login",
                                      origin="http://localhost:8080")[0], 200)
        self.assertEqual(self.request("POST", "/auth/signup", {"value": "x" * 5000})[0], 413)


if __name__ == "__main__":
    unittest.main()
