# Current status — Roth UI B4.3.2

Status date: 2026-10-01.

## Implemented/source-reviewed

- Single addon root: `Roth_UI`; Settings/import/export/diagnostics are in the main TOC.
- Interface `120100`, verified Blizzard baseline `12.1.0.69497`, oUF minimum `14.0.2`.
- Central safety owner for Secret/Forbidden/access and serializable-copy boundaries.
- Fail-fast oUF capability/version contract.
- One SavedVariables root writer and one Blizzard Settings category owner.
- Managed AuraContainers are first-show lazy and do not use raw aura enumeration.
- Target/focus/boss castbars use exact oUF 14 callbacks and native boolean sinks.
- Blizzard action buttons remain Blizzard-owned; Roth UI applies additive skin/art only.
- Action-bar artwork stays `UIParent`-owned and refreshes correctly on login/reload, combat exit and player vehicle transitions.
- One event-driven combat-fader owner; no permanent first-party polling.
- Addon-owned minimap button opens Settings/help without modifying Minimap state.
- `/rothui` and `/rui` remain aliases of `/roth`.
- Retired `unit_policy` and legacy rLib fader/grid/slash modules are removed.
- Deterministic packaging produces one runtime addon directory.

## Repository validation included

The manual workflow is configured to run:

- repository text policy;
- static load-graph/ownership/metadata gate for B4.3.2;
- Lua 5.1 parse of all sources;
- safety, oUF, castbar, lazy-aura, combat-fader, minimap and action-bar event tests;
- deterministic double package build and ZIP inventory.

The latest workflow execution is not recorded by this document. Do not treat the presence of tests as a PASS without the run URL/result.

## Intentionally pending client evidence

- Target/focus/boss cast, channel, empower and interruptibility matrix.
- Party/raid/nameplate aura layout and healer-watch coverage.
- Combat lockdown, taint and forbidden-action logs.
- Stance, vehicle, override, possess and temporary bar states.
- Micro-menu/bag icon and stack-count behavior across Edit Mode/UI scale changes.
- Persisted settings with fresh, migrated and corrupted SavedVariables.
- Orb model/bubble/spark/alpha behavior and small-frame health text modes.
- Minimap button placement/tooltip under common minimap replacements.
- CPU/allocation comparison using `C_AddOnProfiler`.

Open runtime issues remain open until those named-client matrices pass. Historical `todo.md`, `audit.md`, `history.md` and `addon_map.md` are not current architecture authority and are excluded from release packages.
