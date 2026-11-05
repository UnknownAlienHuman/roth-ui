# Current status — Roth UI 3.4.5

## Source and scope

- Base: `3.4.4`, `7008e17e3cc048652b82fc4076249b1bd0da21c9`.
- Selected source: Retail `12.1.5.70688`, Interface `120105`, Blizzard `d07eb00237d8891f153215db98a5df880a26cfe5`.
- External oUF: `14.2.1+`; inspected `c5ff6e4a09bfaf2186e205777e0fab964b5cddc1`.
- KB: `UnknownAlienHuman/wow-addon-engineering-kb@c2a630aa186de401262663cc8568a77988be69df`.
- `70783` remains reviewed post-selected evidence, not a new selected pin.

This pass covers combat deferral, suppression/font ownership, late portrait initialization and ordinary cast-color caching. It is not certification of all subsystems or real-client behavior. Persistence schema, media, vendored libraries, managed-aura adoption and secure-header structures are unchanged.

## Contract-to-regression coverage

| Authority and contract | Correction | Regression |
|---|---|---|
| KB `KB/core/BlizzardUI_EventPatterns.md`, terminal completion/deferred work: cancel stale work inside delivery and reject callback reentry | New immediate requests invalidate pending and draining work; object keys obey the same rule; combat is checked before every callback and unrun work is retained | `test_frame_policy_generations.lua` |
| KB event ownership/compare-and-restore and `KB/nodes/BlizzardUI_UnitFrames.md`, stock-frame suppression boundary | Reacquisition captures a newer foreign property; unchanged suppression retains restoration ownership without repeating setters; failed writes still roll back | `test_frame_policy_reacquire.lua`, existing frame-policy regression |
| Same compare-and-restore rule applied to the atomic font tuple | Foreign path, size or flag changes retire the previous snapshot before another Roth override | `test_font_policy_reacquire.lua` |
| oUF `elements/portrait.lua:Enable/ForceUpdate` and `ouf.lua:EnableElement` at the pin above: activation does not populate the model | Attach once; request one element-only update after late activation, without a full unit-frame refresh | `test_portrait_initial_update.lua` |
| KB `KB/core/BlizzardUI_Performance_Modules.md`: targeted updates and allocation-aware ordinary caches | Compare cached RGBA scalars directly; remove per-callback fingerprint table/string construction while preserving invalidation and direct opaque sinks | `test_target_castbar_cache.lua` |

## Automated acceptance

All five new regression scripts were run against the verified 3.4.4 CI runtime first and failed at the intended boundaries. The missing portrait assignment was also reproduced independently of duplicate attachment. The corrected code passes the five new scripts and twelve locally retained regressions under Lua 5.3 with explicit compatibility aliases. That local subset is not the complete Lua 5.1 gate.

The ordinary repository CI remains authoritative for the exact commit: all existing and new Lua regressions, Lua 5.1 syntax, repository text, TOC/XML/load-order and ownership guards, secure-header semantics, runtime hardening and two deterministic packages. Merge requires that complete gate, followed by main readback and post-merge validation. The PR records exact run IDs and artifact digests rather than attributing an older green result to a later tree.

The focused operation-count tests assert zero extra suppression setters across 50 unchanged requests and zero fingerprint concatenations across 100 unchanged cast callbacks. These are controlled stub observations, not CPU, memory, FPS or native rendering measurements.

## Remaining acceptance

`NOT-RUN`: actual `GetBuildInfo()`, login/reload and migrations in WoW, combat lockdown/taint, native script-object access, model rendering, aura/cast/secure-header/vehicle transitions, interaction, another addon's font/frame overrides, representative resolutions and `C_AddOnProfiler` measurements. An exception guard does not grant protected-call permission; a stub does not emulate Blizzard security.
