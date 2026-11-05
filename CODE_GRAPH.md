# Roth UI dependency graph — 3.4.8

```text
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
import text
  -> transfer envelope validation
  -> persistence transaction
  -> root commit + reconcile + reload
  -> exact-reference rollback on failure

persisted mover geometry
  -> value/table access gates
  -> finite bounds + point/name validation
  -> ordinary independent anchor resolution
  -> snapshot current point
  -> clear + apply once
  -> restore snapshot if SetPoint fails

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

layout refresh requests
  -> deferred_scheduler keyed generation
  -> one timer for all keys
  -> newest callback per key runs once
  -> reentrant work enters the next generation
```

The TOC is the executable load order. `core/safety.lua` and `core/safety_aspects.lua` precede mover consumers; `core/persistence_control_plane.lua` loads after root/schema services; `core/deferred_scheduler.lua` precedes frame-policy bootstrap and action artwork; `units/mini_target_scaffold.lua` precedes its unit styles.
