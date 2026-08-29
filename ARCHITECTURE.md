# Roth UI architecture — B4.3

## Ownership map

| State or subsystem | Authoritative owner |
|---|---|
| SavedVariables root replacement/reset | `core/config_persistence_owner.lua` |
| Runtime config reads/writes | persistence services and `core/sv_store.lua` |
| Runtime settings actions | `core/settings_actions.lua` |
| Blizzard Settings category/pages | `Roth_UI_Options/core/settings_main.lua` and page builders |
| oUF unit-frame lifecycle | oUF 14 |
| Managed aura specification/lifecycle | `core/aura_runtime.lua` |
| Cast discovery/timing/interruptibility | oUF 14 Castbar element |
| Roth castbar visual mapping | `core/target_castbar.lua` |
| Blizzard action buttons and secure state | Blizzard UI |
| Roth action-button skin | `core/action_button_skin.lua` |
| Blizzard-frame visual suppression | `core/frame_policy.lua` plus unit/group policies |

## Resident versus LoadOnDemand

`Roth_UI` contains only combat/runtime services, unit layouts, persistence and a small options loader.

`Roth_UI_Options` is a sibling addon with `LoadOnDemand: 1`. It owns settings pages, import/export and diagnostics. Normal combat rendering does not depend on it.

## Aura lifecycle

Unit styles register plain specifications only. After oUF finishes initializing an object, Roth UI attaches a first-show hook. The first visible transition creates the managed container and its groups/slots. A first show during combat is coalesced and deferred until `PLAYER_REGEN_ENABLED`.

Blizzard candidate filters, sort methods, duration bindings, cooldowns and dispel/stealable regions remain native. Candidate filters are updated only when a normalized fingerprint changes.

## Performance constraints

- No first-party permanent `OnUpdate`; the only approved first-party `OnUpdate` is the drag worker while a mover is actively dragged.
- No raw aura scan or addon-side aura cache.
- No custom action-button owner or replacement paging system.
- No Lua status-bar smoothing loop.
- No eager 3D portrait construction for optional unit frames.
- No resident Settings page construction.

## Safety boundary

The addon does not override Blizzard globals, reparent protected Blizzard frames, unregister their events, manage Blizzard addon enable state, or write Blizzard CVars. Frame policy is reversible alpha/input suppression applied outside combat.
