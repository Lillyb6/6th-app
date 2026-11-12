"""Persistent community photos, profiles and likes, scoped to signed-in users."""

import base64
import binascii
import time

from auth import AuthError


def image_data(value, optional=False):
    if optional and value == "":
        return ""
    if not isinstance(value, str) or len(value) > 7_000_000:
        raise AuthError(400, "Choose a JPEG, PNG or WebP photo under 5 MB.")
    try:
        header, encoded = value.split(",", 1)
        raw = base64.b64decode(encoded, validate=True)
    except (ValueError, binascii.Error):
        raise AuthError(400, "Choose a valid photo.") from None
    formats = {
        "data:image/jpeg;base64": raw.startswith(b"\xff\xd8\xff"),
        "data:image/png;base64": raw.startswith(b"\x89PNG\r\n\x1a\n"),
        "data:image/webp;base64": raw.startswith(b"RIFF") and raw[8:12] == b"WEBP",
    }
    if not formats.get(header) or not 16 <= len(raw) <= 5_000_000:
        raise AuthError(400, "Choose a JPEG, PNG or WebP photo under 5 MB.")
    return value


def text(data, field, limit, required=False):
    value = data.get(field, "")
    if not isinstance(value, str) or len(value.strip()) > limit:
        raise AuthError(400, f"{field.capitalize()} must be {limit} characters or fewer.")
    if required and not value.strip():
        raise AuthError(400, f"Enter a {field}.")
    return value.strip()


class SocialStore:
    def __init__(self, accounts):
        self.accounts = accounts
        with accounts.connect() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS profiles (
                    user_id INTEGER PRIMARY KEY REFERENCES users(id),
                    bio TEXT NOT NULL DEFAULT '', avatar TEXT NOT NULL DEFAULT ''
                );
                CREATE TABLE IF NOT EXISTS posts (
                    id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id),
                    image TEXT NOT NULL, caption TEXT NOT NULL, location TEXT NOT NULL,
                    best INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL
                );
                CREATE TABLE IF NOT EXISTS likes (
                    user_id INTEGER NOT NULL REFERENCES users(id),
                    post_id INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
                    PRIMARY KEY(user_id, post_id)
                );
                CREATE TABLE IF NOT EXISTS comments (
                    id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id),
                    post_id INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
                    body TEXT NOT NULL CHECK(length(body) BETWEEN 1 AND 500),
                    created_at INTEGER NOT NULL
                );
            """)

    def profile(self, user):
        with self.accounts.connect() as db:
            row = db.execute("SELECT bio, avatar FROM profiles WHERE user_id=?", (user['id'],)).fetchone()
        return {"id": user['id'], "name": user['name'], "bio": row['bio'] if row else "",
                "avatar": row['avatar'] if row else ""}

    def update_profile(self, user, data):
        name, bio = text(data, 'name', 60, True), text(data, 'bio', 160)
        avatar = image_data(data.get('avatar', ''), optional=True)
        with self.accounts.connect() as db:
            db.execute("UPDATE users SET name=? WHERE id=?", (name, user['id']))
            db.execute("INSERT INTO profiles VALUES(?,?,?) ON CONFLICT(user_id) DO UPDATE SET bio=excluded.bio, avatar=excluded.avatar",
                       (user['id'], bio, avatar))
        return self.profile({**user, 'name': name})

    def feed(self, user, before=0, own=False):
        with self.accounts.connect() as db:
            rows = db.execute("""
                SELECT p.*, u.name, COALESCE(pr.avatar,'') AS avatar,
                    (SELECT COUNT(*) FROM likes WHERE post_id=p.id) AS like_count,
                    (SELECT COUNT(*) FROM comments WHERE post_id=p.id) AS comment_count,
                    EXISTS(SELECT 1 FROM likes WHERE post_id=p.id AND user_id=?) AS liked
                FROM posts p JOIN users u ON u.id=p.user_id
                LEFT JOIN profiles pr ON pr.user_id=u.id
                WHERE (?=0 OR p.id<?) AND (?=0 OR p.user_id=?)
                ORDER BY p.id DESC LIMIT 13
            """, (user['id'], before, before, int(own), user['id'])).fetchall()
        posts = [dict(row) for row in rows[:12]]
        return {'posts': posts, 'next': posts[-1]['id'] if len(rows) > 12 else None}

    def post(self, user, data):
        photo = image_data(data.get('image'))
        caption, location = text(data, 'caption', 500, True), text(data, 'location', 80)
        with self.accounts.connect() as db:
            cursor = db.execute("INSERT INTO posts(user_id,image,caption,location,best,created_at) VALUES(?,?,?,?,?,?)",
                                (user['id'], photo, caption, location, int(data.get('best') is True), int(time.time())))
        return {'id': cursor.lastrowid}

    def comments(self, post_id):
        with self.accounts.connect() as db:
            if not db.execute("SELECT 1 FROM posts WHERE id=?", (post_id,)).fetchone():
                raise AuthError(404, "This cloud is no longer available.")
            rows = db.execute("""
                SELECT c.id, c.post_id, c.user_id, c.body, c.created_at,
                    u.name, COALESCE(p.avatar, '') AS avatar
                FROM comments c JOIN users u ON u.id=c.user_id
                LEFT JOIN profiles p ON p.user_id=c.user_id
                WHERE c.post_id=? ORDER BY c.created_at, c.id
            """, (post_id,)).fetchall()
        return {'comments': [dict(row) for row in rows]}

    def add_comment(self, user, post_id, data):
        body = text(data, 'body', 500, True)
        with self.accounts.connect() as db:
            if not db.execute("SELECT 1 FROM posts WHERE id=?", (post_id,)).fetchone():
                raise AuthError(404, "This cloud is no longer available.")
            db.execute("INSERT INTO comments(user_id,post_id,body,created_at) VALUES(?,?,?,?)",
                       (user['id'], post_id, body, int(time.time())))
        return self.comments(post_id)

    def action(self, user, post_id, action, data):
        with self.accounts.connect() as db:
            post = db.execute("SELECT user_id FROM posts WHERE id=?", (post_id,)).fetchone()
            if post is None:
                raise AuthError(404, "This cloud is no longer available.")
            if action == 'like':
                if data.get('liked') is True:
                    db.execute("INSERT OR IGNORE INTO likes VALUES(?,?)", (user['id'], post_id))
                else:
                    db.execute("DELETE FROM likes WHERE user_id=? AND post_id=?", (user['id'], post_id))
                count = db.execute("SELECT COUNT(*) FROM likes WHERE post_id=?", (post_id,)).fetchone()[0]
                return {'likes': count, 'liked': data.get('liked') is True}
            if post['user_id'] != user['id']:
                raise AuthError(403, "Only the photographer can change this cloud.")
            if action == 'best':
                db.execute("UPDATE posts SET best=? WHERE id=?", (int(data.get('best') is True), post_id))
            elif action == 'delete':
                db.execute("DELETE FROM posts WHERE id=?", (post_id,))
            else:
                raise AuthError(404, "Not found")
        return {'status': 'ok'}
