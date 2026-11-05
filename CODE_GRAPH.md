# Roth UI dependency graph — 3.4.7

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

late Blizzard frame addon
  -> completed IsAddOnLoaded result or named ADDON_LOADED
  -> remove one-shot ownership before policy callback
  -> reapply reversible frame policy

combat-sensitive request
  -> frame_policy keyed queue
  -> newest request invalidates older pending or draining work
  -> PLAYER_REGEN_ENABLED drain rechecks combat before each callback

layout refresh requests
  -> deferred_scheduler keyed generation
  -> one timer for all keys
  -> newest callback per key runs once
```

The TOC is the executable load order. `core/safety.lua` and `core/safety_aspects.lua` precede mover consumers; `core/persistence_control_plane.lua` loads after root/schema services; `core/deferred_scheduler.lua` precedes action artwork; `units/mini_target_scaffold.lua` precedes its unit styles.
