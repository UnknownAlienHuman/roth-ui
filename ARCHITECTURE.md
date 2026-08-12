# Roth UI architecture

## Runtime layers

1. `init.lua` creates the addon namespace, compatibility helpers and callback surface. `config.lua` seeds defaults, while `core/bootstrap.lua` is the final config gate and calls `Roth_UI:InitConfig()`.
2. `core/` owns safety, deferred scheduling, persistence, frame/bar registries, settings, movers, orbs and Blizzard-frame policy.
3. The root TOC loads `oUF/elements/target_border.lua`, `experience.lua`, and `reputation.lua` plus the `units/` layouts. The on-disk `oUF/elements/rune_orbs.lua` is not in the root TOC/manifest and is inactive in the current package; the active rune presentation is assembled by `core/bars.lua`.
4. Embedded libraries provide action-button, media, key-binding and legacy helper services.
5. The main TOC embeds the action-bar/button-template XML files. The similarly named module TOCs are optional addon wrappers with `RequiredDeps`, not a prerequisite for the main package.

The intended ownership boundary is one owner per protected Blizzard surface: core services coordinate state, while visual modules apply reversible changes. `history.md` and `audit.md` document the completed static refactor and its remaining runtime-proof boundary.

## Persistence

`Roth_UI_DB` and `Roth_UI_DB_Char` are declared in the main TOC. `core/config_persistence_owner.lua`, `core/persistence_*`, `core/sv_store.lua`, `core/persistence_control_plane.lua`, and `core/transfer.lua` coordinate canonical stores, schema, import/export, reset, reconciliation, and logout sanitization. Settings should write through `ns.store`/`ns.persistence`, preserving one owner per domain.

## External boundaries

- Required: `oUF`.
- Optional TOC dependencies: `RothFont`, `RothLib`.
- Embedded: LibStub, CallbackHandler-1.0, LibActionButton-1.0-GE, LibSharedMedia-3.0, LibKeyBound-1.0 and rLib.
