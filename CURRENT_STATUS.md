# Current status — Roth UI 3.4.3

Evidence date: **2026-11-04**.

## Source target

- Addon version: `3.4.3`.
- Retail family: `12.1.5`, Interface `120105`.
- Selected source: `12.1.5.70688`; post-selected `12.1.5.70783` was reviewed and its changed surfaces are outside Roth UI's loaded graph.
- Required external dependency: oUF `14.2.1+`.
- PR #16 was squash-merged to `main` as `d31ec7d8bf3273f3f2bb7896a04ab2e10fb2edfb` after the exact final PR head passed the complete repository workflow.

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
- The target-of-target layout uses canonical `media/target.tga`; the removed `targettarget.tga` had the same Git blob and the regression retains all geometry, layer and anchor checks.

## Automated validation

The authoritative `Addon validation and package` workflow passed on exact PR head `00122dc1133937da9d9404e635336a1156f02115` and on merged `main` commit `d31ec7d8bf3273f3f2bb7896a04ab2e10fb2edfb`.

Executed gates:

- repository text policy;
- 76-entry TOC/XML load graph, ownership and Retail boundaries;
- exact secure-header visibility semantics;
- runtime-hardening guards;
- Lua 5.1 parsing of 116 files and 41 isolated regressions;
- whitespace and merge-conflict checks;
- two byte-identical 199-file release builds.

Verified package SHA-256: `80e3bc35e5f25c10e4f8f64a3aa28f73d66a6ccd0a2b440fe417bcbb0b690369`.

## Client acceptance

`NOT-RUN`: actual `GetBuildInfo()`, login/reload with fresh/migrated/malformed SavedVariables, combat lockdown and taint, casts/channels/empower, managed auras, party/raid secure transitions, vehicle/override action states, movers, Settings, fonts, representative resolutions and `C_AddOnProfiler` measurements.
