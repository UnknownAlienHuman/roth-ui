# Roth UI dependency and event graph — 3.4.1

## Critical load dependencies

The TOC is the executable load order. This table identifies dependencies checked by the static validator or asserted by the consuming module.

| Consumer | Must already be loaded | Purpose |
| --- | --- | --- |
| Frame policy and oUF contract | `init.lua`, safety and forbidden-aspect owners | Access gates and shared combat work |
| Custom oUF elements | oUF dependency contract | Register Experience, Reputation and target border elements |
| Persistence facade and value store | Defaults, configuration owner and canonical root store | One SavedVariables write boundary |
| Settings and runtime services | Persistence, frame policy and deferred scheduler | Configuration access and coalesced refreshes |
| Movers | Frame registry and shared helpers | One handle/layout owner |
| Unit styles | Value/aura/cast helpers and `mini_target_scaffold.lua` | Shared construction without duplicate runtime owners |
| Action skin and artwork | Unit styles, mover runtime and frame policy | Additive Blizzard-button presentation and retained user layouts |

## Bounded event paths

| Request | Authoritative path | Completion |
| --- | --- | --- |
| Combat-sensitive mutation | Keyed `framePolicy.DeferUntilOutOfCombat` callback | Drain outside combat; remove the shared listener |
| Next-frame layout refresh | Keyed `defer.RunNextFrame` callback | Latest callback runs once; pending entry is removed before invocation |
| XP/reputation data change | Custom oUF element callback | Update values/visibility; request artwork only on visibility transition |
| Structural party/raid setting | Persistence and group structure contract | Mark reload required; retain existing secure headers |
| Settings entry | Lazy category/page owner | Register and build each category once |
| Font preference change | Shared settings refresh and font policy | Update changed fonts or restore still-owned overrides |
| Artwork refresh | Configured default geometry followed by mover overrides | Preserve artwork and XP/reputation saved point, scale and size |

Blizzard retains action-button state and native widget behavior; external oUF retains unit/secure-header lifecycle and element dispatch. Roth UI owns its artwork, configuration and bounded presentation work. Tests, documentation and build tools are excluded from runtime packages.
