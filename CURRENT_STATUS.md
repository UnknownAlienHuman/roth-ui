# Current status — Roth UI 3.4.10

## Source and scope

- Base: merged `3.4.9`, `94fdf09b0f7607afcb9fc6e93dad4366a001e242`.
- Selected source: Retail `12.1.5.70688`, Interface `120105`, Blizzard `d07eb00237d8891f153215db98a5df880a26cfe5`.
- External oUF: `14.2.1+`; inspected `c5ff6e4a09bfaf2186e205777e0fab964b5cddc1`.
- KB: `UnknownAlienHuman/wow-addon-engineering-kb@c2a630aa186de401262663cc8568a77988be69df`.
- `70783` remains reviewed post-selected evidence, not a selected-pin promotion.

This pass rechecks request lifetime, terminal managed-object work and remaining parallel owner routes. SavedVariables schema, secure group-header structure, managed-aura filter policy and Blizzard action ownership are unchanged.

## Contract-to-regression coverage

| Authority and contract | Correction | Regression |
|---|---|---|
| KB persistence/lifetime: replaced roots and views must not be retained by helper caches | Read-only unit-config views now use one request-scoped memo graph; global source-to-proxy cache and Lua 5.1-inoperative iteration metamethods removed | `test_config_readonly_view_lifetime.lua` |
| KB terminal work: success/failure/cancellation converge on one terminal state | Managed aura creation batches settle after every spec succeeds or terminally fails; repeated `OnShow` does not rescan them | `test_aura_terminal_settled.lua`, existing aura lifecycle tests |
| KB one-owner topology: one constructor/binder and one registry owner | Non-player castbars bind only in `func.createCastbar`; mover constructors register once through `mover_runtime`; flat mover aliases removed | `test_runtime_owner_cleanup.lua`, `test_mover_runtime.lua`, `test_target_castbar.lua` |
| KB secure-header ownership: configure the oUF public header, do not create a second secure driver owner | Group visibility requires accessible oUF `SetVisibility`; raw state-driver fallback and public bookkeeping/compatibility APIs removed | `test_group_header_visibility.lua` |
| KB scheduler/performance topology: equivalent invalidations use one keyed asynchronous owner | Data bars, Settings and target-castbar refreshes route through required scheduler owners; action artwork exposes only its keyed queue | `test_action_bar_scheduler.lua`, `test_action_bar_background.lua`, `test_settings_general_refresh.lua` |
| KB security: rejected arbitrary data must not be formatted merely to report an error | Read-only config rejection uses one fixed ordinary message and never stringifies the attempted key | `test_config_readonly_view_lifetime.lua` |

## Automated acceptance

The exact candidate must pass the repository workflow: all regressions, Lua 5.1 syntax, repository text, TOC/XML/load-order and ownership/Retail-boundary guards, secure-header semantics, runtime hardening, whitespace checks and two deterministic packages. Merge/publication require exact-head CI, artifact/source parity, main readback and post-merge CI.

## Remaining acceptance

`NOT-RUN`: actual `GetBuildInfo`, login/reload with the real addon stack, native frame suppression/restoration, mover interaction, combat/taint, target/aura restrictions in live content, secure transitions, vehicle/override presentation, rendering, coexistence and `C_AddOnProfiler` measurements. Stub operation counts and exception guards do not establish client permission or performance.
