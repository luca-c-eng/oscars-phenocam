#!/usr/bin/env python3
"""Build ICOS metadata packages and perform the standard two-step upload."""

from __future__ import annotations

import argparse
import hashlib
import http.client
import http.cookiejar
import json
import os
import re
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from datetime import date, datetime, time, timedelta, timezone
from pathlib import Path
from typing import Iterable


OBJECT_SPECIFICATION = "http://meta.icos-cp.eu/resources/cpmeta/etcPhenocamDaily"
ICOS_LICENCE = "http://meta.icos-cp.eu/ontologies/cpmeta/icosLicence"

ENDPOINTS = {
    "staging": {
        "auth": "https://cpauthstaging.icos-cp.eu/password/login",
        "meta": "https://metastaging.icos-cp.eu/upload",
        "data": "https://datastaging.icos-cp.eu",
    },
    "production": {
        "auth": "https://cpauth.icos-cp.eu/password/login",
        "meta": "https://meta.icos-cp.eu/upload",
        "data": "https://data.icos-cp.eu",
    },
}

RETRYABLE_ERROR = 10
CONFIGURATION_ERROR = 20


class IcosClientError(RuntimeError):
    """Base error for the ICOS client."""


class RetryableError(IcosClientError):
    """Network or server failure that may succeed on a later attempt."""


class ConfigurationError(IcosClientError):
    """Local configuration or permanent request error."""


def atomic_write(path: Path, data: bytes, mode: int = 0o600) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    tmp_path = Path(tmp_name)
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp_path, path)
    finally:
        try:
            tmp_path.unlink()
        except FileNotFoundError:
            pass


def sha256_hex(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_fixed_offset(raw: str) -> timezone:
    match = re.fullmatch(r"([+-]?)(\d{1,2})(?::([0-5]\d))?", raw)
    if not match:
        raise ConfigurationError(f"Invalid UTC offset: {raw}")
    sign_text, hours_text, minutes_text = match.groups()
    hours = int(hours_text)
    minutes = int(minutes_text or "0")
    if hours > 14 or (hours == 14 and minutes):
        raise ConfigurationError(f"UTC offset outside supported range: {raw}")
    sign = -1 if sign_text == "-" else 1
    return timezone(sign * timedelta(hours=hours, minutes=minutes))


def utc_day_interval(day_text: str, offset_text: str) -> tuple[str, str]:
    day = date.fromisoformat(day_text)
    station_tz = parse_fixed_offset(offset_text)
    start = datetime.combine(day, time.min, station_tz).astimezone(timezone.utc)
    stop = start + timedelta(days=1)

    def render(value: datetime) -> str:
        return value.isoformat(timespec="seconds").replace("+00:00", "Z")

    return render(start), render(stop)


def build_metadata(args: argparse.Namespace) -> None:
    archive = Path(args.archive)
    if not archive.is_file() or archive.is_symlink():
        raise ConfigurationError(f"Archive is unavailable or unsafe: {archive}")

    checksum = sha256_hex(archive)
    if args.expected_hash and checksum != args.expected_hash:
        raise ConfigurationError("Archive checksum changed before metadata generation")

    start, stop = utc_day_interval(args.day, args.utc_offset)
    payload = {
        "submitterId": args.submitter_id,
        "hashSum": checksum,
        "fileName": archive.name,
        "specificInfo": {
            "station": args.station_uri,
            "acquisitionInterval": {"start": start, "stop": stop},
            "instrument": args.instrument_uri,
        },
        "objectSpecification": OBJECT_SPECIFICATION,
        "references": {"licence": ICOS_LICENCE},
    }
    encoded = (json.dumps(payload, indent=2, sort_keys=True) + "\n").encode()
    atomic_write(Path(args.output), encoded, 0o600)


def read_credentials(path: Path) -> tuple[str, str]:
    if not path.is_file() or path.is_symlink():
        raise ConfigurationError(f"Credentials file is unavailable or unsafe: {path}")
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        raise ConfigurationError(f"Credentials file cannot be read: {path}") from exc
    if len(lines) != 2 or not lines[0] or not lines[1]:
        raise ConfigurationError(
            "Credentials file must contain exactly the account email on line 1 "
            "and password on line 2"
        )
    return lines[0], lines[1]


def response_body(response: object) -> str:
    data = response.read()  # type: ignore[attr-defined]
    return data.decode("utf-8", errors="replace").strip()


def authenticate(opener: urllib.request.OpenerDirector, url: str, email: str, password: str) -> None:
    form = urllib.parse.urlencode({"mail": email, "password": password}).encode()
    request = urllib.request.Request(
        url,
        data=form,
        method="POST",
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    try:
        with opener.open(request, timeout=60) as response:
            response.read()
    except urllib.error.HTTPError as exc:
        detail = response_body(exc)
        if 500 <= exc.code:
            raise RetryableError(f"CPauth server error {exc.code}: {detail}") from exc
        raise ConfigurationError(f"CPauth rejected the account ({exc.code}): {detail}") from exc
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise RetryableError(f"CPauth connection failed: {exc}") from exc


def cookie_header(cookie_jar: http.cookiejar.CookieJar, url: str) -> str:
    request = urllib.request.Request(url)
    cookie_jar.add_cookie_header(request)
    value = request.get_header("Cookie")
    if not value or "cpauthToken=" not in value:
        raise ConfigurationError("CPauth login did not return a cpauthToken cookie")
    return value


def post_metadata(
    opener: urllib.request.OpenerDirector,
    url: str,
    metadata_path: Path,
) -> str:
    payload = metadata_path.read_bytes()
    request = urllib.request.Request(
        url,
        data=payload,
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    try:
        with opener.open(request, timeout=120) as response:
            body = response_body(response)
            if not 200 <= response.status < 300:
                raise RetryableError(f"Unexpected metadata response {response.status}: {body}")
            return body
    except urllib.error.HTTPError as exc:
        detail = response_body(exc)
        if exc.code >= 500 or exc.code in (408, 429):
            raise RetryableError(f"Metadata service error {exc.code}: {detail}") from exc
        raise ConfigurationError(f"Metadata package rejected ({exc.code}): {detail}") from exc
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise RetryableError(f"Metadata service connection failed: {exc}") from exc


def file_chunks(path: Path, chunk_size: int = 1024 * 1024) -> Iterable[bytes]:
    with path.open("rb") as handle:
        while chunk := handle.read(chunk_size):
            yield chunk


def put_archive(url: str, cookie: str, archive: Path) -> str:
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise ConfigurationError(f"Invalid data service URL: {url}")
    connection_cls = (
        http.client.HTTPSConnection if parsed.scheme == "https" else http.client.HTTPConnection
    )
    port = parsed.port or (443 if parsed.scheme == "https" else 80)
    connection = connection_cls(parsed.hostname, port, timeout=900)
    path = urllib.parse.urlunsplit(("", "", parsed.path, parsed.query, ""))
    try:
        connection.request(
            "PUT",
            path,
            body=file_chunks(archive),
            headers={
                "Cookie": cookie,
                "Content-Type": "application/octet-stream",
                "Transfer-Encoding": "chunked",
            },
            encode_chunked=True,
        )
        response = connection.getresponse()
        body = response.read().decode("utf-8", errors="replace").strip()
        if 200 <= response.status < 300:
            return body
        if response.status >= 500 or response.status in (408, 429):
            raise RetryableError(f"Data service error {response.status}: {body}")
        raise ConfigurationError(f"Data object rejected ({response.status}): {body}")
    except (TimeoutError, OSError, http.client.HTTPException) as exc:
        raise RetryableError(f"Data service connection failed: {exc}") from exc
    finally:
        connection.close()


def upload(args: argparse.Namespace) -> None:
    archive = Path(args.archive)
    metadata = Path(args.metadata)
    registered_path = Path(args.registered)
    receipt_path = Path(args.receipt)
    if not archive.is_file() or archive.is_symlink():
        raise ConfigurationError(f"Archive is unavailable or unsafe: {archive}")
    if not metadata.is_file() or metadata.is_symlink():
        raise ConfigurationError(f"Metadata package is unavailable or unsafe: {metadata}")

    try:
        payload = json.loads(metadata.read_text(encoding="utf-8"))
    except OSError as exc:
        raise ConfigurationError(f"Metadata package cannot be read: {metadata}") from exc
    if not isinstance(payload, dict):
        raise ConfigurationError("Metadata package must contain one JSON object")
    checksum = sha256_hex(archive)
    if payload.get("hashSum") != checksum or payload.get("fileName") != archive.name:
        raise ConfigurationError("Archive no longer matches its metadata package")

    endpoints = ENDPOINTS[args.environment]
    email, password = read_credentials(Path(args.credentials))
    cookie_jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cookie_jar))
    authenticate(opener, endpoints["auth"], email, password)
    # Fail before metadata registration when CPauth returned a successful HTTP
    # response without the authentication cookie required by both services.
    cookie_header(cookie_jar, endpoints["meta"])

    if registered_path.exists():
        if not registered_path.is_file() or registered_path.is_symlink():
            raise ConfigurationError(
                f"Registration marker is unavailable or unsafe: {registered_path}"
            )
        try:
            registration_response = registered_path.read_text(encoding="utf-8").strip()
        except OSError as exc:
            raise ConfigurationError(
                f"Registration marker cannot be read: {registered_path}"
            ) from exc
    else:
        registration_response = post_metadata(opener, endpoints["meta"], metadata)
        atomic_write(registered_path, (registration_response + "\n").encode(), 0o600)

    object_url = f"{endpoints['data']}/objects/{checksum}"
    cookie = cookie_header(cookie_jar, object_url)
    data_response = put_archive(object_url, cookie, archive)
    receipt = {
        "completedAt": datetime.now(timezone.utc).isoformat(timespec="seconds").replace(
            "+00:00", "Z"
        ),
        "environment": args.environment,
        "fileName": archive.name,
        "hashSum": checksum,
        "metadataResponse": registration_response,
        "objectUrl": object_url,
        "dataResponse": data_response,
    }
    atomic_write(
        receipt_path,
        (json.dumps(receipt, indent=2, sort_keys=True) + "\n").encode(),
        0o600,
    )


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    subparsers = result.add_subparsers(dest="command", required=True)

    metadata_parser = subparsers.add_parser("build-metadata")
    metadata_parser.add_argument("--archive", required=True)
    metadata_parser.add_argument("--day", required=True)
    metadata_parser.add_argument("--utc-offset", required=True)
    metadata_parser.add_argument("--submitter-id", required=True)
    metadata_parser.add_argument("--station-uri", required=True)
    metadata_parser.add_argument("--instrument-uri", required=True)
    metadata_parser.add_argument("--expected-hash")
    metadata_parser.add_argument("--output", required=True)
    metadata_parser.set_defaults(handler=build_metadata)

    upload_parser = subparsers.add_parser("upload")
    upload_parser.add_argument("--environment", choices=sorted(ENDPOINTS), required=True)
    upload_parser.add_argument("--archive", required=True)
    upload_parser.add_argument("--metadata", required=True)
    upload_parser.add_argument("--credentials", required=True)
    upload_parser.add_argument("--registered", required=True)
    upload_parser.add_argument("--receipt", required=True)
    upload_parser.set_defaults(handler=upload)
    return result


def main() -> int:
    args = parser().parse_args()
    try:
        args.handler(args)
        return 0
    except RetryableError as exc:
        print(str(exc), file=sys.stderr)
        return RETRYABLE_ERROR
    except (ConfigurationError, json.JSONDecodeError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return CONFIGURATION_ERROR


if __name__ == "__main__":
    raise SystemExit(main())
