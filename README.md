# Roth UI

A lightweight Diablo-inspired World of Warcraft Retail interface built on the external [oUF](https://github.com/oUF-wow/oUF) framework.

## Compatibility

- World of Warcraft Retail / Midnight `12.1.0`
- Interface `120100`
- Verified live Blizzard UI baseline: `12.1.0.69933`, source `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`
- Required dependency: oUF `14.1.1` or newer
- Roth UI version: `3.3.8-v57.8-B4.3.4`
- Author: Neomorph

## Installation

Install the release archive's single addon folder into `_retail_/Interface/AddOns/`:

```text
Roth_UI/
```

Install oUF `14.1.1` or newer separately. Settings, import/export, diagnostics and the minimap button are included in `Roth_UI`; there is no companion options addon.

## Commands

- `/roth` — command list
- `/roth options` — open Settings
- `/roth config` — open Health Orb settings
- `/rothui` and `/rui` — backward-compatible aliases for `/roth`

The addon-owned minimap button opens Settings with left-click and shows command help with right-click. Settings are not opened during combat.

## Runtime architecture

- Blizzard owns action buttons, paging, bindings, vehicle/override state and visibility. Roth UI applies additive art/skin only.
- oUF owns unit-frame lifecycle, health/power/class resources, secure group headers and cast discovery/timing.
- Party and raid secure headers are created at most once per UI session. Provider visibility, scale, position and range can update live; child-structure changes are persisted as reload-required settings.
- Desired/applied group visibility and foreign-frame suppression state live in addon-owned weak-key tables, not on Blizzard/oUF objects.
- One coalescing `PLAYER_REGEN_ENABLED` queue owns bounded post-combat work and unregisters when drained.
- Group-header visibility uses the oUF header contract outside combat and never reparents protected headers.
- General aura display uses Blizzard-managed AuraContainers through oUF; Roth UI does not enumerate raw AuraData or own `UNIT_AURA` state.
- `core/safety.lua` owns Secret/Forbidden/access and serializable-copy guards; `core/safety_aspects.lua` handles operation-specific forbidden aspects.
- Blizzard Settings registration is lazy: ordinary login does not force `Blizzard_Settings` to load.
- `core/config_persistence_owner.lua` is the only SavedVariables root writer.
- `core/settings_main.lua` is the only Blizzard Settings category owner.
- `core/combat_fader.lua` is the only class-bar combat-fade owner and uses events instead of a permanent `OnUpdate`.
- Action-bar artwork remains `UIParent`-owned and does not reparent protected Blizzard frames.
- 3D portraits and managed aura containers are created lazily.
- Status-bar smoothing uses native `Enum.StatusBarInterpolation`.

## Validation

The manual `Addon validation and package` workflow performs:

- repository text-policy checks;
- TOC/XML closure, exact metadata, load-order and ownership validation;
- secure group-header lifecycle and reload-only structure checks;
- lazy Settings and operation-specific forbidden-aspect checks;
- rejection of retired aura scanners, replacement action bars, duplicate Settings/SavedVariables owners and legacy rLib modules;
- Lua 5.1 parsing of all Lua sources;
- isolated safety, frame-policy, oUF, castbar, aura, combat-fader, group-header, Settings, action-button, minimap and action-bar tests;
- two deterministic package builds followed by byte comparison;
- runtime-only ZIP inventory and SHA-256 generation.

Static checks do not prove in-client safety. Before calling a release client-certified, validate login/reload, target/focus/boss casts, party/raid auras, secure header enable/disable and reload-required transitions, stance/action bars, vehicle/override/possess states, Edit Mode, persistence migration, `/console taintLog 1` and `C_AddOnProfiler` on the target Retail client.

## License

See `LICENSE.txt` and `Credits.txt`.
