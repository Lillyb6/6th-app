"""Social features through real authenticated HTTP requests."""
import base64
import json
import http.client
import tempfile
import threading
import unittest
from pathlib import Path
from server import create_server

# Valid one-pixel PNG. No real user data or running service required.
PHOTO = 'data:image/png;base64,' + base64.b64encode(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEklEQVR4nGPo2H23Y/ddBggFADo6CIFrmVhZAAAAAElFTkSuQmCC')).decode()

class SocialTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / 'social.sqlite3'
        self.server = create_server('127.0.0.1', 0, self.path)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.stop)
        self.user = self.server.accounts.signup({'name': 'Sky', 'email': 'sky@example.com', 'password': 'cloud-password-123'})
        self.other = self.server.accounts.signup({'name': 'River', 'email': 'river@example.com', 'password': 'cloud-password-456'})

    def stop(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(5)
        self.temp.cleanup()

    def request(self, method, path, data=None, token=None):
        conn = http.client.HTTPConnection(*self.server.server_address, timeout=10)
        try:
            headers = {'Content-Type': 'application/json'}
            if token: headers['Authorization'] = 'Bearer ' + token
            conn.request(method, path, json.dumps(data) if data is not None else None, headers)
            result = conn.getresponse()
            return result.status, json.loads(result.read())
        finally:
            conn.close()

    def post(self):
        status, body = self.request('POST', '/posts', {'image': PHOTO, 'caption': 'A sleeping dragon', 'location': 'Chicago', 'best': True}, self.user['token'])
        self.assertEqual(status, 201, body)
        return body['id']

    def test_feed_shared_between_accounts_and_profile_isolated(self):
        self.post()
        status, feed = self.request('GET', '/feed', token=self.other['token'])
        self.assertEqual(status, 200)
        self.assertEqual(feed['posts'][0]['caption'], 'A sleeping dragon')
        self.assertEqual(feed['posts'][0]['name'], 'Sky')
        own = self.request('GET', '/profile/posts', token=self.other['token'])[1]
        self.assertEqual(own['posts'], [])
        # Reopening the same database keeps photos.
        from social import SocialStore
        from auth import AccountStore
        reopened = SocialStore(AccountStore(self.path))
        self.assertEqual(reopened.feed(self.other['user'])['posts'][0]['image'], PHOTO)

    def test_like_is_idempotent_and_unlike_removes_it(self):
        post_id = self.post()
        for _ in range(2):
            status, body = self.request('POST', f'/posts/{post_id}/like', {'liked': True}, self.other['token'])
            self.assertEqual(status, 200)
            self.assertEqual(body['likes'], 1)
        body = self.request('POST', f'/posts/{post_id}/like', {'liked': False}, self.other['token'])[1]
        self.assertEqual(body['likes'], 0)

    def test_only_owner_can_feature_or_delete_and_delete_cascades(self):
        post_id = self.post()
        for action in ('best', 'delete'):
            self.assertEqual(self.request('POST', f'/posts/{post_id}/{action}', {'best': False}, self.other['token'])[0], 403)
        self.assertEqual(self.request('POST', f'/posts/{post_id}/best', {'best': False}, self.user['token'])[0], 200)
        self.request('POST', f'/posts/{post_id}/like', {'liked': True}, self.other['token'])
        self.assertEqual(self.request('POST', f'/posts/{post_id}/delete', {}, self.user['token'])[0], 200)
        self.assertEqual(self.request('GET', '/feed', token=self.user['token'])[1]['posts'], [])
        with self.server.accounts.connect() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM likes').fetchone()[0], 0)

    def test_profile_changes_persist_and_update_feed_identity(self):
        self.post()
        status, result = self.request('POST', '/profile', {'name': 'Sky Blue', 'bio': 'Always looking up.', 'avatar': PHOTO}, self.user['token'])
        self.assertEqual(status, 200)
        self.assertEqual(result['bio'], 'Always looking up.')
        feed = self.request('GET', '/feed', token=self.other['token'])[1]
        self.assertEqual(feed['posts'][0]['name'], 'Sky Blue')
        self.assertEqual(feed['posts'][0]['avatar'], PHOTO)

    def test_auth_required_and_invalid_uploads_rejected(self):
        self.assertEqual(self.request('GET', '/feed')[0], 401)
        self.assertEqual(self.request('POST', '/posts', {})[0], 401)
        for image, caption in [('not-an-image', 'Cloud'), (PHOTO, ''), (PHOTO, 'x' * 501)]:
            self.assertEqual(self.request('POST', '/posts', {'image': image, 'caption': caption}, self.user['token'])[0], 400)
        self.assertEqual(self.request('POST', '/profile', {'name': '', 'bio': '', 'avatar': ''}, self.user['token'])[0], 400)

    def test_pagination_has_no_duplicates(self):
        for i in range(14):
            self.server.social.post(self.user['user'], {'image': PHOTO, 'caption': f'Cloud {i}'})
        first = self.request('GET', '/feed', token=self.user['token'])[1]
        second = self.request('GET', f"/feed?before={first['next']}", token=self.user['token'])[1]
        ids = [p['id'] for p in first['posts'] + second['posts']]
        self.assertEqual(len(ids), 14)
        self.assertEqual(len(set(ids)), 14)
        self.assertIsNone(second['next'])
