# Roth UI architecture — 3.4.3

## Boundaries

| Concern | Owner |
|---|---|
| Secret/access/serialization guards | `core/safety.lua`, `core/safety_aspects.lua` |
| Canonical SavedVariables roots | `core/config_persistence_owner.lua`, `core/persistence_root_store.lua` |
| Import/export/reset transaction | `core/persistence_control_plane.lua`, `core/transfer.lua` |
| Orb persistence | `core/orb_persistence_owner.lua` |
| Combat deferral / foreign-frame state | `core/frame_policy.lua` |
| Next-frame coalescing | `core/deferred_scheduler.lua` |
| Movers | `core/mover_runtime.lua` |
| Fonts | `core/font_policy.lua` |
| Managed auras | `core/aura_runtime.lua` |
| Settings category | `core/settings_main.lua` |
| Unit/secure-header lifecycle | external oUF |
| Secure action state | Blizzard UI |

## Persistence transaction

```text
untrusted transfer envelope
  -> one bounded strict tree copy
  -> exact root/schema validation
  -> capture exact current root references
  -> one root commit
  -> one reconcile
  -> ReloadUI
  -> rollback exact references on false/throw/reload failure
```

Strict copies reject inaccessible/secret values, unsupported types, non-finite numbers, cycles, aliases, excessive depth, excessive tables/entries and excessive aggregate string bytes. Export copies first and never sanitizes live roots. Malformed legacy roots do not block reset/import recovery because rollback authority is the exact pre-transaction references; the detached snapshot is only a fallback.

Raw root getters/writers are captured by their owner and removed from shared namespace tables after load. Diagnostics retain only bounded read closures.

## Scheduling

`framePolicy.DeferUntilOutOfCombat` is the single keyed combat-exit queue. `framePolicy.DeferForObject` assigns weak-key object identities instead of deriving keys with `tostring(frame)`. `deferred_scheduler.RunNextFrame` is the sole next-frame queue. It coalesces all keys into one timer per generation, swaps generations before callback execution and isolates callback failures. Action-bar artwork has no parallel queue state or timer fallback.

## Secure/UI rules

- Never reparent protected Blizzard frames, replace Blizzard action-button ownership, unregister Blizzard events, write CVars or mutate addon enable state.
- Party/raid secure headers are created once per session; structural changes require reload.
- Managed auras use the native container contract; no raw aura scanner or parallel `UNIT_AURA` state.
- Foreign-frame suppression is transactional: a setter that mutates and then throws is detected and rolled back.
- First-party `OnUpdate` loops are prohibited.

## Compatibility evidence

- KB-selected Blizzard source remains `12.1.5.70688`; the reviewed `12.1.5.70783` delta changes Roleset restrictions, Battle.net/title-icon metadata and `UNIT_COMBAT.amount` secrecy, none of which is consumed by Roth's loaded graph.
- External oUF minimum is `14.2.1`, pinned at `c5ff6e4a09bfaf2186e205777e0fab964b5cddc1`, to retain current secret-scrubbing, tag and event fixes.
