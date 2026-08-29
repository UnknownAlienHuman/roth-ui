#!/usr/bin/env python3
"""Build and verify a deterministic single-root Roth UI release archive."""

from __future__ import annotations

import argparse
import hashlib
import sys
import zipfile
from pathlib import Path, PurePosixPath

import validate_addon

ROOT = Path(__file__).resolve().parents[1]
VERSION = validate_addon.VERSION
FIXED_TIME = (2026, 1, 1, 0, 0, 0)
SERVICE_NAMES = {
    ".git", ".github", "tools", "tests", "todo.md", "todo.archive.md", "audit.md",
    "history.md", "addon_map.md", "AGENT_GUIDE.md", "ARCHITECTURE.md", "CODE_GRAPH.md",
    "CODE_INDEX.md", "CURRENT_STATUS.md", "MIDNIGHT_12_1_MIGRATION.md", "README.md",
    "STOP.txt", "_branch_marker.txt", "_probe_do_not_keep.txt", "oops.txt",
}


def graph_paths() -> set[PurePosixPath]:
    _, direct = validate_addon.parse_toc(validate_addon.MAIN_TOC)
    return {entry.path for entry in validate_addon.expand(direct)}


def collect() -> dict[PurePosixPath, Path]:
    files: dict[PurePosixPath, Path] = {}

    def add(source: Path, archive: PurePosixPath) -> None:
        if not source.is_file():
            raise RuntimeError(f"missing package file: {source.relative_to(ROOT)}")
        files[archive] = source

    add(validate_addon.MAIN_TOC, PurePosixPath("Roth_UI/Roth_UI.toc"))
    for rel in graph_paths():
        add(ROOT / rel, PurePosixPath("Roth_UI") / rel)

    for name in ("LICENSE.txt", "Credits.txt"):
        add(ROOT / name, PurePosixPath("Roth_UI") / name)

    for source in sorted((ROOT / "media").rglob("*")):
        if source.is_file():
            rel = PurePosixPath(source.relative_to(ROOT).as_posix())
            add(source, PurePosixPath("Roth_UI") / rel)

    return files


def build(output: Path) -> tuple[str, int]:
    validate_addon.main()
    files = collect()
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for archive_path in sorted(files, key=str):
            data = files[archive_path].read_bytes()
            info = zipfile.ZipInfo(str(archive_path), FIXED_TIME)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            info.create_system = 3
            archive.writestr(info, data)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    verify(output)
    return digest, len(files)


def verify(path: Path) -> None:
    if not path.is_file():
        raise RuntimeError(f"archive does not exist: {path}")
    expected = {str(item) for item in collect()}
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise RuntimeError("duplicate ZIP paths")
        if names != sorted(names):
            raise RuntimeError("ZIP paths are not deterministic/sorted")
        actual = set(names)
        if actual != expected:
            raise RuntimeError(
                f"package mismatch: missing={sorted(expected-actual)[:10]} extra={sorted(actual-expected)[:10]}"
            )
        for name in names:
            parts = PurePosixPath(name).parts
            if any(part in SERVICE_NAMES or part.startswith("todo") for part in parts):
                raise RuntimeError(f"service file leaked into package: {name}")
            if not name.startswith("Roth_UI/"):
                raise RuntimeError(f"unexpected archive root: {name}")
        if "Roth_UI/Roth_UI.toc" not in actual:
            raise RuntimeError("Roth_UI/Roth_UI.toc is missing")
        if any(name.startswith("Roth_UI_Options/") for name in actual):
            raise RuntimeError("separate options addon leaked into package")
        bad = archive.testzip()
        if bad:
            raise RuntimeError(f"corrupt ZIP member: {bad}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", nargs="?", type=Path, default=ROOT / "dist" / f"Roth_UI-{VERSION}.zip")
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    if args.verify:
        verify(args.output)
        print(f"verified {args.output}")
    else:
        digest, count = build(args.output)
        print(f"built {args.output}: {count} files, sha256={digest}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, validate_addon.ValidationError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
