# Midnight 12.1 migration record — B4.3.4

- Interface: `120100`
- Addon: `3.3.8-v57.8-B4.3.4`
- Verified live Blizzard source: `Gethe/wow-ui-source@09b9db7948abc9b9648dedaab51eb0cf3ee67b31` (`12.1.0.69933`)
- oUF requirement: `14.1.1` or newer
- Package: one `Roth_UI` addon directory

## Current contracts

### Security/access

`core/safety.lua` centralizes access checks, Forbidden-region handling, safe method/property calls and serializable ordinary-data copies. `core/safety_aspects.lua` handles operation-specific restrictions such as `Enum.ForbiddenAspect.SetTexture`. Restricted values do not enter feature state or SavedVariables.

### oUF

`core/ouf_contract.lua` fails fast when oUF is missing, older than `14.1.1` or lacks required Retail capabilities, including secure group-header spawning.

### Secure party/raid headers

oUF retains every spawned secure header. Roth UI therefore creates party/raid headers once per UI session, stores desired/applied visibility in weak-key addon metadata, changes visibility through the oUF header contract outside combat and never reparents them. Settings that alter child construction—orientation, portrait type, aura containers or healer-watch slots—persist normally but require reload. Provider visibility, scale, position and range remain live.

### Shared post-combat work

`core/frame_policy.lua` owns the keyed/coalescing `PLAYER_REGEN_ENABLED` queue used by provider/frame policy. It unregisters after every drain, executes callbacks through the safety owner and holds only active suppression snapshots in a weak-key table. A successful restoration discards the snapshot so the next cycle captures Blizzard's current state.

### Bootstrap events

`core/frame_policy_bootstrap.lua` uses a one-shot `PLAYER_LOGIN` listener and named `ContinueOnAddOnLoaded` callbacks. Its compatibility `ADDON_LOADED` fallback tracks only `Blizzard_UnitFrame` and `Blizzard_CompactRaidFrames` and unregisters after both resolve.

### Settings

Settings files remain in the single addon root, but category registration and builder execution are lazy. Normal login does not load `Blizzard_Settings`; Roth entry points load/register it synchronously when requested. Registration is idempotent and reentrancy-safe.

### Auras

`core/aura_runtime.lua` is the sole managed-aura owner. Unit layouts queue specifications. Managed groups/slots are registered at first show outside combat. Blizzard owns filtering, sorting, button allocation and updates.

### Castbars

oUF owns cast state. Roth UI implements exact callbacks and forwards potentially restricted `notInterruptible` values unchanged to native boolean sinks.

### Action buttons/art

Blizzard owns buttons, paging, bindings and vehicle/override/possess state. Roth UI applies additive presentation outside combat only. Foreign-region access and operation-specific texture restrictions are checked before mutation; artwork bookkeeping remains addon-owned.

## Repository/static acceptance

The manual workflow must pass repository text policy, B4.3.4 TOC/XML/load-order/ownership validation, secure-header/runtime hardening guards, Lua 5.1 parsing, thirteen isolated tests, deterministic double package construction and single-root ZIP inventory.

## Required client matrix

1. Clean install with `Roth_UI` plus external oUF 14.1.1+.
2. Login and `/reload` with fresh, migrated and corrupted SavedVariables.
3. Party/raid provider enable/disable, arena override, roster churn and structural settings applied after reload.
4. Click targeting/click casting and `/console taintLog 1` with secure headers.
5. Target/focus/boss cast, channel, empower and interruptibility transitions.
6. Target/focus/party/raid/nameplate managed aura layout and tooltips.
7. Stance, vehicle, override, possess and temporary action-bar states.
8. Edit Mode, action-bar rows, micro-menu/bag/stack-count presentation and UI-scale changes.
9. Orb models, bubble/spark alpha, power colors and small-unit health text modes.
10. `C_AddOnProfiler` CPU/allocation capture.

Static/source completion is not client certification. Record the exact Retail build, addon commit, scenario and observed result.
