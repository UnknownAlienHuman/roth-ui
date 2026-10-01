# Midnight 12.1 migration record — B4.3.2

- Interface: `120100`
- Addon: `3.3.8-v57.8-B4.3.2`
- Verified Blizzard source: `Gethe/wow-ui-source@027d26c3406d3de2cbd2b1f67d468fe033a1bcd4` (`12.1.0.69497`)
- oUF requirement: `14.0.2` or newer
- Package: one `Roth_UI` addon directory

## Removed legacy architecture

- legacy `self.Buffs` / `self.Debuffs` scanners;
- addon-owned `UNIT_AURA` application state;
- raw `C_UnitAuras` / `AuraUtil.ForEachAura` display paths;
- compatibility aura monkey-patching;
- replacement action bars and experimental secure ownership;
- LibActionButton/LibKeyBound resident dependencies;
- Lua smoothing and retired rLib frame-fader/grid/slash modules;
- layout-side `UnitCastingInfo` / `UnitChannelInfo` polling;
- duplicate SavedVariables root writer and Settings owner;
- separate `Roth_UI_Options` addon root;
- global Blizzard overrides, event unregistering and protected-frame reparenting;
- old `core/unit_policy.lua` suppression owner.

## Current contracts

### Security/access

`core/safety.lua` centralizes access checks, Forbidden-region handling, safe method/property calls and serializable ordinary-data copies. Restricted values do not enter feature state or SavedVariables.

### oUF

`core/ouf_contract.lua` fails fast when oUF is missing, older than `14.0.2` or lacks required Retail 12.1 capabilities.

### Auras

`core/aura_runtime.lua` is the sole managed-aura owner. Unit layouts queue specifications. Managed groups/slots are registered at first show outside combat. Blizzard owns filtering, sorting, button allocation and updates.

### Castbars

oUF owns cast state. Roth UI implements exact oUF 14 callbacks and forwards potentially restricted `notInterruptible` values unchanged to native boolean sinks.

### Settings and persistence

Settings pages, import/export, diagnostics and actions live in the main addon. `core/config_persistence_owner.lua` is the sole SavedVariables root writer; `core/settings_main.lua` is the sole Settings category registrar.

### Action buttons/art

Blizzard owns buttons, paging, bindings and vehicle/override/possess state. Roth UI applies additive presentation only. Artwork remains `UIParent`-owned and refreshes from bounded native/Edit Mode signals. Login booleans are not treated as unit tokens.

### Combat fading

`core/combat_fader.lua` owns all class-bar fading through combat events and weak state. `_G.rCombatFrameFader` is retained only as a thin compatibility alias to that owner.

### Minimap/commands

An addon-owned eventless minimap button opens Settings/help. `/rothui` and `/rui` route to the existing `/roth` parser.

## Repository/static acceptance

The manual workflow must pass:

1. repository text-policy guard;
2. B4.3.2 TOC/XML/load-order/ownership validator;
3. Lua 5.1 parse of all Lua files;
4. safety, oUF, castbar, aura, combat-fader, minimap and action-bar event tests;
5. deterministic double package build and byte comparison;
6. ZIP inventory containing one runtime `Roth_UI` root and no service/development files.

## Required client matrix

1. Clean install with `Roth_UI` plus external oUF 14.0.2+.
2. Login and `/reload` with fresh, migrated and corrupted SavedVariables.
3. Target/focus/boss cast, channel, empower, interruptible/non-interruptible transitions.
4. Target/focus/party/raid/nameplate managed aura layout and tooltips.
5. Supported healer classes and spell coverage after spec changes.
6. Combat entry/exit, retargeting and group-size transitions.
7. Stance, vehicle, override, possess and temporary action-bar states.
8. Edit Mode, action-bar rows, micro-menu/bag/stack-count presentation and UI-scale changes.
9. Orb models, bubble/spark alpha, power colors and small-unit health text modes.
10. Settings/minimap/commands in and out of combat.
11. `/console taintLog 1`, Lua errors and `C_AddOnProfiler` CPU/allocation capture.

Static/source completion is not client certification. Record the exact Retail build, addon commit, scenario and observed result.
