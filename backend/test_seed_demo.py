import tempfile
import unittest
from pathlib import Path
from auth import AccountStore
from social import SocialStore
from seed_demo import seed_demo, remove_demo

class DemoSeedTests(unittest.TestCase):
    def test_seed_is_repeatable_and_cleanup_preserves_real_accounts(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'demo.sqlite3'
            accounts = AccountStore(path)
            social = SocialStore(accounts)
            real = accounts.signup({'name':'Real member', 'email':'real@example.test', 'password':'cloud-password-123'})['user']
            self.assertEqual(seed_demo(path), 6)
            self.assertEqual(seed_demo(path), 0)
            posts = social.feed(real)['posts']
            self.assertEqual(len(posts), 6)
            self.assertTrue(all(p['avatar'].startswith('data:image/png;base64,') for p in posts))
            self.assertTrue(all(p['like_count'] > 0 for p in posts))
            # A normal member's post must survive removing all demo content.
            social.post(real, {'image':posts[0]['image'], 'caption':'My real cloud'})
            self.assertEqual(remove_demo(path), 6)
            self.assertEqual(remove_demo(path), 0)
            remaining = social.feed(real)['posts']
            self.assertEqual([p['caption'] for p in remaining], ['My real cloud'])
            with accounts.connect() as db:
                self.assertEqual(db.execute('SELECT COUNT(*) FROM users').fetchone()[0], 1)
