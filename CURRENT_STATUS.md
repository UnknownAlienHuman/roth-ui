# Current status — Roth UI 3.4.7

## Source and scope

- Base: `3.4.6`, `6fb1f54403fcc707a95e90dd515cc7802139f3ae`.
- Selected source: Retail `12.1.5.70688`, Interface `120105`, Blizzard `d07eb00237d8891f153215db98a5df880a26cfe5`.
- External oUF: `14.2.1+`; inspected `c5ff6e4a09bfaf2186e205777e0fab964b5cddc1`.
- KB: `UnknownAlienHuman/wow-addon-engineering-kb@c2a630aa186de401262663cc8568a77988be69df`.
- `70783` remains reviewed post-selected evidence, not a selected-pin promotion.

This pass covers persisted mover geometry and completed-addon readiness for reversible Blizzard-frame policy. No persistence schema, Settings, secure-header, aura, cast, library, media or workflow changes are included.

## Contract-to-regression coverage

| Authority and contract | Correction | Regression |
|---|---|---|
| KB Secret Value guide: gate before conversion, comparison, table traversal or storage; KB SavedVariables guide: imported/persisted documents are bounded ordinary data | Mover point/size/scale reads gate values and tables before `tonumber`, indexing or comparison; reject secret/inaccessible, forbidden-table and non-finite values | `test_mover_input_safety.lua`; `test_mover_source_contract.lua` |
| KB Aura/layout guidance and selected ForbiddenAspect docs: `UntrustedLayoutScriptExecution` propagates to objects anchored to a restricted object | Validate standard anchor points and bounded names; reject self/restricted anchors and resolve unsafe/missing names to independent `UIParent` | Same mover safety regression |
| KB transaction/cleanup rule: establish rollback before mutation and do not leave partial state after a failed callback/API call | Capture the existing single point before `ClearAllPoints`; on failed `SetPoint`, restore the exact captured tuple. Multi-anchor frames are left unchanged | Same mover safety regression plus existing mover interaction test |
| Blizzard selected `EventUtil.ContinueOnAddOnLoaded`: first `IsAddOnLoaded` result includes loading; second means completed. KB one-shot rule: detach before feature code | Bootstrap uses the second result, retains a bounded named fallback until completion, removes delivery ownership before policy invocation and drops the dead unit-policy branch | `test_frame_policy_bootstrap_readiness.lua`, updated existing bootstrap regression |

## Automated acceptance

All three new regression scripts fail at their intended boundaries against unchanged 3.4.6. The corrected runtime passes them plus the existing mover and bootstrap regressions under the explicitly separate Lua 5.3 compatibility runner. Local parsing covers all available runtime/test Lua files; complete Lua 5.1 CI remains authoritative.

The repository workflow must pass on the exact candidate: all regressions, Lua 5.1 syntax, repository text, TOC/XML/load-order and ownership/Retail-boundary guards, secure-header semantics, runtime hardening and two deterministic packages. Merge and publication require exact-head CI, artifact/source parity, main readback and post-merge CI.

## Remaining acceptance

`NOT-RUN`: actual `GetBuildInfo`, login/reload with real SavedVariables, mover drag/resize at representative resolutions and UI scales, restricted anchor behavior in the native client, Blizzard-frame load timing, combat/taint, secure transitions, rendering, coexistence and `C_AddOnProfiler` measurements. Stub operation counts and exception guards do not establish client permission or performance.
