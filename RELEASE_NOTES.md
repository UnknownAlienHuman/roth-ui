# Roth UI 3.4.9

Target: Retail `12.1.5.70688`, Interface `120105`, external oUF `14.2.1+`.

## Changes

- Require the shared asynchronous next-frame scheduler; remove synchronous fallback execution from scheduler and move-grid paths.
- Keep one external oUF owner: `init.lua` publishes `ns.oUF`, and all runtime consumers require it instead of consulting globals independently.
- Gate target class text, target-selection sounds and player runtime identity before comparison, formatting, keying or retention.
- Make session logging and SavedVariables diagnostics ordinary-only; restricted values use fixed neutral markers and are never stringified.
- Add executable regressions for scheduler ownership, oUF ownership, runtime identity and diagnostic transport boundaries.

## Verification boundary

Complete Lua 5.1 repository CI, deterministic package comparison and post-merge main validation remain publication gates. Real WoW login/reload, combat, taint, secure transitions, rendering, coexistence and profiler checks remain `NOT-RUN`.

Keep existing SavedVariables. This patch does not change their schema or mover data.
