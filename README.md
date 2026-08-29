# Roth UI

A lightweight Diablo-inspired World of Warcraft Retail interface built on the external [oUF](https://github.com/oUF-wow/oUF) framework.

## Compatibility

- World of Warcraft Retail / Midnight `12.1.0`
- Interface `120100`
- Verified Blizzard UI source: `12.1.0.69497`, commit `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`
- Required dependency: oUF `14.0.2` or newer
- Roth UI version: `3.3.8-v57.8-B4.3`
- Author: Neomorph

## Installation

Install both folders from the release archive into `_retail_/Interface/AddOns/`:

```text
Roth_UI/
Roth_UI_Options/
```

Install oUF `14.0.2` or newer separately. `Roth_UI_Options` is LoadOnDemand and is loaded only when settings, import/export, or diagnostics are requested.

## Runtime architecture

- Blizzard owns action buttons, paging, bindings, vehicle/override state and visibility. Roth UI applies an additive skin only.
- oUF owns unit health, power, class resources, runes, cast discovery and cast timing.
- General auras use Blizzard managed `AuraContainer` objects through oUF 14.
- Aura specifications are queued during unit-frame construction; `CreateAuras` and `AddGroup`/`AddSlot` are deferred until the frame is first shown.
- Roth UI does not enumerate raw `AuraData` or maintain addon-owned `UNIT_AURA` state.
- Target/focus/boss castbars forward oUF interruptibility directly to native boolean sinks; the value is never branched on in Lua.
- 3D portraits are created only when their frame is first shown.
- Status-bar smoothing uses native `Enum.StatusBarInterpolation`; the old Lua smoothing loop is removed.
- SavedVariables root replacement has one owner: `core/config_persistence_owner.lua`.

## Validation

The repository gate performs:

- main and LoadOnDemand TOC/XML closure validation;
- exact Interface/build/oUF metadata checks;
- critical load-order and ownership checks;
- rejection of retired aura scanners, replacement action bars and legacy libraries;
- rejection of raw aura enumeration and raw cast polling in first-party code;
- Lua 5.1 parsing of all sources;
- castbar secret-sink and lazy-aura lifecycle regression tests;
- two deterministic package builds followed by byte comparison;
- runtime-only ZIP verification.

Static checks do not prove in-client combat safety. Before describing a build as client-certified, validate login/reload, target/focus/boss casts, party/raid auras, combat transitions, vehicles/override states, Edit Mode and `/console taintLog 1` in the target Retail build.

## License

See `LICENSE.txt` and `Credits.txt`.
