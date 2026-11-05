# Current status — Roth UI 3.4.3

Evidence date: **2026-11-04**.

## Source target

- Addon version: `3.4.3`.
- Retail family: `12.1.5`, Interface `120105`.
- Selected source: `12.1.5.70688`; post-selected `12.1.5.70783` was reviewed and its changed surfaces are outside Roth UI's loaded graph.
- Required external dependency: oUF `14.2.1+`.
- Pull request: #16. Merge is allowed only after the complete repository workflow passes on the exact final head.

## Implemented

- SavedVariables import/reset uses detached strict validation, exact-reference snapshots, one root commit, one reconciliation and rollback for false, thrown and reload-failure paths.
- Account and character roots are validated as one bounded tree, rejecting cross-root aliases, cycles, inaccessible values, unsupported types, non-finite numbers and excessive depth/table/entry/string budgets.
- Export copies first and never sanitizes or exposes live roots. Malformed legacy roots do not prevent reset or recovery import.
- Raw root getters and writers are captured by the transaction owner and removed from shared namespace tables.
- Foreign-frame suppression restores partial writes; object-scoped deferred work uses weak-key identities rather than stringified frame keys.
- One shared next-frame scheduler owns one timer per generation, latest-per-key coalescing, callback-error isolation and reentrant next-generation work.
- The legacy global combat-fader owner, duplicate persistence routes, unused helper exports and one-use locals were removed.
- Orb migration runs at the `LoadSavedVariablesFirst` boundary without a redundant own-addon `ADDON_LOADED` owner.
- Transfer UI releases imported/exported text and active closures when hidden.
- Media ownership was re-audited by exact runtime references and SHA-256: 84 unused or duplicate files, totaling 7,026,025 bytes, were removed; 120 owned media files remain.

## Automated validation

The authoritative `Addon validation and package` workflow runs repository policy guards, TOC/XML/load-order validation, Lua 5.1 syntax, all isolated Lua regressions and two deterministic package builds. A workflow result applies only to its exact commit; a previous green head is not evidence for a later head.

The audit application run exposed and corrected stale test fixtures after production contracts were tightened. PR #16 must be green on the final non-bot-authored head before merge, and `main` must pass its push workflow after merge.

## Client acceptance

`NOT-RUN`: actual `GetBuildInfo()`, login/reload with fresh/migrated/malformed SavedVariables, combat lockdown and taint, casts/channels/empower, managed auras, party/raid secure transitions, vehicle/override action states, movers, Settings, fonts, representative resolutions and `C_AddOnProfiler` measurements.
