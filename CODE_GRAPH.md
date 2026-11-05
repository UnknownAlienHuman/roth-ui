# Roth UI dependency graph — 3.4.4

```text
safety
  -> frame policy / oUF contract
  -> config owner + defaults
  -> root store + low-level value API
  -> schema/domain/reconcile services
  -> persistence control plane
  -> diagnostics/settings/transfer
  -> units/action presentation
```

Critical runtime paths:

```text
import text
  -> transfer envelope validation
  -> persistence transaction
  -> root commit + reconcile + reload
  -> exact-reference rollback on failure

combat-sensitive request
  -> frame_policy keyed queue
  -> PLAYER_REGEN_ENABLED drain
  -> listener removed

layout refresh requests
  -> deferred_scheduler keyed generation
  -> one timer for all keys
  -> newest callback per key runs once
  -> reentrant work enters the next generation
```

The TOC is the executable load order. `core/safety.lua` precedes all consumers; `core/persistence_control_plane.lua` loads after root/schema services; `core/deferred_scheduler.lua` precedes action artwork; `units/mini_target_scaffold.lua` precedes its unit styles.
