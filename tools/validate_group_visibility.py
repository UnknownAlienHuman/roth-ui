#!/usr/bin/env python3
"""Guard exact oUF group-header visibility and ownership semantics."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VISIBILITY = ROOT / "core" / "group_header_visibility.lua"
TEST = ROOT / "tests" / "test_group_header_visibility.lua"
PARTY = ROOT / "units" / "party.lua"
RAID = ROOT / "units" / "raid.lua"
FRAME_POLICY = ROOT / "core" / "frame_policy.lua"


def fail(message: str) -> None:
    raise SystemExit(f"ERROR: {message}")


def main() -> int:
    runtime = VISIBILITY.read_text(encoding="utf-8-sig")
    regression = TEST.read_text(encoding="utf-8-sig")
    party = PARTY.read_text(encoding="utf-8-sig")
    raid = RAID.read_text(encoding="utf-8-sig")
    frame_policy = FRAME_POLICY.read_text(encoding="utf-8-sig")

    for forbidden in ("SetParent", "hiddenParents"):
        if forbidden in runtime:
            fail(f"secure group-header owner contains forbidden token: {forbidden}")

    for required in (
        'value == "show" or value == "hide"',
        'return "custom " .. value',
        'function service.ApplyDesired',
        'function service.GetDesired',
        'function service.Park(frame)',
        '__mode = "k"',
    ):
        if required not in runtime:
            fail(f"group-header visibility contract missing: {required}")

    for required in (
        'calls[2] == "custom hide"',
        'calls[4] == "custom show"',
        'temporary hide overwrote desired visibility',
        'temporary show overwrote desired visibility',
    ):
        if required not in regression:
            fail(f"group-header regression assertion missing: {required}")

    for path, text in (("units/party.lua", party), ("units/raid.lua", raid)):
        for forbidden in (
            "__roth_vis",
            "SetParent(UIParent)",
            "RebuildPartyStructureRuntime",
            "RebuildRaidStructureRuntime",
            "__rothPartyPendingEnabled",
            "__rothRaidPendingEnabled",
            "partyRegenHook",
            "raidRegenHook",
        ):
            if forbidden in text:
                fail(f"secure header layout contains retired mutation in {path}: {forbidden}")
        for required in ("groupVisibility.ApplyDesired", "framePolicy.DeferUntilOutOfCombat"):
            if required not in text:
                fail(f"secure header layout contract missing in {path}: {required}")

    for required in (
        'self:UnregisterEvent("PLAYER_REGEN_ENABLED")',
        "local work = pending",
        "pending = {}",
        "TryCall(callback)",
        "CanUseRegion",
    ):
        if required not in frame_policy:
            fail(f"shared out-of-combat queue contract missing: {required}")

    print("Group-header visibility semantic guard passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
