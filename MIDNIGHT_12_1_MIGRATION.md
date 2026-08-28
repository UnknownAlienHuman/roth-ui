# Midnight 12.1 migration record

- Date: 2026-08-28
- Addon target: World of Warcraft Retail `12.1.0` / Interface `120100`
- Addon version: `3.3.8-v57.8-B4.1`
- Blizzard UI source pin: `Gethe/wow-ui-source@027d26c3406d3de2cbd2b1f67d468fe033a1bcd4` (`12.1.0.69497`)
- oUF baseline: `14.0.2` (`cbdb1d2f33bfcf4e9a5e44f02df3ebcefd35b491`)

## Why the migration is required

Retail 12.1 replaces the legacy general-unit-aura model used by older oUF layouts. Roth UI previously constructed plain frames, assigned them to `self.Buffs` / `self.Debuffs`, attached Lua filters and read `AuraData` or `UNIT_AURA` payloads for timers, healer watches and dispel-color inference.

The supported 12.1 path is a Blizzard-managed `CustomAuraContainerTemplate`, exposed by oUF 14 as `frame:CreateAuras()`, with managed aura groups/slots and native AuraButton visual bindings. Raw aura values can be secret in restricted contexts and must not be used as application state.

## Implemented compatibility boundary

`core/aura_runtime_12_1.lua` is loaded after the legacy compatibility helpers in `core/lib.lua` and before unit-frame construction. It replaces the active aura entry points while keeping the surrounding unit-layout code stable:

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
- the own-caster candidate-filter upgrade is applied once per managed group, avoiding a redundant `UpdateAllAuras()` on every refresh;
- the obsolete Roth `UNIT_AURA` callback unregisters only itself through oUF's per-function `UnregisterEvent`, preserving unrelated oUF element handlers.

The old `core/group_aura_watch.lua` scanner remains in the repository for history and diffability but is no longer listed in `Roth_UI.toc`. It therefore cannot register its raw `AuraUtil.ForEachAura`, `C_UnitAuras.GetAuraDataByAuraInstanceID`, payload caching or incremental scanner path at runtime. The static validator rejects any future attempt to return it to the load graph.

Dormant legacy aura helper bodies still exist in `core/lib.lua`; the managed adapter overrides their public entry points before unit styles are registered. They should be removed only after the managed migration has been proven in the Retail client.

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
| Party/raid healer aura watch | Managed helpful group with `includeSpellIDs` and `isFromPlayerOrPlayerPet` |
| Raw harmful-aura scan for health-frame glow | Removed; native per-aura dispel border is authoritative |
| Raw healer-watch scanner | Excluded from the TOC runtime graph |
| Legacy Roth `UNIT_AURA` recolor callback | Detached per handler; managed containers refresh natively |

## Deliberate behavior change: raid harmful filtering

The old raid harmful filter was an OR-chain that accepted boss debuffs, several dispel types, explicit spell IDs and boss-caster auras. Retail 12.1 candidate-filter fields in one group are conjunctive. Splitting that OR-chain across several groups can duplicate one aura when it matches more than one group.

The migration therefore uses one managed `HARMFUL` group with `AuraContainerSortMethod.UnitFrameDebuff` rather than reproducing the old Lua predicate inaccurately. This preserves a bounded, prioritized debuff display without reading protected aura state. The default raid aura block is disabled in `defaults/raid.lua`, so this behavior only applies when the user enables it.

## Load-order repair

`core/settings_general.lua` requires `ns.settingsActions` at file load. The previous TOC loaded `core/settings_actions.lua` later, causing a deterministic initialization failure. The TOC now loads `core/settings_actions.lua` immediately after `core/settings_main.lua` and before all settings pages that assert it.

## Protected action bars

`Roth_UI.disableProtectedActionBarOwnership` remains enabled and `cfg.bars.secureOwnerBars` remains disabled. This migration does not claim that custom ownership of Blizzard action buttons is combat-safe. The fallback must remain until vehicle, override, possess, shapeshift, paging, binding and combat-lockdown scenarios are proven in the Retail client.

## Static and source verification completed

- The complete TOC/XML closure resolves without missing, duplicate or case-colliding paths.
- Exact metadata is enforced: Interface `120100`, author Neomorph, Blizzard build `12.1.0.69497`, oUF minimum `14.0.2`.
- Critical initialization and aura-boundary load-order constraints are enforced.
- The retired raw healer-watch scanner is rejected if it re-enters the runtime graph.
- The managed adapter/guard are rejected if they reintroduce raw `C_UnitAuras`, `AuraUtil.ForEachAura` or AuraData resolver calls.
- The healer-watch filter includes both the spell whitelist and own-caster predicate, with an idempotence guard against repeated full updates.
- Every repository Lua source parses with `luac5.1 -p`.
- Whitespace errors and unresolved merge-conflict markers are rejected.
- The implementation was reviewed against pinned Blizzard `CustomAuraContainer` source and oUF 14 aura/event elements.

The repository owner directed this source/static-validated changeset to be integrated into `main`. That decision does not convert the checks below into completed evidence.

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

Runtime verification is not represented as completed until client evidence is attached to a commit, issue, pull request or release record.
