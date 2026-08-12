# Roth UI architecture

## Runtime layers

1. `init.lua` creates the addon namespace, compatibility helpers and callback surface.
2. `core/` owns safety, deferred scheduling, persistence, frame/bar registries, settings, movers, orbs and Blizzard-frame policy.
3. `oUF/elements/` and `units/` define unit-frame layout and custom elements.
4. Embedded libraries provide action-button, media, key-binding and legacy helper services.
5. Optional module TOCs load action-bar and button-template extensions after the main addon.

The intended ownership boundary is one owner per protected Blizzard surface: core services coordinate state, while visual modules apply reversible changes. `history.md` and `audit.md` document the completed static refactor and its remaining runtime-proof boundary.

## Persistence

`Roth_UI_DB` and `Roth_UI_DB_Char` are declared in the main TOC. Persistence services under `core/persistence_*`, `core/sv_store.lua`, `core/config_persistence_owner.lua` and `core/transfer.lua` coordinate schema, import/export, reset and reconciliation. This area is still being consolidated, so changes should preserve the single-owner direction documented in `todo.md`.

## External boundaries

- Required: `oUF`.
- Optional TOC dependencies: `RothFont`, `RothLib`.
- Embedded: LibStub, CallbackHandler-1.0, LibActionButton-1.0-GE, LibSharedMedia-3.0, LibKeyBound-1.0 and rLib.
