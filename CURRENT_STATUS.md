# Current status — Roth UI 3.4.3

Evidence date: **2026-11-03**. Source/static evidence is separated from target-client acceptance.

## Selected target

| Component | Version / evidence |
| --- | --- |
| Addon | `3.4.3`, one `Roth_UI` package root |
| Retail source | `12.1.5.70688`, Gethe/wow-ui-source `d07eb00237d8891f153215db98a5df880a26cfe5` |
| TOC Interface | `120105`; client `GetBuildInfo()` not captured |
| External framework | oUF `14.1.1+`; reviewed `8f37c36e3ed37d2fcfca2f3690f5e37e52b758c7` |
| Knowledge base | wow-addon-engineering-kb `b03e1635d0ff8bcd6be4f4dfac589dafec4e5e83` |

## Implemented in 3.4.3

- Persistence export reads detached strict snapshots and performs no cleanup mutation on live roots.
- Import is one reversible transaction: strict staging, complete-root snapshot, one replacement, reconciliation acceptance and rollback on false/throwing outcomes.
- Reset/reload is reversible when reload invocation fails.
- Detached root replacement rejects unsupported descendants and shared-reference graphs instead of silently truncating them.
- Foreign-frame suppression rolls back partial alpha/mouse changes and retains only unresolved ownership state.
- Obsolete optional dependency metadata is removed.
- Validation is mandatory on pull requests and pushes to `main`; manual dispatch remains the only release-publication path.

## Validation state

The repository contains **36 isolated Lua regression scripts** and **111 Lua files total** after this change. The affected persistence, transfer, frame-policy and bootstrap regressions passed in the development preflight. The authoritative full Lua 5.1 result and deterministic package artifact are produced by the GitHub Actions validation attached to the commit/PR.

A green static workflow proves source parsing, ownership guards, isolated control flow and package determinism. It does not emulate WoW's secure execution engine.

## Client acceptance — NOT-RUN

Before claiming runtime certification:

1. Record `GetBuildInfo()`, installed oUF version and enabled addons.
2. Test first install, migration, malformed SavedVariables, export/import rollback, reset/reload and `/reload`.
3. Exercise combat, target/focus/boss casts, managed auras, secure party/raid transitions, action-bar vehicle/override states and Settings.
4. Capture taint output and compare CPU/allocation measurements with `C_AddOnProfiler` under a controlled workload.
5. Verify movers, fonts, orb visuals, text fit and layering across representative resolutions and Cyrillic names.
