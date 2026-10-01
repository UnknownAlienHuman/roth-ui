# Roth UI

A lightweight Diablo-inspired World of Warcraft Retail interface built on the external [oUF](https://github.com/oUF-wow/oUF) framework.

## Compatibility

- World of Warcraft Retail / Midnight `12.1.0`
- Interface `120100`
- Verified Blizzard UI baseline: `12.1.0.69497`, source `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`
- Required dependency: oUF `14.0.2` or newer
- Roth UI version: `3.3.8-v57.8-B4.3.2`
- Author: Neomorph

## Installation

Install the release archive's single addon folder into `_retail_/Interface/AddOns/`:

```text
Roth_UI/
```

Install oUF `14.0.2` or newer separately. Settings, import/export, diagnostics and the minimap button are included in `Roth_UI`; there is no `Roth_UI_Options` companion folder.

## Commands

- `/roth` — command list
- `/roth options` — open Settings
- `/roth config` — open Health Orb settings
- `/rothui` and `/rui` — backward-compatible aliases for `/roth`

The addon-owned minimap button opens Settings with left-click and shows command help with right-click. Settings are not opened during combat.

## Runtime architecture

- Blizzard owns action buttons, paging, bindings, vehicle/override state and visibility. Roth UI applies additive art/skin only.
- oUF owns unit-frame lifecycle, health/power/class resources and cast discovery/timing.
- General aura display uses Blizzard-managed AuraContainers through oUF 14; Roth UI does not enumerate raw AuraData or own `UNIT_AURA` state.
- `core/safety.lua` owns Secret/Forbidden/access and serializable-copy guards.
- `core/config_persistence_owner.lua` is the only SavedVariables root writer.
- `core/settings_main.lua` is the only Blizzard Settings category owner.
- `core/combat_fader.lua` is the only class-bar combat-fade owner and uses events instead of a permanent `OnUpdate`.
- Action-bar artwork remains `UIParent`-owned and does not reparent protected Blizzard frames.
- 3D portraits and managed aura containers are created lazily.
- Status-bar smoothing uses native `Enum.StatusBarInterpolation`.

## Validation

The manual `Addon validation and package` workflow performs:

- repository text-policy checks;
- TOC/XML closure, metadata, load-order and ownership validation;
- rejection of retired aura scanners, replacement action bars, duplicate Settings/SavedVariables owners and legacy rLib modules;
- Lua 5.1 parsing of all Lua sources;
- isolated safety, oUF, castbar, aura, combat-fader, minimap and action-bar event tests;
- two deterministic package builds followed by byte comparison;
- runtime-only ZIP inventory and SHA-256 generation.

Static checks do not prove in-client safety. Before calling a release client-certified, validate login/reload, target/focus/boss casts, party/raid auras, stance/action bars, vehicle/override/possess states, Edit Mode, persistence migration, `/console taintLog 1` and `C_AddOnProfiler` on the target Retail client.

## License

See `LICENSE.txt` and `Credits.txt`.
