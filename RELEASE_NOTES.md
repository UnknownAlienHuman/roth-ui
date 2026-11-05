# Roth UI 3.4.3

Target: Retail `12.1.5.70688`, Interface `120105`, external oUF `14.2.1+`.

## Changes

- Made import/reset atomic with strict staging, exact-reference rollback and reload inside the transaction boundary.
- Made export immutable and rejected cycles, aliases, inaccessible values, unsupported values, non-finite numbers and oversized trees.
- Preserved recovery when existing legacy SavedVariables are malformed.
- Closed raw live-root access after owner capture and removed unused compatibility aliases.
- Rolled back partial Blizzard-frame suppression writes.
- Replaced frame-string queue keys with weak object identity.
- Consolidated all next-frame refresh work onto one timer per generation; action-art no longer has an optional/fallback scheduler.
- Removed the global combat-fader alias and the duplicate persistence rebuild command.
- Removed 18 one-use locals and two inert configuration-time lookups.
- Moved orb migration to the pre-file SavedVariables boundary and removed its redundant load-event owner.
- Clear transfer-dialog strings and closures on hide to release large export/import buffers.
- Raised the external oUF minimum to `14.2.1` for current secret/tag/event fixes.
- Removed 84 unowned or duplicate media files (7,026,025 bytes uncompressed).

## Validation

Audit-candidate local checks: 75 packaged Lua files parsed, 12 focused regressions passed, deterministic ZIP reproduced byte-for-byte, extracted package validated (199 files; 76 TOC/XML graph entries). Full Lua 5.1 GitHub CI and Retail client acceptance for this exact overlay remain `NOT-RUN` until the overlay is pushed.

Install the ZIP's `Roth_UI` folder and keep existing SavedVariables.
