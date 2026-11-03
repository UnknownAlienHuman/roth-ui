# Roth UI code index — 3.4.0

Target: Retail `12.1.5`, Interface `120105`, source build `12.1.5.70688`; required oUF `14.1.1+`.

| Area | Files |
|---|---|
| Bootstrap, metadata, namespace | `Roth_UI.toc`, `init.lua`, `core/bootstrap.lua` |
| Safety boundaries | `core/safety.lua`, `core/safety_aspects.lua` |
| oUF dependency contract and custom elements | `core/ouf_contract.lua`, `oUF/elements/*.lua` |
| Defaults and configuration | `defaults/*.lua`, `config.lua`, `charspecific.lua` |
| Persistence services | `core/config_persistence_owner.lua`, `core/persistence_*.lua`, `core/sv_store.lua` |
| Settings, actions, transfer, diagnostics | `core/settings_*.lua`, `core/settings_actions.lua`, `core/transfer.lua`, `core/debug_commands.lua` |
| Commands and minimap entry | `core/slashcmd.lua`, `core/slash_aliases.lua`, `core/minimap_button.lua` |
| Combat and refresh policy | `core/frame_policy.lua`, `core/deferred_scheduler.lua`, `core/frame_policy_bootstrap.lua` |
| Secure group headers | `core/group_header_visibility.lua`, `core/group_structure_contract.lua`, `units/party.lua`, `units/raid.lua` |
| Managed aura lifecycle | `core/aura_runtime.lua` |
| Castbar visual adapter | `core/target_castbar.lua`, `core/lib.lua` |
| Unit values, tags, and miscellaneous elements | `core/unit_value_runtime.lua`, `core/unit_misc_runtime.lua`, `core/tags.lua` |
| Unit layout builders | `units/*.lua`, `units/mini_target_scaffold.lua`, `core/units.lua` |
| Bars, orbs, and fonts | `core/bars.lua`, `core/orb_runtime.lua`, `core/orb_text_controller.lua`, `core/font_policy.lua` |
| Mover and move grid | `core/mover_runtime.lua`, `core/movegrid.lua` |
| Combat fade owner | `core/combat_fader.lua` |
| Blizzard provider policy | `core/group_policy.lua`, `core/frame_policy_bootstrap.lua` |
| Action buttons and artwork | `core/action_button_skin.lua`, `core/action_bar_background.lua` |
| Validation and tests | `tools/validate_*.py`, `tools/run_lua_tests.py`, `tools/package_release.py`, `tests/*.lua` |

Use `python3 tools/run_lua_tests.py` to run every isolated Lua regression. The validators check TOC/XML closure, metadata and ordering, source policy, security boundaries, group-header lifecycle, and packaging rules. Static validation does not establish client runtime behavior; current in-client build, combat, taint, visual, and performance checks are `NOT-RUN`.
