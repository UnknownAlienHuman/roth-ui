# Current status — Roth UI B4.3.3

Status date: 2026-10-01.

## Implemented/source-reviewed

- Single addon root: `Roth_UI`; Settings/import/export/diagnostics remain in the main TOC.
- Interface `120100`, verified Blizzard baseline `12.1.0.69497`, oUF minimum `14.1.1`.
- Central safety owner for Secret/Forbidden/access and serializable-copy boundaries.
- Fail-fast oUF capability/version contract including `SpawnHeader`.
- One SavedVariables root writer and one Blizzard Settings category owner.
- Managed AuraContainers are first-show lazy and do not use raw aura enumeration.
- Target/focus/boss castbars use exact oUF callbacks and native boolean sinks.
- Blizzard action buttons remain Blizzard-owned; Roth UI applies additive skin/art only.
- One event-driven combat-fader owner; no permanent first-party polling.
- Party/raid secure headers are session-owned: standard Settings no longer respawn or reparent them.
- Structural group settings are reload-required; provider visibility, scale, position and range remain live.
- Group visibility prefers the oUF header method, is out-of-combat-only and stores state in weak-key addon metadata.
- Addon-owned minimap button opens Settings/help without modifying Minimap state.
- Deterministic packaging produces one runtime addon directory.

## Repository validation configured

The manual workflow runs repository text policy, B4.3.3 load-graph/ownership/metadata validation, Lua 5.1 parsing, eight isolated regression tests and deterministic double package construction.

The current source pass locally verified Python syntax, workflow YAML parsing and the new static text contracts. Lua 5.1, the complete repository validator, deterministic packaging and WoW-client execution remain `NOT-RUN` until the workflow/client matrix is executed.

## Intentionally pending client evidence

- Login and `/reload` with fresh/migrated/corrupted SavedVariables.
- Party/raid provider enable/disable and structural setting application after reload.
- Party/raid roster churn, arena transitions, click targeting/casting and taint log.
- Target/focus/boss cast, channel, empower and interruptibility matrix.
- Party/raid/nameplate aura layout and healer-watch coverage.
- Stance, vehicle, override, possess and temporary bar states.
- Micro-menu/bag icon and stack-count behavior across Edit Mode/UI scale changes.
- Orb model/bubble/spark/alpha behavior and small-frame health text modes.
- CPU/allocation comparison using `C_AddOnProfiler`.

Open runtime issues remain open until those named-client matrices pass. Historical `todo.md`, `audit.md`, `history.md` and `addon_map.md` are not current architecture authority and are excluded from release packages.
