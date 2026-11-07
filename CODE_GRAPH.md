# Roth UI dependency graph — 3.4.10

```text
init -> canonical ns.oUF
safety
  -> frame policy / oUF contract
  -> config owner + defaults
  -> root store + low-level value API
  -> schema/domain/reconcile services
  -> persistence control plane
  -> diagnostics/settings/transfer
  -> movers/units/action presentation
```

Critical runtime paths:

```text
unit identity value
  -> immediate access/secret gate
  -> ordinary normalized presentation state
  -> native/addon-owned sink
  -> no generic retention or logging

unit config request
  -> current canonical settings table
  -> request-scoped read-only proxy graph
  -> shared descendants reuse one proxy inside that graph
  -> graph and replaced source become collectible together

import text
  -> transfer envelope validation
  -> persistence transaction
  -> root commit + reconcile + reload
  -> exact-reference rollback on failure

persisted mover geometry
  -> value/table access gates
  -> finite bounds + point/name validation
  -> ordinary independent anchor resolution
  -> one mover-runtime registration/category
  -> snapshot current point
  -> clear + apply once
  -> restore snapshot if SetPoint fails

managed aura specifications
  -> owner/access/combat recheck
  -> create once or terminally fail each specification
  -> update successful siblings once
  -> settle batch until a new specification is added

non-player castbar
  -> func.createCastbar
  -> one TargetCastbarRuntime.Bind
  -> oUF callbacks
  -> native boolean/color sinks

Settings readiness
  -> Roth ADDON_LOADED after all builders
  -> Blizzard_Settings completion or explicit lazy load
  -> register one complete category tree
  -> partial native registration failure is terminal until reload

late Blizzard frame addon
  -> completed IsAddOnLoaded result or named ADDON_LOADED
  -> claim and detach one-shot ownership
  -> frame_policy_bootstrap keyed invalidation
  -> deferred_scheduler coalesces login/addon signals
  -> one reversible group-frame policy pass

combat-sensitive request
  -> frame_policy keyed queue
  -> newest request invalidates older pending or draining work
  -> PLAYER_REGEN_ENABLED drain rechecks combat before each callback
  -> listener removed when no pending work remains

action artwork invalidation
  -> QueueActionBarArtworkRefresh only
  -> deferred_scheduler key action-bar-background
  -> one owner refreshes layout and reapplies mover state

layout refresh requests
  -> mandatory deferred_scheduler keyed generation
  -> one timer for all keys
  -> newest callback per key runs once
  -> reentrant work enters the next generation
```

The TOC is the executable load order. `init.lua` establishes `ns.oUF`; safety modules precede all value consumers; `core/persistence_control_plane.lua` loads after root/schema services; `core/deferred_scheduler.lua` precedes move-grid, Settings refresh, target castbars, frame-policy bootstrap and action artwork; `units/mini_target_scaffold.lua` precedes its unit styles.
