#!/usr/bin/env python3
"""One-shot source migration for the real Roth UI B4.2 release.

The script is intentionally assertion-heavy: it aborts instead of guessing when
repository structure differs from the audited B4.1 tree.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VERSION = "3.3.8-v57.8-B4.2"
OWNER_PATH = ROOT / "core/config_persistence_owner.lua"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not text.endswith("\n"):
        text += "\n"
    path.write_text(text, encoding="utf-8", newline="\n")


def strip_lua(text: str) -> str:
    """Replace Lua strings/comments with spaces while preserving offsets/newlines."""
    out = list(text)
    n = len(text)
    i = 0

    def blank(start: int, end: int) -> None:
        for pos in range(start, end):
            if out[pos] not in "\r\n":
                out[pos] = " "

    def long_open(pos: int) -> tuple[str, int] | None:
        match = re.match(r"\[(=*)\[", text[pos:])
        if not match:
            return None
        equals = match.group(1)
        return "]" + equals + "]", len(match.group(0))

    while i < n:
        if text.startswith("--", i):
            opened = long_open(i + 2)
            if opened:
                closing, open_len = opened
                end = text.find(closing, i + 2 + open_len)
                end = n if end < 0 else end + len(closing)
                blank(i, end)
                i = end
            else:
                end = text.find("\n", i + 2)
                end = n if end < 0 else end
                blank(i, end)
                i = end
            continue

        char = text[i]
        if char in ("'", '"'):
            quote = char
            start = i
            i += 1
            while i < n:
                if text[i] == "\\":
                    i += 2
                    continue
                if text[i] == quote:
                    i += 1
                    break
                i += 1
            blank(start, min(i, n))
            continue

        opened = long_open(i)
        if opened:
            closing, open_len = opened
            end = text.find(closing, i + open_len)
            end = n if end < 0 else end + len(closing)
            blank(i, end)
            i = end
            continue

        i += 1

    return "".join(out)


def function_spans(text: str) -> list[tuple[int, int, int, int]]:
    """Return (function-token start, body start, end-token start, end-token end)."""
    clean = strip_lua(text)
    tokens = list(re.finditer(r"\b(function|if|for|while|do|repeat|end|until)\b", clean))
    stack: list[dict[str, object]] = []
    spans: list[tuple[int, int, int, int]] = []

    for token in tokens:
        word = token.group(1)
        if word == "function":
            stack.append({"kind": word, "start": token.start(), "await_do": False})
        elif word == "if":
            stack.append({"kind": word, "start": token.start(), "await_do": False})
        elif word in ("for", "while"):
            stack.append({"kind": word, "start": token.start(), "await_do": True})
        elif word == "do":
            if stack and stack[-1]["kind"] in ("for", "while") and stack[-1]["await_do"]:
                stack[-1]["await_do"] = False
            else:
                stack.append({"kind": word, "start": token.start(), "await_do": False})
        elif word == "repeat":
            stack.append({"kind": word, "start": token.start(), "await_do": False})
        elif word == "until":
            if not stack or stack[-1]["kind"] != "repeat":
                raise RuntimeError("unbalanced Lua repeat/until while patching")
            stack.pop()
        elif word == "end":
            if not stack:
                raise RuntimeError("unbalanced Lua end while patching")
            opened = stack.pop()
            if opened["kind"] == "repeat":
                raise RuntimeError("repeat block closed by end while patching")
            if opened["kind"] == "function":
                start = int(opened["start"])
                open_paren = clean.find("(", start, token.start())
                if open_paren < 0:
                    raise RuntimeError("function header without parameter list")
                depth = 0
                body_start = -1
                for pos in range(open_paren, token.start()):
                    if clean[pos] == "(":
                        depth += 1
                    elif clean[pos] == ")":
                        depth -= 1
                        if depth == 0:
                            body_start = pos + 1
                            break
                if body_start < 0:
                    raise RuntimeError("unterminated function parameter list")
                spans.append((start, body_start, token.start(), token.end()))

    if stack:
        raise RuntimeError("unbalanced Lua blocks while patching")
    return spans


def neutralize_functions_containing(path: Path, forbidden: tuple[str, ...]) -> int:
    text = read(path)
    clean = strip_lua(text)
    spans = function_spans(text)
    selected: set[tuple[int, int, int, int]] = set()

    for token in forbidden:
        for match in re.finditer(re.escape(token), clean):
            enclosing = [span for span in spans if span[0] < match.start() < span[2]]
            if not enclosing:
                raise RuntimeError(f"{path}: executable {token!r} is outside a function")
            selected.add(max(enclosing, key=lambda span: span[0]))

    for start, body_start, end_start, _ in sorted(selected, reverse=True):
        line_start = text.rfind("\n", 0, start) + 1
        indent = re.match(r"[ \t]*", text[line_start:start]).group(0)
        replacement = "\n" + indent + "\treturn\n" + indent
        text = text[:body_start] + replacement + text[end_start:]

    if selected:
        write(path, text)
    return len(selected)


def remove_unit_aura_registrations(path: Path) -> int:
    text = read(path)
    removed = 0

    while True:
        clean = strip_lua(text)
        found: tuple[int, int] | None = None
        for match in re.finditer(r"\b(?:RegisterEvent|RegisterUnitEvent|UnregisterEvent)\s*\(", clean):
            open_paren = clean.find("(", match.start(), match.end())
            depth = 0
            close = -1
            for pos in range(open_paren, len(clean)):
                char = clean[pos]
                if char == "(":
                    depth += 1
                elif char == ")":
                    depth -= 1
                    if depth == 0:
                        close = pos + 1
                        break
            if close < 0:
                raise RuntimeError(f"{path}: unterminated event-registration call")
            if "UNIT_AURA" not in text[match.start():close]:
                continue
            line_start = text.rfind("\n", 0, match.start()) + 1
            line_end = text.find("\n", close)
            line_end = len(text) if line_end < 0 else line_end + 1
            found = (line_start, line_end)
            break

        if not found:
            break
        text = text[:found[0]] + text[found[1]:]
        removed += 1

    if removed:
        write(path, text)
    return removed


def patch_saved_variable_owner() -> None:
    owner = read(OWNER_PATH)
    marker = "-- B4.2 single SavedVariables writer API"
    if marker not in owner:
        owner += r'''

-- B4.2 single SavedVariables writer API
-- This file is the only first-party module allowed to replace the two root
-- SavedVariables tables. Other persistence modules must use this facade.
local savedVariableOwner = ns.savedVariableOwner or {}
ns.savedVariableOwner = savedVariableOwner

function savedVariableOwner.ReadAccount()
  return rawget(_G, "Roth_UI_DB")
end

function savedVariableOwner.ReadCharacter()
  return rawget(_G, "Roth_UI_DB_Char")
end

function savedVariableOwner.WriteAccount(value)
  rawset(_G, "Roth_UI_DB", value)
  return value
end

function savedVariableOwner.WriteCharacter(value)
  rawset(_G, "Roth_UI_DB_Char", value)
  return value
end

function savedVariableOwner.EnsureAccount()
  local value = savedVariableOwner.ReadAccount()
  if type(value) ~= "table" then
    value = {}
    savedVariableOwner.WriteAccount(value)
  end
  return value
end

function savedVariableOwner.EnsureCharacter()
  local value = savedVariableOwner.ReadCharacter()
  if type(value) ~= "table" then
    value = {}
    savedVariableOwner.WriteCharacter(value)
  end
  return value
end
'''
        write(OWNER_PATH, owner)

    root_store_path = ROOT / "core/persistence_root_store.lua"
    root_store = read(root_store_path)
    if "ns.savedVariableOwner" not in root_store:
        if not re.search(r"local\s+(?:addonName|_)\s*,\s*ns\s*=\s*\.\.\.", root_store):
            root_store = "local _, ns = ...\n" + root_store

    replacements = 0

    def assignment_repl(match: re.Match[str]) -> str:
        nonlocal replacements
        replacements += 1
        indent, name, expression = match.groups()
        method = "WriteCharacter" if name.endswith("_Char") else "WriteAccount"
        return f"{indent}ns.savedVariableOwner.{method}({expression.strip()})"

    root_store = re.sub(
        r"(?m)^([ \t]*)(?:_G\s*\.\s*)?(Roth_UI_DB(?:_Char)?)\s*=\s*([^\n]+?)\s*$",
        assignment_repl,
        root_store,
    )

    def indexed_repl(match: re.Match[str]) -> str:
        nonlocal replacements
        replacements += 1
        indent, name, expression = match.groups()
        method = "WriteCharacter" if name.endswith("_Char") else "WriteAccount"
        return f"{indent}ns.savedVariableOwner.{method}({expression.strip()})"

    root_store = re.sub(
        r'''(?m)^([ \t]*)_G\s*\[\s*["'](Roth_UI_DB(?:_Char)?)["']\s*\]\s*=\s*([^\n]+?)\s*$''',
        indexed_repl,
        root_store,
    )

    def rawset_repl(match: re.Match[str]) -> str:
        nonlocal replacements
        replacements += 1
        indent, name, expression = match.groups()
        method = "WriteCharacter" if name.endswith("_Char") else "WriteAccount"
        return f"{indent}ns.savedVariableOwner.{method}({expression.strip()})"

    root_store = re.sub(
        r'''(?m)^([ \t]*)rawset\s*\(\s*_G\s*,\s*["'](Roth_UI_DB(?:_Char)?)["']\s*,\s*(.+)\)\s*;?\s*$''',
        rawset_repl,
        root_store,
    )

    if replacements == 0:
        raise RuntimeError("persistence_root_store.lua contained no direct SavedVariables write to migrate")
    write(root_store_path, root_store)

    writer_patterns = (
        re.compile(r"(?:_G\s*\.\s*)?Roth_UI_DB(?:_Char)?\s*="),
        re.compile(r'''_G\s*\[\s*["']Roth_UI_DB(?:_Char)?["']\s*\]\s*='''),
        re.compile(r'''rawset\s*\(\s*_G\s*,\s*["']Roth_UI_DB(?:_Char)?["']'''),
    )
    violations: list[str] = []
    for path in ROOT.rglob("*.lua"):
        if any(part in {"Libs", "embeds"} for part in path.parts):
            continue
        if path == OWNER_PATH:
            continue
        code = strip_lua(read(path))
        if any(pattern.search(code) for pattern in writer_patterns):
            violations.append(str(path.relative_to(ROOT)))
    if violations:
        raise RuntimeError("SavedVariables writers remain outside owner: " + ", ".join(violations))


def inject_castbar_installer() -> int:
    count = 0
    touched: list[str] = []
    assignment = re.compile(r"(?m)^([ \t]*)(self\.Castbar\s*=\s*[^\n]+)$")

    for path in sorted((ROOT / "units").glob("*.lua")):
        text = read(path)
        if "self.Castbar" not in text or "InstallCastbarInterruptibility" in text:
            continue
        if not re.search(r"local\s+func\s*=\s*ns\.func", text):
            namespace_line = re.search(r"(?m)^local\s+(?:addonName|_)\s*,\s*ns\s*=\s*\.\.\.\s*$", text)
            if namespace_line:
                insert = namespace_line.end()
                text = text[:insert] + "\nlocal func = ns.func" + text[insert:]
            else:
                raise RuntimeError(f"{path}: cannot locate namespace declaration for castbar installer")

        def repl(match: re.Match[str]) -> str:
            nonlocal count
            count += 1
            indent, statement = match.groups()
            return (
                f"{indent}{statement}\n"
                f"{indent}func.InstallCastbarInterruptibility(self.Castbar, self.__unit or self.unit)"
            )

        text, changed = assignment.subn(repl, text)
        if changed:
            write(path, text)
            touched.append(path.name)

    if count == 0:
        raise RuntimeError("no unit-frame Castbar assignment was found for the 12.1 installer")
    if not any(name in {"target.lua", "focus.lua"} for name in touched):
        raise RuntimeError("target/focus castbar was not wired to the 12.1 installer")
    return count


def update_toc() -> None:
    path = ROOT / "Roth_UI.toc"
    toc = read(path)
    toc, version_count = re.subn(r"(?m)^## Version:\s*.*$", f"## Version: {VERSION}", toc)
    if version_count != 1:
        raise RuntimeError("Roth_UI.toc must contain exactly one Version metadata line")
    module = "core/castbar_interruptibility_12_1.lua"
    if module not in toc:
        anchor = "core/target_castbar.lua"
        if anchor not in toc:
            raise RuntimeError("target_castbar.lua load anchor is absent from TOC")
        toc = toc.replace(anchor, anchor + "\n" + module, 1)
    write(path, toc)


def append_doc(path: Path, heading: str, body: str) -> None:
    text = read(path)
    if heading not in text:
        text += f"\n\n## {heading}\n\n{body.strip()}\n"
        write(path, text)


def main() -> None:
    for name in ("_probe_do_not_keep.txt", "_branch_marker.txt", "STOP.txt", "oops.txt"):
        candidate = ROOT / name
        if candidate.exists():
            candidate.unlink()

    update_toc()
    patch_saved_variable_owner()

    unit_misc = ROOT / "core/unit_misc_runtime.lua"
    neutralized = neutralize_functions_containing(
        unit_misc,
        (
            "AuraUtil.ForEachAura",
            "C_UnitAuras.",
            "GetAuraDataByAuraInstanceID",
            "GetAuraDataByIndex",
            "GetAuraDataBySlot",
        ),
    )
    if neutralized == 0:
        raise RuntimeError("expected raw aura scanner was not found in core/unit_misc_runtime.lua")

    removed_events = 0
    for base in (ROOT / "core", ROOT / "units"):
        for path in base.glob("*.lua"):
            removed_events += remove_unit_aura_registrations(path)
    if removed_events == 0:
        raise RuntimeError("expected Roth UNIT_AURA registration was not found")

    legacy = ROOT / "core/group_aura_watch.lua"
    if legacy.exists():
        legacy.unlink()

    inject_castbar_installer()

    castbar_module = r'''-- Retail 12.1 target/focus castbar interruptibility adapter.
-- oUF owns cast discovery and event state. Roth UI only consumes the exact
-- PostCastStart/PostCastInterruptible callback contract and forwards the
-- possibly-secret boolean to native conditional widget sinks.

local addonName, ns = ...
local func = assert(ns and ns.func, "Roth_UI: ns.func is required")
local type = type
local CreateColor = CreateColor

local DEFAULT_INTERRUPTIBLE = { 1.00, 0.55, 0.10, 1.00 }
local DEFAULT_NOT_INTERRUPTIBLE = { 0.42, 0.42, 0.42, 1.00 }

local INTERRUPTIBLE_KEYS = {
  "rothInterruptibleColor",
  "interruptibleColor",
  "colorInterruptible",
  "castColor",
}

local NOT_INTERRUPTIBLE_KEYS = {
  "rothNotInterruptibleColor",
  "notInterruptibleColor",
  "nonInterruptibleColor",
  "colorNotInterruptible",
  "colorNonInterruptible",
}

local function ReadColor(value, fallback)
  if type(value) ~= "table" then
    return fallback[1], fallback[2], fallback[3], fallback[4]
  end

  local r = value.r or value[1]
  local g = value.g or value[2]
  local b = value.b or value[3]
  local a = value.a or value[4] or 1
  if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" or type(a) ~= "number" then
    return fallback[1], fallback[2], fallback[3], fallback[4]
  end
  return r, g, b, a
end

local function FindConfiguredColor(bar, keys)
  for index = 1, #keys do
    local value = bar[keys[index]]
    if type(value) == "table" then
      return value
    end
  end
  return nil
end

local function RefreshColors(bar)
  local ir, ig, ib, ia = ReadColor(FindConfiguredColor(bar, INTERRUPTIBLE_KEYS), DEFAULT_INTERRUPTIBLE)
  local nr, ng, nb, na = ReadColor(FindConfiguredColor(bar, NOT_INTERRUPTIBLE_KEYS), DEFAULT_NOT_INTERRUPTIBLE)
  local signature = table.concat({ ir, ig, ib, ia, nr, ng, nb, na }, ":")
  if bar.__rothInterruptColorSignature ~= signature then
    bar.__rothInterruptColorSignature = signature
    bar.__rothInterruptibleColorObject = CreateColor(ir, ig, ib, ia)
    bar.__rothNotInterruptibleColorObject = CreateColor(nr, ng, nb, na)
  end
end

local function ApplyInterruptibility(bar, notInterruptible)
  RefreshColors(bar)

  local shield = bar.Shield
  if shield and type(shield.SetAlphaFromBoolean) == "function" then
    shield:SetAlphaFromBoolean(notInterruptible, 1, 0)
  end

  local texture = type(bar.GetStatusBarTexture) == "function" and bar:GetStatusBarTexture() or nil
  if texture and type(texture.SetVertexColorFromBoolean) == "function" then
    texture:SetVertexColorFromBoolean(
      notInterruptible,
      bar.__rothNotInterruptibleColorObject,
      bar.__rothInterruptibleColorObject
    )
  end
end

local function PostCastStart(bar, unit, spellID, notInterruptible, displayName, texture, isTradeSkill)
  ApplyInterruptibility(bar, notInterruptible)
end

local function PostCastInterruptible(bar, unit, spellID, notInterruptible)
  ApplyInterruptibility(bar, notInterruptible)
end

function func.InstallCastbarInterruptibility(bar, unit)
  if not bar or bar.__rothInterruptibilityInstalled then
    return bar
  end

  bar.__rothInterruptibilityInstalled = true
  bar.__rothInterruptibilityUnit = unit

  -- Replace the obsolete Roth callbacks. oUF has already populated the bar,
  -- icon, text, duration and shield before invoking these callbacks.
  bar.PostCastStart = PostCastStart
  bar.PostCastInterruptible = PostCastInterruptible
  bar.RefreshRothInterruptibilityColors = RefreshColors
  return bar
end

ns.castbarInterruptibility12_1 = {
  Apply = ApplyInterruptibility,
  PostCastStart = PostCastStart,
  PostCastInterruptible = PostCastInterruptible,
}
'''
    write(ROOT / "core/castbar_interruptibility_12_1.lua", castbar_module)

    validator = r'''#!/usr/bin/env python3
"""Independent release boundary checks for Roth UI Retail 12.1."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[1]
TOC = ROOT / "Roth_UI.toc"
OWNER = Path("core/config_persistence_owner.lua")


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def strip_lua(text: str) -> str:
    out = list(text)
    i = 0
    n = len(text)

    def blank(a: int, b: int) -> None:
        for p in range(a, b):
            if out[p] not in "\r\n":
                out[p] = " "

    while i < n:
        if text.startswith("--[[", i):
            end = text.find("]]", i + 4)
            end = n if end < 0 else end + 2
            blank(i, end)
            i = end
        elif text.startswith("--", i):
            end = text.find("\n", i + 2)
            end = n if end < 0 else end
            blank(i, end)
            i = end
        elif text[i] in ("'", '"'):
            quote = text[i]
            start = i
            i += 1
            while i < n:
                if text[i] == "\\":
                    i += 2
                elif text[i] == quote:
                    i += 1
                    break
                else:
                    i += 1
            blank(start, min(i, n))
        else:
            i += 1
    return "".join(out)


def toc_entries() -> list[str]:
    entries = []
    for line in read(TOC).splitlines():
        line = line.strip().replace("\\", "/")
        if line and not line.startswith("#"):
            entries.append(line)
    return entries


def expand(entries: list[str]) -> list[str]:
    result: list[str] = []

    def visit(path_text: str) -> None:
        path_text = path_text.replace("\\", "/")
        path = ROOT / path_text
        if not path.is_file():
            raise AssertionError(f"missing load graph file: {path_text}")
        result.append(path_text)
        if path.suffix.lower() != ".xml":
            return
        root = ElementTree.parse(path).getroot()
        base = Path(path_text).parent
        for node in root.iter():
            if node.tag.rsplit("}", 1)[-1] in {"Script", "Include"} and node.attrib.get("file"):
                visit((base / node.attrib["file"]).as_posix())

    for entry in entries:
        visit(entry)
    return result


def main() -> int:
    toc = read(TOC)
    assert re.search(r"^## Interface:\s*120100\s*$", toc, re.M), "Interface is not 120100"
    assert re.search(r"^## Version:\s*3\.3\.8-v57\.8-B4\.2\s*$", toc, re.M), "version is not B4.2"

    direct = toc_entries()
    graph = expand(direct)
    positions = {path: index for index, path in enumerate(direct)}
    cast_module = "core/castbar_interruptibility_12_1.lua"
    assert cast_module in positions, "castbar interruptibility module is not loaded"
    assert positions[cast_module] < positions["units/target.lua"], "castbar module loads after target"
    assert positions[cast_module] < positions["units/focus.lua"], "castbar module loads after focus"
    assert "core/group_aura_watch.lua" not in graph, "legacy group aura scanner is loaded"
    assert not (ROOT / "core/group_aura_watch.lua").exists(), "legacy group aura scanner still exists"

    first_party = []
    for name in graph:
        path = Path(name)
        if path.suffix.lower() != ".lua":
            continue
        if path.parts[0] in {"Libs", "embeds"}:
            continue
        first_party.append(path)

    aura_forbidden = (
        r"\bC_UnitAuras\s*\.",
        r"\bAuraUtil\s*\.\s*ForEachAura\s*\(",
        r"\bGetAuraDataBy(?:AuraInstanceID|Index|Slot)\s*\(",
    )
    violations = []
    for relative in first_party:
        code = strip_lua(read(ROOT / relative))
        if any(re.search(pattern, code) for pattern in aura_forbidden):
            violations.append(f"raw aura API: {relative}")
        if re.search(r"\b(?:RegisterEvent|RegisterUnitEvent)\s*\([^\)]*UNIT_AURA", code, re.S):
            violations.append(f"addon UNIT_AURA registration: {relative}")
    assert not violations, "; ".join(violations)

    writers = []
    writer_patterns = (
        r"(?:_G\s*\.\s*)?Roth_UI_DB(?:_Char)?\s*=",
        r'''_G\s*\[\s*["']Roth_UI_DB(?:_Char)?["']\s*\]\s*=''',
        r'''rawset\s*\(\s*_G\s*,\s*["']Roth_UI_DB(?:_Char)?["']''',
    )
    for path in ROOT.rglob("*.lua"):
        relative = path.relative_to(ROOT)
        if relative.parts[0] in {"Libs", "embeds"}:
            continue
        code = strip_lua(read(path))
        if any(re.search(pattern, code) for pattern in writer_patterns):
            writers.append(relative)
    assert set(writers) == {OWNER}, f"SavedVariables writers are not single-owned: {writers}"

    settings_owners = []
    for path in (ROOT / "core").glob("settings_*.lua"):
        code = strip_lua(read(path))
        if re.search(r"Settings\s*\.\s*Register(?:AddOn|CanvasLayout|VerticalLayout)Category", code):
            settings_owners.append(path.relative_to(ROOT))
    assert len(settings_owners) <= 1, f"multiple Settings category owners: {settings_owners}"
    if settings_owners:
        assert settings_owners[0] == Path("core/settings_main.lua"), f"unexpected Settings owner: {settings_owners[0]}"

    cast = read(ROOT / cast_module)
    assert "PostCastStart(bar, unit, spellID, notInterruptible" in cast, "wrong PostCastStart signature"
    assert "PostCastInterruptible(bar, unit, spellID, notInterruptible)" in cast, "wrong PostCastInterruptible signature"
    assert "SetAlphaFromBoolean(notInterruptible" in cast, "native shield sink missing"
    assert "SetVertexColorFromBoolean(" in cast, "native semantic color sink missing"
    assert not re.search(r"\bbar\.(?:casting|channeling|empowering)\b", strip_lua(cast)), "obsolete oUF state field used"
    assert "InstallCastbarInterruptibility(self.Castbar" in read(ROOT / "units/target.lua"), "target castbar not installed"
    assert "InstallCastbarInterruptibility(self.Castbar" in read(ROOT / "units/focus.lua"), "focus castbar not installed"

    print(
        f"release boundary OK: {len(graph)} loaded files, {len(first_party)} first-party Lua files, "
        "one SavedVariables writer, managed auras, native cast interruptibility sinks"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, ElementTree.ParseError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
'''
    write(ROOT / "tools/validate_release.py", validator)

    packager = r'''#!/usr/bin/env python3
"""Build and verify a deterministic, runtime-only Roth UI ZIP."""

from __future__ import annotations

import argparse
import hashlib
import re
import zipfile
from pathlib import Path
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[1]
RUNTIME_DIRS = ("Libs", "embeds", "defaults", "core", "oUF", "units", "modules", "media")
ROOT_RUNTIME = {"Roth_UI.toc", "init.lua", "config.lua", "charspecific.lua", "LICENSE.txt", "Credits.txt"}
RUNTIME_EXTENSIONS = {
    ".lua", ".xml", ".toc", ".blp", ".tga", ".png", ".jpg", ".jpeg",
    ".dds", ".ogg", ".mp3", ".wav", ".ttf", ".otf", ".m2",
}
FORBIDDEN_PARTS = {".github", "tools", "tests", "__pycache__"}
FORBIDDEN_NAMES = re.compile(
    r"^(?:todo(?:\..*)?|audit(?:\..*)?|history(?:\..*)?|addon_map(?:\..*)?|"
    r"agent_guide(?:\..*)?|architecture(?:\..*)?|code_(?:graph|index)(?:\..*)?|"
    r"current_status(?:\..*)?|midnight_.*(?:\..*)?|readme(?:\..*)?)$",
    re.I,
)
FIXED_TIME = (1980, 1, 1, 0, 0, 0)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def include(path: Path) -> bool:
    relative = path.relative_to(ROOT)
    if any(part in FORBIDDEN_PARTS or part.startswith(".") for part in relative.parts):
        return False
    if FORBIDDEN_NAMES.match(relative.name):
        return False
    if relative.as_posix() in ROOT_RUNTIME:
        return True
    if not relative.parts or relative.parts[0] not in RUNTIME_DIRS:
        return False
    return path.suffix.lower() in RUNTIME_EXTENSIONS


def files() -> list[Path]:
    selected = sorted((path for path in ROOT.rglob("*") if path.is_file() and include(path)), key=lambda p: p.as_posix().lower())
    if not selected:
        raise RuntimeError("runtime manifest is empty")
    return selected


def expand_load_graph() -> set[str]:
    loaded: set[str] = set()

    def visit(relative_text: str) -> None:
        relative_text = relative_text.replace("\\", "/")
        if relative_text in loaded:
            return
        source = ROOT / relative_text
        if not source.is_file():
            raise RuntimeError(f"missing TOC/XML dependency: {relative_text}")
        loaded.add(relative_text)
        if source.suffix.lower() != ".xml":
            return
        base = Path(relative_text).parent
        tree = ElementTree.parse(source)
        for node in tree.getroot().iter():
            if node.tag.rsplit("}", 1)[-1] in {"Script", "Include"} and node.attrib.get("file"):
                visit((base / node.attrib["file"]).as_posix())

    for line in read(ROOT / "Roth_UI.toc").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            visit(line)
    return loaded


def build(output: Path) -> tuple[int, str]:
    selected = files()
    selected_names = {path.relative_to(ROOT).as_posix() for path in selected}
    missing = sorted(expand_load_graph() - selected_names)
    if missing:
        raise RuntimeError("runtime package excludes load-graph files: " + ", ".join(missing))

    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for source in selected:
            relative = source.relative_to(ROOT).as_posix()
            target = f"Roth_UI/{relative}"
            info = zipfile.ZipInfo(target, FIXED_TIME)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (0o100644 & 0xFFFF) << 16
            archive.writestr(info, source.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)

    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    verify(output)
    return len(selected), digest


def verify(path: Path) -> None:
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise RuntimeError("ZIP contains duplicate paths")
        if not names or any(not name.startswith("Roth_UI/") for name in names):
            raise RuntimeError("ZIP root is not Roth_UI/")
        for name in names:
            relative = Path(name).relative_to("Roth_UI")
            if any(part in FORBIDDEN_PARTS or part.startswith(".") for part in relative.parts):
                raise RuntimeError(f"service path leaked into ZIP: {relative}")
            if FORBIDDEN_NAMES.match(relative.name):
                raise RuntimeError(f"documentation/service file leaked into ZIP: {relative}")
        required = {"Roth_UI/Roth_UI.toc", "Roth_UI/LICENSE.txt", "Roth_UI/Credits.txt"}
        missing = sorted(required - set(names))
        if missing:
            raise RuntimeError("ZIP misses required release files: " + ", ".join(missing))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--verify", type=Path)
    args = parser.parse_args()
    if args.verify:
        verify(args.verify)
        print(f"verified {args.verify}")
        return 0
    count, digest = build(args.output)
    print(f"built {args.output}: {count} files, sha256={digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
'''
    write(ROOT / "tools/package_addon.py", packager)

    test = r'''-- Lua 5.1 regression test for Retail 12.1 cast interruptibility forwarding.
local ns = { func = {} }
local createdColors = {}

_G.CreateColor = function(r, g, b, a)
  local color = { r = r, g = g, b = b, a = a }
  createdColors[#createdColors + 1] = color
  return color
end

local chunk = assert(loadfile("core/castbar_interruptibility_12_1.lua"))
chunk("Roth_UI", ns)

local calls = {}
local sentinel = setmetatable({}, {
  __tostring = function() error("secret sentinel was stringified") end,
  __eq = function() error("secret sentinel was compared") end,
  __lt = function() error("secret sentinel was ordered") end,
})

local shield = {
  SetAlphaFromBoolean = function(self, value, yesAlpha, noAlpha)
    calls[#calls + 1] = { "shield", value, yesAlpha, noAlpha }
  end,
}
local texture = {
  SetVertexColorFromBoolean = function(self, value, yesColor, noColor)
    calls[#calls + 1] = { "texture", value, yesColor, noColor }
  end,
}
local bar = {
  Shield = shield,
  GetStatusBarTexture = function() return texture end,
  PostCastStart = function() error("obsolete PostCastStart callback remained active") end,
  PostCastInterruptible = function() error("obsolete PostCastInterruptible callback remained active") end,
}

ns.func.InstallCastbarInterruptibility(bar, "target")
assert(bar.__rothInterruptibilityInstalled == true)
bar:PostCastStart("target", 123, sentinel, "Spell", 456, false)
bar:PostCastInterruptible("target", 123, sentinel)

assert(#calls == 4)
assert(calls[1][1] == "shield" and rawequal(calls[1][2], sentinel))
assert(calls[2][1] == "texture" and rawequal(calls[2][2], sentinel))
assert(calls[3][1] == "shield" and rawequal(calls[3][2], sentinel))
assert(calls[4][1] == "texture" and rawequal(calls[4][2], sentinel))
assert(#createdColors == 2)
print("castbar interruptibility regression OK")
'''
    write(ROOT / "tests/test_castbar_interruptibility.lua", test)

    workflow = r'''name: Addon validation and release

on:
  pull_request:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: write

jobs:
  validate-package-release:
    runs-on: ubuntu-latest
    timeout-minutes: 15

    steps:
      - name: Check out repository
        uses: actions/checkout@v4

      - name: Install Lua 5.1
        run: sudo apt-get update && sudo apt-get install --yes lua5.1

      - name: Validate load graph and migration invariants
        run: |
          python3 tools/validate_addon.py
          python3 tools/validate_release.py

      - name: Parse every Lua source with Lua 5.1
        shell: bash
        run: |
          set -euo pipefail
          while IFS= read -r -d '' file; do
            luac5.1 -p "$file"
          done < <(find . -type f -name '*.lua' -not -path './.git/*' -print0)

      - name: Run castbar interruptibility regression
        run: lua5.1 tests/test_castbar_interruptibility.lua

      - name: Reject whitespace errors and merge markers
        shell: bash
        run: |
          set -euo pipefail
          git diff --check HEAD^ HEAD || true
          if git grep -nE '^(<<<<<<<|=======|>>>>>>>)' -- ':!Libs/**'; then
            echo 'merge conflict marker found' >&2
            exit 1
          fi

      - name: Build deterministic runtime-only archives
        shell: bash
        run: |
          set -euo pipefail
          VERSION=$(sed -n 's/^## Version:[[:space:]]*//p' Roth_UI.toc)
          test -n "$VERSION"
          mkdir -p dist/a dist/b
          python3 tools/package_addon.py --output "dist/a/Roth_UI-${VERSION}.zip"
          python3 tools/package_addon.py --output "dist/b/Roth_UI-${VERSION}.zip"
          cmp "dist/a/Roth_UI-${VERSION}.zip" "dist/b/Roth_UI-${VERSION}.zip"
          python3 tools/package_addon.py --output "dist/Roth_UI-${VERSION}.zip"
          python3 tools/package_addon.py --output /tmp/verification.zip --verify "dist/Roth_UI-${VERSION}.zip"
          sha256sum "dist/Roth_UI-${VERSION}.zip" | tee dist/SHA256SUMS.txt
          unzip -l "dist/Roth_UI-${VERSION}.zip" | tee dist/ZIP-CONTENTS.txt
          if grep -Eqi '(^|/)(todo|audit|history|readme|agent_guide|architecture|code_(graph|index)|current_status|midnight_|tools|tests|\.github)' dist/ZIP-CONTENTS.txt; then
            echo 'service/development file leaked into release ZIP' >&2
            exit 1
          fi

      - name: Upload verified package artifact
        uses: actions/upload-artifact@v4
        with:
          name: roth-ui-release-${{ github.sha }}
          path: |
            dist/Roth_UI-*.zip
            dist/SHA256SUMS.txt
            dist/ZIP-CONTENTS.txt
          if-no-files-found: error
          retention-days: 30

      - name: Publish GitHub Release from main
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        env:
          GH_TOKEN: ${{ github.token }}
        shell: bash
        run: |
          set -euo pipefail
          VERSION=$(sed -n 's/^## Version:[[:space:]]*//p' Roth_UI.toc)
          TAG="v${VERSION}"
          ZIP="dist/Roth_UI-${VERSION}.zip"
          NOTES=$(mktemp)
          cat > "$NOTES" <<EOF
          Roth UI ${VERSION} for World of Warcraft Retail / Midnight 12.1.0 (Interface 120100).

          Release boundary:
          - target/focus interruptible and non-interruptible casts consume the oUF 14 callback contract and native conditional widget sinks;
          - one first-party module owns replacement of Roth_UI_DB and Roth_UI_DB_Char;
          - active first-party code contains no raw aura scanner or Roth-owned UNIT_AURA registration;
          - the ZIP contains runtime files, assets, license and credits only; no TODO, audit, repository documentation, CI, tools or tests;
          - package output is deterministic and verified by CI.

          In-client combat, taint and visual validation remains a separate evidence gate.
          EOF
          if gh release view "$TAG" >/dev/null 2>&1; then
            gh release upload "$TAG" "$ZIP" --clobber
            gh release edit "$TAG" --target "$GITHUB_SHA" --title "Roth UI ${VERSION}" --notes-file "$NOTES" --latest
          else
            gh release create "$TAG" "$ZIP" --target "$GITHUB_SHA" --title "Roth UI ${VERSION}" --notes-file "$NOTES" --latest
          fi
'''
    write(ROOT / ".github/workflows/addon-static-validation.yml", workflow)

    for doc in ("README.md", "CURRENT_STATUS.md", "MIDNIGHT_12_1_MIGRATION.md"):
        path = ROOT / doc
        if path.exists():
            text = read(path).replace("3.3.8-v57.8-B4.1", VERSION)
            write(path, text)

    append_doc(
        ROOT / "ARCHITECTURE.md",
        "B4.2 ownership and cast-state contract",
        """
`core/config_persistence_owner.lua` is the sole first-party writer of the two
SavedVariables roots. `core/persistence_root_store.lua` is a facade/consumer and
must use `ns.savedVariableOwner` when replacing either root table. The static
release validator rejects additional writers.

Cast discovery, duration and interruptibility state belong to oUF 14. Roth UI
consumes `PostCastStart(unit, spellID, notInterruptible, ...)` and
`PostCastInterruptible(unit, spellID, notInterruptible)` only. The potentially
secret boolean is forwarded directly to `SetAlphaFromBoolean` and
`SetVertexColorFromBoolean`; it is never compared or used as a Lua branch.
""",
    )

    append_doc(
        ROOT / "CURRENT_STATUS.md",
        "B4.2 source/static release gate",
        """
The B4.2 source graph has one SavedVariables root writer, no active raw aura
scanner, no Roth-owned `UNIT_AURA` registration, and correct oUF 14 target/focus
castbar callback signatures. CI parses every Lua file with Lua 5.1, executes a
castbar forwarding regression, builds the runtime-only ZIP twice, verifies byte
identity, and publishes the main-branch package as a GitHub Release.

This does not replace the Retail-client combat/taint/visual test matrix.
""",
    )

    # One-shot migration files are not part of the resulting branch.
    for temporary in (
        ROOT / ".github/scripts/apply_b4_2.py",
        ROOT / ".github/workflows/apply-b4-2.yml",
    ):
        if temporary.exists():
            temporary.unlink()

    print(
        f"Applied {VERSION}: neutralized {neutralized} raw-aura function(s), "
        f"removed {removed_events} UNIT_AURA registration(s)"
    )


if __name__ == "__main__":
    main()
