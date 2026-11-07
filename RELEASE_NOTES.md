# Roth UI 3.4.10

Target: Retail `12.1.5.70688`, Interface `120105`, external oUF `14.2.1+`.

## Changes

- Make read-only unit-config proxy graphs request-scoped so replaced SavedVariables roots are collectible; reject writes without stringifying arbitrary keys.
- Settle managed-aura creation batches after every specification succeeds or reaches terminal failure, eliminating repeated `OnShow` scans.
- Bind each non-player castbar once in the constructor and remove per-layout duplicate bind paths and unused cast-unit retention.
- Route mover registration and saved-layout application through `mover_runtime`; remove flat aliases and duplicate constructor registration.
- Require the oUF secure-header `SetVisibility` contract; remove the parallel raw state-driver fallback and historical public bookkeeping helpers.
- Expose one keyed action-artwork invalidation queue; remove direct namespace, per-frame and player-frame refresh routes.
- Require the shared next-frame scheduler for Settings and target-castbar refreshes.
- Add executable regressions for proxy lifetime, terminal aura batches, owner cleanup, canonical mover registration and action-art scheduling.

## Verification boundary

Complete Lua 5.1 repository CI, deterministic package comparison and post-merge main validation remain publication gates. Real WoW login/reload, combat, taint, secure transitions, rendering, coexistence and profiler checks remain `NOT-RUN`.

Keep existing SavedVariables. This patch does not change their schema or mover data.
