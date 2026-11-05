# Roth UI 3.4.8

Target: Retail `12.1.5.70688`, Interface `120105`, external oUF `14.2.1+`.

## Changes

- Coalesce login and named Blizzard-addon completion signals into one keyed next-frame group-policy pass.
- Keep completed-addon one-shot ownership terminal before scheduling and ignore duplicate delivery.
- Isolate global-font failure so it cannot cancel the independent Blizzard-frame policy invalidation.
- Require the canonical group-policy and font owners at the documented TOC boundary; retain no unit-frame compatibility route.
- Expand both bootstrap regressions for same-frame coalescing, immediate EventUtil delivery, repeated callbacks, font failure and cleanup.
- Restore the verified Settings lifecycle architecture and dependency-graph path without removing the 3.4.7 mover contracts.

## Verification boundary

The focused regressions reproduce the new boundaries against 3.4.7. Complete Lua 5.1 repository CI, deterministic package comparison and post-merge main validation remain publication gates. Real WoW addon-load timing, combat, taint, native frame restoration, visuals and profiler checks remain `NOT-RUN`.

Keep existing SavedVariables. This patch does not change their schema or mover data.
