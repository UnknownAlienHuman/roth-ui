# Roth UI code index

| Area | Entry points | Scope |
|---|---|---|
| Bootstrap | `init.lua`, `core/bootstrap.lua` | Namespace, load sequencing and runtime startup |
| Persistence | `core/persistence_*.lua`, `core/sv_store.lua`, `config.lua` | SavedVariables, schema, transfer, drift and reports |
| Safety/policy | `core/safety.lua`, `core/frame_policy.lua`, `core/unit_policy.lua` | Combat-safe and reversible Blizzard-frame policy |
| Auras (Retail 12.1) | `core/aura_runtime_12_1.lua`, `core/aura_runtime_12_1_guard.lua`, `core/unit_misc_runtime.lua` | Active managed `AuraContainer` adapter, fail-closed/own-caster/event-detachment guard and inert legacy compatibility facades; the raw `core/group_aura_watch.lua` scanner remains in history but is excluded from the TOC load graph; see `MIDNIGHT_12_1_MIGRATION.md` |
| Action bars | `core/action_bar_*.lua`, `core/bar_runtime_registry.lua` | Secure bars, dock, override, vehicle and visibility paths; protected ownership remains disabled by default |
| Movers | `core/mover_runtime.lua`, `core/movegrid.lua`, `embeds/rLib/dragframe.lua` | Registration, drag and persisted placement |
| Orbs/bars | `core/orb_*.lua`, `core/bars.lua` | Player resources and status bars |
| Units | loaded `units/*.lua`; loaded elements `oUF/elements/target_border.lua`, `experience.lua`, `reputation.lua` | oUF layouts, castbars and unit-specific elements; other on-disk element files are inactive unless added to the root TOC |
| Settings | `core/settings_*.lua`, `core/settings_actions.lua` | In-game settings and apply/reset operations; `settings_actions.lua` must load before page builders that assert it |
| Validation | `tools/validate_addon.py`, `.github/workflows/addon-static-validation.yml` | TOC/XML closure, metadata and order invariants, retired-module exclusion, managed-aura boundary, full Lua 5.1 parsing, whitespace and conflict-marker checks |
| Optional modules | `modules/Roth_UI_*/*` | ActionBarStyler, button templates and oUF helpers |

Primary load order is recorded in [`Roth_UI.toc`](Roth_UI.toc). The Retail 12.1 compatibility boundary and required runtime matrix are recorded in [`MIDNIGHT_12_1_MIGRATION.md`](MIDNIGHT_12_1_MIGRATION.md). Historical/static findings are in [`history.md`](history.md) and [`audit.md`](audit.md).
