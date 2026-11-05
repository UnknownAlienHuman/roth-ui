# Roth UI architecture — 3.4.7

## Boundaries

| Concern | Owner |
|---|---|
| Secret/access/serialization guards | `core/safety.lua`, `core/safety_aspects.lua` |
| Canonical SavedVariables roots | `core/config_persistence_owner.lua`, `core/persistence_root_store.lua` |
| Import/export/reset transaction | `core/persistence_control_plane.lua`, `core/transfer.lua` |
| Orb persistence | `core/orb_persistence_owner.lua` |
| Combat deferral / foreign-frame state | `core/frame_policy.lua` |
| Blizzard-frame load readiness | `core/frame_policy_bootstrap.lua` |
| Next-frame coalescing | `core/deferred_scheduler.lua` |
| Movers and persisted geometry | `core/mover_runtime.lua` |
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

Strict copies reject inaccessible/secret values, unsupported types, non-finite numbers, cycles, aliases, excessive depth, excessive tables/entries and excessive aggregate string bytes. Export reads roots without ensure/migration side effects, then shares the import schema validator. A reentrancy lock prevents nested import/reset and intermediate export/reconcile until cleanup. Strict copies reject metatables and gate table contents before traversal.

## Mover geometry

Mover persistence is a narrow data contract, not permission to mutate an arbitrary frame graph:

```text
stored point/size/scale
  -> gate root and each consumed value
  -> reject forbidden tables, secret/inaccessible values and NaN/Infinity
  -> validate standard anchor points and bounded global anchor names
  -> reject self anchors and layout-restricted/forbidden anchor objects
  -> fall back to UIParent when a named anchor is unavailable or unsafe
  -> snapshot the current single-anchor point
  -> apply one mutation transaction
  -> restore the snapshot if SetPoint throws or returns failure
```

A frame with multiple anchors is not rewritten from a one-point persistence record. Mover code does not infer permission from a global name and does not anchor ordinary layout to an object carrying `UntrustedLayoutScriptExecution`.

## Scheduling and readiness

`framePolicy.DeferUntilOutOfCombat` is the single keyed combat-exit queue. A newer request cancels older pending or draining work. `deferred_scheduler.RunNextFrame` is the sole next-frame queue.

`frame_policy_bootstrap` distinguishes `IsAddOnLoaded`'s loading-inclusive first return from its completed second return. Named fallback listeners remove their ownership before invoking policy code, so reentry cannot duplicate delivery. The retired `ApplyUnitFramePolicy` compatibility branch is absent.

## Secure/UI rules

- Never reparent protected Blizzard frames, replace Blizzard action-button ownership, unregister Blizzard events, write CVars or mutate addon enable state.
- Party/raid secure headers are created once per session; structural changes require reload.
- Managed auras recheck owner visibility/access when deferred work runs and do not expose a raw aura scanner.
- Foreign-frame suppression and global fonts use compare-and-restore ownership.
- Lazy portraits attach once and request their first update through oUF.
- First-party `OnUpdate` loops are prohibited.

## Compatibility evidence

- KB-selected Blizzard source remains `12.1.5.70688`; reviewed `12.1.5.70783` changes no loaded Roth surface.
- External oUF minimum is `14.2.1`, pinned at `c5ff6e4a09bfaf2186e205777e0fab964b5cddc1`.
