# Roth UI architecture — 3.4.3

## Compatibility target

Retail `12.1.5`, Interface `120105`, selected source build `12.1.5.70688`; required oUF `14.1.1+`. These pins are source evidence, not client acceptance.

## Package and load boundary

Roth UI ships as one addon root. oUF is a separately installed required dependency. `LoadSavedVariablesFirst: 1` makes Roth's declared roots available before file-scope migration and frame construction; it does not establish player/world/protected-action readiness.

## Ownership map

| State or subsystem | Authoritative owner |
|---|---|
| Secret/access/serialization guards | `core/safety.lua` |
| Operation-specific forbidden aspects | `core/safety_aspects.lua` |
| Canonical SavedVariables roots and config proxy | `core/config_persistence_owner.lua`, `core/persistence_root_store.lua` |
| Import/export/reset transaction | `core/persistence_control_plane.lua`, `core/transfer.lua` |
| Orb schema/store lifecycle | `core/orb_persistence_owner.lua` |
| Blizzard Settings category | `core/settings_main.lua` |
| oUF unit and secure-header lifecycle | external oUF `14.1.1+` |
| Combat deferral and reversible foreign-frame state | `core/frame_policy.lua` |
| Keyed next-frame work | `core/deferred_scheduler.lua` |
| Movers | `core/mover_runtime.lua` |
| Fonts | `core/font_policy.lua` |
| Managed auras | `core/aura_runtime.lua` |
| Blizzard action state | Blizzard UI |
| Roth action presentation | `core/action_button_skin.lua`, `core/action_bar_background.lua` |

## Persistence transaction

```text
untrusted transfer envelope
  -> strict detached tree validation
  -> snapshot current account + character roots
  -> one canonical root replacement
  -> schema reconciliation
  -> accept, or restore snapshot and reconcile rollback
```

Export follows the inverse safety boundary: copy the complete canonical roots first, then serialize the detached document. Export never sanitizes live state. Shared-reference graphs, cycles, restricted values, unsupported types and non-finite numbers fail the strict boundary.

## Lifecycle

Configuration defaults and canonical roots are available before file-scope unit consumers. The control plane retains only `PLAYER_LOGIN` reconciliation and `PLAYER_LOGOUT` sanitation; orb persistence keeps its existing bounded addon-load initialization owner.

`framePolicy.DeferUntilOutOfCombat` remains the sole keyed combat-exit queue. Foreign-frame suppression captures restorable state, applies both writes as a transaction and rolls back a partial failure before returning false.

## Secure/UI constraints

- Never reparent protected Blizzard frames, replace Blizzard action ownership, unregister Blizzard events, mutate enable state or write Blizzard CVars.
- Secure party/raid headers are session-owned and never rebuilt during combat.
- Managed aura data and cast discovery remain Blizzard/oUF-owned.
- No first-party permanent `OnUpdate` loop, raw aura cache, raw cast poller or Lua status-bar smoothing owner is permitted.
