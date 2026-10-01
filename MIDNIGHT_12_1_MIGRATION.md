# Midnight 12.1 migration record — B4.3.3

- Interface: `120100`
- Addon: `3.3.8-v57.8-B4.3.3`
- Verified Blizzard source: `Gethe/wow-ui-source@027d26c3406d3de2cbd2b1f67d468fe033a1bcd4` (`12.1.0.69497`)
- oUF requirement: `14.1.1` or newer
- Package: one `Roth_UI` addon directory

## Current contracts

### Security/access

`core/safety.lua` centralizes access checks, Forbidden-region handling, safe method/property calls and serializable ordinary-data copies. Restricted values do not enter feature state or SavedVariables.

### oUF

`core/ouf_contract.lua` fails fast when oUF is missing, older than `14.1.1` or lacks required Retail capabilities, including secure group-header spawning.

### Secure party/raid headers

oUF retains every spawned secure header. Roth UI therefore creates party/raid headers once per UI session, changes visibility through the oUF header contract outside combat and never reparents them. Settings that alter child construction—orientation, portrait type, aura containers or healer-watch slots—persist normally but require reload. Provider visibility, scale, position and range remain live.

### Auras

`core/aura_runtime.lua` is the sole managed-aura owner. Unit layouts queue specifications. Managed groups/slots are registered at first show outside combat. Blizzard owns filtering, sorting, button allocation and updates.

### Castbars

oUF owns cast state. Roth UI implements exact callbacks and forwards potentially restricted `notInterruptible` values unchanged to native boolean sinks.

### Settings and persistence

Settings pages, import/export, diagnostics and actions live in the single main addon. `core/config_persistence_owner.lua` is the sole SavedVariables root writer; `core/settings_main.lua` is the sole Settings category registrar.

### Action buttons/art

Blizzard owns buttons, paging, bindings and vehicle/override/possess state. Roth UI applies additive presentation only. Artwork remains `UIParent`-owned and refreshes from bounded native/Edit Mode signals.

## Repository/static acceptance

The manual workflow must pass repository text policy, B4.3.3 TOC/XML/load-order/ownership validation, Lua 5.1 parsing, safety/oUF/castbar/aura/fader/group-header/minimap/action-bar tests, deterministic double package construction and single-root ZIP inventory.

## Required client matrix

1. Clean install with `Roth_UI` plus external oUF 14.1.1+.
2. Login and `/reload` with fresh, migrated and corrupted SavedVariables.
3. Party/raid provider enable/disable, roster churn and structural settings applied after reload.
4. Click targeting/click casting, arena transitions and `/console taintLog 1` with secure headers.
5. Target/focus/boss cast, channel, empower and interruptibility transitions.
6. Target/focus/party/raid/nameplate managed aura layout and tooltips.
7. Stance, vehicle, override, possess and temporary action-bar states.
8. Edit Mode, action-bar rows, micro-menu/bag/stack-count presentation and UI-scale changes.
9. Orb models, bubble/spark alpha, power colors and small-unit health text modes.
10. `C_AddOnProfiler` CPU/allocation capture.

Static/source completion is not client certification. Record the exact Retail build, addon commit, scenario and observed result.
