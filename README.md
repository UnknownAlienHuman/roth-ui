# Roth UI

A Diablo-inspired World of Warcraft Retail interface built around Blizzard's native unit, action-bar, aura, and Settings systems, with [oUF](https://github.com/oUF-wow/oUF) providing unit-frame lifecycle and elements.

## Compatibility

- Target client: Retail `12.1.5`, Interface `120105`, target source build `12.1.5.70688`.
- Addon version: `3.4.2`.
- Required dependency: oUF `14.1.1` or newer. Install oUF separately; Roth UI includes the library files required by its own package but not oUF.
- Source pins used for review: [Blizzard UI source `d07eb002`](https://github.com/Gethe/wow-ui-source/tree/d07eb00237d8891f153215db98a5df880a26cfe5) and [oUF `8f37c36`](https://github.com/oUF-wow/oUF/tree/8f37c36e3ed37d2fcfca2f3690f5e37e52b758c7), checked `2026-11-02`.
- Author: Neomorph.

These are compatibility targets and source-review references. The addon has **not** been validated in the target client: `GetBuildInfo`, combat behavior, taint, visual layout, and performance checks are `NOT-RUN`.

## Installation

Install the release archive's `Roth_UI` folder into `_retail_/Interface/AddOns/`. Install a compatible oUF release separately and enable both addons. Settings, commands, import/export, diagnostics, and the minimap button are included in `Roth_UI`; no companion options addon is needed.

## Commands

- `/roth` — command list
- `/roth options` — open Settings
- `/roth config` — open health orb settings
- `/rothui` and `/rui` — backward-compatible aliases for `/roth`

The minimap button opens Settings with left-click and shows command help with right-click. Settings do not open during combat.

## Runtime ownership

- Blizzard owns action buttons, paging, bindings, vehicle and override state, and native visibility. Roth UI adds button skin and `UIParent`-owned artwork.
- oUF owns unit-frame lifecycle, health/power/class resources, secure group headers, cast discovery, and managed aura events.
- One shared frame policy coalesces bounded work until combat ends. The keyed next-frame scheduler coalesces layout refreshes. Owners do not keep separate permanent combat-exit listeners.
- `core/mover_runtime.lua` is the sole mover owner for frame handles and saved point, scale, and size. Blizzard frames are not reparented.
- `core/font_policy.lua` owns Roth font updates and optional Blizzard font overrides. It restores only the exact Blizzard font state it still owns.
- `units/mini_target_scaffold.lua` shares construction for focus, boss, pet, target-of-target, and pet-target frames while each style supplies its own settings.
- The custom Experience element in `oUF/elements/experience.lua` owns rested XP display. The experience and reputation elements request action-artwork refresh only when their visibility changes.
- `core/config_persistence_owner.lua` is the only SavedVariables root writer; `core/settings_main.lua` is the only Blizzard Settings category owner.
- The legacy embedded mover helper has been removed; mover behavior lives in the main runtime.

## Source checks and tests

Run the isolated Lua tests with:

```bash
python3 tools/run_lua_tests.py
```

The runner discovers every `tests/test_*.lua` file. The current tree contains 75 addon Lua source files and 34 isolated regression scripts (109 Lua files total). The runner accepts `--lua PATH` or `LUA_BIN` and uses the interpreter's native `loadfile` parser when a standalone Lua 5.1 compiler is unavailable. Repository and addon validators are available under `tools/`; static checks do not establish in-client safety or performance.

See [release notes](RELEASE_NOTES.md), [current status](CURRENT_STATUS.md), and [12.1.5 migration notes](MIGRATION_12_1_5.md) for implementation detail and validation status.

## License

See `LICENSE.txt` and `Credits.txt`.
