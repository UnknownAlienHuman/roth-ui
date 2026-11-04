# Current status — Roth UI 3.4.3 audit candidate

Evidence date: **2026-11-04**.

Selected source remains `12.1.5.70688`. Post-selected `12.1.5.70783` was reviewed; its changed APIs are outside Roth's loaded graph. oUF `14.2.1` is now the minimum reviewed dependency.

## Implemented

- SavedVariables import/reset uses detached strict validation, exact-reference snapshot, one root commit, one reconciliation and rollback for false/throw/reload failure.
- Full export validates account and character roots as one tree, so cross-root aliases cannot be laundered by separate copies.
- Strict serialization now has depth, table-count, entry-count and aggregate-string-byte ceilings.
- Malformed legacy roots no longer prevent recovery import/reset; exact root references remain rollback authority.
- Raw config/root getters and writers are captured then removed from shared namespace tables. Dead namespace aliases were removed.
- Foreign-frame suppression rolls back partial setters, including setters that mutate before throwing.
- Object-scoped deferred work uses weak-key identities; `tostring(frame)` keys are gone.
- The retired global `rCombatFrameFader`, duplicate `svrebuild` route and unused value-helper exports were removed; class bars bind directly to their sole owners.
- Removed 18 one-use locals, including inert addon-name captures and unused `LibSharedMedia`/locale lookups during configuration load.
- Transfer-dialog hide clears encoded/pasted text and active closures instead of retaining potentially large buffers for the session.
- The shared next-frame scheduler now owns one timer per generation, preserves latest-per-key semantics, isolates callback failures and sends reentrant work to the next generation. Action-bar artwork requires that owner and has no fallback scheduler.
- Orb persistence migrates at file scope under `LoadSavedVariablesFirst`; the redundant own-addon `ADDON_LOADED` frame was removed. Live root maps remain private.
- Media ownership was re-audited by exact Lua string literals and SHA-256. **84 unused/duplicate files (7,026,025 bytes)** were removed; **120** owned media files remain.

## Validation performed on this second-pass overlay

| Gate | Result |
|---|---|
| Python validator syntax | PASS |
| Packaged runtime Lua parse with available `texlua` | PASS; 75 runtime Lua files |
| Focused regression layer | PASS; 12 tests |
| Exact media ownership | PASS |
| Duplicate media SHA-256 scan | PASS |
| Deterministic runtime package | PASS; two byte-identical builds |
| Extracted package root/layout/TOC/XML closure | PASS; 199 files, 76 load-graph entries |
| Focused regressions against extracted package | PASS |
| Full Lua 5.1 CI for this overlay | NOT-RUN; overlay is not pushed from this environment |
| Retail client acceptance | NOT-RUN |

The original PR #16 head passed GitHub Actions before this candidate. That result must not be attributed to the unpushed audit changes.

## Remaining client acceptance

Record the actual `GetBuildInfo()` and installed oUF version, then test login/reload with fresh/migrated/malformed SavedVariables, combat/taint, casts/channels/empower, managed auras, party/raid secure headers, vehicle/override action states, movers, Settings, fonts, representative resolutions and `C_AddOnProfiler` measurements.
