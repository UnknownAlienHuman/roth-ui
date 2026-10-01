# Roth UI code index — B4.3.4

| Area | Files |
|---|---|
| Bootstrap/namespace | `init.lua`, `core/bootstrap.lua` |
| Secret/Forbidden/access boundary | `core/safety.lua`, `core/safety_aspects.lua` |
| oUF dependency contract | `core/ouf_contract.lua` |
| Config/persistence ownership | `core/config_persistence_owner.lua`, `core/persistence_*.lua`, `core/sv_store.lua`, `config.lua` |
| Settings/import/export/diagnostics | `core/settings_*.lua`, `core/settings_actions.lua`, `core/transfer.lua`, `core/debug_commands.lua` |
| Commands/minimap entry | `core/slashcmd.lua`, `core/slash_aliases.lua`, `core/minimap_button.lua` |
| Shared post-combat/frame policy | `core/frame_policy.lua`, `core/frame_policy_bootstrap.lua` |
| Secure group headers | `core/group_header_visibility.lua`, `core/group_structure_contract.lua`, `units/party.lua`, `units/raid.lua` |
| Lazy managed auras | `core/aura_runtime.lua` |
| Castbar visuals | `core/target_castbar.lua`, `core/lib.lua` |
| Unit values and tags | `core/unit_value_runtime.lua`, `core/unit_misc_runtime.lua`, `core/tags.lua` |
| Unit layouts | `units/*.lua`, `core/units.lua`, `oUF/elements/*.lua` |
| Class resources/orbs | `core/bars.lua`, `core/orb_runtime.lua`, `core/orb_text_controller.lua` |
| Combat fade owner | `core/combat_fader.lua` |
| Movers | `core/mover_runtime.lua`, `core/movegrid.lua`, `embeds/rLib/dragframe.lua`, `embeds/rLib/snapguides.lua` |
| Blizzard provider policy | `core/group_policy.lua`, `core/frame_policy_bootstrap.lua` |
| Action buttons/art | `core/action_button_skin.lua`, `core/action_bar_background.lua` |
| Validation/package | `tools/validate_addon.py`, `tools/validate_repository_text.py`, `tools/validate_group_visibility.py`, `tools/validate_runtime_hardening.py`, `tools/package_release.py`, `tests/*.lua` |

The validators reject live Settings callbacks that rebuild secure party/raid structure, protected-header reparenting or foreign bookkeeping fields, permanent post-combat queues, eager Blizzard Settings registration, old oUF/build metadata, retired raw-aura/action-bar modules and duplicate ownership paths.
