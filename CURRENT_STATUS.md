# Current status — Roth UI 3.4.8

## Source and scope

- Base: `3.4.7`, `0a563d8fa912e3c9bb09a97973077af9508730ac`.
- Selected source: Retail `12.1.5.70688`, Interface `120105`, Blizzard `d07eb00237d8891f153215db98a5df880a26cfe5`.
- External oUF: `14.2.1+`; inspected `c5ff6e4a09bfaf2186e205777e0fab964b5cddc1`.
- KB: `UnknownAlienHuman/wow-addon-engineering-kb@c2a630aa186de401262663cc8568a77988be69df`.
- `70783` remains reviewed post-selected evidence, not a selected-pin promotion.

This pass extends the already corrected Blizzard-addon readiness path with one keyed invalidation owner and independent failure isolation. The 3.4.7 mover hardening remains unchanged. Persistence schema, Settings runtime, secure headers, auras, casts, libraries, media and workflows are unchanged.

## Contract-to-regression coverage

| Authority and contract | Correction | Regression |
|---|---|---|
| KB performance topology: equivalent same-frame invalidations use one dirty/keyed pass, not repeated feature work | Login and both named Blizzard-addon completion signals enqueue the same `frame-policy-bootstrap:apply` key | `test_frame_policy_bootstrap.lua` and `test_frame_policy_bootstrap_readiness.lua` assert one pending key and one policy pass |
| KB event lifecycle: one-shot state is claimed before feature code; callback-triggered reentry belongs to a later generation | Fallback ownership is removed before scheduling; `FinishWatchedAddon` rejects duplicate native/EventUtil delivery | same regressions cover repeated delivery and final listener cleanup |
| KB owner isolation: an error in one independent owner must not cancel another owner's terminal work | Global-font execution uses `safety.TryCall`; frame-policy scheduling still occurs after a font exception | bootstrap regression injects a throwing font owner |
| Repository ownership: `group_policy` is the sole Blizzard party/raid suppression owner; oUF owns ordinary unit frames | Bootstrap requires `ApplyGroupFramePolicy` and contains no `ApplyUnitFramePolicy` path | regression trap remains at zero calls |
| Documentation continuity | Restored the verified Settings lifecycle and readiness graph while preserving 3.4.7 mover contracts | repository diff and text validation |

## Automated acceptance

The expanded bootstrap regressions fail against the unchanged 3.4.7 path at the coalescing and font-failure boundaries. The corrected focused files parse under the separately identified compatibility runner; complete Lua 5.1 CI remains authoritative.

The repository workflow must pass on the exact candidate: all regressions, Lua 5.1 syntax, repository text, TOC/XML/load-order and ownership/Retail-boundary guards, secure-header semantics, runtime hardening and two deterministic packages. Merge and publication require exact-head CI, artifact/source parity, main readback and post-merge CI.

## Remaining acceptance

`NOT-RUN`: actual `GetBuildInfo`, login/reload with the real addon stack, same-frame Blizzard addon completion timing, native frame suppression/restoration, mover interaction, combat/taint, secure transitions, rendering, coexistence and `C_AddOnProfiler` measurements. Stub operation counts and exception guards do not establish client permission or performance.
