# Roth UI code index — 3.4.3

Target: Retail `12.1.5`, Interface `120105`, source build `12.1.5.70688`; required oUF `14.1.1+`.

| Area | Files |
|---|---|
| Bootstrap and namespace | `Roth_UI.toc`, `init.lua`, `core/bootstrap.lua` |
| Safety boundaries | `core/safety.lua`, `core/safety_aspects.lua` |
| oUF contract and custom elements | `core/ouf_contract.lua`, `oUF/elements/*.lua` |
| Defaults and configuration | `defaults/*.lua`, `config.lua`, `charspecific.lua` |
| Canonical persistence | `core/config_persistence_owner.lua`, `core/persistence_root_store.lua`, `core/sv_store.lua`, `core/persistence_*.lua` |
| Transfer transaction | `core/persistence_control_plane.lua`, `core/transfer.lua`, `core/settings_transfer.lua` |
| Orb persistence/defaults/runtime | `core/db.lua`, `core/orb_persistence_owner.lua`, `core/orb_runtime.lua`, `core/orb_text_controller.lua` |
| Settings and commands | `core/settings_*.lua`, `core/settings_actions.lua`, `core/debug_commands.lua`, `core/slash*.lua` |
| Combat and refresh policy | `core/frame_policy.lua`, `core/deferred_scheduler.lua`, `core/frame_policy_bootstrap.lua` |
| Secure group headers | `core/group_header_visibility.lua`, `core/group_structure_contract.lua`, `units/party.lua`, `units/raid.lua` |
| Managed auras/casts | `core/aura_runtime.lua`, `core/target_castbar.lua` |
| Units, values and bars | `units/*.lua`, `core/units.lua`, `core/unit_*_runtime.lua`, `core/tags.lua`, `core/bars.lua` |
| Movers, fonts and artwork | `core/mover_runtime.lua`, `core/movegrid.lua`, `core/font_policy.lua`, `core/action_*.lua` |
| Validation and package | `tools/validate_*.py`, `tools/run_lua_tests.py`, `tools/package_release.py`, `tests/*.lua` |

`python3 tools/run_lua_tests.py` discovers every `tests/test_*.lua` regression. Pull requests and pushes to `main` run the complete validation/package workflow automatically.
