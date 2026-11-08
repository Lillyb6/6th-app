"""Add or remove explicitly fictional sample posts without touching real accounts.

Run: python backend/seed_demo.py [--remove]
The assets are bundled, so seeding requires no network access.
"""
import argparse
import base64
import os
from pathlib import Path
import secrets
import time

from auth import AccountStore
from social import SocialStore, image_data

ROOT = Path(__file__).resolve().parent.parent
MEMBERS = [
    ('maya', 'Maya Wren', 'sunset-clouds-sky-2.webp', 'The sky really said peach season. Stayed outside until the last bit of pink disappeared.', 'Evening walk', 5),
    ('theo', 'Theo Park', 'blue-sky-background-clouds.webp', 'Pretty sure this one is a very sleepy dragon. Anyone else see it?', 'Head in the clouds', 3),
    ('juniper', 'Juniper Lane', 'a-clear-blue-sky-with-scattered-fluffy.jpg', 'A tiny reminder to look up on your way home. The best part of my afternoon.', 'The long way home', 4),
    ('noah', 'Noah Reed', 'sun-and-some-clouds.webp', 'No plans. Just sunshine and an unreasonable number of cloud photos in my camera roll.', 'Somewhere sunny', 2),
    ('amara', 'Amara Sol', 'sunset-clouds-sky.webp', 'That quiet minute when everything turns gold. Worth missing the bus for.', 'Golden hour', 5),
    ('leo', 'Leo Bennett', 'a-bright-blue-sky-filled-with-scattered.jpg', 'Little islands in a very big blue ocean. This is my kind of daydream.', 'A slow afternoon', 1),
]


def data_url(path):
    mime = {'.webp': 'webp', '.jpg': 'jpeg', '.png': 'png'}[path.suffix]
    return image_data('data:image/' + mime + ';base64,' + base64.b64encode(path.read_bytes()).decode())


def seed_demo(database_path=None):
    # Validate every bundled file before changing the database.
    media = {key: (data_url(ROOT / 'assets' / photo), data_url(ROOT / 'backend/demo_assets' / (key + '.png')))
             for key, _, photo, _, _, _ in MEMBERS}
    accounts = AccountStore(database_path or os.environ.get('AUTH_DATABASE', ROOT / 'backend/data/accounts.sqlite3'))
    SocialStore(accounts)
    now = int(time.time())
    with accounts.connect() as db:
        db.executescript('''
            CREATE TABLE IF NOT EXISTS demo_members (
                seed_key TEXT PRIMARY KEY,
                user_id INTEGER UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE
            );
            CREATE TABLE IF NOT EXISTS demo_posts (
                seed_key TEXT PRIMARY KEY,
                post_id INTEGER UNIQUE NOT NULL REFERENCES posts(id) ON DELETE CASCADE
            );
        ''')
        members = {}
        for key, name, _, _, _, _ in MEMBERS:
            row = db.execute('SELECT user_id FROM demo_members WHERE seed_key=?', (key,)).fetchone()
            if row:
                members[key] = row['user_id']
                continue
            # Random hashes deliberately provide no usable demo login credentials.
            cursor = db.execute('INSERT INTO users(email,name,salt,password_hash) VALUES(?,?,?,?)',
                                (key + '@demo.cloudclub.invalid', name, secrets.token_bytes(16), secrets.token_bytes(32)))
            user_id = cursor.lastrowid
            members[key] = user_id
            db.execute('INSERT INTO demo_members VALUES(?,?)', (key, user_id))
            db.execute('INSERT INTO profiles VALUES(?,?,?)', (user_id, 'Fictional Cloud Club demo member. Always looking up.', media[key][1]))
        added = 0
        # Insert oldest first so the first member is at the top of the live feed.
        for i in reversed(range(len(MEMBERS))):
            key, _, _, caption, location, count = MEMBERS[i]
            if db.execute('SELECT 1 FROM demo_posts WHERE seed_key=?', (key,)).fetchone():
                continue
            post = db.execute('INSERT INTO posts(user_id,image,caption,location,best,created_at) VALUES(?,?,?,?,1,?)',
                              (members[key], media[key][0], caption, location, now - (i + 1) * 2100))
            post_id = post.lastrowid
            db.execute('INSERT INTO demo_posts VALUES(?,?)', (key, post_id))
            likers = [user_id for user_id in members.values() if user_id != members[key]][:count]
            db.executemany('INSERT INTO likes VALUES(?,?)', [(user_id, post_id) for user_id in likers])
            added += 1
    return added


def remove_demo(database_path=None):
    accounts = AccountStore(database_path or os.environ.get('AUTH_DATABASE', ROOT / 'backend/data/accounts.sqlite3'))
    with accounts.connect() as db:
        if not db.execute("SELECT 1 FROM sqlite_master WHERE name='demo_members'").fetchone():
            return 0
        ids = [row['user_id'] for row in db.execute('SELECT user_id FROM demo_members')]
        for user_id in ids:
            db.execute('DELETE FROM likes WHERE user_id=?', (user_id,))
            db.execute('DELETE FROM posts WHERE user_id=?', (user_id,))
            db.execute('DELETE FROM profiles WHERE user_id=?', (user_id,))
            db.execute('DELETE FROM sessions WHERE user_id=?', (user_id,))
            db.execute('DELETE FROM users WHERE id=?', (user_id,))
    return len(ids)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--remove', action='store_true', help='Remove only the fictional demo accounts and their posts.')
    args = parser.parse_args()
    if args.remove:
        print(f'Removed {remove_demo()} fictional members and their sample posts.')
    else:
        print(f'Added {seed_demo()} sample cloud posts. Existing posts and accounts were preserved.')
