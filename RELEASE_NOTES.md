# Roth UI 3.4.6

Target: Retail `12.1.5.70688`, Interface `120105`, external oUF `14.2.1+`.

## Changes

- Prevent preloaded or partially loaded Blizzard Settings from registering an empty Roth panel before its builder files finish.
- Gate registration on completion of both addon loads; keep Settings lazy and use the second IsAddOnLoaded return in the fallback.
- Release registration locks after load errors. A later explicit open may retry a failed load; partial native control registration is terminal until reload, preventing duplicate settings.
- Mark aura duration text, cooldown swipe and managed-aura font changes as requiring reload. Ordinary font updates remain live.
- Remove unrelated candidate-filter scans from appearance-only changes; target aura ownership filters still update immediately.
- Add three executable regressions and extend the existing lifecycle fixture without removing its reentrancy or combat-queue assertions.

## Verification boundary

The PR receipt records the exact Lua 5.1 CI runs and package digests. Local compatibility checks are separate from the complete repository gate. Real WoW-client Settings, aura rendering, combat, taint and profiler checks remain `NOT-RUN`.

Keep existing SavedVariables. Managed aura appearance changes take effect after `/reload`; changing candidate filters does not require reloading.
