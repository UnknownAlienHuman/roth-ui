# Retail 12.1.5 migration evidence — Roth UI 3.4.0

Checked on **2026-11-04**. This record supersedes the historical [12.1.0 migration record](MIDNIGHT_12_1_MIGRATION.md) for current development.

## Source selection

- Knowledge base: [`UnknownAlienHuman/wow-addon-engineering-kb@c2a630aa186de401262663cc8568a77988be69df`](https://github.com/UnknownAlienHuman/wow-addon-engineering-kb/tree/c2a630aa186de401262663cc8568a77988be69df), including the selected 12.1.5 overlay and post-release continuity record.
- Blizzard source: [`Gethe/wow-ui-source@d07eb00237d8891f153215db98a5df880a26cfe5`](https://github.com/Gethe/wow-ui-source/tree/d07eb00237d8891f153215db98a5df880a26cfe5). Its [`version.txt`](https://github.com/Gethe/wow-ui-source/blob/d07eb00237d8891f153215db98a5df880a26cfe5/version.txt) identifies `12.1.5.70688`.
- TOC Interface: `120105`, selected for the 12.1.5 patch family. This is not an observed `GetBuildInfo()` result from this environment.
- oUF: latest release tag observed during this review was `14.2.1`, resolving to [`c5ff6e4a09bfaf2186e205777e0fab964b5cddc1`](https://github.com/oUF-wow/oUF/tree/c5ff6e4a09bfaf2186e205777e0fab964b5cddc1). It remains an external dependency. Its MIT license and repository policy were reviewed before implementation reference use.

## Reviewed contracts and resulting changes

| Contract | Pinned evidence | Roth UI decision |
| --- | --- | --- |
| ScriptObject access and forbidden state | [SimpleFrameScriptObject API](https://github.com/Gethe/wow-ui-source/blob/d07eb00237d8891f153215db98a5df880a26cfe5/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameScriptObjectAPIDocumentation.lua) | Central safety owner; query results must be accessible booleans. Unknown or failed queries prevent mutations. |
| FontObject mutation | [SimpleFont API](https://github.com/Gethe/wow-ui-source/blob/d07eb00237d8891f153215db98a5df880a26cfe5/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontAPIDocumentation.lua) | Guard object access, use the ordinary font tuple, skip unchanged writes and restore only Roth-owned changes. No invented font-specific forbidden aspect. |
| Operation-specific restrictions | [ForbiddenAspect constants](https://github.com/Gethe/wow-ui-source/blob/d07eb00237d8891f153215db98a5df880a26cfe5/Interface/AddOns/Blizzard_APIDocumentationGenerated/ForbiddenAspectConstantsDocumentation.lua) | Keep operation checks in `core/safety_aspects.lua`; do not treat a failed query as permission. |
| Player XP event payload | [Unit API/events](https://github.com/Gethe/wow-ui-source/blob/d07eb00237d8891f153215db98a5df880a26cfe5/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua) and [oUF events](https://github.com/oUF-wow/oUF/blob/c5ff6e4a09bfaf2186e205777e0fab964b5cddc1/events.lua) | `PLAYER_XP_UPDATE` carries `unitTarget`. Register through oUF's general event path and filter that payload explicitly; do not apply a unit filter to world-entry/level payloads. |
| Element refresh callbacks | [oUF health](https://github.com/oUF-wow/oUF/blob/c5ff6e4a09bfaf2186e205777e0fab964b5cddc1/elements/health.lua), [oUF power](https://github.com/oUF-wow/oUF/blob/c5ff6e4a09bfaf2186e205777e0fab964b5cddc1/elements/power.lua) | `ForceUpdate` already reaches the element's `PostUpdate`; invoke a manual fallback only when `ForceUpdate` is absent. |
| Managed auras | [AuraContainer implementation](https://github.com/Gethe/wow-ui-source/tree/d07eb00237d8891f153215db98a5df880a26cfe5/Interface/AddOns/Blizzard_AuraContainer) | Retain the managed-container design, validate public methods on construction and gate filter/layout mutations. No raw aura scanning or redundant event owner. |
| Settings | [Blizzard Settings implementation guide](https://github.com/Gethe/wow-ui-source/blob/d07eb00237d8891f153215db98a5df880a26cfe5/Interface/AddOns/Blizzard_Settings_Shared/Blizzard_ImplementationReadme.lua) | Retain lazy registration, invoke category opening once and route combat-sensitive refresh through the common queue. |

The selected patch does not require replacing every already-valid API. This update changes the concrete ownership, validation and callback defects found in the loaded addon graph while retaining native status-bar interpolation, Blizzard action ownership and session-owned secure group headers.

## Persistence compatibility

`Roth_UI_DB`, `Roth_UI_DB_Char`, per-character mover data and the `RUI1` transfer prefix are retained. Public value getters copy table results; the internal live configuration/default accessors remain live for runtime consumers. Strict writes reject inaccessible values, unsupported keys/types, cycles and excessive nesting without partially replacing valid configuration. An explicit saved `false` stays false even when its default is true.

Import rejects encoded text above 2 MiB and compressed or decompressed serialized payloads above 4 MiB before the next processing stage. The post-decompression check cannot prevent the native decompressor's temporary allocation. Applying transfer roots in combat is rejected, so an import cannot unexpectedly apply after combat ends.

## Acceptance boundary

See [CURRENT_STATUS.md](CURRENT_STATUS.md) for executed local gates and the client matrix. Stub-based Lua tests establish addon-side behavior; they do not prove secure execution, taint freedom, visual fit or CPU savings in Retail. Those claims remain **NOT-RUN** until recorded against a named client build.

## 3.4.2 loading correction — 2026-11-03

Roth initializes configuration and constructs unit frames during TOC file execution. Without `LoadSavedVariablesFirst`, replacing the initial config root at `ADDON_LOADED` left already-captured unit configuration views bound to defaults. A local integration reproduction using the actual persistence modules demonstrated this stale-reference path.

The TOC now opts into `LoadSavedVariablesFirst: 1`, and the static validator requires it. Selected primary evidence: [Blizzard Damage Meter TOC](https://github.com/Gethe/wow-ui-source/blob/d07eb00237d8891f153215db98a5df880a26cfe5/Interface/AddOns/Blizzard_DamageMeter/Blizzard_DamageMeter.toc). The [KB persistence guide](https://github.com/UnknownAlienHuman/wow-addon-engineering-kb/blob/c2a630aa186de401262663cc8568a77988be69df/KB/addon/Addon_SavedVariables.md) documents the own-SavedVariables boundary and its limits. This opt-in does not establish player, world, dependency or protected-action readiness. Named-client third-party loading verification remains NOT-RUN.

## Post-selected 70783 review — 2026-11-04

`Gethe/wow-ui-source@297d7aaaa736f346b3e036f38ee088eaf7f8c07f` identifies `12.1.5.70783`. The reviewed delta adds Battle.net `subIcon` metadata, title-icon parameters, a Roleset combat restriction and marks `UNIT_COMBAT.amount` secret. Roth UI consumes none of those surfaces, so the KB-selected compatibility pin remains `12.1.5.70688`; named-client acceptance is still `NOT-RUN`.
