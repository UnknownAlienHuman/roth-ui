# Roth UI 3.4.0

Retail 12.1.5 source update and runtime ownership cleanup. Selected Blizzard source: **12.1.5.70688**, TOC Interface **120105**. Requires external **oUF 14.1.1 or newer**.

## Changes

- Unified post-combat work and next-frame scheduling. Removed duplicate event queues, redundant orb/XP updates and repeated font refreshes.
- Removed the unused legacy mover library. All movers use the same constructor and bronze/gold handles, with SHIFT-drag, combat guards and saved-layout restoration.
- Consolidated pet and small target frame construction. Corrected target health background/glow geometry and removed a stale raid-anchor reference to a nonexistent texture.
- Reworked the font owner: optional Blizzard FontObject changes are reversible, unchanged fonts are skipped and global font-path variables are preserved.
- Hardened access and forbidden-aspect guards. Managed-aura capabilities are checked when containers are created; health/power presentation avoids ordinary Lua operations on inaccessible values.
- Corrected Settings category opening, detached public table getters, preservation of saved `false` values, strict write validation and combat rejection for imported configuration.
- Preserved the `RUI1` transfer format and existing SavedVariables roots. Added transfer size checks and explicit rejection of unsupported serialized values.
- Removed eight unused/duplicate media files, saving 3.08 MiB before compression. Kept the Diablo-inspired artwork and available font choices.
- Added an automatically discovered Lua regression runner and stronger deterministic package verification. The manual GitHub workflow reads its release version from the TOC.

## Installation

Install a current Retail oUF separately. Extract the release ZIP so that the game sees `Interface/AddOns/Roth_UI/Roth_UI.toc`; the ZIP contains one `Roth_UI` directory. Replace the old addon directory to remove retired files. Keep your SavedVariables; this update does not require a settings reset. Open options with `/roth options` or the minimap button.

## Validation and limits

Local repository validators, Lua 5.1 syntax checks and 22 isolated regression scripts pass. Two runtime package builds are byte-identical. The package includes only the loaded addon graph, retained media and attribution/license files.

Retail-client combat, taint, secure-action, visual and profiler acceptance is **NOT-RUN** in this environment. No performance percentage or complete in-game compatibility certification is claimed. See [CURRENT_STATUS.md](CURRENT_STATUS.md) for the exact validation boundary and [MIGRATION_12_1_5.md](MIGRATION_12_1_5.md) for pinned API evidence.
