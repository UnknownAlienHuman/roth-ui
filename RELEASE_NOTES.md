# Roth UI 3.4.1

Follow-up safety, persistence and runtime-correctness release. The compatibility target remains Retail **12.1.5.70688**, TOC Interface **120105**, with external **oUF 14.1.1 or newer**. The source references remain those checked on **2026-11-02**: Blizzard UI source `d07eb00237d8891f153215db98a5df880a26cfe5` and oUF `8f37c36e3ed37d2fcfca2f3690f5e37e52b758c7`.

## Changes

- Tightened access-aware handling for unit tags, orb values, target classification, experience values, threat coloring and status text. Lua-side formatting and comparisons require readable ordinary values; supported opaque values stay on native display paths.
- Centralized serializable-number validation, including rejection of NaN and positive or negative infinity. Cleanup cuts cyclic references and commits its changes only after a successful root scan, preserving live table identities. Invalid nested writes and paths are rejected before changing persisted data or initializing missing roots.
- Made template persistence validate and normalize names in its owner. Reserved metadata names and names over 24 Unicode code points are rejected. Save selection changes only after successful persistence; unsuccessful save, load, delete, reset and root replacement preserve the existing canonical roots.
- Orb controls now display defaults from the default configuration while their getters continue to show the saved value, including explicit `false`. Delete/reset confirmation fails closed when the popup service is unavailable.
- Replaced six repeated resource-bar constructors with shared pip, decoration and container builders. Kept their geometry and textures; visibility changes run only when the pip maximum or vehicle state changes. Removed unused helper exports, aliases and native frames used only as namespaces.
- Kept focus, pet, party and raid threat dispatch under oUF's event lifecycle. Queued move-grid and portrait work checks that its owner is still visible. Health-value settings refresh once per frame; the unused immediate scheduler mode was removed.

## Installation and compatibility

Install a current Retail oUF separately. Extract the release ZIP so that the game sees `Interface/AddOns/Roth_UI/Roth_UI.toc`; the ZIP contains one `Roth_UI` directory. Keep existing SavedVariables. Open options with `/roth options` or the minimap button.

## Validation and limits

The current tree contains 75 addon Lua source files and 31 isolated regression scripts (106 Lua files total). All 106 files pass native `assert(loadfile(...))` syntax checks with Lua 5.1.1, all 31 isolated regressions pass, and all four repository validators pass. The standalone `luac5.1` compiler is unavailable. Two package builds are byte-identical and contain 283 runtime files.

Retail-client combat, taint, secure-action, visual and profiler acceptance remains **NOT-RUN**. No performance percentage or complete in-game compatibility certification is claimed. The prior 3.4.0 release established the 12.1.5 migration and package/runtime ownership changes; its source evidence remains in [MIGRATION_12_1_5.md](MIGRATION_12_1_5.md).
