# Midnight 12.1 migration record — B4.3

- Interface: `120100`
- Addon: `3.3.8-v57.8-B4.3`
- Blizzard source: `Gethe/wow-ui-source@027d26c3406d3de2cbd2b1f67d468fe033a1bcd4` (`12.1.0.69497`)
- oUF: `14.0.2` / `cbdb1d2f33bfcf4e9a5e44f02df3ebcefd35b491`

## Removed legacy architecture

- legacy `self.Buffs` / `self.Debuffs` scanner implementations;
- addon-owned `UNIT_AURA` application state;
- raw `C_UnitAuras` and `AuraUtil.ForEachAura` display paths;
- compatibility aura guard/monkey-patching layer;
- replacement action bars and experimental secure ownership;
- LibActionButton and LibKeyBound resident dependencies;
- Lua `oUF_Smooth` update loop;
- layout-side `UnitCastingInfo` / `UnitChannelInfo` polling;
- duplicate SavedVariables root writer;
- global Blizzard function overrides and protected-frame reparenting.

## Current contracts

### Auras

`core/aura_runtime.lua` is the sole first-party managed-aura owner. Unit layouts queue specifications. Managed groups/slots are registered only at first show, outside combat. Blizzard owns parsing, filtering, sorting, button allocation and updates.

### Castbars

oUF owns cast state. Roth UI implements the exact `PostCastStart` and `PostCastInterruptible` signatures and forwards `notInterruptible` unchanged to `SetAlphaFromBoolean` and `SetVertexColorFromBoolean`.

### Settings

Runtime actions remain resident. Blizzard Settings registration, page construction, import/export and diagnostics live in `Roth_UI_Options` with `LoadOnDemand: 1`.

### Action buttons

Blizzard owns buttons and secure state. Roth UI applies only additive textures/font/cooldown presentation to public button regions.

## Required client matrix

1. Clean install with both Roth folders and oUF 14.0.2+.
2. Login and `/reload` with fresh and migrated SavedVariables.
3. Target/focus/boss cast, channel, empower, interruptible and non-interruptible transitions.
4. Target/focus/party/raid managed aura layout and tooltips.
5. Supported healer classes and spell coverage after spec changes.
6. Combat entry/exit, retargeting and group-size transitions.
7. Vehicle, override, possess and temporary shapeshift states.
8. Edit Mode, movers and Settings LoadOnDemand behavior.
9. `/console taintLog 1`, Lua errors and `C_AddOnProfiler` CPU/allocation capture.
