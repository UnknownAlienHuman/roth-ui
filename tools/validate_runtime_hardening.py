#!/usr/bin/env python3
"""Static guard for lazy Settings, bounded bootstrap and safe action skinning."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    raise SystemExit(f"ERROR: {message}")


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def assert_contains(text: str, token: str, label: str) -> None:
    if token not in text:
        fail(f"{label} missing: {token}")


def main() -> int:
    toc_lines = [line.strip().replace("\\", "/") for line in read("Roth_UI.toc").splitlines()]
    try:
        safety_pos = toc_lines.index("core/safety.lua")
        aspects_pos = toc_lines.index("core/safety_aspects.lua")
        contract_pos = toc_lines.index("core/ouf_contract.lua")
    except ValueError as error:
        fail(f"required safety load-order entry missing: {error}")
    if not safety_pos < aspects_pos < contract_pos:
        fail("safety_aspects.lua must load after safety.lua and before ouf_contract.lua")

    aspects = read("core/safety_aspects.lua")
    for token in (
        "HasAnyForbiddenAspects",
        "function safety.HasForbiddenAspect",
        "function safety.CanUseRegionFor",
        "ReportGuardFailure",
    ):
        assert_contains(aspects, token, "forbidden-aspect guard")

    settings = read("core/settings_main.lua")
    if "ContinueOnOwnAddonLoaded" in settings:
        fail("Settings registration must not force eager registration on Roth ADDON_LOADED")
    for token in (
        "RegisterWhenBlizzardSettingsLoads",
        'ContinueOnAddOnLoaded("Blizzard_Settings"',
        "ui.registering",
        'self:UnregisterEvent("PLAYER_REGEN_ENABLED")',
        'C_AddOns.LoadAddOn("Blizzard_Settings")',
    ):
        assert_contains(settings, token, "lazy Settings lifecycle")

    bootstrap = read("core/frame_policy_bootstrap.lua")
    for token in (
        'ContinueOnAddOnLoaded',
        'self:UnregisterEvent("PLAYER_LOGIN")',
        'self:UnregisterEvent("ADDON_LOADED")',
        'self:SetScript("OnEvent", nil)',
        'Blizzard_UnitFrame',
        'Blizzard_CompactRaidFrames',
    ):
        assert_contains(bootstrap, token, "bounded frame-policy bootstrap")

    skin = read("core/action_button_skin.lua")
    for forbidden in ("__rothSkinBackground", "__rothSkinBorder"):
        if forbidden in skin:
            fail(f"action-button skin stores private metadata on Blizzard button: {forbidden}")
    for token in (
        "CanUseRegionFor",
        "SET_TEXTURE_ASPECT",
        '__mode = "k"',
        "PLAYER_REGEN_ENABLED",
        "backgroundAttempted",
        "borderAttempted",
        "TryMethod",
    ):
        assert_contains(skin, token, "action-button safety contract")

    for test_path in (
        "tests/test_safety_aspects.lua",
        "tests/test_frame_policy_bootstrap.lua",
        "tests/test_settings_lifecycle.lua",
        "tests/test_action_button_skin.lua",
    ):
        if not (ROOT / test_path).is_file():
            fail(f"missing regression test: {test_path}")

    print("Runtime hardening guard passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
