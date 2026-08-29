#!/usr/bin/env python3
"""Reject retired vendor identifiers from tracked repository paths and contents."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


def _tracked_files() -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        check=True,
        stdout=subprocess.PIPE,
    )
    return [Path(raw.decode("utf-8", "surrogateescape")) for raw in result.stdout.split(b"\0") if raw]


def _patterns() -> tuple[re.Pattern[bytes], re.Pattern[bytes]]:
    prefix = bytes((101, 108, 118))
    product = prefix + bytes((117, 105))
    exact = re.compile(
        br"(?i)(?:"
        + re.escape(product)
        + br"|"
        + re.escape(prefix)
        + br"(?:private|character|char)?db)"
    )
    derived = re.compile(br"(?i)(?<![a-z0-9_])" + re.escape(prefix) + br"[a-z0-9_]+")
    return exact, derived


def _matches(data: bytes, patterns: tuple[re.Pattern[bytes], re.Pattern[bytes]]) -> bool:
    return any(pattern.search(data) for pattern in patterns)


def main() -> int:
    patterns = _patterns()
    findings: list[str] = []

    for path in _tracked_files():
        encoded_path = path.as_posix().encode("utf-8", "surrogateescape")
        if _matches(encoded_path, patterns):
            findings.append(f"path: {path.as_posix()}")

        try:
            payload = path.read_bytes()
        except OSError as error:
            findings.append(f"unreadable: {path.as_posix()}: {error}")
            continue

        if _matches(payload, patterns):
            findings.append(f"content: {path.as_posix()}")

    if findings:
        print("Retired vendor references found:", file=sys.stderr)
        for finding in findings:
            print(f"  {finding}", file=sys.stderr)
        return 1

    print("Repository text guard passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
