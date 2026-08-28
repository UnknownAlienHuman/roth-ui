# Midnight 12.1 migration record

Date: 2026-08-27  
Addon target: World of Warcraft Retail `12.1.0` / Interface `120100`  
Blizzard UI source pin: `Gethe/wow-ui-source@027d26c3406d3de2cbd2b1f67d468fe033a1bcd4` (`12.1.0.69497`)  
oUF baseline: `14.0.2` (`cbdb1d2f33bfcf4e9a5e44f02df3ebcefd35b491`)

## Why the migration is required

Retail 12.1 replaces the legacy general-unit-aura model used by older oUF layouts. Roth UI previously constructed plain frames, assigned them to `self.Buffs` / `self.Debuffs`, attached Lua filters and read `AuraData` or `UNIT_AURA` payloads for timers, healer watches and dispel-color inference.

The supported 12.1 path is a Blizzard-managed `CustomAuraContainerTemplate`, exposed by oUF 14 as `frame:CreateAuras()`, with `AddAuraGroup` / `AddAuraSlot` and native AuraButton visual bindings. Raw aura values can be secret in restricted contexts and must not be used as application state.

## Implemented compatibility boundary

`core/aura_runtime_12_1.lua` is loaded after the old compatibility modules and before unit-frame construction. It replaces the active aura entry points while keeping the surrounding unit-layout code stable:

- `func.SetupNativeAuraFrame`
- `func.createBuffs`
- `func.createDebuffs`
- `func.CreateSafeAuraWatch`
- `func.RefreshSafeAuraWatch`
- `func.checkColors`
- `func.QueueGroupAuraColorUpdate`

`core/aura_runtime_12_1_guard.lua` loads immediately afterward and hardens that boundary before any unit style is registered:

- missing `frame:CreateAuras()` fails closed instead of returning a legacy `Buffs` / `Debuffs` placeholder;
- healer-watch groups retain the previous `PLAYER` caster restriction through `SetAuraGroupCandidateFilters()` with `isFromPlayerOrPlayerPet`;
- the obsolete Roth `UNIT_AURA` callback unregisters only itself through oUF's per-function `UnregisterEvent`, preserving unrelated oUF element handlers.

The older scanner implementations remain in the tree for history and diffability, but the 12.1 runtime overrides them before unit styles are registered. The guard prevents an older oUF release from accidentally reactivating those legacy element paths. They are not the active state path.

## Behavior mapping

| Legacy behavior | Retail 12.1 implementation |
|---|---|
| `self.Buffs` / `self.Debuffs` plain-frame elements | oUF `CreateAuras()` managed containers |
| Aura count text | AuraButton `SetApplicationCount` sink through oUF |
| Cooldown spiral | AuraButton `SetDurationCooldown` sink through oUF |
| Target/focus duration text | AuraButton `SetDurationText` sink through oUF |
| Debuff-type border | AuraButton `AddDispelTypeTexture` sink through oUF |
| Stealable border | Native stealable-filter texture sink through oUF |
| `onlyShowPlayer` | `candidateFilters.isFromPlayerOrPlayerPet` |
| Raid helpful whitelist | `candidateFilters.includeSpellIDs` |
| Party healer aura watch | Managed helpful group with `includeSpellIDs` and `isFromPlayerOrPlayerPet` |
| Raw harmful-aura scan for health-frame glow | Removed; native per-aura dispel border is authoritative |
| Legacy Roth `UNIT_AURA` recolor callback | Detached per handler; managed containers refresh natively |

## Deliberate behavior change: raid harmful filtering

The old raid harmful filter was an OR-chain that accepted boss debuffs, several dispel types, explicit spell IDs and boss-caster auras. Retail 12.1 candidate-filter fields in one group are conjunctive. Splitting that OR-chain across several groups can duplicate one aura when it matches more than one group.

The migration therefore uses one managed `HARMFUL` group with `AuraContainerSortMethod.UnitFrameDebuff` rather than reproducing the old Lua predicate inaccurately. This preserves a bounded, prioritized debuff display without reading protected aura state. The default raid aura block is disabled in `defaults/raid.lua`, so this behavior only applies when the user enables it.

## Load-order repair

`core/settings_general.lua` requires `ns.settingsActions` at file load. The previous TOC loaded `core/settings_actions.lua` later, causing a deterministic initialization failure. The TOC now loads `core/settings_actions.lua` immediately after `core/settings_main.lua` and before all settings pages that assert it.

## Protected action bars

`Roth_UI.disableProtectedActionBarOwnership` remains enabled and `cfg.bars.secureOwnerBars` remains disabled. This migration does not claim that custom ownership of Blizzard action buttons is combat-safe. The fallback must remain until vehicle, override, possess, shapeshift, paging, binding and combat-lockdown scenarios are proven in the Retail client.

## Static verification completed

- Lua compilation checks for the managed runtime and guard with LuaTeX `loadfile`.
- Mock construction test for managed harmful/helpful containers and party aura watch.
- Guard mock for fail-closed behavior, own-caster candidate filters, explicit `ForceUpdate` and per-handler `UNIT_AURA` detachment.
- TOC duplicate-entry and dependency-order checks.
- Exact local/remote Git blob verification for the guard module.
- Source review against Blizzard `CustomAuraContainer` implementation and oUF 14 aura/event elements.

## Required in-client verification

1. Clean login and `/reload` with oUF 14.0.2 or newer.
2. Target and focus buffs/debuffs, stacks, cooldown spirals, durations and tooltips.
3. Friendly, hostile and player targets; target swaps during combat.
4. Party frames in solo, party and raid transitions.
5. Healer aura-watch indicators for every supported healer class.
6. Raid frames with aura display both disabled and explicitly enabled.
7. Arena, battleground, dungeon, raid boss and open-world combat.
8. Vehicle, override, possess and temporary shapeshift bars.
9. Edit Mode, movers, settings changes and SavedVariables migration.
10. `/console taintLog 1`, BugSack/BugGrabber and CPU profiling with no secret-value or forbidden-action errors.

Runtime verification is not represented as completed until client evidence is attached to a commit or release record.
