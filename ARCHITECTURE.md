# Roth UI architecture — 3.4.10

## Boundaries

| Concern | Owner |
|---|---|
| Secret/access/serialization guards | `core/safety.lua`, `core/safety_aspects.lua` |
| Canonical external oUF reference | `init.lua` -> `ns.oUF` |
| Canonical SavedVariables roots | `core/config_persistence_owner.lua`, `core/persistence_root_store.lua` |
| Import/export/reset transaction | `core/persistence_control_plane.lua`, `core/transfer.lua` |
| Orb persistence | `core/orb_persistence_owner.lua` |
| Combat deferral / foreign-frame state | `core/frame_policy.lua` |
| Blizzard-frame load readiness | `core/frame_policy_bootstrap.lua` |
| Next-frame coalescing | `core/deferred_scheduler.lua` |
| Movers and persisted geometry | `core/mover_runtime.lua` |
| Secure group-header visibility | `core/group_header_visibility.lua` -> oUF `header:SetVisibility` |
| Action-bar artwork invalidation | `core/action_bar_background.lua` -> `QueueActionBarArtworkRefresh` |
| Non-player castbar callbacks | `core/lib.lua` -> `core/target_castbar.lua` |
| Fonts | `core/font_policy.lua` |
| Managed auras | `core/aura_runtime.lua` |
| Settings category | `core/settings_main.lua` |
| Session logging / SV diagnostics | `core/logger.lua`, `core/sv_doctor.lua` |
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

Read-only unit configuration is exposed as a request-scoped proxy graph. One graph preserves descendant alias identity, but no global cache retains replaced SavedVariables roots. Rejected writes use a fixed ordinary error and never stringify an arbitrary key. Lua 5.1-inoperative table `__pairs`/`__len` pseudo-contracts are absent.

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
  -> restore the snapshot if SetPoint fails
```

A frame with multiple anchors is not rewritten from a one-point persistence record. Constructors pass their canonical category to `mover_runtime` and register once. Flat `ns.*`/`func.*` registry and layout aliases are not published.

## Scheduling and readiness

`framePolicy.DeferUntilOutOfCombat` is the single keyed combat-exit queue. A newer request cancels older pending or draining work. `deferred_scheduler.RunNextFrame` is the sole next-frame queue, requires `C_Timer.After`, swaps generations before delivery and isolates callback failures. A missing scheduler dependency is a load-order error, never permission to recurse synchronously.

Settings font/health refresh, target-castbar refresh and action-bar artwork invalidation all require the shared scheduler. External data-bar and Settings consumers may only queue action artwork; synchronous and per-frame refresh aliases are absent.

`frame_policy_bootstrap` distinguishes `IsAddOnLoaded`'s loading-inclusive first return from its completed second return. Named completion callbacks claim their one-shot state before scheduling. Login and Blizzard-addon completion signals share one scheduler key, so equivalent same-frame invalidations produce one group-frame policy pass. The font owner is invoked through the safety boundary and cannot suppress that independent policy invalidation.

## Unit identity and framework ownership

`init.lua` validates the required external oUF version and publishes one namespace reference. All elements, helpers and layouts require `ns.oUF`; no downstream module can silently adopt a different `_G.oUF` instance.

Unit identity, class, reaction and target-state values are gated before comparison, stringification, table indexing or retention. Inaccessible target metadata collapses to a neutral/unavailable presentation. Player runtime identity is retained only when ordinary and type-valid.

`func.createCastbar` is the sole non-player castbar binding site. Unit layouts construct castbars but do not bind a second callback owner or retain an unused cast-unit field.

Secure party/raid visibility uses the required oUF header `SetVisibility` method. Roth does not install a second raw state driver, expose its weak bookkeeping table or keep historical park/forget compatibility routes.

## Managed aura lifecycle

Each owner keeps one finite specification batch:

```text
new specification
  -> owner/access/combat recheck
  -> create once or mark terminal failure
  -> activate/update successful siblings once
  -> mark the batch settled
```

Repeated `OnShow` delivery does not rescan a batch whose specifications are all successful or terminally failed. Adding a new specification reopens exactly one batch without retrying failed managed adoption.

## Diagnostic transports

Session logs and SavedVariables reports are ordinary-only transports. They do not stringify, key, compare or retain inaccessible/secret values. Restricted diagnostic input is replaced by fixed ordinary markers such as `<restricted>` and `<restricted-key>`.

## Secure/UI rules

- Never reparent protected Blizzard frames, replace Blizzard action-button ownership, unregister Blizzard events, write CVars or mutate addon enable state.
- Party/raid secure headers are created once per session; structural changes require reload.
- Managed auras recheck owner visibility/access when deferred work runs and do not expose a raw aura scanner.
- Foreign-frame suppression and global fonts use compare-and-restore ownership.
- Lazy portraits attach once and request their first update through oUF.
- First-party `OnUpdate` loops are prohibited.

## Settings lifecycle

Settings registration waits for both this addon's completed file load and completed Blizzard_Settings load. Presence of the global Settings table or the first IsAddOnLoaded return is not completion. Explicit opening may lazily load Blizzard_Settings after Roth's builders are ready.

A failed load before native registration releases the lock and permits a later explicit open. Once native control registration has begun, an exception is terminal until reload: partial controls are not replayed and the root category is not intentionally published before its builders complete.

Managed aura duration widgets, cooldown widgets and their font are construction-time presentation. Their settings mark reload required; ordinary Roth fonts still refresh immediately. Candidate-filter changes remain live and do not recreate or inspect adopted children. Appearance-only changes do not trigger candidate-filter scans.

## Compatibility evidence

- KB-selected Blizzard source remains `12.1.5.70688`; reviewed `12.1.5.70783` changes no loaded Roth surface.
- External oUF minimum is `14.2.1`, pinned at `c5ff6e4a09bfaf2186e205777e0fab964b5cddc1`.
