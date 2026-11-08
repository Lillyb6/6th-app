"""HTTP regression tests. Run with `python -m unittest discover -s backend`."""

import http.client
import threading
import unittest
from http.server import ThreadingHTTPServer

from server import CloudClubHandler


class HealthHeadTests(unittest.TestCase):
    def test_head_matches_get_headers_without_a_body(self):
        server = ThreadingHTTPServer(("127.0.0.1", 0), CloudClubHandler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        connection = http.client.HTTPConnection(*server.server_address, timeout=5)
        try:
            for path, expected_status in (("/health", 200), ("/missing", 404)):
                with self.subTest(path=path):
                    connection.request("GET", path)
                    response = connection.getresponse()
                    body = response.read()
                    content_type = response.getheader("Content-Type")
                    self.assertEqual(response.status, expected_status)

                    connection.request("HEAD", path)
                    response = connection.getresponse()
                    self.assertEqual(response.status, expected_status)
                    self.assertEqual(response.getheader("Content-Type"), content_type)
                    self.assertEqual(response.getheader("Content-Length"), str(len(body)))
                    self.assertEqual(response.read(), b"")
        finally:
            connection.close()
            server.shutdown()
            server.server_close()
            thread.join()


if __name__ == "__main__":
    unittest.main()
