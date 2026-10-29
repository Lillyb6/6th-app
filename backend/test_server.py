"""HTTP contract tests. Run from the repository root with unittest discovery."""

import http.client
import json
import threading
import unittest
from http.server import ThreadingHTTPServer

from server import CloudClubHandler


class CloudClubApiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), CloudClubHandler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=5)

    def get_json(self, path):
        connection = http.client.HTTPConnection(*self.server.server_address, timeout=5)
        self.addCleanup(connection.close)
        connection.request("GET", path)
        response = connection.getresponse()
        body = response.read()
        self.assertEqual(response.getheader("Content-Type"), "application/json; charset=utf-8")
        self.assertEqual(int(response.getheader("Content-Length")), len(body))
        return response.status, json.loads(body)

    def test_health_reports_service_status(self):
        status, payload = self.get_json("/health")
        self.assertEqual(status, 200)
        self.assertEqual(payload, {"status": "ok", "service": "cloud-club-api"})

    def test_health_accepts_query_parameters(self):
        status, payload = self.get_json("/health?probe=readiness")
        self.assertEqual(status, 200)
        self.assertEqual(payload["status"], "ok")

    def test_unknown_routes_return_json_not_found(self):
        for path in ("/", "/missing", "/health/", "/healthcheck"):
            with self.subTest(path=path):
                status, payload = self.get_json(path)
                self.assertEqual(status, 404)
                self.assertEqual(payload, {"error": "Not found"})


if __name__ == "__main__":
    unittest.main()
