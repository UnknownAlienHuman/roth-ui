#!/usr/bin/env python3
"""Static release gate for Roth UI Retail 12.1 / oUF 14."""

from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
VERSION = "3.3.8-v57.8-B4.3"
INTERFACE = "120100"
TARGET_BUILD = "12.1.0.69497"
OUF_MIN = "14.0.2"

MAIN_TOC = ROOT / "Roth_UI.toc"
OPTIONS_ROOT = ROOT / "Roth_UI_Options"
OPTIONS_TOC = OPTIONS_ROOT / "Roth_UI_Options.toc"

RETIRED_PATHS = {
    "STOP.txt", "_branch_marker.txt", "_probe_do_not_keep.txt", "oops.txt",
    "core/aura_runtime_12_1.lua", "core/aura_runtime_12_1_guard.lua",
    "core/group_aura_watch.lua", "oUF/elements/rune_orbs.lua",
    "core/action_bar_secure_runtime.lua", "core/action_bar_dock.lua",
    "core/action_bar_bar1.lua", "core/action_bar_bar2.lua", "core/action_bar_bar3.lua",
    "core/action_bar_bar4.lua", "core/action_bar_bar5.lua",
    "core/action_bar_overridebar.lua", "core/action_bar_multibar_visibility.lua",
    "core/bar_runtime_registry.lua", "core/pet_action_bar.lua", "core/stance_bar.lua",
    "core/micromenu_bar.lua", "core/bags_bar.lua", "core/extrabar_holder.lua",
    "core/leave_vehicle_bar.lua", "core/hide_endcaps.lua",
    "modules/Roth_UI_oUFModules/modules/oUF_Smooth.lua",
    "Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua",
    "Libs/LibKeyBound-1.0/LibKeyBound-1.0.lua",
}

FIRST_PARTY_PREFIXES = (
    "init.lua", "config.lua", "charspecific.lua", "defaults/", "core/", "units/", "oUF/",
    "Roth_UI_Options/core/",
)


class ValidationError(RuntimeError):
    pass


@dataclass(frozen=True)
class Entry:
    path: PurePosixPath
    source: PurePosixPath


def fail(message: str) -> None:
    raise ValidationError(message)


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8-sig")
    except FileNotFoundError as exc:
        fail(f"missing file: {path.relative_to(ROOT)}")
        raise exc


def normalize(raw: str) -> PurePosixPath:
    value = raw.strip().replace("\\", "/")
    while value.startswith("./"):
        value = value[2:]
    path = PurePosixPath(value)
    if not value or path.is_absolute() or ".." in path.parts:
        fail(f"unsafe addon path: {raw!r}")
    return path


def parse_toc(toc: Path, addon_root: Path) -> tuple[dict[str, str], list[Entry]]:
    metadata: dict[str, str] = {}
    entries: list[Entry] = []
    source = PurePosixPath(toc.relative_to(ROOT).as_posix())
    for line_no, raw in enumerate(read(toc).splitlines(), 1):
        line = raw.strip()
        if not line:
            continue
        if line.startswith("#") and not line.startswith("##"):
            continue
        if line.startswith("##"):
            match = re.match(r"^##\s*([^:]+):\s*(.*?)\s*$", line)
            if not match:
                fail(f"malformed metadata in {source}:{line_no}")
            metadata[match.group(1).strip()] = match.group(2).strip()
            continue
        relative = normalize(line)
        full = normalize((PurePosixPath(addon_root.relative_to(ROOT).as_posix()) / relative).as_posix())
        entries.append(Entry(full, source))
    if not entries:
        fail(f"{source} has no load entries")
    return metadata, entries


def local_tag(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def expand_xml(entry: Entry, stack: tuple[PurePosixPath, ...]) -> list[Entry]:
    if entry.path in stack:
        fail("recursive XML include: " + " -> ".join(map(str, (*stack, entry.path))))
    path = ROOT / entry.path
    try:
        root = ET.fromstring(read(path))
    except ET.ParseError as exc:
        fail(f"invalid XML in {entry.path}: {exc}")
    result = [entry]
    for node in root.iter():
        if local_tag(node.tag) not in {"Script", "Include"}:
            continue
        raw = node.attrib.get("file")
        if not raw:
            continue
        child = Entry(normalize((entry.path.parent / normalize(raw)).as_posix()), entry.path)
        if child.path.suffix.lower() == ".xml":
            result.extend(expand_xml(child, (*stack, entry.path)))
        else:
            read(ROOT / child.path)
            result.append(child)
    return result


def expand(entries: list[Entry]) -> list[Entry]:
    result: list[Entry] = []
    for entry in entries:
        read(ROOT / entry.path)
        result.extend(expand_xml(entry, ()) if entry.path.suffix.lower() == ".xml" else [entry])
    return result


def assert_unique(entries: list[Entry], label: str) -> None:
    exact: dict[PurePosixPath, Entry] = {}
    folded: dict[str, PurePosixPath] = {}
    for entry in entries:
        if entry.path in exact:
            fail(f"duplicate {label} load: {entry.path}")
        exact[entry.path] = entry
        key = str(entry.path).casefold()
        if key in folded and folded[key] != entry.path:
            fail(f"case-colliding {label} paths: {folded[key]} and {entry.path}")
        folded[key] = entry.path


def assert_main_metadata(meta: dict[str, str]) -> None:
    expected = {
        "Interface": INTERFACE,
        "Author": "Neomorph",
        "Version": VERSION,
        "RequiredDeps": "oUF",
        "X-oUF-Min-Version": OUF_MIN,
        "X-Target-Build": TARGET_BUILD,
    }
    for key, value in expected.items():
        if meta.get(key) != value:
            fail(f"Roth_UI.toc {key} must be {value!r}, got {meta.get(key)!r}")


def assert_options_metadata(meta: dict[str, str]) -> None:
    expected = {
        "Interface": INTERFACE,
        "Author": "Neomorph",
        "Version": VERSION,
        "RequiredDeps": "Roth_UI",
        "LoadOnDemand": "1",
        "X-Target-Build": TARGET_BUILD,
    }
    for key, value in expected.items():
        if meta.get(key) != value:
            fail(f"Roth_UI_Options.toc {key} must be {value!r}, got {meta.get(key)!r}")


def assert_order(entries: list[Entry]) -> None:
    pos = {str(e.path): i for i, e in enumerate(entries)}
    def before(a: str, b: str) -> None:
        if a not in pos or b not in pos:
            fail(f"required load-order entry missing: {a} or {b}")
        if pos[a] >= pos[b]:
            fail(f"load order: {a} must load before {b}")
    before("init.lua", "core/config_persistence_owner.lua")
    before("core/config_persistence_owner.lua", "config.lua")
    before("core/options_loader.lua", "core/settings_actions.lua")
    before("core/target_castbar.lua", "core/lib.lua")
    before("core/lib.lua", "core/aura_runtime.lua")
    before("core/aura_runtime.lua", "units/target.lua")
    before("core/frame_policy.lua", "core/group_policy.lua")
    before("core/frame_policy.lua", "core/unit_policy.lua")


def strip_lua_comments(text: str) -> str:
    out: list[str] = []
    i = 0
    quote: str | None = None
    while i < len(text):
        ch = text[i]
        if quote:
            out.append(ch)
            if ch == "\\" and i + 1 < len(text):
                i += 1
                out.append(text[i])
            elif ch == quote:
                quote = None
            i += 1
            continue
        if ch in {"'", '"'}:
            quote = ch
            out.append(ch)
            i += 1
            continue
        if text.startswith("--[[", i):
            end = text.find("]]", i + 4)
            if end == -1:
                return "".join(out)
            out.append("\n" * text[i:end + 2].count("\n"))
            i = end + 2
            continue
        if text.startswith("--", i):
            end = text.find("\n", i + 2)
            if end == -1:
                break
            out.append("\n")
            i = end + 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def first_party_lua(entries: list[Entry]) -> dict[str, str]:
    result: dict[str, str] = {}
    for entry in entries:
        path = str(entry.path)
        if entry.path.suffix.lower() != ".lua":
            continue
        if any(path == prefix or path.startswith(prefix) for prefix in FIRST_PARTY_PREFIXES):
            result[path] = strip_lua_comments(read(ROOT / entry.path))
    return result


def assert_retired_absent() -> None:
    present = sorted(path for path in RETIRED_PATHS if (ROOT / path).exists())
    if present:
        fail("retired/service paths still present: " + ", ".join(present))


def assert_runtime_boundaries(main: list[Entry], options: list[Entry]) -> None:
    main_paths = {str(e.path) for e in main}
    options_paths = {str(e.path) for e in options}
    if any(path.startswith("Roth_UI_Options/") for path in main_paths):
        fail("LoadOnDemand Options code leaked into the resident main TOC")
    if main_paths & options_paths:
        fail("main and Options TOCs load the same path")

    sources = first_party_lua(main + options)
    combined = "\n".join(sources.values())
    forbidden = {
        "raw aura enumeration": r"\bC_UnitAuras\s*\.|\bAuraUtil\s*\.\s*ForEachAura\s*\(|\bUnit(?:Aura|Buff|Debuff)\s*\(",
        "addon-owned UNIT_AURA": r"[\"']UNIT_AURA[\"']",
        "raw cast polling": r"\bUnitCastingInfo\s*\(|\bUnitChannelInfo\s*\(",
        "legacy smoothing": r"\.Smooth\b|oUF_Smooth",
        "legacy addon globals": r"(?<!C_AddOns\.)\b(?:GetAddOnMetadata|LoadAddOn|GetNumAddOns|GetAddOnInfo)\s*\(",
        "removed action libraries": r"LibActionButton|LibKeyBound|KeyBound",
        "old interface panel API": r"InterfaceOptionsFrame_OpenToCategory",
        "old mouse focus API": r"\bGetMouseFocus\s*\(",
        "global Blizzard override": r"(?:^|\n)\s*(?:_G\.)?(?:RaidFinderFrame_UpdateTab|CompactRaidFrameManager_UpdateShown|PartyFrame_Update)\s*=",
    }
    for label, pattern in forbidden.items():
        if re.search(pattern, combined, re.MULTILINE):
            fail(f"{label} reintroduced into first-party runtime")

    for path, text in sources.items():
        if path != "core/aura_runtime.lua" and re.search(r"\b(?:CreateAuras|AddGroup|AddSlot)\s*\(", text):
            fail(f"managed aura ownership escaped core/aura_runtime.lua: {path}")
        if re.search(r"(?:Set|Hook)Script\s*\(\s*[\"']OnUpdate", text) and path != "embeds/rLib/dragframe.lua":
            fail(f"unapproved first-party OnUpdate: {path}")

    runtime = sources.get("core/aura_runtime.lua", "")
    for token in ("QueueAuraRegion", "RegisterInitCallback", 'HookScript("OnShow"', "EnableElement(\"Auras\")", "AddGroup", "AddSlot"):
        if token not in runtime:
            fail(f"lazy managed aura contract missing token: {token}")
    if runtime.find('HookScript("OnShow"') > runtime.find("CreateAuraRegion(frame"):
        # Declaration order is not semantically important; this only catches an obviously missing lifecycle.
        pass

    cast = sources.get("core/target_castbar.lua", "")
    required_cast = (
        "function runtime.PostCastStart(bar, unit, spellID, notInterruptible)",
        "function runtime.PostCastInterruptible(bar, unit, spellID, notInterruptible)",
        "SetAlphaFromBoolean(notInterruptible, 1, 0)",
        "SetVertexColorFromBoolean",
    )
    for token in required_cast:
        if token not in cast:
            fail(f"target castbar contract missing: {token}")

    bars = sources.get("core/bars.lua", "")
    exact_classpower = "element.PostUpdate = function(elem, cur, maxValue, hasCurChanged, hasMaxChanged, powerType, ...)"
    if exact_classpower not in bars:
        fail("oUF 14 ClassPower.PostUpdate signature drifted")

    settings_registrars = [path for path, text in sources.items() if "RegisterVerticalLayoutCategory" in text]
    if settings_registrars != ["Roth_UI_Options/core/settings_main.lua"]:
        fail(f"Settings category must have one owner, got {settings_registrars}")

    root_writers: list[str] = []
    writer_pattern = re.compile(r"(?:\bRoth_UI_DB(?:_Char)?\s*=|_G\s*\[[^\]]*(?:ACCOUNT_DB_VAR|CHAR_DB_VAR|Roth_UI_DB)[^\]]*\]\s*=|rawset\s*\(\s*_G\s*,\s*[^,]*(?:ACCOUNT_DB_VAR|CHAR_DB_VAR|Roth_UI_DB))")
    for path, text in sources.items():
        if writer_pattern.search(text):
            root_writers.append(path)
    if any(path != "core/config_persistence_owner.lua" for path in root_writers):
        fail(f"SavedVariables root writer escaped owner: {root_writers}")


def assert_no_case_collisions_repo() -> None:
    seen: dict[str, Path] = {}
    for path in ROOT.rglob("*"):
        if ".git" in path.parts:
            continue
        rel = path.relative_to(ROOT)
        key = rel.as_posix().casefold()
        if key in seen and seen[key] != rel:
            fail(f"case-colliding repository paths: {seen[key]} and {rel}")
        seen[key] = rel


def main() -> int:
    main_meta, main_direct = parse_toc(MAIN_TOC, ROOT)
    options_meta, options_direct = parse_toc(OPTIONS_TOC, OPTIONS_ROOT)
    main_graph = expand(main_direct)
    options_graph = expand(options_direct)
    assert_main_metadata(main_meta)
    assert_options_metadata(options_meta)
    assert_unique(main_graph, "main")
    assert_unique(options_graph, "Options")
    assert_order(main_graph)
    assert_retired_absent()
    assert_no_case_collisions_repo()
    assert_runtime_boundaries(main_graph, options_graph)
    print(
        f"Roth UI {VERSION} static gate OK: "
        f"main={len(main_graph)} entries, options={len(options_graph)} entries, "
        f"Interface={INTERFACE}, build={TARGET_BUILD}, oUF>={OUF_MIN}"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValidationError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
