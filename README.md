# Roth UI

Diablo-inspired World of Warcraft UI built around the oUF framework. The addon provides custom unit frames, resource orbs, action-bar styling, movers, Blizzard-frame policies, and a settings/persistence layer.

## Preview

![Roth UI Community Edition in game](https://media.forgecdn.net/attachments/1569/226/screenshot-2026-03-07-072119-png.png)

Screenshot from the [CurseForge gallery](https://www.curseforge.com/wow/addons/roth-ui-community-edition).

## Compatibility

- World of Warcraft Retail / Midnight `12.1.0`
- Interface: `120100`
- Verified source baseline: Blizzard UI build `12.1.0.69497`
- Required framework: `oUF 14.0.2` or newer
- Addon version: `3.3.8-v57.8-B4.1`
- Author: Neomorph
- CurseForge reference: [Roth UI Community Edition](https://www.curseforge.com/wow/addons/roth-ui-community-edition)

Roth UI uses the Retail 12.1 managed aura architecture exposed by oUF: `frame:CreateAuras()`, managed aura groups, native AuraButton count/cooldown/duration bindings, and native dispel/stealable visual sinks. An older oUF release that only implements legacy `self.Buffs` / `self.Debuffs` elements is not compatible.

## Installation

1. Install `oUF 14.0.2` or newer separately.
2. Copy the `Roth_UI` directory into `World of Warcraft/_retail_/Interface/AddOns/`.
3. Enable Roth UI and oUF in the character-selection AddOns list.
4. Use the in-game Roth settings and `/roth` commands after login.

The repository contains embedded support libraries (LibStub, CallbackHandler, LibActionButton-GE, LibSharedMedia and LibKeyBound). The TOC also declares optional `RothFont` and `RothLib`; verify those addon names in the target installation before enabling optional integrations.

## Retail 12.1 safety model

- General unit auras are owned by Blizzard/oUF managed `AuraContainer` objects.
- The active Roth UI path does not enumerate raw `AuraData`, derive aura state from `UNIT_AURA`, or perform manual aura-duration arithmetic.
- The obsolete `core/group_aura_watch.lua` raw scanner is retained only for history and is excluded from the runtime TOC graph.
- Party and raid healer-watch indicators use managed `includeSpellIDs` plus `isFromPlayerOrPlayerPet` candidate filters.
- The own-caster filter is installed once per managed healer-watch group, avoiding repeated full container updates.
- Dispel information is rendered through native aura-button borders instead of health-frame color inference from protected aura data.
- Direct ownership of Blizzard protected action bars remains disabled by default pending explicit in-client combat and vehicle-state validation.

## Development and validation

Development rules, pinned Blizzard sources, API migration notes and secret-value guidance live in [wow-addon-engineering-kb](https://github.com/UnknownAlienHuman/wow-addon-engineering-kb).

The repository workflow validates the complete TOC/XML closure, exact Retail metadata, critical load order, exclusion of retired runtime scanners, the managed-aura boundary, every Lua file with Lua 5.1, whitespace, and merge markers.

Static and source validation do not prove combat safety. Before describing a release as runtime-verified, validate login/reload, target/focus/party/raid auras, healer aura-watch behavior, combat transitions, target changes, vehicles/override bars, Edit Mode and `/console taintLog 1` in the current Retail client.

Repository maps and historical notes are in [`AGENT_GUIDE.md`](AGENT_GUIDE.md), [`CURRENT_STATUS.md`](CURRENT_STATUS.md), [`MIDNIGHT_12_1_MIGRATION.md`](MIDNIGHT_12_1_MIGRATION.md), [`todo.md`](todo.md), [`history.md`](history.md), [`addon_map.md`](addon_map.md), and [`audit.md`](audit.md).

## License

The inherited Roth UI code in this repository is distributed under the MIT License; preserve the copyright and permission notice in [`LICENSE.txt`](LICENSE.txt).
