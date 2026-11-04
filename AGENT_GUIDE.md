# Roth UI agent guide

## Current target

Addon `3.4.3` targets Retail `12.1.5`, Interface `120105`, source build `12.1.5.70688`. Review pins: Blizzard UI `d07eb00237d8891f153215db98a5df880a26cfe5`, oUF `8f37c36e3ed37d2fcfca2f3690f5e37e52b758c7`, KB `b03e1635d0ff8bcd6be4f4dfac589dafec4e5e83`. Client combat, taint, visual and performance acceptance is `NOT-RUN`.

Read `README.md`, `ARCHITECTURE.md`, `CODE_INDEX.md`, `CODE_GRAPH.md`, `CURRENT_STATUS.md`, the TOC and applicable knowledge-base contracts before editing.

## Ownership boundaries

- `core/safety.lua` owns access and serialization guards. Strict import/export documents must be complete trees; never silently drop unsupported descendants or aliases.
- `core/config_persistence_owner.lua` is the SavedVariables root writer. `core/persistence_control_plane.lua` owns transfer/reset transaction orchestration.
- Export works on detached strict copies. Import snapshots both roots, commits once and rolls back failed replacement/reconciliation. Do not add a second import path.
- `LoadSavedVariablesFirst` makes declared roots available before file-scope consumers. Keep root migration and later player-ready reconciliation as separate, explicit lifecycle stages.
- `core/frame_policy.lua` owns foreign-frame suppression and the keyed combat-exit queue. Partial mutation must roll back.
- oUF owns unit frames, secure group headers, cast discovery and managed aura events. Blizzard owns secure action state.
- `core/mover_runtime.lua`, `core/font_policy.lua`, `core/aura_runtime.lua` and `core/settings_main.lua` remain sole owners.

## Validation

Run:

```bash
python3 tools/validate_repository_text.py
python3 tools/validate_addon.py
python3 tools/validate_group_visibility.py
python3 tools/validate_runtime_hardening.py
python3 tools/run_lua_tests.py
```

The current tree contains 36 isolated regression scripts and 111 Lua files. GitHub Actions repeats the full Lua 5.1 and deterministic-package gate on every pull request and push to `main`. Report unavailable client checks as `NOT-RUN`; never infer secure-client acceptance from source tests.
