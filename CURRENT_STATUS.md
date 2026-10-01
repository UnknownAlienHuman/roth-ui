# Current status — Roth UI B4.3.4

Status date: 2026-10-01.

## Implemented/source-reviewed

- Single addon root: `Roth_UI`; Settings/import/export/diagnostics remain in the main TOC.
- Interface `120100`, verified live Blizzard baseline `12.1.0.69933`, oUF minimum `14.1.1`.
- Central Secret/Forbidden/access/serialization owner plus operation-specific forbidden-aspect guards.
- Fail-fast oUF capability/version contract including `SpawnHeader`.
- One SavedVariables root writer and one Blizzard Settings category owner.
- Blizzard Settings registration/page construction is lazy and reentrancy-safe.
- Managed AuraContainers are first-show lazy and do not use raw aura enumeration.
- Target/focus/boss castbars use exact oUF callbacks and native boolean sinks.
- Blizzard action buttons remain Blizzard-owned; Roth skinning is additive, out-of-combat, access-gated and forbidden-aspect-aware.
- One event-driven combat-fader owner; no permanent first-party polling.
- One shared keyed/coalescing post-combat queue; it unregisters `PLAYER_REGEN_ENABLED` after every drain.
- Party/raid secure headers are session-owned: Settings never respawn or reparent them.
- Desired/applied header visibility and foreign-frame suppression state are stored in addon-owned weak-key tables.
- Structural group settings are reload-required; provider visibility, scale, position and range remain live.
- Addon-owned minimap button opens Settings/help without modifying Minimap state.
- Deterministic packaging is configured for one runtime addon directory.

## Auxiliary validation completed

- Remote Git tree/readback and fast-forward ancestry checks.
- Python syntax/static guards for group visibility, lazy Settings and action-button hardening.
- Available LuaTeX runtime: safety aspects, frame policy, oUF contract, group visibility, Settings lifecycle and action-button safety tests.
- No open pull requests remain.

## Not yet executed

- Full Lua 5.1 parse of every repository Lua file.
- Full repository validators against a materialized checkout.
- Deterministic double package build and ZIP inventory.
- New GitHub Actions workflow run.
- Retail client matrix and taint/profiler evidence.

## Required client evidence

- Login and `/reload` with fresh/migrated/corrupted SavedVariables.
- Party/raid provider enable/disable, arena override, roster churn and structural settings after reload.
- Click targeting/click casting and `/console taintLog 1` with secure headers.
- Target/focus/boss cast, channel, empower and interruptibility matrix.
- Party/raid/nameplate aura layout and healer-watch coverage.
- Stance, vehicle, override, possess and temporary bar states.
- Micro-menu/bag icon and stack-count behavior across Edit Mode/UI scale changes.
- Orb model/bubble/spark/alpha behavior and small-frame health text modes.
- CPU/allocation comparison using `C_AddOnProfiler`.

Open runtime issues remain open until those named-client matrices pass. Historical `todo.md`, `audit.md`, `history.md` and `addon_map.md` are not current architecture authority and are excluded from release packages.
