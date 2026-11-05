# Current status — Roth UI 3.4.4

## Source and scope

- Base: released `3.4.3`, source `ee13d71dd94d44a93df50b0689a94459a570ae9c`.
- Selected source: Retail `12.1.5.70688`, Interface `120105`, Blizzard `d07eb00237d8891f153215db98a5df880a26cfe5`.
- External oUF: `14.2.1+`; inspected `c5ff6e4a09bfaf2186e205777e0fab964b5cddc1`.
- KB: `UnknownAlienHuman/wow-addon-engineering-kb@c2a630aa186de401262663cc8568a77988be69df`.
- `70783` remains reviewed post-selected evidence, not a new selected pin.

This is a focused contract audit of persistence, serialization and managed-aura lifecycle, not certification of every subsystem or runtime scenario.

## Contract-to-regression coverage

| Contract and inspected authority | Correction | Regression |
|---|---|---|
| KB `KB/addon/Addon_SavedVariables.md`: export must not mutate authoritative state; validate detached schema | Read-only root acquisition bypasses ensure/migration; exports use the import validator and reject missing selected roots | `test_persistence_export_integration.lua` loads actual config/root/control-plane owners |
| KB `KB/deep/WoWDevSecretValue_KB_12.1.5.md`: value and table access are separate; gate before traversal. SavedVariables guide: portable documents exclude metatables | `canaccesstable` gates traversal; strict copy rejects root/nested/protected metatables without invoking them | `test_strict_serialization_access.lua` |
| KB SavedVariables and `KB/core/BlizzardUI_EventPatterns.md`: establish transaction/reentrancy and cleanup ownership before callbacks | One exclusive import/reset transaction; no intermediate export/public reconcile; error releases lock | `test_persistence_reentrancy.lua` loads actual root owners |
| KB `KB/nodes/BlizzardUI_Auras.md` and second-pass overlay: current-context access, one-time adoption and native update ownership | Recheck visible/current owner, idempotent attachment, isolate failed adoption without retry, gate filter setter | `test_aura_lifecycle_failures.lua`; updated `test_aura_lazy.lua` |
| oUF `elements/auras.lua:Create/Enable/Update` and `ouf.lua:EnableElement/AddMetaElement` at the pin above: creation, activation and unit assignment are distinct | Enable new late containers; one `UpdateAllElements` after a successful creation batch; no raw aura scan or extra candidate-filter refresh | Lazy-aura and lifecycle regressions model the inspected split |

The inspected security, lifecycle and unit-frame guides preserve the separation between source review and real client permission. No stock-frame suppression, secure-header structure, cast timing, library or media changes are part of this patch.

## Automated acceptance

The ordinary repository workflow owns the complete Lua 5.1 syntax/regression suite, repository text policy, TOC/XML order, ownership/Retail boundaries, secure-header semantics and two deterministic package builds. Its result applies to its exact commit, not a prior green head.

New regressions were reproduced against the released 3.4.3 runtime before applying the fixes. Local compatibility checks use Lua 5.3 with Lua 5.1 aliases; they are not the authoritative Lua 5.1 gate. CI must validate the complete repository rather than the locally retained test subset.

## Remaining client acceptance

`NOT-RUN`: actual `GetBuildInfo()`, fresh/migrated/malformed SavedVariables login/reload, combat lockdown and taint, managed aura rendering/access transitions, casts/channels/empower, party/raid secure transitions, vehicle/override states, movers, Settings, fonts, resolutions, coexistence with other addons and `C_AddOnProfiler` measurements.

A protected-call exception guard is not permission. A stub access predicate does not emulate Blizzard restrictions. No measured CPU, memory, FPS or blanket compatibility claim is made.
