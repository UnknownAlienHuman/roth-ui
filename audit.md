# Roth UI audit report

- Initial audit date: 2026-03-14
- Current compatibility update: 2026-08-27
- Audit type: static source review; Retail client evidence remains pending.

## Retail 12.1 status update

The March report below is a historical snapshot. The Retail 12.1 migration changes the current status of several findings:

- `Roth_UI.toc` now targets Interface `120100` and records the verified Blizzard UI baseline `12.1.0.69497`.
- The deterministic settings startup failure is repaired by loading `core/settings_actions.lua` before `core/settings_general.lua`.
- The active target/focus/party/raid aura path now uses oUF 14 managed `AuraContainer` objects.
- The old harmful-aura health-glow scan and healer-watch scanner remain on disk for history, but the 12.1 adapter overrides their public entry points before unit styles are registered.
- A guard fails closed when the required managed oUF API is absent, preserves own-caster healer-watch filtering, and removes only Roth UI's obsolete `UNIT_AURA` callback.
- Protected Blizzard action-bar ownership remains disabled. No action-bar runtime claim is upgraded without combat, vehicle, paging and binding evidence from the client.
- Static CI now validates the TOC/XML closure, load order, managed-aura boundary, every Lua file, whitespace, and conflict markers.

The authoritative compatibility record and runtime matrix are in [`MIDNIGHT_12_1_MIGRATION.md`](MIDNIGHT_12_1_MIGRATION.md). Runtime-proof is still not complete; the migration must remain unreleased until the documented client matrix passes.

## Update after the initial audit

After the original report was written, the code had already moved forward:

- the legacy `RuneFrame` kill path was removed;
- group aura recolor moved to an incremental-aware cache, and `/roth aurastats` again used runtime counters.

The 12.1 migration subsequently superseded the raw group-aura state path entirely. Historical sections below should be read as evidence of the repository's prior state, not as the current compatibility verdict.

## Initial verdict

The primary pass from 2026-03-13 was largely implemented.

This was not a case where the todo list had been written ahead of the code. The source showed that most of the upper implementation pass had landed. The remaining work was different in nature:

1. live validation of rewritten paths;
2. consolidation of ownership/service boundaries in persistence and legacy mirrors;
3. performance and polish for group aura and mini-castbar paths;
4. cleanup of monoliths and the older compatibility layer.

## What the initial audit checked

- Read the full `todo.md` snapshot (`2711` lines at that time).
- Reviewed key runtime files from the upper backlog block.
- Ran a Lua syntax smoke test over all project Lua files: `92` files, `0` parse errors.
- Checked old-risk patterns including `Show = Hide`, `UnregisterAllEvents`, `C_Timer.After`, registry mirrors, castbar ownership, and BuffFrame legacy entry points.

## What was confirmed in the initial pass

See [`history.md`](history.md).

In summary:

- combat-lockdown layout paths for micromenu, stance and bags were guarded;
- the irreversible player/pet Blizzard castbar kill path was removed;
- the default aura styling path for BuffFrame was cut off;
- action-bar runtime and registry ownership had been extracted;
- ExtraAction and ZoneAbility used a holder/follower model;
- the frame-policy stack had been split;
- safe group aura watch and part of the settings/runtime surface existed;
- target and mini-castbar runtime had been rewritten.

## What remained incomplete

### 1. Runtime proof

Static code can establish structure, but it cannot close:

- managed aura behavior under secret restrictions;
- Edit Mode versus player castbar behavior;
- mini-castbar matrix for `targettarget`, `focus` and `boss`;
- vehicle, override, possess, ExtraAction and ZoneAbility transitions;
- save/reload/reset/import/export/migration smoke tests.

This remains current.

### 2. Persistence is not reduced to one owner

The situation improved, but the consolidation is incomplete:

- `config.lua` still owns defaults/schema/config-root logic;
- `core/sv_store.lua` remains a large owner, transfer, mirror and runtime layer;
- `core/db.lua` remains a large consumer/service layer;
- compatibility surfaces `ns.cfgSaved` and `db.char` remain.

### 3. Group aura stack

The March snapshot still contained a full harmful-aura scan in `core/unit_misc_runtime.lua`. Retail 12.1 no longer permits that as a general restricted-context state source. The current adapter makes the scan inactive and uses native managed aura-button borders instead.

Client validation is still required to prove the resulting display behavior and CPU profile.

### 4. Monolith split remains technical debt

The heaviest files in the original snapshot were:

- `core/lib.lua` — `2351` lines;
- `config.lua` — `1622` lines;
- `core/sv_store.lua` — `1536` lines;
- `core/bars.lua` — `1074` lines;
- `units/player.lua` — `1049` lines;
- `core/db.lua` — `970` lines.

The 12.1 compatibility layer intentionally isolates patch migration risk; it does not claim to finish this architectural cleanup.

## Practical next order

1. Complete the Retail 12.1 client matrix and attach evidence.
2. Fix any runtime regressions found by that matrix before merge/release.
3. Consolidate persistence ownership.
4. Decide the final removal boundary for legacy aura implementations after the migration is proven.
5. Then split monoliths and clean media/compat surfaces.
