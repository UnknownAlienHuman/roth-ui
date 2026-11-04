#!/usr/bin/env python3
"""Static guard for lazy Settings, bounded lifecycle and transactional persistence."""

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


def assert_absent(text: str, token: str, label: str) -> None:
    if token in text:
        fail(f"{label} must not contain: {token}")


def main() -> int:
    toc = read("Roth_UI.toc")
    toc_lines = [line.strip().replace("\\", "/") for line in toc.splitlines()]
    try:
        safety_pos = toc_lines.index("core/safety.lua")
        aspects_pos = toc_lines.index("core/safety_aspects.lua")
        contract_pos = toc_lines.index("core/ouf_contract.lua")
    except ValueError as error:
        fail(f"required safety load-order entry missing: {error}")
    if not safety_pos < aspects_pos < contract_pos:
        fail("safety_aspects.lua must load after safety.lua and before ouf_contract.lua")
    assert_absent(toc, "## OptionalDeps:", "retired optional dependency metadata")

    workflow = read(".github/workflows/addon-static-validation.yml")
    for token in ("pull_request:", "push:", "workflow_dispatch:", "cancel-in-progress: true"):
        assert_contains(workflow, token, "automatic validation workflow")

    safety = read("core/safety.lua")
    for token in (
        "canaccessvalue",
        "CopySerializableStrict",
        "if strict then",
        "Shared-reference graphs",
    ):
        assert_contains(safety, token, "strict serialization boundary")

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
        "DeferUntilOutOfCombat",
        'C_AddOns.LoadAddOn("Blizzard_Settings")',
    ):
        assert_contains(settings, token, "lazy Settings lifecycle")

    bootstrap = read("core/frame_policy_bootstrap.lua")
    for token in (
        "ContinueOnAddOnLoaded",
        'self:UnregisterEvent("PLAYER_LOGIN")',
        'self:UnregisterEvent("ADDON_LOADED")',
        'self:SetScript("OnEvent", nil)',
        "Blizzard_UnitFrame",
        "Blizzard_CompactRaidFrames",
    ):
        assert_contains(bootstrap, token, "bounded frame-policy bootstrap")

    frame_policy = read("core/frame_policy.lua")
    for token in (
        "ApplyProperty",
        "RestoreTrackedState",
        "state.appliedAlpha",
        "state.appliedMouse",
        'UnregisterEvent("PLAYER_REGEN_ENABLED")',
    ):
        assert_contains(frame_policy, token, "transactional frame policy")

    control_plane = read("core/persistence_control_plane.lua")
    for token in (
        "CopySerializableStrict",
        "SnapshotCanonicalRoots",
        "ValidateTransferPayload",
        "RestoreSnapshot",
        "ReconcileAccepted",
        "persistenceApi.RebuildRuntime = persistenceApi.Reconcile",
    ):
        assert_contains(control_plane, token, "transactional persistence control plane")
    assert_absent(control_plane, 'RegisterEvent("ADDON_LOADED")', "persistence control plane")
    assert_absent(control_plane, "persistenceApi.Sanitize({ logoutEvent = false })", "export path")

    root_store = read("core/persistence_root_store.lua")
    assert_contains(root_store, "CopySerializableStrict", "detached root replacement")
    assert_absent(root_store, "local CopySerializable =", "detached root replacement")

    transfer = read("core/transfer.lua")
    for token in (
        "CopySerializableStrict",
        "SavedVariables could not be copied for export.",
        "ApplyTransferRoots",
    ):
        assert_contains(transfer, token, "transfer boundary")
    assert_absent(transfer, "local CopySerializable =", "transfer boundary")

    skin = read("core/action_button_skin.lua")
    for forbidden in ("__rothSkinBackground", "__rothSkinBorder"):
        if forbidden in skin:
            fail(f"action-button skin stores private metadata on Blizzard button: {forbidden}")
    for token in (
        "CanUseRegionFor",
        "SET_TEXTURE_ASPECT",
        '__mode = "k"',
        "DeferUntilOutOfCombat",
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
        "tests/test_frame_policy.lua",
        "tests/test_persistence_control_plane.lua",
        "tests/test_persistence_root_store.lua",
        "tests/test_strict_serialization_aliases.lua",
        "tests/test_transfer.lua",
    ):
        if not (ROOT / test_path).is_file():
            fail(f"missing regression test: {test_path}")

    print("Runtime hardening guard passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
