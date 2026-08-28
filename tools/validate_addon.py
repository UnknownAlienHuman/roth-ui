#!/usr/bin/env python3
"""Static structural checks for the Roth UI addon package.

The validator intentionally checks only properties that can be proven without a
running World of Warcraft client: TOC metadata/order, path resolution (including
XML expansions), duplicate load entries, retired runtime modules, and the 12.1
managed-aura boundary.
"""

from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
TOC_PATH = ROOT / "Roth_UI.toc"

RETIRED_RUNTIME_PATHS = {
    PurePosixPath("core/group_aura_watch.lua"),
}


class ValidationError(RuntimeError):
    pass


@dataclass(frozen=True)
class LoadedEntry:
    path: PurePosixPath
    source: PurePosixPath


def normalize_path(raw: str) -> PurePosixPath:
    value = raw.strip().replace("\\", "/")
    while value.startswith("./"):
        value = value[2:]
    path = PurePosixPath(value)
    if not value or path.is_absolute() or ".." in path.parts:
        raise ValidationError(f"unsafe or empty addon path: {raw!r}")
    return path


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8-sig")
    except FileNotFoundError as exc:
        raise ValidationError(f"missing file: {path.relative_to(ROOT)}") from exc
    except UnicodeDecodeError as exc:
        raise ValidationError(f"file is not UTF-8: {path.relative_to(ROOT)}") from exc


def parse_toc() -> tuple[dict[str, str], list[LoadedEntry]]:
    text = read_text(TOC_PATH)
    metadata: dict[str, str] = {}
    entries: list[LoadedEntry] = []

    for line_number, raw_line in enumerate(text.splitlines(), start=1):
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("#") and not line.startswith("##"):
            continue
        if line.startswith("##"):
            match = re.match(r"^##\s*([^:]+):\s*(.*)$", line)
            if not match:
                raise ValidationError(f"malformed TOC metadata at line {line_number}: {raw_line!r}")
            metadata[match.group(1).strip()] = match.group(2).strip()
            continue

        entries.append(LoadedEntry(normalize_path(line), PurePosixPath("Roth_UI.toc")))

    if not entries:
        raise ValidationError("Roth_UI.toc has no load entries")
    return metadata, entries


def local_tag(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def expand_xml(entry: LoadedEntry, stack: tuple[PurePosixPath, ...]) -> list[LoadedEntry]:
    xml_path = ROOT / entry.path
    if entry.path in stack:
        chain = " -> ".join(str(item) for item in (*stack, entry.path))
        raise ValidationError(f"recursive XML include: {chain}")

    text = read_text(xml_path)
    try:
        root = ET.fromstring(text)
    except ET.ParseError as exc:
        raise ValidationError(f"invalid XML in {entry.path}: {exc}") from exc

    expanded: list[LoadedEntry] = [entry]
    parent = entry.path.parent
    next_stack = (*stack, entry.path)

    for node in root.iter():
        if local_tag(node.tag) not in {"Script", "Include"}:
            continue
        raw_file = node.attrib.get("file")
        if not raw_file:
            continue
        child_path = normalize_path(str(parent / normalize_path(raw_file)))
        child = LoadedEntry(child_path, entry.path)
        if child_path.suffix.lower() == ".xml":
            expanded.extend(expand_xml(child, next_stack))
        else:
            read_text(ROOT / child_path)
            expanded.append(child)

    return expanded


def expand_load_graph(entries: list[LoadedEntry]) -> list[LoadedEntry]:
    expanded: list[LoadedEntry] = []
    for entry in entries:
        read_text(ROOT / entry.path)
        if entry.path.suffix.lower() == ".xml":
            expanded.extend(expand_xml(entry, ()))
        else:
            expanded.append(entry)
    return expanded


def assert_metadata(metadata: dict[str, str]) -> None:
    if metadata.get("Interface") != "120100":
        raise ValidationError(
            f"Interface must be exactly 120100 for the Retail 12.1 package; got {metadata.get('Interface')!r}"
        )
    if metadata.get("Author") != "Neomorph":
        raise ValidationError(f"Author must remain Neomorph; got {metadata.get('Author')!r}")
    if metadata.get("X-Target-Build") != "12.1.0.69497":
        raise ValidationError(
            "X-Target-Build must remain pinned to the verified 12.1.0.69497 source snapshot"
        )
    required_deps = {item.strip() for item in metadata.get("RequiredDeps", "").split(",") if item.strip()}
    if "oUF" not in required_deps:
        raise ValidationError("Roth UI must declare oUF in RequiredDeps")
    if metadata.get("X-oUF-Min-Version") != "14.0.2":
        raise ValidationError("X-oUF-Min-Version must remain pinned to 14.0.2 for this migration")
    if not metadata.get("Version"):
        raise ValidationError("Roth UI must declare a non-empty addon Version")


def assert_unique_paths(entries: list[LoadedEntry]) -> None:
    exact: dict[PurePosixPath, LoadedEntry] = {}
    folded: dict[str, PurePosixPath] = {}
    for entry in entries:
        prior = exact.get(entry.path)
        if prior is not None:
            raise ValidationError(
                f"duplicate load entry {entry.path} (from {prior.source} and {entry.source})"
            )
        exact[entry.path] = entry

        key = str(entry.path).casefold()
        prior_path = folded.get(key)
        if prior_path is not None and prior_path != entry.path:
            raise ValidationError(f"case-colliding paths in load graph: {prior_path} and {entry.path}")
        folded[key] = entry.path


def assert_retired_runtime_paths(entries: list[LoadedEntry]) -> None:
    loaded = {entry.path for entry in entries}
    retired_but_loaded = sorted(RETIRED_RUNTIME_PATHS & loaded, key=str)
    if retired_but_loaded:
        joined = ", ".join(str(path) for path in retired_but_loaded)
        raise ValidationError(f"retired raw-scanner module re-entered the runtime load graph: {joined}")


def assert_order(entries: list[LoadedEntry]) -> None:
    positions = {entry.path: index for index, entry in enumerate(entries)}

    def before(left: str, right: str) -> None:
        lhs = PurePosixPath(left)
        rhs = PurePosixPath(right)
        if lhs not in positions:
            raise ValidationError(f"required load entry missing: {lhs}")
        if rhs not in positions:
            raise ValidationError(f"required load entry missing: {rhs}")
        if positions[lhs] >= positions[rhs]:
            raise ValidationError(f"load-order violation: {lhs} must load before {rhs}")

    before("init.lua", "config.lua")
    before("core/settings_main.lua", "core/settings_actions.lua")
    before("core/settings_actions.lua", "core/settings_general.lua")
    before("core/lib.lua", "core/aura_runtime_12_1.lua")
    before("core/aura_runtime_12_1.lua", "core/aura_runtime_12_1_guard.lua")
    before("core/aura_runtime_12_1_guard.lua", "units/target.lua")
    before("core/aura_runtime_12_1_guard.lua", "units/party.lua")
    before("core/aura_runtime_12_1_guard.lua", "units/raid.lua")


def assert_managed_aura_boundary() -> None:
    runtime_path = ROOT / "core/aura_runtime_12_1.lua"
    guard_path = ROOT / "core/aura_runtime_12_1_guard.lua"
    runtime = read_text(runtime_path)
    guard = read_text(guard_path)
    combined = runtime + "\n" + guard

    required_tokens = (
        "CreateAuras",
        "AddGroup",
        "includeSpellIDs",
        "isFromPlayerOrPlayerPet",
        "SetAuraGroupCandidateFilters",
        "__rothOwnCasterFilterApplied",
        "UnregisterEvent(\"UNIT_AURA\"",
    )
    for token in required_tokens:
        if token not in combined:
            raise ValidationError(f"12.1 managed-aura boundary is missing required token: {token}")

    forbidden_calls = (
        r"\bC_UnitAuras\s*\.",
        r"\bAuraUtil\s*\.\s*ForEachAura\s*\(",
        r"\bGetAuraDataBy(?:AuraInstanceID|Index|Slot)\s*\(",
        r"\bGetUnitAuras\s*\(",
        r"\bGetUnitAuraInstanceIDs\s*\(",
    )
    for pattern in forbidden_calls:
        if re.search(pattern, combined):
            raise ValidationError(f"raw aura access reintroduced into the 12.1 boundary: {pattern}")

    if "element.__rothOwnCasterFilterApplied == true" not in guard:
        raise ValidationError("healer-watch candidate filters must be guarded against repeated full updates")


def main() -> int:
    metadata, toc_entries = parse_toc()
    expanded = expand_load_graph(toc_entries)
    assert_metadata(metadata)
    assert_unique_paths(expanded)
    assert_retired_runtime_paths(expanded)
    assert_order(expanded)
    assert_managed_aura_boundary()

    lua_count = sum(1 for entry in expanded if entry.path.suffix.lower() == ".lua")
    xml_count = sum(1 for entry in expanded if entry.path.suffix.lower() == ".xml")
    print(
        "Roth UI static structure OK: "
        f"{len(expanded)} loaded entries ({lua_count} Lua, {xml_count} XML), "
        "Interface 120100, build 12.1.0.69497, oUF >= 14.0.2, "
        "legacy aura scanner excluded."
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValidationError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
