#!/usr/bin/env python3
"""Validate and atomically maintain OSCARS detection metadata state."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import stat
import sys
import tempfile


MODES = ("metadata", "annotated", "privacy", "delete")
VISION_FIELDS = {
    "detected", "software_name", "software_version", "model_id", "model_version",
    "annotated_image", "privacy_image", "classes", "total_count",
}
VISION_IDENTITY = {
    "software_name": "phenocam-detection",
    "software_version": "0.2.3",
    "model_id": "yolo26n-phenocam",
    "model_version": "0.1.6",
}

_LINE_ENDING = re.compile(r"\r\n|\r|\n")
_SECTION_HEADER = re.compile(r"\[([^\[\]]+)\]")
_FIELD_KEY = re.compile(r"[A-Za-z][A-Za-z0-9_]*")


class MetadataError(RuntimeError):
    """Report one fixed public error for invalid or unsafe metadata."""


def _line_content(line: str) -> str:
    return _LINE_ENDING.sub("", line, count=1).strip(" \t")


def _section_name(line: str) -> str | None:
    match = _SECTION_HEADER.fullmatch(_line_content(line))
    return match.group(1) if match else None


def _detection_ranges(lines: list[str]) -> list[tuple[int, int]]:
    ranges: list[tuple[int, int]] = []
    start: int | None = None
    for index, line in enumerate(lines):
        name = _section_name(line)
        if name is None:
            continue
        if start is not None:
            ranges.append((start, index))
            start = None
        if name == "detection":
            start = index
    if start is not None:
        ranges.append((start, len(lines)))
    return ranges


def _fields(lines: list[str], start: int, end: int) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in lines[start + 1 : end]:
        content = _line_content(line)
        if not content:
            continue
        if "=" not in content:
            raise MetadataError()
        key, value = content.split("=", 1)
        if not _FIELD_KEY.fullmatch(key) or key in result:
            raise MetadataError()
        result[key] = value
    return result


def _validate_vision(fields: dict[str, str]) -> None:
    if not VISION_FIELDS.issubset(fields):
        raise MetadataError()
    if any(fields[key] != value for key, value in VISION_IDENTITY.items()):
        raise MetadataError()
    if fields["detected"] not in ("true", "false"):
        raise MetadataError()
    if not fields["total_count"].isdigit():
        raise MetadataError()
    count = int(fields["total_count"])
    if (count > 0) != (fields["detected"] == "true"):
        raise MetadataError()
    if (count > 0) != bool(fields["classes"]):
        raise MetadataError()


def _read(path: Path) -> tuple[str, os.stat_result]:
    try:
        status = path.stat(follow_symlinks=False)
        if path.suffix.lower() != ".meta" or not stat.S_ISREG(status.st_mode):
            raise MetadataError()
        return path.read_bytes().decode("utf-8", errors="strict"), status
    except MetadataError:
        raise
    except Exception:
        raise MetadataError() from None


def _state(text: str) -> str:
    lines = text.splitlines(keepends=True)
    ranges = _detection_ranges(lines)
    if not ranges:
        return "pending"
    if len(ranges) != 1:
        raise MetadataError()

    fields = _fields(lines, *ranges[0])
    has_enabled = "filter_enabled" in fields
    has_mode = "filter_mode" in fields
    if has_enabled != has_mode:
        raise MetadataError()

    if not has_enabled:
        _validate_vision(fields)
        return "vision"

    if tuple(fields)[:2] != ("filter_enabled", "filter_mode"):
        raise MetadataError()
    if fields["filter_mode"] not in MODES:
        raise MetadataError()
    if fields["filter_enabled"] == "off":
        if set(fields) != {"filter_enabled", "filter_mode"}:
            raise MetadataError()
        return "off"
    if fields["filter_enabled"] != "on":
        raise MetadataError()

    _validate_vision(fields)
    return "ready"


def _separator(text: str, line_ending: str) -> str:
    if not text:
        return ""
    match = re.search(r"(?:\r\n|\r|\n)+$", text)
    ending_count = len(_LINE_ENDING.findall(match.group())) if match else 0
    return line_ending * max(0, 2 - ending_count)


def _write_atomic(path: Path, text: str, original: os.stat_result) -> None:
    descriptor: int | None = None
    temporary_path: Path | None = None
    committed = False
    try:
        current = path.stat(follow_symlinks=False)
        if not stat.S_ISREG(current.st_mode) or (
            current.st_dev,
            current.st_ino,
        ) != (original.st_dev, original.st_ino):
            raise MetadataError()
        descriptor, name = tempfile.mkstemp(
            prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
        )
        temporary_path = Path(name)
        with os.fdopen(descriptor, "wb") as temporary:
            descriptor = None
            os.fchmod(temporary.fileno(), stat.S_IMODE(original.st_mode))
            temporary.write(text.encode("utf-8"))
            temporary.flush()
            os.fsync(temporary.fileno())
        os.replace(temporary_path, path)
        committed = True
    except MetadataError:
        raise
    except Exception:
        raise MetadataError() from None
    finally:
        if descriptor is not None:
            try:
                os.close(descriptor)
            except OSError:
                pass
        if temporary_path is not None and not committed:
            try:
                temporary_path.unlink()
            except OSError:
                pass


def mark_off(path: Path, mode: str) -> None:
    text, status = _read(path)
    if _state(text) != "pending":
        raise MetadataError()
    line_match = _LINE_ENDING.search(text)
    ending = line_match.group() if line_match else "\n"
    section = ending.join(
        ("[detection]", "filter_enabled=off", f"filter_mode={mode}")
    ) + ending
    _write_atomic(path, text + _separator(text, ending) + section, status)


def mark_on(path: Path, mode: str) -> None:
    text, status = _read(path)
    if _state(text) != "vision":
        raise MetadataError()
    lines = text.splitlines(keepends=True)
    start, _ = _detection_ranges(lines)[0]
    ending_match = _LINE_ENDING.search(text)
    ending = ending_match.group() if ending_match else "\n"
    fields = (f"filter_enabled=on{ending}", f"filter_mode={mode}{ending}")
    lines[start + 1 : start + 1] = fields
    _write_atomic(path, "".join(lines), status)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Maintain OSCARS detection metadata state."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    status_parser = subparsers.add_parser("status")
    status_parser.add_argument("--meta", required=True, type=Path)

    for command in ("mark-off", "mark-on"):
        command_parser = subparsers.add_parser(command)
        command_parser.add_argument("--meta", required=True, type=Path)
        command_parser.add_argument("--mode", required=True, choices=MODES)

    arguments = parser.parse_args()
    try:
        if arguments.command == "status":
            text, _ = _read(arguments.meta)
            print(_state(text))
        elif arguments.command == "mark-off":
            mark_off(arguments.meta, arguments.mode)
        else:
            mark_on(arguments.meta, arguments.mode)
    except MetadataError:
        print("error: detection metadata is invalid", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
