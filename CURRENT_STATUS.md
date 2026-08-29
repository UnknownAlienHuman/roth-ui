# Current status — Roth UI B4.3

Status date: 2026-08-28.

## Source/static verified

- Interface `120100`, Blizzard build `12.1.0.69497`, oUF minimum `14.0.2`.
- Settings UI is a LoadOnDemand sibling addon.
- SavedVariables root replacement/reset has one owner.
- Managed aura containers are first-show lazy and do not use raw aura enumeration.
- Healer-watch entries use managed slots and ignore spell IDs not present in the current `C_Spell` registry.
- Target/focus/boss interruptibility uses exact oUF 14 callback signatures and native boolean sinks.
- Replacement action bars, LibActionButton, LibKeyBound and Lua smoothing are removed.
- 3D portraits are first-show lazy.
- The package is deterministic and contains only the two runtime addon roots.

## Intentionally pending client evidence

- Real target/focus/boss cast, channel and empower scenarios.
- Party/raid aura layout and supported healer-watch spell coverage.
- Combat lockdown, taint and forbidden-action logging.
- Vehicle, override, possess and temporary bar states.
- Edit Mode, mover persistence and migration of old real-world SavedVariables.
- CPU/allocation comparison using `C_AddOnProfiler` on the target client.

Historical `todo.md`, `audit.md`, `history.md` and `addon_map.md` are not current architecture authority and are excluded from release packages.
