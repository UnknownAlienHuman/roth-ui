# Current status — Roth UI 3.4.6

## Source and scope

- Base: `3.4.5`, `d994b2bd28b117abdd1f7d9b41e8a873e7890396`.
- Selected source: Retail `12.1.5.70688`, Interface `120105`, Blizzard `d07eb00237d8891f153215db98a5df880a26cfe5`.
- External oUF: `14.2.1+`; inspected `c5ff6e4a09bfaf2186e205777e0fab964b5cddc1`.
- KB: `UnknownAlienHuman/wow-addon-engineering-kb@c2a630aa186de401262663cc8568a77988be69df`.
- `70783` remains reviewed post-selected evidence, not a selected-pin promotion.

This pass covers Settings startup/readiness, registration failure recovery and managed-aura appearance settings. No persistence schema, secure-header, cast, managed-aura runtime, library, media or workflow changes are included.

## Contract-to-regression coverage

| Authority and contract | Correction | Regression |
|---|---|---|
| KB `KB/addon/Addon_SavedVariables.md`: pre-file SavedVariables does not mean addon initialization completed; register settings once after required initialization | Wait for Roth's completed load, then completed Blizzard_Settings load; explicit open cannot bypass unfinished builders | `test_settings_readiness.lua` covers preloaded, absent and partially loaded Settings with EventUtil and native-event fallback |
| Blizzard `Interface/AddOns/Blizzard_SharedXML/EventUtil.lua:ContinueOnAddOnLoaded` at the selected pin: use the second IsAddOnLoaded result, not the loading-inclusive first result | Fallback distinguishes loading from finished and detaches before callback delivery | Same readiness test; existing `test_settings_lifecycle.lua` now delivers Roth completion before opening |
| KB `KB/core/BlizzardUI_EventPatterns.md`: terminal state and cleanup before reentrant callbacks; no duplicate native registrations | Release registration lock after failed loading; allow a later explicit retry only before registration; partial native registration fails closed until reload | `test_settings_registration_failure.lua` injects native-load and builder errors |
| KB `KB/nodes/BlizzardUI_Auras.md`: initializeFrame is one-time adoption; no later child mutation. oUF `elements/auras.lua:CreateButton`; Roth `core/aura_runtime.lua:CreateAuraRegion/StyleManagedAuraButton` | Duration/cooldown widgets and aura fonts explicitly require reload. Keep ordinary font refresh and live candidate-filter changes; remove appearance-only filter scans | `test_settings_aura_appearance.lua` exercises real Settings proxy setters and stored reload flags, with refresh counters |

## Automated acceptance

All three new regression scripts failed at their intended boundaries against the unchanged 3.4.5 runtime before fixes. Focused local checks use Lua 5.3 with explicit compatibility aliases; they are not the authoritative Lua 5.1 suite.

The existing repository workflow remains the full gate: all isolated regressions, Lua 5.1 syntax, repository text, load-order/ownership/Retail-boundary, secure-header and runtime-hardening checks, plus two deterministic packages. The PR receipt records exact final-head and merged-main runs and package digests after validation. No earlier green commit is attributed to this tree.

Appearance-only setters no longer scan aura candidate filters in the controlled regression. This is an operation-count observation, not a native CPU, allocation or FPS measurement.

## Remaining acceptance

`NOT-RUN`: actual GetBuildInfo, login/reload with the real addon stack, native Settings interaction/load order, combat/taint, managed aura rendering/access, secure group/vehicle transitions, cast/model rendering, other-addon coexistence and C_AddOnProfiler measurements. Exception handling does not grant protected-call permission. This focused patch does not certify every subsystem.
