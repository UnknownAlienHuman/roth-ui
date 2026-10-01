# Roth UI architecture — B4.3.2

## Package boundary

Roth UI ships one addon root:

```text
Roth_UI/
```

Settings, import/export, diagnostics, commands and the minimap button are part of the same TOC. `Roth_UI_Options` is retired and rejected by the release validator.

## Ownership map

| State or subsystem | Authoritative owner |
|---|---|
| Secret/Forbidden/access/serialization guards | `core/safety.lua` |
| External oUF capability/version contract | `core/ouf_contract.lua` |
| SavedVariables root replacement/reset | `core/config_persistence_owner.lua` |
| Runtime config reads/writes | persistence services and `core/sv_store.lua` |
| Runtime settings actions | `core/settings_actions.lua` |
| Blizzard Settings category/pages | `core/settings_main.lua` and page builders |
| Slash command parser | `core/slashcmd.lua` |
| Backward-compatible slash aliases | `core/slash_aliases.lua` |
| Minimap entry point | `core/minimap_button.lua` |
| oUF unit-frame lifecycle | external oUF 14.0.2+ |
| Managed aura specification/lifecycle | `core/aura_runtime.lua` |
| Cast discovery/timing/interruptibility | oUF 14 Castbar element |
| Roth castbar visual mapping | `core/target_castbar.lua` |
| Class-bar combat fading | `core/combat_fader.lua` |
| Blizzard action buttons and secure state | Blizzard UI |
| Roth action-button skin | `core/action_button_skin.lua` |
| Roth action-bar artwork | `core/action_bar_background.lua` |
| Blizzard-frame visual suppression | `core/frame_policy.lua` and `core/group_policy.lua` |

## Load order

```text
embedded rLib drag/snap subset
  -> external libraries
  -> init bridge
  -> safety
  -> oUF contract
  -> config persistence owner/defaults/runtime services
  -> settings/diagnostics/commands/minimap
  -> unit/aura/frame-policy runtime
  -> unit layouts
  -> action-button skin and action-bar artwork
```

Safety and oUF validation fail fast before configuration and frame construction. Settings actions load before all page builders and before the minimap button.

## Aura lifecycle

Unit styles register plain specifications only. After oUF initializes an object, Roth UI attaches a first-show hook. The first visible transition creates the managed container and groups/slots outside combat; a first show during combat is deferred until `PLAYER_REGEN_ENABLED`.

Blizzard candidate filters, sorting, DurationObjects, cooldowns and dispel/stealable regions remain native. Roth UI does not enumerate raw AuraData or own `UNIT_AURA` state.

## Action bars

Blizzard owns secure buttons, paging, state drivers, vehicles, override/possess state, bindings and visibility.

Roth UI:

- adds presentation to public button regions;
- suppresses selected decorative art with alpha only;
- keeps its artwork `UIParent`-owned;
- coalesces Edit Mode/auxiliary-bar refreshes;
- performs no structural refresh on combat entry;
- refreshes after login/reload, combat exit and player vehicle transitions.

## Performance constraints

- No first-party permanent `OnUpdate`; the only approved one is the temporary drag worker.
- No raw aura scan or addon-side aura cache.
- No replacement action-button owner or paging system.
- No Lua status-bar smoothing loop.
- No eager 3D portrait construction for optional unit frames.
- No unbounded event/timer retry loops.
- No broad foreign-frame sweep.

## Safety boundary

The addon does not override Blizzard globals, reparent protected Blizzard frames, unregister Blizzard events, manage Blizzard addon enable state or write Blizzard CVars.

Potentially restricted values are gated before Lua use. Addon persistence accepts only ordinary serializable primitives/tables. Region access uses the centralized safety owner and fails closed on access constraints or Forbidden state.

## Compatibility surface

- oUF `14.0.2` or newer is mandatory; incomplete/older capabilities fail at load.
- `/roth`, `/rothui` and `/rui` route to one parser.
- `_G.rCombatFrameFader` remains a thin alias to the sole event-driven fader owner; the retired rLib fader is not loaded or shipped.
