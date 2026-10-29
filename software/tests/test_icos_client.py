from __future__ import annotations

import argparse
import contextlib
import importlib.util
import io
import json
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from unittest import mock


MODULE_PATH = Path(__file__).parents[1] / "scripts" / "icos_client.py"
SPEC = importlib.util.spec_from_file_location("icos_client", MODULE_PATH)
assert SPEC and SPEC.loader
icos_client = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(icos_client)


class Handler(BaseHTTPRequestHandler):
    metadata_seen = False
    archive_seen = b""
    login_status = 200
    metadata_status = 200
    put_status = 200
    send_auth_cookie = True
    metadata_requests = 0
    put_requests = 0

    def log_message(self, format: str, *args: object) -> None:
        return

    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)
        if self.path == "/password/login":
            self.assert_form(body)
            self.send_response(Handler.login_status)
            if Handler.login_status < 300 and Handler.send_auth_cookie:
                self.send_header("Set-Cookie", "cpauthToken=test-token; Path=/")
            self.end_headers()
            if Handler.login_status >= 300:
                self.wfile.write(b"login rejected")
            return
        if self.path == "/upload":
            Handler.metadata_requests += 1
            if "cpauthToken=test-token" not in self.headers.get("Cookie", ""):
                self.send_error(401)
                return
            payload = json.loads(body)
            if payload["objectSpecification"] != icos_client.OBJECT_SPECIFICATION:
                self.send_error(400)
                return
            if Handler.metadata_status >= 300:
                self.send_response(Handler.metadata_status)
                self.end_headers()
                self.wfile.write(b"metadata unavailable")
                return
            Handler.metadata_seen = True
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"https://data.example/objects/test")
            return
        self.send_error(404)

    def assert_form(self, body: bytes) -> None:
        if b"mail=station%40example.org" not in body or b"password=secret" not in body:
            self.send_error(400)
            raise AssertionError("unexpected login form")

    def do_PUT(self) -> None:
        Handler.put_requests += 1
        if "cpauthToken=test-token" not in self.headers.get("Cookie", ""):
            self.send_error(401)
            return
        if self.headers.get("Transfer-Encoding") != "chunked":
            self.send_error(411)
            return
        chunks = []
        while True:
            size = int(self.rfile.readline().strip(), 16)
            if size == 0:
                self.rfile.readline()
                break
            chunks.append(self.rfile.read(size))
            self.rfile.read(2)
        Handler.archive_seen = b"".join(chunks)
        self.send_response(Handler.put_status)
        self.end_headers()
        if Handler.put_status < 300:
            self.wfile.write(b"Upload completed")
        else:
            self.wfile.write(b"data service unavailable")


class IcosClientTests(unittest.TestCase):
    def setUp(self) -> None:
        Handler.metadata_seen = False
        Handler.archive_seen = b""
        Handler.login_status = 200
        Handler.metadata_status = 200
        Handler.put_status = 200
        Handler.send_auth_cookie = True
        Handler.metadata_requests = 0
        Handler.put_requests = 0
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.previous_endpoints = icos_client.ENDPOINTS["staging"]
        self.base = f"http://127.0.0.1:{self.server.server_port}"
        icos_client.ENDPOINTS["staging"] = {
            "auth": self.base + "/password/login",
            "meta": self.base + "/upload",
            "data": self.base,
        }

    def tearDown(self) -> None:
        icos_client.ENDPOINTS["staging"] = self.previous_endpoints
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def test_two_step_upload_and_receipt(self) -> None:
        with tempfile.TemporaryDirectory(dir=Path(__file__).parents[2]) as tmp:
            root = Path(tmp)
            archive = root / "IT-Tst_PHEN_20261027_L01_F01.zip"
            archive.write_bytes(b"test archive bytes")
            metadata = root / "metadata.json"
            icos_client.build_metadata(
                argparse.Namespace(
                    archive=str(archive),
                    day="2026-10-27",
                    utc_offset="+1",
                    submitter_id="ETC",
                    station_uri="http://meta.icos-cp.eu/resources/stations/ES_IT-Tst",
                    instrument_uri="http://meta.icos-cp.eu/resources/instruments/ETC_TEST",
                    expected_hash=None,
                    output=str(metadata),
                )
            )
            credentials = root / "credentials.txt"
            credentials.write_text("station@example.org\nsecret\n")
            registered = root / "registered.txt"
            receipt = root / "receipt.json"
            icos_client.upload(
                argparse.Namespace(
                    archive=str(archive),
                    metadata=str(metadata),
                    credentials=str(credentials),
                    registered=str(registered),
                    receipt=str(receipt),
                    environment="staging",
                )
            )

            self.assertTrue(Handler.metadata_seen)
            self.assertEqual(Handler.archive_seen, archive.read_bytes())
            self.assertTrue(registered.is_file())
            saved = json.loads(receipt.read_text())
            self.assertEqual(saved["dataResponse"], "Upload completed")
            self.assertEqual(saved["environment"], "staging")

    def _upload_paths(self, root: Path) -> argparse.Namespace:
        archive = root / "IT-Tst_PHEN_20261027_L01_F01.zip"
        archive.write_bytes(b"test archive bytes")
        metadata = root / "metadata.json"
        icos_client.build_metadata(
            argparse.Namespace(
                archive=str(archive),
                day="2026-10-27",
                utc_offset="+1",
                submitter_id="ETC",
                station_uri="http://meta.icos-cp.eu/resources/stations/ES_IT-Tst",
                instrument_uri="http://meta.icos-cp.eu/resources/instruments/ETC_TEST",
                expected_hash=None,
                output=str(metadata),
            )
        )
        credentials = root / "credentials.txt"
        credentials.write_text("station@example.org\nsecret\n")
        return argparse.Namespace(
            archive=str(archive),
            metadata=str(metadata),
            credentials=str(credentials),
            registered=str(root / "registered.txt"),
            receipt=str(root / "receipt.json"),
            environment="staging",
        )

    def test_login_without_token_stops_before_metadata_post(self) -> None:
        with tempfile.TemporaryDirectory(dir=Path(__file__).parents[2]) as tmp:
            args = self._upload_paths(Path(tmp))
            Handler.send_auth_cookie = False
            with self.assertRaises(icos_client.ConfigurationError):
                icos_client.upload(args)
            self.assertEqual(Handler.metadata_requests, 0)
            self.assertEqual(Handler.put_requests, 0)

    def test_retry_after_put_failure_does_not_repeat_metadata_post(self) -> None:
        with tempfile.TemporaryDirectory(dir=Path(__file__).parents[2]) as tmp:
            root = Path(tmp)
            args = self._upload_paths(root)
            Handler.put_status = 503
            with self.assertRaises(icos_client.RetryableError):
                icos_client.upload(args)
            self.assertTrue(Path(args.registered).is_file())
            self.assertFalse(Path(args.receipt).exists())
            self.assertEqual(Handler.metadata_requests, 1)
            self.assertEqual(Handler.put_requests, 1)

            Handler.put_status = 200
            icos_client.upload(args)
            self.assertEqual(Handler.metadata_requests, 1)
            self.assertEqual(Handler.put_requests, 2)
            self.assertTrue(Path(args.receipt).is_file())

    def test_retryable_and_permanent_http_failures_are_distinct(self) -> None:
        with tempfile.TemporaryDirectory(dir=Path(__file__).parents[2]) as tmp:
            args = self._upload_paths(Path(tmp))
            Handler.metadata_status = 503
            with self.assertRaises(icos_client.RetryableError):
                icos_client.upload(args)

            Handler.metadata_status = 400
            with self.assertRaises(icos_client.ConfigurationError):
                icos_client.upload(args)

    def test_credentials_require_exactly_two_lines(self) -> None:
        with tempfile.TemporaryDirectory(dir=Path(__file__).parents[2]) as tmp:
            credentials = Path(tmp) / "credentials.txt"
            credentials.write_text("station@example.org\nsecret\nextra\n")
            with self.assertRaises(icos_client.ConfigurationError):
                icos_client.read_credentials(credentials)

    def test_symlink_registration_marker_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory(dir=Path(__file__).parents[2]) as tmp:
            root = Path(tmp)
            args = self._upload_paths(root)
            target = root / "target.txt"
            target.write_text("registered")
            Path(args.registered).symlink_to(target)
            with self.assertRaises(icos_client.ConfigurationError):
                icos_client.upload(args)

    def test_cli_exit_codes_distinguish_retryable_and_configuration_errors(self) -> None:
        def raise_retryable(_: argparse.Namespace) -> None:
            raise icos_client.RetryableError("retry")

        def raise_configuration(_: argparse.Namespace) -> None:
            raise icos_client.ConfigurationError("blocked")

        fake_parser = mock.Mock()
        errors = io.StringIO()
        with mock.patch.object(icos_client, "parser", return_value=fake_parser), \
             contextlib.redirect_stderr(errors):
            fake_parser.parse_args.return_value = argparse.Namespace(handler=raise_retryable)
            self.assertEqual(icos_client.main(), icos_client.RETRYABLE_ERROR)

            fake_parser.parse_args.return_value = argparse.Namespace(
                handler=raise_configuration
            )
            self.assertEqual(icos_client.main(), icos_client.CONFIGURATION_ERROR)


if __name__ == "__main__":
    unittest.main()
