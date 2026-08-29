#!/usr/bin/env python3
"""Build and verify a deterministic, runtime-only Roth UI release archive."""

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


def graph_paths(toc: Path, addon_root: Path) -> set[PurePosixPath]:
    _, direct = validate_addon.parse_toc(toc, addon_root)
    return {entry.path for entry in validate_addon.expand(direct)}


def collect() -> dict[PurePosixPath, Path]:
    files: dict[PurePosixPath, Path] = {}
    main_graph = graph_paths(validate_addon.MAIN_TOC, ROOT)
    options_graph = graph_paths(validate_addon.OPTIONS_TOC, validate_addon.OPTIONS_ROOT)

    def add(source: Path, archive: PurePosixPath) -> None:
        if not source.is_file():
            raise RuntimeError(f"missing package file: {source.relative_to(ROOT)}")
        files[archive] = source

    add(validate_addon.MAIN_TOC, PurePosixPath("Roth_UI/Roth_UI.toc"))
    for rel in main_graph:
        add(ROOT / rel, PurePosixPath("Roth_UI") / rel)

    for name in ("LICENSE.txt", "Credits.txt"):
        add(ROOT / name, PurePosixPath("Roth_UI") / name)

    for base in (ROOT / "media",):
        for source in sorted(base.rglob("*")):
            if source.is_file():
                rel = PurePosixPath(source.relative_to(ROOT).as_posix())
                add(source, PurePosixPath("Roth_UI") / rel)

    add(validate_addon.OPTIONS_TOC, PurePosixPath("Roth_UI_Options/Roth_UI_Options.toc"))
    for rel in options_graph:
        local = PurePosixPath(*rel.parts[1:])
        add(ROOT / rel, PurePosixPath("Roth_UI_Options") / local)

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
    expected = {str(path) for path in collect()}
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise RuntimeError("duplicate ZIP paths")
        if names != sorted(names):
            raise RuntimeError("ZIP paths are not deterministic/sorted")
        actual = set(names)
        if actual != expected:
            missing = sorted(expected - actual)
            extra = sorted(actual - expected)
            raise RuntimeError(f"package mismatch: missing={missing[:10]} extra={extra[:10]}")
        for name in names:
            parts = PurePosixPath(name).parts
            if any(part in SERVICE_NAMES or part.startswith("todo") for part in parts):
                raise RuntimeError(f"service file leaked into package: {name}")
            if not (name.startswith("Roth_UI/") or name.startswith("Roth_UI_Options/")):
                raise RuntimeError(f"unexpected archive root: {name}")
        if "Roth_UI/Roth_UI.toc" not in actual or "Roth_UI_Options/Roth_UI_Options.toc" not in actual:
            raise RuntimeError("required addon roots are missing")
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
