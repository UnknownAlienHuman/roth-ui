# Roth UI agent guide

Current production target: Retail/Midnight `12.1.0`, Interface `120100`, verified live Blizzard build `12.1.0.69933`, external oUF `14.1.1+`. Current addon version: `3.3.8-v57.8-B4.3.4`.

Before editing, read the current `UnknownAlienHuman/wow-addon-engineering-kb` channel/instructions and this repository's TOC, architecture, status and code. Inspect third-party repository policy/license files before using their implementation as evidence; a repository prohibition on AI/reference use is binding.

Authority order:

1. Current Roth UI repository code, TOC and this guide for project behavior.
2. Selected current policy/routes in `UnknownAlienHuman/wow-addon-engineering-kb`.
3. Exact pinned Blizzard source/generated API documentation for platform contracts.
4. Exact external oUF `14.1.1+` source for framework contracts.
5. Named-client runtime evidence for state/data/restriction behavior.

Hard boundaries:

- One package root: `Roth_UI`. Do not restore a separate options addon.
- `core/safety.lua` owns Secret/Forbidden/access and serializable-copy guards.
- `core/safety_aspects.lua` owns operation-specific forbidden-aspect checks.
- `core/aura_runtime.lua` is the only first-party managed-aura owner.
- Do not add raw aura scans or addon-owned `UNIT_AURA` state.
- Do not poll casts outside oUF.
- Do not branch, compare, format, serialize, retain or index secret-capable values before access gating.
- Do not restore replacement action buttons, LibActionButton, LibKeyBound or `oUF_Smooth` without a new measured design review.
- Blizzard action buttons/state drivers remain Blizzard-owned; Roth art is additive and `UIParent`-owned.
- oUF secure party/raid headers are session-owned. Never reparent or live-rebuild them; structural settings require reload.
- Keep desired/applied visibility and all foreign-widget bookkeeping in addon-owned weak-key tables.
- Use the shared frame-policy queue for bounded post-combat work; do not add parallel permanent `PLAYER_REGEN_ENABLED` owners.
- Blizzard Settings registration remains lazy and must not force `Blizzard_Settings` to load on normal login.
- Do not register a second Blizzard Settings category owner.
- Do not write SavedVariables root globals outside `core/config_persistence_owner.lua`.
- `core/combat_fader.lua` is the only class-bar fade owner; the global alias may only point to it.
- Do not add permanent first-party `OnUpdate`; the active-drag worker is the sole approved exception.
- Do not override Blizzard globals, reparent protected Blizzard frames, unregister Blizzard events or infer hidden state from errors/visibility/animation/timing.
- Retired `core/unit_policy.lua` and legacy rLib fader/grid/slash modules must remain absent.

Repository work is performed directly in `main`, with non-forced fast-forward publication and remote readback. Do not create task branches or worktrees.

Before publication run, when tools are available:

```bash
python3 tools/validate_repository_text.py
python3 tools/validate_addon.py
python3 tools/validate_group_visibility.py
python3 tools/validate_runtime_hardening.py
find . -type f -name '*.lua' -not -path './.git/*' -print0 | xargs -0 -n1 luac5.1 -p
lua5.1 tests/test_safety.lua
lua5.1 tests/test_safety_aspects.lua
lua5.1 tests/test_frame_policy.lua
lua5.1 tests/test_ouf_contract.lua
lua5.1 tests/test_target_castbar.lua
lua5.1 tests/test_aura_lazy.lua
lua5.1 tests/test_combat_fader.lua
lua5.1 tests/test_group_header_visibility.lua
lua5.1 tests/test_settings_lifecycle.lua
lua5.1 tests/test_action_button_skin.lua
lua5.1 tests/test_minimap_button.lua
lua5.1 tests/test_action_bar_background.lua
python3 tools/package_release.py
```

If Lua/client/Actions execution is unavailable, report tests as `NOT-RUN`; do not infer PASS from source review. Do not call a build client-verified without the complete in-game matrix plus taint/profiler evidence.
