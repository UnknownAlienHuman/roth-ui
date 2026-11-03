# Roth UI agent guide

## Current target

Addon `3.4.0` targets Retail `12.1.5`, Interface `120105`, target source build `12.1.5.70688`. Source references checked `2026-11-02`: Blizzard UI source `d07eb00237d8891f153215db98a5df880a26cfe5` and oUF `14.1.1` at `8f37c36e3ed37d2fcfca2f3690f5e37e52b758c7`. Live client build, combat, taint, visual, and performance verification have not been run; do not describe the addon as client-certified.

Before editing, read `README.md`, `ARCHITECTURE.md`, `CODE_INDEX.md`, `CODE_GRAPH.md`, the current status and migration notes, the TOC, and applicable local policy guides. Treat current repository code and explicit project instructions as authoritative. Check pinned framework/platform source for API contracts when needed; distinguish source review from client evidence.

## Ownership boundaries

- `core/safety.lua` owns access, secret/forbidden, and serializable-copy guards; `core/safety_aspects.lua` owns operation-specific forbidden-aspect checks.
- `core/config_persistence_owner.lua` is the only SavedVariables root writer. `core/settings_main.lua` is the only Blizzard Settings category owner.
- `core/aura_runtime.lua` is the sole managed-aura lifecycle owner. Do not enumerate raw aura data or create separate `UNIT_AURA` state.
- oUF owns unit-frame lifecycle, secure party/raid headers, unit elements, cast discovery, and managed aura events. Do not poll casts outside oUF.
- `core/frame_policy.lua` owns reversible Blizzard-frame suppression and the single keyed out-of-combat queue. `core/deferred_scheduler.lua` owns keyed next-frame coalescing. Do not add parallel permanent combat-exit listeners.
- `core/mover_runtime.lua` owns mover creation and saved frame point/scale/size. Use it for every frame that needs movement; keep layout defaults current and preserve saved overrides.
- `core/font_policy.lua` owns Roth font updates and optional reversible Blizzard font changes. Restore only a snapshot that still matches the exact state Roth applied.
- `units/mini_target_scaffold.lua` is the shared builder for mini target layouts. Individual styles must continue supplying their own settings and optional elements.
- The oUF Experience element owns rested XP updates. Avoid adding a second rested-bar updater through `Experience.PostUpdate`.
- Blizzard action buttons, secure state, paging, bindings, vehicle/override state, and visibility remain Blizzard-owned. Roth skins are additive; action-bar artwork stays `UIParent`-owned.
- Retired embedded mover helper files and obsolete unit policy files must remain absent.

## Security and runtime rules

- Gate secret-capable or inaccessible values before comparison, formatting, conversion, serialization, retention, or indexing.
- Never reparent protected Blizzard frames, override Blizzard globals, unregister Blizzard events, change addon enable state, or write Blizzard CVars.
- Party and raid headers are session-owned. Never respawn or rebuild their child structure during combat; structural settings require reload.
- Keep bookkeeping for foreign frames in addon-owned weak-key tables, not fields added to Blizzard or oUF objects.
- Keep Settings registration lazy; normal login must not force `Blizzard_Settings` to load.
- Keep bootstrap listeners bounded and remove them when their work completes.
- Do not add first-party `OnUpdate` loops.
- Maintain the Diablo-inspired visual language while preserving each unit's established geometry, tags, and optional elements during shared-builder changes.

## Shared checkout workflow

Work in the existing shared `main` checkout. Do not create branches or worktrees, or commit/publish changes, unless the repository owner explicitly requests that action. Preserve other contributors' edits and avoid restoring deleted files from the baseline.

## Validation

Run the complete isolated Lua suite with the discovered Lua 5.1 interpreter:

```bash
python3 tools/run_lua_tests.py
```

The current suite contains 22 tests. The repository has 97 Lua source files for syntax validation. When available, also run:

```bash
python3 tools/validate_repository_text.py
python3 tools/validate_addon.py
python3 tools/validate_group_visibility.py
python3 tools/validate_runtime_hardening.py
find . -type f -name '*.lua' -not -path './.git/*' -print0 | xargs -0 -n1 luac5.1 -p
```

Report missing tools or unavailable client checks as `NOT-RUN`; never infer a pass from source inspection. Release validation also requires in-client login/reload, secure-header transitions, casts, auras, vehicle/action-bar states, Settings, and persistence checks, plus taint and profiler evidence. Those target-client checks have not been run for this target.
