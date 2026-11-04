# Roth UI 3.4.3

Persistence transactions, lifecycle cleanup and mandatory continuous validation. The compatibility target remains Retail `12.1.5.70688`, Interface `120105`, with external oUF `14.1.1+`.

## Changes

- Export now creates a detached strict snapshot and never sanitizes or exposes live SavedVariables roots.
- Import validates a complete tree, rejects cycles/shared aliases/unsupported values, snapshots both roots, commits once and rolls back when replacement or reconciliation fails.
- Factory reset restores the previous roots when `ReloadUI` cannot complete.
- Direct root replacement uses strict copying rather than silently dropping unsupported descendants.
- Blizzard-frame suppression is transactional: a failed second mutation rolls back the first, including setters that mutate and then throw.
- Retired `RothFont`/`RothLib` optional dependency metadata is removed; Roth's bundled font assets remain unchanged.
- GitHub validation now runs on every pull request and push to `main`, while release publication remains an explicit manual action.
- Added regressions for strict alias rejection, persistence rollback, export immutability and failed reset recovery.

## Installation

Install the ZIP's `Roth_UI` folder into `_retail_/Interface/AddOns/` and keep existing SavedVariables. Install oUF `14.1.1+` separately.

## Acceptance boundary

Source/static validation and isolated Lua tests do not establish in-client combat, taint, visual or performance acceptance. Those checks remain `NOT-RUN` until recorded against a named Retail build.
