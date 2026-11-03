# Current status — Roth UI 3.4.1

Evidence date: **2026-11-03**. Source and local test results are recorded separately from game-client acceptance.

## Selected target

| Component | Selected version / evidence |
| --- | --- |
| Addon | `3.4.1`, one `Roth_UI` package root |
| Retail source | `12.1.5.70688`, [Gethe/wow-ui-source at d07eb00237d8](https://github.com/Gethe/wow-ui-source/commit/d07eb00237d8891f153215db98a5df880a26cfe5) |
| TOC Interface | `120105`, derived from the selected patch family; client `GetBuildInfo()` not captured |
| External framework | oUF `14.1.1+`; reviewed [14.1.1 source](https://github.com/oUF-wow/oUF/tree/8f37c36e3ed37d2fcfca2f3690f5e37e52b758c7) |
| Knowledge base | [wow-addon-engineering-kb at b03e1635d0ff](https://github.com/UnknownAlienHuman/wow-addon-engineering-kb/tree/b03e1635d0ff8bcd6be4f4dfac589dafec4e5e83) |

## Implemented

- Safety queries reject inaccessible, missing, throwing or non-boolean results. Unit-value, experience, tag, orb and target-classification paths gate access before ordinary Lua operations; secret-capable presentation uses supported native sinks.
- Managed AuraContainer methods are checked when each container is created. Secure group headers remain session-owned; structural settings still require reload.
- `core/frame_policy.lua` owns the shared keyed post-combat queue. Settings, button skinning, artwork, portrait hit areas, fonts and movers use that owner.
- `core/deferred_scheduler.lua` schedules one next-frame callback per key and retains the newest requested callback. Idle first-party `OnUpdate` polling and repeated retry timers are absent.
- `core/font_policy.lua` owns Roth fonts and an optional explicit set of Blizzard FontObjects. Disabling the override restores the captured font unless another owner has changed it. Global font-path variables are not overwritten.
- `core/mover_runtime.lua` is the sole mover implementation. Bronze/gold handles, SHIFT-drag, safe drag completion and saved artwork/XP/reputation layout use the same implementation. The unloaded legacy mover library has been removed.
- Pet and small target layouts share `units/mini_target_scaffold.lua`; target background and glow geometry are corrected. Experience owns its rested overlay once, without a duplicate callback in the bar constructor.
- Settings opens its category once. Orb control defaults come from default data while getters show saved data, including explicit `false`; destructive controls fail closed when confirmation UI is missing.
- Template names are trimmed and validated by the persistence owner, reserved metadata names and names over 24 Unicode code points are rejected, and the selected name changes only after a successful save/delete. Failed template writes, loads, deletes and resets preserve the canonical roots.
- Public value getters return detached table values. Strict writes reject incomplete, inaccessible, cyclic, nonserializable and non-finite nested data before mutating persisted values; sparse/invalid paths are rejected without creating missing roots.
- Import keeps the `RUI1` format, checks encoded and decoded size limits, validates serializable input and rejects application during combat. Size checks after native decompression do not cap the decompressor's temporary allocation.
- Six resource-bar constructors share pip and decoration builders while keeping their original geometry and textures. Repeated maximum/vehicle states skip visibility changes. Unused helper exports, aliases and namespace-only native frames are removed. Focus/pet/party/raid rely on oUF event visibility behavior; deferred portrait/grid work checks visibility before running.
- Saved-data cleanup plans removals before applying them. A rejected root scan leaves all live tables untouched; successful cleanup preserves valid child identities and removes cycles, non-finite numbers and unsupported descendants.
- Eight unused or byte-identical media files were removed: **3,230,202 uncompressed bytes**. Referenced artwork and fonts remain in the package; packaging checks literal media references and compares every archived file with its source.
- Release filenames and the manual workflow derive their version from the TOC. The Lua runner discovers all regression files automatically.

## Local validation

| Gate | Result |
| --- | --- |
| Repository text policy | PASS |
| TOC/XML graph, ownership and Retail boundary checks | PASS; 76 expanded entries |
| Secure-header visibility and runtime hardening guards | PASS |
| Lua 5.1.1 syntax via native `assert(loadfile(...))` | PASS; 106 Lua files |
| Isolated Lua 5.1 regression scripts | PASS; 31 scripts |
| Lua compiler (`luac5.1`) | NOT-RUN; compiler unavailable in this environment |
| Workflow YAML structure and manual-trigger contract | PASS; workflow execution NOT-RUN |
| Deterministic runtime ZIP | PASS; two builds byte-identical, 283 files |

The regressions use isolated API stubs and secret-value sentinels. They exercise addon control flow and ownership; they do not emulate the client's secure execution engine. Package SHA256 and inventory accompany the built ZIP rather than being embedded in this file.

## Client acceptance — NOT-RUN

The environment has no Retail client. These results must be collected in the named client before claiming runtime certification or a measured performance improvement:

1. Record `GetBuildInfo()`, installed oUF version and enabled addons. Test login and `/reload` with fresh, migrated and malformed SavedVariables.
2. Test target/focus/boss casts, channels, empower, interruptibility, restricted health/power text and offline/dead/tapped states.
3. Test party/raid provider toggles, arena overrides, roster changes, click targeting/casting and structural settings after reload. Capture taint output.
4. Test managed auras and healer-watch coverage, action-bar paging, stance/vehicle/override/possess states and Edit Mode transitions.
5. Move and reset artwork, experience/reputation bars, units and alternate power; verify saved positions after refresh and reload, and entering combat during a drag.
6. Check fonts, orb effects, text fit and layering at representative resolutions/UI scales, including Cyrillic names. Enable/disable font overrides alongside another font addon.
7. Compare CPU and allocation measurements with `C_AddOnProfiler` under the same workload. No FPS/CPU percentage improvement is asserted by this update.

Historical `todo.md`, `todo.archive.md`, `audit.md`, `history.md`, `addon_map.md` and `MIDNIGHT_12_1_MIGRATION.md` remain historical evidence, are not current architecture authority, and are excluded from runtime packages. See [migration evidence](MIGRATION_12_1_5.md) and [release notes](RELEASE_NOTES.md).
