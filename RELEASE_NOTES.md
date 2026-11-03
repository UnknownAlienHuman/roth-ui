# Roth UI 3.4.2

Configuration startup and lifecycle fixes. The target remains Retail **12.1.5.70688**, Interface **120105**, with external **oUF 14.1.1+**. Source pins remain unchanged; local evidence date: **2026-11-03**.

## Changes

- Enabled `LoadSavedVariablesFirst: 1`. Roth constructs unit frames during file loading, so saved settings must be available before configuration views are captured. This prevents frames retaining default configuration after the loader supplies saved data. The static validator now requires this contract.
- Sanitized configuration before recursive migration and repaired malformed table shapes. Existing castbar enable flags and legacy party/raid provider choices are preserved. Unreadable config roots recover through complete defaults.
- Removed the redundant mover traversal from Reset All. A failed persistence reset leaves mover positions intact; successful canonical reset already clears those settings before reload.
- Made restoration of Blizzard-frame alpha and mouse state independent. Roth restores only properties that still match its last successful writes and preserves changes made by other owners. A partial failure retains only unresolved restoration work.
- Released completed load callbacks and removed completed persistence load/login listeners. Logout sanitation remains registered.
- Removed repeated configuration commentary and made the Lua test runner usable with a Lua 5.1 interpreter even when the standalone compiler is absent.

## Installation

Install the ZIP's `Roth_UI` folder into `_retail_/Interface/AddOns/` with compatible oUF installed separately. Keep existing SavedVariables. Open Settings with `/roth options`.

## Validation

The suite contains 34 isolated regression scripts, including configuration startup with real persistence modules, malformed data recovery, failed reset, bootstrap cleanup and partial frame-state restoration. Final source and extracted-package checks are recorded in [CURRENT_STATUS.md](CURRENT_STATUS.md).

Game-client startup order, combat, taint, visual behavior and profiling remain **NOT-RUN**. Local tests exercise addon logic and simulated API contracts, not the client's secure execution engine. The loading directive's source evidence is linked in [MIGRATION_12_1_5.md](MIGRATION_12_1_5.md).
