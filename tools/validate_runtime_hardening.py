#!/usr/bin/env python3
"""Static guard for lazy Settings, bounded lifecycle and transactional persistence."""

from __future__ import annotations

import hashlib
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


def lua_string_literals(text: str) -> list[str]:
    literals: list[str] = []
    index = 0
    while index < len(text):
        if text.startswith("--[[", index):
            end = text.find("]]", index + 4)
            index = len(text) if end < 0 else end + 2
            continue
        if text.startswith("--", index):
            end = text.find("\n", index + 2)
            index = len(text) if end < 0 else end + 1
            continue

        quote = text[index]
        if quote not in {"'", '"'}:
            index += 1
            continue

        index += 1
        value: list[str] = []
        while index < len(text):
            char = text[index]
            if char == "\\" and index + 1 < len(text):
                escaped = text[index + 1]
                if escaped == "\\":
                    value.append("\\")
                elif escaped == quote:
                    value.append(quote)
                else:
                    value.extend(("\\", escaped))
                index += 2
                continue
            if char == quote:
                index += 1
                literals.append("".join(value))
                break
            value.append(char)
            index += 1
    return literals


def validate_media_ownership() -> None:
    media_root = ROOT / "media"
    references: set[str] = set()
    for path in ROOT.rglob("*"):
        if (
            not path.is_file()
            or "media" in path.parts
            or path.suffix.casefold() not in {".lua", ".toc", ".xml"}
        ):
            continue
        text = path.read_text(encoding="utf-8-sig", errors="ignore")
        values = lua_string_literals(text) if path.suffix.casefold() == ".lua" else text.splitlines()
        for value in values:
            references.add(value.strip().casefold().replace("/", "\\"))

    hashes: dict[str, Path] = {}
    for path in sorted(media_root.iterdir()):
        if not path.is_file():
            continue
        name = path.name.casefold()
        stem = path.stem.casefold()
        owned = any(
            value == name or value == stem
            or value.endswith("\\" + name) or value.endswith("\\" + stem)
            for value in references
        )
        if not owned:
            fail(f"unowned media asset: {path.relative_to(ROOT)}")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        previous = hashes.get(digest)
        if previous is not None:
            fail(
                "byte-identical media assets: "
                f"{previous.relative_to(ROOT)} and {path.relative_to(ROOT)}"
            )
        hashes[digest] = path


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
    assert_contains(toc, "## X-oUF-Min-Version: 14.2.1", "oUF minimum version")

    workflow = read(".github/workflows/addon-static-validation.yml")
    for token in ("pull_request:", "push:", "workflow_dispatch:", "cancel-in-progress: true"):
        assert_contains(workflow, token, "automatic validation workflow")

    safety = read("core/safety.lua")
    for token in (
        "canaccessvalue",
        "CopySerializableStrict",
        "if strict then",
        "Shared-reference graphs",
        "maxEntries",
        "maxStringBytes",
        "A depth limit",
        "size bound",
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
        "DeferForObject",
        'DeferForObject("frame-suppression"',
        'UnregisterEvent("PLAYER_REGEN_ENABLED")',
        '__mode = "k"',
    ):
        assert_contains(frame_policy, token, "transactional frame policy")
    assert_absent(frame_policy, "tostring(frame)", "frame-policy identity")

    for path in ("core/lib.lua", "core/aura_runtime.lua", "core/mover_runtime.lua", "units/party.lua"):
        text = read(path)
        assert_contains(text, "DeferForObject", f"object-scoped deferral in {path}")
        for forbidden in ("tostring(frame)", "tostring(self)", "tostring(f)"):
            assert_absent(text, forbidden, f"object identity in {path}")

    control_plane = read("core/persistence_control_plane.lua")
    for token in (
        "CopySerializableStrict",
        "CanAccess",
        "SnapshotCanonicalRoots",
        "ValidateTransferPayload",
        "RestorePersistenceRoots",
        "ApplyTransferRootsAndReload",
        "storeApi.CommitRoots = nil",
        "storeApi.GetCanonicalStores = nil",
        "storeApi.GetPersistenceStores = nil",
        "storeApi.SetDomainRoot = nil",
        "storeApi.GetConfigRoot = nil",
        "ns.GetPersistenceStores = nil",
        "ns.configPersistence.ReconcileConfigStore = nil",
    ):
        assert_contains(control_plane, token, "transactional persistence control plane")
    assert_absent(control_plane, 'RegisterEvent("ADDON_LOADED")', "persistence control plane")
    assert_absent(control_plane, "persistenceApi.RebuildRuntime", "duplicate persistence reconcile alias")
    assert_absent(control_plane, "persistenceApi.ResetRoots", "public root mutation")
    assert_absent(control_plane, "persistenceApi.ReplaceRoots", "public root mutation")
    assert_absent(control_plane, "persistenceApi.GetCanonicalStores", "public live-root access")
    assert_absent(control_plane, "persistenceApi.GetStores", "public live-root access")

    root_store = read("core/persistence_root_store.lua")
    for token in (
        "CommitPersistenceRoots",
        "RestorePersistenceRootReferences",
        "storeApi.CommitRoots",
        "configOwner.EnsureCanonicalStores = nil",
        "configOwner.GetConfigRoot = nil",
        "configOwner.GetConfigDefaults = nil",
        "configOwner.SetCanonicalConfigStore = nil",
        "configOwner.ReplaceCanonicalRoots = nil",
        "configOwner.InitializeConfigDefaults = nil",
    ):
        assert_contains(root_store, token, "internal root owner")
    assert_absent(root_store, "CopySerializableStrict", "single strict validation owner")
    assert_absent(root_store, "function ns.ReplacePersistenceRoots", "public root mutation")
    assert_absent(root_store, "function ns.ResetPersistenceRoots", "public root mutation")
    assert_absent(root_store, "storeApi.SetConfigRoot", "unused raw config-root writer")

    config_owner = read("core/config_persistence_owner.lua")
    for forbidden in (
        "function ns.EnsureCanonicalPersistenceStores",
        "function ns.GetCanonicalTemplateStore",
        "function ns.GetCanonicalOrbCharStore",
        "function ns.SetCanonicalConfigStore",
        "function ns.SetCanonicalTemplateStore",
        "function ns.SetCanonicalOrbCharStore",
        "function ns.ReconcileConfigStore",
    ):
        assert_absent(config_owner, forbidden, "public config-root access")

    orb_owner = read("core/orb_persistence_owner.lua")
    for token in (
        "storeApi.GetOrbCharRoot = nil",
        "storeApi.SetOrbCharRoot = nil",
        "storeApi.GetOrbGlobalRoot = nil",
        "InitializeOrbPersistence",
        "LoadSavedVariablesFirst",
    ):
        assert_contains(orb_owner, token, "bounded orb persistence owner")
    assert_absent(orb_owner, 'RegisterEvent("ADDON_LOADED")', "duplicate orb load owner")
    assert_absent(orb_owner, 'CreateFrame("Frame")', "duplicate orb load owner")
    assert_absent(orb_owner, "function orbPersistence.GetStores", "public live orb roots")

    doctor = read("core/sv_doctor.lua")
    for token in ("persistence.GetScanStores = nil", "persistence.GetStorageLabels = nil"):
        assert_contains(doctor, token, "bounded SavedVariables diagnostics")

    unit_misc = read("core/unit_misc_runtime.lua")
    assert_absent(unit_misc, "func.round", "retired panel helper")

    scheduler = read("core/deferred_scheduler.lua")
    for token in (
        "safety.TryCall",
        "local order = {}",
        "local scheduled = false",
        "local work = pending",
        "pending = {}",
        "TryCall(callback)",
    ):
        assert_contains(scheduler, token, "single next-frame scheduler")
    if scheduler.count("C_Timer.After(0, Drain)") != 1:
        fail("next-frame scheduler must own exactly one timer path")

    action_art = read("core/action_bar_background.lua")
    for token in (
        "local RunNextFrame = assert(ns.defer and ns.defer.RunNextFrame",
        'RunNextFrame("action-bar-background", RunQueuedRefresh)',
    ):
        assert_contains(action_art, token, "single next-frame artwork scheduler")
    assert_absent(action_art, "C_Timer.After", "duplicate artwork scheduler")
    assert_absent(action_art, "refreshQueued", "duplicate artwork queue state")

    combat_fader = read("core/combat_fader.lua")
    bars = read("core/bars.lua")
    assert_absent(combat_fader, "_G.rCombatFrameFader", "retired combat-fader global")
    assert_absent(bars, "rCombatFrameFader", "retired combat-fader global consumer")
    assert_contains(bars, "local AttachCombatFader = assert(func.AttachCombatFader",
      "direct combat-fader owner")

    debug_commands = read("core/debug_commands.lua")
    assert_contains(debug_commands, "persistence.GetConfigRoot = nil", "public live config-root closure")
    assert_absent(debug_commands, "RunSVRebuild", "duplicate persistence reconcile command")
    assert_absent(read("core/sv_store.lua"), "SVRebuildRuntime", "duplicate persistence rebuild route")

    for path, token in (
        ("core/sv_store.lua", "function ns.GetOrbCharValue"),
        ("core/sv_store.lua", "function ns.SetOrbCharValue"),
        ("core/sv_doctor.lua", "ns.SVDoctorScan ="),
        ("core/sv_doctor.lua", "ns.SVTestReport ="),
        ("core/persistence_report_service.lua", "ns.PersistenceSchemaReport ="),
        ("core/config_persistence_owner.lua", "function ns.GetConfigPersistenceInfo"),
    ):
        assert_absent(read(path), token, "dead namespace alias")

    transfer = read("core/transfer.lua")
    for token in (
        "CopySerializableStrict(envelope)",
        "ALLOWED_ENVELOPE_KEYS",
        "Import mode mismatch",
        "ApplyTransferRootsAndReload",
        "ClearDialogState",
        'dialog:SetScript("OnHide", ClearDialogState)',
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
        "tests/test_deferred_scheduler.lua",
        "tests/test_combat_fader_owner.lua",
        "tests/test_persistence_control_plane.lua",
        "tests/test_persistence_root_store.lua",
        "tests/test_config_persistence_bootstrap.lua",
        "tests/test_orb_persistence_owner.lua",
        "tests/test_strict_serialization_aliases.lua",
        "tests/test_strict_serialization_limits.lua",
        "tests/test_transfer.lua",
    ):
        if not (ROOT / test_path).is_file():
            fail(f"missing regression test: {test_path}")

    validate_media_ownership()
    print("Runtime hardening guard passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
