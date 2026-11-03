"""SQLite accounts and revocable, expiring bearer sessions."""

import hashlib
import hmac
import re
import secrets
import sqlite3
import time
from contextlib import contextmanager
from pathlib import Path


class AuthError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status


class AccountStore:
    ITERATIONS = 600_000
    SESSION_SECONDS = 24 * 60 * 60

    def __init__(self, path):
        self.path = str(path)
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        with self.connect() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS users (
                    id INTEGER PRIMARY KEY, email TEXT UNIQUE NOT NULL,
                    name TEXT NOT NULL, salt BLOB NOT NULL,
                    password_hash BLOB NOT NULL
                );
                CREATE TABLE IF NOT EXISTS sessions (
                    token_hash TEXT PRIMARY KEY,
                    user_id INTEGER NOT NULL REFERENCES users(id),
                    expires_at INTEGER NOT NULL
                );
            """)

    @contextmanager
    def connect(self):
        db = sqlite3.connect(self.path, timeout=10)
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA foreign_keys = ON")
        try:
            with db:
                yield db
        finally:
            db.close()

    @classmethod
    def password_hash(cls, password, salt):
        return hashlib.pbkdf2_hmac(
            "sha256", password.encode("utf-8"), salt, cls.ITERATIONS
        )

    @staticmethod
    def credentials(data):
        email, password = data.get("email"), data.get("password")
        if not isinstance(email, str) or not isinstance(password, str):
            raise AuthError(400, "Email and password are required.")
        email = email.strip().lower()
        if len(email) > 254 or not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", email):
            raise AuthError(400, "Enter a valid email address.")
        if not 12 <= len(password) <= 128:
            raise AuthError(400, "Use a password between 12 and 128 characters.")
        return email, password

    def signup(self, data):
        email, password = self.credentials(data)
        name = data.get("name")
        if not isinstance(name, str) or not 1 <= len(name.strip()) <= 60:
            raise AuthError(400, "Enter a name between 1 and 60 characters.")
        salt = secrets.token_bytes(16)
        digest = self.password_hash(password, salt)
        try:
            with self.connect() as db:
                cursor = db.execute(
                    "INSERT INTO users(email, name, salt, password_hash) VALUES(?,?,?,?)",
                    (email, name.strip(), salt, digest),
                )
                user_id = cursor.lastrowid
        except sqlite3.IntegrityError:
            raise AuthError(409, "An account with that email already exists.") from None
        return self.new_session(user_id)

    def login(self, data):
        email, password = self.credentials(data)
        with self.connect() as db:
            user = db.execute("SELECT * FROM users WHERE email = ?", (email,)).fetchone()
        salt = user["salt"] if user else bytes(16)
        digest = self.password_hash(password, salt)
        if user is None or not hmac.compare_digest(digest, user["password_hash"]):
            raise AuthError(401, "Incorrect email or password.")
        return self.new_session(user["id"])

    def new_session(self, user_id):
        token = secrets.token_urlsafe(32)
        now = int(time.time())
        with self.connect() as db:
            db.execute("DELETE FROM sessions WHERE expires_at <= ?", (now,))
            db.execute(
                "INSERT INTO sessions VALUES(?,?,?)",
                (self.token_hash(token), user_id, now + self.SESSION_SECONDS),
            )
        return {
            "token": token, "user": self.current_user(token),
            "expires_at": now + self.SESSION_SECONDS,
        }

    @staticmethod
    def token_hash(token):
        return hashlib.sha256(token.encode("utf-8")).hexdigest()

    def current_user(self, token):
        if not token or len(token) > 200:
            raise AuthError(401, "Please log in again.")
        with self.connect() as db:
            row = db.execute("""
                SELECT users.id, users.email, users.name
                FROM sessions JOIN users ON users.id = sessions.user_id
                WHERE token_hash = ? AND expires_at > ?
            """, (self.token_hash(token), int(time.time()))).fetchone()
        if row is None:
            raise AuthError(401, "Please log in again.")
        return dict(row)

    def logout(self, token):
        self.current_user(token)
        with self.connect() as db:
            db.execute("DELETE FROM sessions WHERE token_hash = ?", (self.token_hash(token),))
