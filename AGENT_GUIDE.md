# Roth UI agent guide

## Start here

Read [`Roth_UI.toc`](Roth_UI.toc) first, then follow `init.lua` -> `config.lua` -> `core/bootstrap.lua`. `init.lua` receives `(addonName, ns)`, publishes `_G.Roth_UI`, and is the namespace contract for every main-addon chunk. `core/bootstrap.lua` calls `Roth_UI:InitConfig()` after the persistence/config files have been loaded. `config.lua` defines defaults; it is not the runtime owner of SavedVariables.

The main TOC loads embedded `rLib` through `embeds/rLib/rLib.xml`, bundled libraries, `init.lua`, oUF elements/defaults, safety and persistence services, settings/mover/frame policy, unit definitions, and action-bar files. Its XML entries are expanded in place: `modules/Roth_UI_rActionBarStyler/rActionBar.xml` loads `hide_blizzart.lua`, `slashcmd.lua`, `spellflyout.lua`, and `cooldown.lua`; the two button XML files load their respective `core.lua`/`theme.lua`. The separate module TOCs under `modules/` are optional addon wrappers and are not required to understand the main package load.

## Runtime and state flow

1. `config.lua` seeds defaults and canonical persistence descriptors.
2. `core/persistence_root_store.lua`, `persistence_domain_registry.lua`, `persistence_schema_registry.lua`, `config_persistence_owner.lua`, and `sv_store.lua` establish account/template/character stores.
3. `core/bootstrap.lua` finalizes config and releases `Roth_UI:ListenForLoaded` callbacks.
4. `core/frame_policy_bootstrap.lua` and `core/units.lua` install frame policy and oUF unit layouts; `units/*.lua` and `oUF/elements/*.lua` render player/target/group/raid/boss frames.
5. `core/bar_runtime_registry.lua`, `action_bar_secure_runtime.lua`, `action_bar_bar*.lua`, `bars.lua`, `orb_runtime.lua`, and `mover_runtime.lua` build and refresh bars, orbs, and movers.
6. `core/settings_main.lua` registers Blizzard Settings proxy controls. `core/settings_actions.lua` and `persistence_control_plane.lua` are the write/reset/import/export boundary.

Declared stores are `Roth_UI_DB` (account settings and shared orb templates) and `Roth_UI_DB_Char` (character orb state). Writes must go through `ns.store`/`ns.persistence`; runtime reads should use the read-only config view or `GetConfigValue`, not ad-hoc SavedVariables tables. `persistence_control_plane.lua` listens for `ADDON_LOADED`, `PLAYER_LOGIN`, and `PLAYER_LOGOUT`, reconciling and sanitizing at those boundaries.

## Surfaces and dependencies

- Slash: `core/slashcmd.lua:262-264` registers `SLASH_roth1` (`/roth`) with settings, movers, persistence doctor/reconcile/rebuild/reset, smoke, schema, aura diagnostics, export/import, and Blizzard restore commands. The bundled `LibKeyBound-1.0` also registers `/libkeybound`, `/kb`, and `/lkb` (`Libs/LibKeyBound-1.0/LibKeyBound-1.0.lua:166-169`).
- Settings: `core/settings_main.lua` creates root/subcategories; settings writes may queue through `PLAYER_REGEN_ENABLED` because protected frame changes are not safe in combat.
- Required external dependency: `oUF` (`RequiredDeps`). Optional TOC dependencies: `RothFont`, `RothLib`.
- Bundled libraries: LibStub, CallbackHandler-1.0, LibActionButton-1.0-GE, LibSharedMedia-3.0, LibKeyBound-1.0, and embedded `rLib`. No direct source-level dependency on the other current Roth addons was found; optional module TOCs depend on `Roth_UI`.

## Invariants and risks

- Keep one owner for each persistence domain; do not reintroduce a parallel `ns.cfg`/SavedVariables write path.
- `Roth_UI.disableProtectedActionBarOwnership` is intentionally `true`. Secure action bars, `SecureHandlerStateTemplate`, protected buttons, `InCombatLockdown`, and `PLAYER_REGEN_ENABLED` queues are the primary taint/combat boundary.
- Unit/group/raid code handles `UNIT_AURA`, threat, vehicle, arena-prep, and regen events. The active DK rune path is the loaded `core/bars.lua:203-265,778-875`; the on-disk `oUF/elements/rune_orbs.lua` is not listed by `Roth_UI.toc` and is absent from the manifest `loadedFiles`, so treat it as inactive unless the TOC changes. The component wrapper files `modules/Roth_UI_rActionBarStyler/bootstrap.lua`, `modules/Roth_UI_rButtonTemplate/bootstrap.lua`, and `modules/Roth_UI_rButtonTemplate_Roth/bootstrap.lua` are likewise not reached by the current root TOC/XML closure; the root loads their active XML/Lua paths directly. Action-bar and mover refreshes must stay deferred where the code already queues them.
- Blizzard party/raid restore diagnostics in `core/blizzard_restore_debug.lua` can load/enable Blizzard addons; treat those commands as explicit diagnostic operations.
- `oUF` color compatibility is patched in `init.lua`; preserve both array-style RGB and `GetRGB()` behavior.

## Change routing

- Persistence/schema/migration: `core/config_persistence_owner.lua`, `persistence_*`, `sv_store.lua`, `config.lua`; update the canonical store contract and doctor output together.
- Settings/UI and command behavior: `core/settings_*.lua`, `settings_actions.lua`, `slashcmd.lua`; do not write DB directly from controls.
- Secure bars/action buttons: `core/action_bar_secure_runtime.lua`, `action_bar_bar*.lua`, `action_bar_overridebar.lua`, `action_bar_multibar_visibility.lua`; verify combat queue and binding refresh.
- Unit frame visuals/events: matching `units/<unit>.lua`, `oUF/elements/<element>.lua`, and `core/unit_policy.lua`/`frame_policy.lua`.
- Movers/layout: `core/mover_runtime.lua`, `movegrid.lua`, `embeds/rLib/dragframe.lua`; preserve saved anchors and out-of-combat guards.
- Optional module addon changes: edit the module folder plus its own TOC/XML; remember the same files are embedded by the main TOC.

## Verification

Static: compare every file listed by `Roth_UI.toc` (including XML expansions), run the repository Lua parser and TOC-reference checks, and inspect `git diff --check`. Runtime smoke commands are `/roth svtest`, `/roth svdoctor`, `/roth svreconcile`, `/roth svrebuild`, `/roth settingsschema`, and `/roth smoke full`; test settings/import/reset in and out of combat and confirm `PLAYER_REGEN_ENABLED` drains pending work. The current audit is source/static only; game-client behavior and exact current `oUF` API compatibility remain unverified here.
