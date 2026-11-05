# Roth UI 3.4.7

Target: Retail `12.1.5.70688`, Interface `120105`, external oUF `14.2.1+`.

## Changes

- Gate persisted mover values and tables before conversion or traversal; reject secrets, inaccessible values, protected tables and NaN/Infinity.
- Validate mover anchor points and bounded global names. Reject self/layout-restricted anchors and use `UIParent` as the independent fallback.
- Apply saved points transactionally: capture the current point first and restore it when `SetPoint` fails. Leave multi-anchor frames unchanged rather than performing an incomplete rollback.
- Use the completed second return from `C_AddOns.IsAddOnLoaded` in Blizzard-frame bootstrap; named fallback listeners detach before policy callbacks.
- Remove the dead `ApplyUnitFramePolicy` compatibility branch.
- Add three regressions and update the existing mover/bootstrap fixtures without removing prior interaction, combat or lifecycle assertions.

## Verification boundary

The PR receipt records exact Lua 5.1 CI runs and package digests. Local compatibility tests are separate from the complete repository gate. Real WoW mover geometry, restricted objects, addon loading, combat, taint, visuals and profiler checks remain `NOT-RUN`.

Keep existing SavedVariables. Invalid or unsafe stored mover geometry is ignored rather than applied.
