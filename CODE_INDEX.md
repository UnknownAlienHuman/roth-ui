# Roth UI code index

| Area | Entry points | Scope |
|---|---|---|
| Bootstrap | `init.lua`, `core/bootstrap.lua` | Namespace, load sequencing and runtime startup |
| Persistence | `core/persistence_*.lua`, `core/sv_store.lua`, `config.lua` | SavedVariables, schema, transfer, drift and reports |
| Safety/policy | `core/safety.lua`, `core/frame_policy.lua`, `core/unit_policy.lua` | Combat-safe and reversible Blizzard-frame policy |
| Action bars | `core/action_bar_*.lua`, `core/bar_runtime_registry.lua` | Secure bars, dock, override, vehicle and visibility paths |
| Movers | `core/mover_runtime.lua`, `core/movegrid.lua`, `embeds/rLib/dragframe.lua` | Registration, drag and persisted placement |
| Orbs/bars | `core/orb_*.lua`, `core/bars.lua` | Player resources and status bars |
| Units | loaded `units/*.lua`; loaded elements `oUF/elements/target_border.lua`, `experience.lua`, `reputation.lua` | oUF layouts, castbars and unit-specific elements; other on-disk element files are inactive unless added to the root TOC |
| Settings | `core/settings_*.lua`, `core/settings_actions.lua` | In-game settings and apply/reset operations |
| Optional modules | `modules/Roth_UI_*/*` | ActionBarStyler, button templates and oUF helpers |

Primary load order is recorded in [`Roth_UI.toc`](Roth_UI.toc). Historical/static findings are in [`history.md`](history.md) and [`audit.md`](audit.md).
