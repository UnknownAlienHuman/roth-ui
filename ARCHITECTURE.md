# Roth UI architecture — B4.3.4

## Package boundary

Roth UI ships one addon root:

```text
Roth_UI/
```

Settings, import/export, diagnostics, commands and the minimap button are part of the same TOC. Blizzard Settings registration and page construction are deferred until `Blizzard_Settings` is loaded or Roth's own settings entry point is opened.

## Ownership map

| State or subsystem | Authoritative owner |
|---|---|
| Secret/Forbidden/access/serialization guards | `core/safety.lua` |
| Operation-specific forbidden aspects | `core/safety_aspects.lua` |
| External oUF capability/version contract | `core/ouf_contract.lua` |
| SavedVariables root replacement/reset | `core/config_persistence_owner.lua` |
| Runtime config reads/writes | persistence services and `core/sv_store.lua` |
| Runtime settings actions | `core/settings_actions.lua` |
| Blizzard Settings category/pages | `core/settings_main.lua` and page builders |
| Slash command parser | `core/slashcmd.lua` |
| Backward-compatible slash aliases | `core/slash_aliases.lua` |
| Minimap entry point | `core/minimap_button.lua` |
| oUF unit-frame/secure-header lifecycle | external oUF `14.1.1+` |
| Secure group-header visibility | `core/group_header_visibility.lua` |
| Secure group-structure policy | `core/group_structure_contract.lua` |
| Shared post-combat deferral / reversible frame policy | `core/frame_policy.lua` |
| Managed aura specification/lifecycle | `core/aura_runtime.lua` |
| Cast discovery/timing/interruptibility | oUF Castbar element |
| Roth castbar visual mapping | `core/target_castbar.lua` |
| Class-bar combat fading | `core/combat_fader.lua` |
| Blizzard action buttons and secure state | Blizzard UI |
| Roth action-button skin | `core/action_button_skin.lua` |
| Roth action-bar artwork | `core/action_bar_background.lua` |
| Blizzard-frame provider policy | `core/group_policy.lua` and `core/frame_policy_bootstrap.lua` |

## Secure party/raid lifecycle

oUF `SpawnHeader` creates protected headers and retains them in its header registry. Roth UI therefore treats each party/raid header as session-owned:

```text
spawn once outside combat
  -> configure child structure once
  -> retain header for the UI session
  -> update visibility/scale/position/range only through supported paths
  -> apply structural settings after reload
```

`GroupHeaderVisibility` stores desired/applied visibility in a weak-key addon table, uses `header:SetVisibility` when available, falls back to a state driver only outside combat and never reparents a header. Temporary provider/arena overrides do not overwrite the configured visibility condition.

All bounded post-combat provider and suppression work routes through `framePolicy.DeferUntilOutOfCombat`. The queue is keyed/coalesced, executes callbacks through the safety owner and unregisters `PLAYER_REGEN_ENABLED` after every drain.

## Settings lifecycle

The Roth Settings files remain in the single addon root, but category registration and builder execution are lazy. Login does not force `Blizzard_Settings` to load. `/roth options`, `/roth config` and the minimap entry synchronously load/register Settings when needed. Registration is idempotent and guarded against reentrant `LoadAddOn` callbacks.

## Aura lifecycle

Unit styles register plain specifications only. After oUF initializes an object, Roth UI attaches a first-show hook. The first visible transition creates the managed container and groups/slots outside combat; a first show during combat is deferred until `PLAYER_REGEN_ENABLED`.

Blizzard candidate filters, sorting, DurationObjects, cooldowns and dispel/stealable regions remain native. Roth UI does not enumerate raw AuraData or own `UNIT_AURA` state.

## Action bars

Blizzard owns secure buttons, paging, state drivers, vehicles, override/possess state, bindings and visibility. Roth UI adds presentation only outside combat. Foreign-region access and operation-specific texture restrictions are checked before mutation; bookkeeping remains in weak-key addon tables.

## Performance constraints

- No first-party permanent `OnUpdate`; the only approved one is the temporary drag worker.
- No raw aura scan or addon-side aura cache.
- No replacement action-button owner or paging system.
- No Lua status-bar smoothing loop.
- No eager 3D portrait construction for optional unit frames.
- No secure party/raid header respawn loop.
- No parallel permanent post-combat queues.
- No eager Blizzard Settings registration.
- No unbounded event/timer retry loop or broad foreign-frame sweep.

## Safety boundary

The addon does not override Blizzard globals, reparent protected Blizzard frames, unregister Blizzard events, manage Blizzard addon enable state or write Blizzard CVars. Potentially restricted values are gated before Lua use. Operation-specific forbidden aspects are queried before relevant foreign-widget mutations. Addon persistence accepts only ordinary serializable primitives/tables.
