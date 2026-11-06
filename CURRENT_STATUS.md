# Current status — Roth UI 3.4.9

## Source and scope

- Base: `3.4.8`, `9b257c4c934e2adff501f9fd4d12d31258ad5691`.
- Selected source: Retail `12.1.5.70688`, Interface `120105`, Blizzard `d07eb00237d8891f153215db98a5df880a26cfe5`.
- External oUF: `14.2.1+`; inspected `c5ff6e4a09bfaf2186e205777e0fab964b5cddc1`.
- KB: `UnknownAlienHuman/wow-addon-engineering-kb@c2a630aa186de401262663cc8568a77988be69df`.
- `70783` remains reviewed post-selected evidence, not a selected-pin promotion.

This pass audits framework ownership and ordinary-value transport boundaries. Persistence schema, mover data, secure group-header topology, managed-aura configuration and action-button ownership are unchanged.

## Contract-to-regression coverage

| Authority and contract | Correction | Regression |
|---|---|---|
| KB event/performance topology: next-frame work must keep one asynchronous owner and must not silently recurse | `deferred_scheduler` requires `C_Timer.After`; move-grid requires `ns.defer.RunNextFrame` | `test_deferred_scheduler.lua`, `test_required_runtime_owners.lua` |
| Repository ownership: `init.lua` publishes the sole external oUF reference | Removed every downstream global-oUF fallback and the redundant config reassignment | `test_required_runtime_owners.lua` plus existing unit/data-bar tests |
| KB security: gate before nil/equality/stringification/keying/retention | Target class/sound paths and player runtime identity now consume only ordinary values | `test_target_identity_access.lua`, `test_runtime_identity_access.lua` |
| KB generic transport boundary: logs/reports are ordinary-only | Logger and SVDoctor replace restricted input with fixed markers and never stringify restricted keys/values | `test_diagnostic_access_boundaries.lua` |

## Automated acceptance

The exact candidate must pass the repository workflow: all regressions, Lua 5.1 syntax, repository text, TOC/XML/load-order and ownership/Retail-boundary guards, secure-header semantics, runtime hardening, whitespace checks and two deterministic packages. Merge/publication require exact-head CI, artifact/source parity, main readback and post-merge CI.

## Remaining acceptance

`NOT-RUN`: actual `GetBuildInfo`, login/reload with the real addon stack, target identity restrictions in live content, native frame suppression/restoration, mover interaction, combat/taint, secure transitions, rendering, coexistence and `C_AddOnProfiler` measurements. Stub operation counts and exception guards do not establish client permission or performance.
