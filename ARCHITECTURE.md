# Roth UI architecture — 3.4.1

## Compatibility target

Retail `12.1.5`, Interface `120105`, target source build `12.1.5.70688`; required oUF `14.1.1+`. Review pins checked `2026-11-02`: Blizzard UI source `d07eb00237d8891f153215db98a5df880a26cfe5` and oUF `8f37c36e3ed37d2fcfca2f3690f5e37e52b758c7`. These source pins do not constitute client testing. Client build, combat, taint, visuals, and performance are `NOT-RUN`.

## Package and load boundary

Roth UI ships as one addon root, `Roth_UI`. oUF is a separately installed required dependency. The TOC loads the safety and frame-policy foundations before the oUF contract and unit elements, then runtime services, settings, and unit layouts. `units/mini_target_scaffold.lua` loads before every style that calls its shared builder.

## Ownership map

| State or subsystem | Authoritative owner |
|---|---|
| Secret/access/serialization guards | `core/safety.lua` |
| Operation-specific forbidden aspects | `core/safety_aspects.lua` |
| oUF dependency contract | `core/ouf_contract.lua` |
| SavedVariables root replacement/reset | `core/config_persistence_owner.lua` |
| Runtime config access | persistence services and `core/sv_store.lua` |
| Blizzard Settings category | `core/settings_main.lua` and its page builders |
| oUF unit and secure-header lifecycle | external oUF `14.1.1+` |
| Shared combat deferral and reversible foreign-frame state | `core/frame_policy.lua` |
| Keyed next-frame work | `core/deferred_scheduler.lua` |
| Mover handles and persisted point/scale/size | `core/mover_runtime.lua` |
| Roth and optional reversible Blizzard fonts | `core/font_policy.lua` |
| Mini target frame construction | `units/mini_target_scaffold.lua` |
| Rested XP progress | custom `oUF/elements/experience.lua` element |
| Managed aura specifications and lifecycle | `core/aura_runtime.lua` |
| Cast discovery, timing, and interruptibility | oUF Castbar element |
| Castbar visual adaptation | `core/target_castbar.lua` |
| Class-bar combat fade | `core/combat_fader.lua` |
| Blizzard action buttons and secure state | Blizzard UI |
| Roth action-button appearance | `core/action_button_skin.lua` |
| Roth action-bar artwork | `core/action_bar_background.lua` |
| Blizzard-frame provider policy | `core/group_policy.lua`, `core/frame_policy_bootstrap.lua` |

## Runtime coordination

`framePolicy.DeferUntilOutOfCombat` is the one keyed combat-exit queue. Owners schedule bounded work there; the policy installs a `PLAYER_REGEN_ENABLED` listener only while work is pending and removes it after draining. `deferred_scheduler.RunNextFrame` separately coalesces non-combat layout refreshes by key.

Settings category registration is lazy. Ordinary login does not force `Blizzard_Settings` to load. The font policy records original font values only when it successfully applies an override, and restores them only while the current value still matches Roth UI's last applied font.

## Secure group lifecycle

oUF `SpawnHeader` creates secure party and raid headers. Roth UI creates each header at most once per UI session, outside combat, and configures child structure once. It retains the header while updating supported visibility, scale, position and range. Changes to child construction take effect after reload.

`core/group_header_visibility.lua` stores desired and applied visibility in a weak-key addon table. It uses the oUF header visibility contract where available and a state driver only outside combat. It never reparents a secure header. Temporary provider or arena overrides do not replace the configured visibility condition.

## Unit and aura lifecycle

The styles for focus, boss, pet, target-of-target, and pet-target share geometry and construction through `units/mini_target_scaffold.lua`. Each style retains its own settings, tags, and optional elements. Other styles keep their dedicated layouts.

Unit styles provide plain aura specifications. `core/aura_runtime.lua` creates managed containers lazily after a frame first becomes visible and only outside combat. Blizzard owns aura data, filtering, sorting, duration objects, cooldowns, and dispel/stealable regions. Roth UI does not enumerate raw aura data or own a parallel `UNIT_AURA` cache.

The Experience element updates current XP and rested progress once per callback. Reputation and experience data changes do not trigger artwork layout; only a visibility transition requests that refresh.

## Action bars and movers

Blizzard owns secure buttons, state drivers, paging, bindings, vehicle/override/possess state, and visibility. Roth UI applies its skin outside combat and draws artwork as a `UIParent` child. The artwork applies configured geometry first, captures current reset defaults, then applies saved mover overrides.

`core/mover_runtime.lua` is the only mover owner. It creates handles and handles drag, scale, resize, persistence, lock/unlock, and reset. The legacy embedded mover helper was removed. No Blizzard frame is reparented.

## Performance and safety constraints

- Do not add permanent first-party `OnUpdate` loops, raw aura scans, addon-side aura caches, replacement action-button systems, or Lua status-bar smoothing loops.
- Do not eagerly create optional 3D portraits, respawn secure headers, register Settings at login, or add unbounded event/timer retries or broad foreign-frame sweeps.
- Do not override Blizzard globals, reparent protected Blizzard frames, unregister Blizzard events, change addon enable state, or write Blizzard CVars.
- Gate inaccessible and secret-capable values before Lua comparison, formatting, conversion, storage, or indexing. Query relevant forbidden aspects before restricted foreign-widget operations.
- Persist ordinary data only; SavedVariables root writes remain centralized in `core/config_persistence_owner.lua`.
