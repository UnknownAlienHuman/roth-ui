# Roth UI

Diablo-inspired World of Warcraft Retail interface built on Blizzard-owned action/UI systems and external [oUF](https://github.com/oUF-wow/oUF).

## Compatibility

- Addon: `3.4.9`
- Retail target: `12.1.5`, Interface `120105`
- Selected Blizzard source: `12.1.5.70688` (`d07eb00237d8891f153215db98a5df880a26cfe5`)
- Reviewed post-selected delta: `12.1.5.70783` (`297d7aaaa736f346b3e036f38ee088eaf7f8c07f`)
- Required dependency: oUF `14.2.1+` (`c5ff6e4a09bfaf2186e205777e0fab964b5cddc1` reviewed)
- Knowledge base: `wow-addon-engineering-kb@c2a630aa186de401262663cc8568a77988be69df`

These are source-review targets, not proof of in-client compatibility. Combat, taint, visual and profiler acceptance remain `NOT-RUN`.

## Installation

Install the archive's single `Roth_UI` directory into `_retail_/Interface/AddOns/`. Install oUF separately. Keep existing SavedVariables. Open settings with `/roth options`.

## Commands

- `/roth` — command list
- `/roth options` — Settings
- `/roth config` — health-orb settings
- `/rothui`, `/rui` — aliases

## Runtime ownership

- `init.lua` validates external oUF once and publishes the canonical `ns.oUF`; downstream modules do not fall back to a second global owner.
- Blizzard owns secure action buttons, paging, bindings, vehicle/override state and native visibility.
- oUF owns unit-frame lifecycle, secure group headers, cast discovery and managed-aura events.
- `core/persistence_control_plane.lua` owns import/reset transactions and rollback.
- `core/frame_policy.lua` owns foreign-frame suppression and the keyed combat-exit queue.
- `core/deferred_scheduler.lua` is the only next-frame scheduler and requires the Retail timer owner.
- `core/mover_runtime.lua` owns validated mover geometry and transactional point restoration.
- `core/font_policy.lua`, `core/aura_runtime.lua` and `core/settings_main.lua` remain sole subsystem owners.
- Runtime logs and SavedVariables diagnostics accept ordinary values only; inaccessible/secret values are represented by fixed neutral tokens.

## Validation

Run:

```bash
python3 tools/validate_repository_text.py
python3 tools/validate_addon.py
python3 tools/validate_group_visibility.py
python3 tools/validate_runtime_hardening.py
python3 tools/run_lua_tests.py
```

Static/stub validation does not emulate WoW's secure execution engine. See `CURRENT_STATUS.md`.

## License

See `LICENSE.txt` and `Credits.txt`.
