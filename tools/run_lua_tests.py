#!/usr/bin/env python3
"""Parse all addon Lua and run every isolated regression with Lua 5.1."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lua", default=os.environ.get("LUA_BIN") or shutil.which("lua5.1") or shutil.which("lua"))
    parser.add_argument("--luac", default=os.environ.get("LUAC_BIN") or shutil.which("luac5.1"),
                        help="Optional Lua 5.1 compiler; otherwise use the interpreter's native loadfile parser")
    args = parser.parse_args()
    if not args.lua:
        parser.error("Lua 5.1 was not found; pass --lua PATH or set LUA_BIN")
    subprocess.run([args.lua, "-e", 'assert(_VERSION == "Lua 5.1", "Lua 5.1 is required")'], check=True)

    sources = sorted(path for path in ROOT.rglob("*.lua") if ".git" not in path.parts)
    if args.luac:
        version = subprocess.run([args.luac, "-v"], capture_output=True, text=True, check=True)
        if "Lua 5.1" not in version.stdout + version.stderr:
            raise SystemExit("Lua 5.1 compiler is required")
        for source in sources:
            subprocess.run([args.luac, "-p", str(source)], cwd=ROOT, check=True)
    else:
        checks = "\n".join(f"assert(loadfile({json.dumps(source.relative_to(ROOT).as_posix())}))" for source in sources)
        subprocess.run([args.lua, "-"], input=checks, text=True, cwd=ROOT, check=True)
    tests = sorted((ROOT / "tests").glob("test_*.lua"))
    if not tests:
        raise SystemExit("No Lua regression tests found")
    for test in tests:
        subprocess.run([args.lua, str(test.relative_to(ROOT))], cwd=ROOT, check=True)
    print(f"Lua 5.1: parsed {len(sources)} files; passed {len(tests)} isolated regressions.")


if __name__ == "__main__":
    main()
