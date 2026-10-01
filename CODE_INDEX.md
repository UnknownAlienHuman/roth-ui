# Roth UI code index — B4.3.2

| Area | Files |
|---|---|
| Bootstrap/namespace | `init.lua`, `core/bootstrap.lua` |
| Secret/Forbidden/access boundary | `core/safety.lua` |
| oUF dependency contract | `core/ouf_contract.lua` |
| Config/persistence ownership | `core/config_persistence_owner.lua`, `core/persistence_*.lua`, `core/sv_store.lua`, `config.lua` |
| Settings/import/export/diagnostics | `core/settings_*.lua`, `core/settings_actions.lua`, `core/transfer.lua`, `core/debug_commands.lua` |
| Commands/minimap entry | `core/slashcmd.lua`, `core/slash_aliases.lua`, `core/minimap_button.lua` |
| Lazy managed auras | `core/aura_runtime.lua` |
| Castbar visuals | `core/target_castbar.lua`, `core/lib.lua` |
| Unit values and tags | `core/unit_value_runtime.lua`, `core/unit_misc_runtime.lua`, `core/tags.lua` |
| Unit layouts | `units/*.lua`, `core/units.lua`, `oUF/elements/*.lua` |
| Class resources/orbs | `core/bars.lua`, `core/orb_runtime.lua`, `core/orb_text_controller.lua` |
| Combat fade owner | `core/combat_fader.lua` |
| Movers | `core/mover_runtime.lua`, `core/movegrid.lua`, `embeds/rLib/dragframe.lua`, `embeds/rLib/snapguides.lua` |
| Blizzard-frame policy | `core/frame_policy.lua`, `core/group_policy.lua`, `core/frame_policy_bootstrap.lua` |
| Action buttons/art | `core/action_button_skin.lua`, `core/action_bar_background.lua` |
| Validation/package | `tools/validate_addon.py`, `tools/validate_repository_text.py`, `tools/package_release.py`, `tests/*.lua` |

## Retired paths

The release validator rejects:

- `Roth_UI_Options` and old options loader;
- `core/unit_policy.lua`;
- legacy rLib frame-fader/grid/slash modules;
- raw-aura compatibility modules;
- replacement action-bar modules/libraries;
- Lua smoothing module;
- service/probe marker files.
