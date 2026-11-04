# Roth UI

A Diablo-inspired World of Warcraft Retail interface built around Blizzard-owned action bars and widgets, with [oUF](https://github.com/oUF-wow/oUF) providing unit-frame lifecycle and elements.

## Compatibility

- Addon version: `3.4.3`.
- Target client: Retail `12.1.5`, Interface `120105`, selected source build `12.1.5.70688`.
- Required dependency: oUF `14.1.1` or newer, installed separately.
- Review pins: Blizzard UI source `d07eb00237d8891f153215db98a5df880a26cfe5`, oUF `8f37c36e3ed37d2fcfca2f3690f5e37e52b758c7`, and knowledge base `b03e1635d0ff8bcd6be4f4dfac589dafec4e5e83`.

These are source-review targets, not client certification. Combat, taint, visual and profiler acceptance remain `NOT-RUN` until recorded in the target client.

## Installation

Install the release archive's `Roth_UI` folder into `_retail_/Interface/AddOns/`. Install a compatible oUF release separately and enable both addons. Keep existing SavedVariables when upgrading.

## Commands

- `/roth` — command list
- `/roth options` — open Settings
- `/roth config` — open Health Orb settings
- `/rothui` and `/rui` — compatibility aliases

## Runtime ownership

- Blizzard owns secure action buttons, paging, bindings, vehicle/override state and native visibility. Roth UI adds presentation only.
- oUF owns unit-frame lifecycle, secure group headers, cast discovery and managed aura events.
- `core/frame_policy.lua` owns the keyed out-of-combat queue and reversible foreign-frame suppression. Partial writes are rolled back before returning failure.
- `core/persistence_control_plane.lua` owns transfer and reset transactions. Import validates detached data, snapshots current roots, commits once and rolls back rejected reconciliation or failed reload.
- `core/config_persistence_owner.lua` remains the only SavedVariables root writer; `core/orb_persistence_owner.lua` remains the sole owner of orb template and character-state migration.
- `core/mover_runtime.lua`, `core/font_policy.lua`, `core/aura_runtime.lua` and `core/settings_main.lua` remain the sole owners of their respective lifecycles.

## Validation

Pull requests and pushes to `main` automatically run repository policy checks, load-graph/ownership validation, Lua 5.1 parsing, every isolated regression, deterministic packaging and artifact upload. Static and stub tests do not prove secure-client behavior.

See [release notes](RELEASE_NOTES.md), [current status](CURRENT_STATUS.md), and [architecture](ARCHITECTURE.md).

## License

See `LICENSE.txt` and `Credits.txt`.
