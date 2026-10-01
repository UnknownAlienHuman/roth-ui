#!/usr/bin/env python3
"""Guard exact oUF group-header visibility semantics."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VISIBILITY = ROOT / "core" / "group_header_visibility.lua"
TEST = ROOT / "tests" / "test_group_header_visibility.lua"


def fail(message: str) -> None:
    raise SystemExit(f"ERROR: {message}")


def main() -> int:
    runtime = VISIBILITY.read_text(encoding="utf-8-sig")
    regression = TEST.read_text(encoding="utf-8-sig")

    for forbidden in ("SetParent", "hiddenParents"):
        if forbidden in runtime:
            fail(f"secure group-header owner contains forbidden token: {forbidden}")

    for required in (
        'value == "show" or value == "hide"',
        'return "custom " .. value',
        'function service.Park(frame)',
        '__mode = "k"',
    ):
        if required not in runtime:
            fail(f"group-header visibility contract missing: {required}")

    for required in ('calls[2] == "custom hide"', 'calls[3] == "custom show"'):
        if required not in regression:
            fail(f"group-header regression assertion missing: {required}")

    print("Group-header visibility semantic guard passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
