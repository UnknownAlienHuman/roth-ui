# Roth UI 3.4.4

Target: Retail `12.1.5.70688`, Interface `120105`, external oUF `14.2.1+`.

## Fixes

- Export no longer runs root repair/migration while reading SavedVariables. It validates a detached document through the same schema boundary as import; missing selected roots, unsupported schemas and malformed shapes fail without live changes.
- Strict serialization rejects metatables, including protected metatables, and uses the table-access predicate before traversal. Value access alone is not table-content access.
- Import/reset reject reentrant root transactions. Export and public reconciliation cannot observe or mutate intermediate roots; the exclusive lock releases on success and error.
- Deferred aura creation rechecks the owner's current visibility and access. Hidden/denied owners do not allocate; a later permitted show can initialize normally.
- Aura attachment is idempotent. Partial initialization failure releases the creation lock, does not block independent regions and is not automatically retried; reload remains the recovery boundary after failed native adoption.
- A successful lazy creation batch enables its new containers and invokes one public oUF update to assign their current unit. Adding a region to an already enabled Auras element also activates that region.
- Candidate-filter updates check current container access and do not advance their fingerprint after a denied update. Completed aura setup queues no redundant combat-exit work.

## Verification boundary

Four added regression files cover real-owner export, table access/metatables, persistence reentrancy and aura lifecycle/failure boundaries. The existing lazy-aura test now uses the real safety helper and models actual visibility and oUF activation/update separation.

The exact commit must pass the repository's Lua 5.1, ownership, load-order and deterministic-package gates. In-client login/reload, combat/taint, secure transitions, aura rendering, interaction and profiler acceptance remain `NOT-RUN`. These changes do not establish measured CPU/FPS improvements.

Replace the `Roth_UI` folder; retain SavedVariables and the separately installed oUF dependency.
