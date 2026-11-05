# Roth UI 3.4.5

Target: Retail `12.1.5.70688`, Interface `120105`, external oUF `14.2.1+`.

## Changes

- Cancel obsolete combat-exit work when a newer request runs immediately, including replacements made while the old batch is draining.
- Reject recursive queue drains and preserve unrun work if combat resumes during a callback.
- Refresh foreign-frame restoration baselines when another owner changes a property before Roth reapplies suppression. Repeated unchanged suppression performs no extra native setters.
- Preserve newer foreign font tuples across reapplication and restoration, including same-path size/flag changes.
- Initialize late-created 3D portraits through their oUF element update and prevent duplicate lifecycle attachment.
- Replace cast-color string fingerprints with ordinary RGBA scalar comparison; unchanged callbacks do not construct fingerprint tables/strings.
- Add five regression scripts reproduced against the previous verified runtime. No new scheduler, polling loop, SavedVariables migration, library or media payload.

## Verification boundary

The complete Lua 5.1 repository workflow must pass on the exact PR candidate and merged main. `CURRENT_STATUS.md` maps each change to KB/oUF authority and its regression. Operation-count tests are not measured FPS/CPU improvements.

Actual WoW-client combat, taint, rendering, interaction and profiler acceptance remains `NOT-RUN`.

Install the ZIP's `Roth_UI` folder and keep existing SavedVariables.
