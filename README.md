# Roth UI

Diablo-inspired World of Warcraft UI built around the oUF framework. The addon provides custom unit frames, resource orbs, action-bar styling, movers, Blizzard-frame policies, and a settings/persistence layer.

## Preview

![Roth UI Community Edition in game](https://media.forgecdn.net/attachments/1569/226/screenshot-2026-03-07-072119-png.png)

Screenshot from the [CurseForge gallery](https://www.curseforge.com/wow/addons/roth-ui-community-edition).

## Compatibility

- Interface: `120001`, `120005`
- Version: `3.3.8-v57.8-B3.5`
- Author: Neomorph
- CurseForge reference: [Roth UI Community Edition](https://www.curseforge.com/wow/addons/roth-ui-community-edition)

## Installation

1. Install a compatible `oUF` release separately.
2. Copy the `Roth_UI` directory into `World of Warcraft/_retail_/Interface/AddOns/`.
3. Enable Roth UI and its required dependency in the character-selection AddOns list.
4. Use the in-game Roth settings and `/roth` commands after login.

The repository contains embedded support libraries (LibStub, CallbackHandler, LibActionButton-GE, LibSharedMedia and LibKeyBound). The TOC also declares optional `RothFont` and `RothLib`; verify those addon names in the target installation before enabling optional integrations.

## Development status

The current tree contains a substantial ownership and persistence refactor. Static history records many completed combat-safety, action-bar, registry, aura-watch and castbar changes. The remaining work is primarily runtime validation and further consolidation of persistence/legacy paths; see [`todo.md`](todo.md), [`history.md`](history.md), [`addon_map.md`](addon_map.md), and [`audit.md`](audit.md).

## License

The inherited Roth UI code in this repository is distributed under the MIT License; preserve the copyright and permission notice in [`LICENSE.txt`](LICENSE.txt).
