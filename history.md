# Roth_UI history

Дата аудита: 2026-03-14
Источник: полный `todo.md` из архива + текущий код аддона.

Этот файл хранит то, что уже **сделано и подтверждено статически**. Полный исходный todo сохранён в `todo.archive.md`.

## Главное

Текущий большой pass от 2026-03-13 в целом **реально приземлён в коде**. Это не бумажный рефактор: в аддоне действительно появились новые сервисы, reversible policy для Blizzard frame paths, вынесенный action-bar runtime, registry/runtime ownership и deferred orchestration.

## Update 2026-03-17

- `core/extrabar_holder.lua` теперь реально следует shared Blizzard `ExtraAbilityContainer`, а не считает `ExtraActionBarFrame` primary visibility/layout owner. Это закрывает самый явный остаточный drift в thin-wrapper path для `ExtraAction` / `ZoneAbility`.
- Secure main bar получил один coherent visibility/layout contract: `bar1` регистрируется с `MAIN_BAR_VISIBILITY_DRIVER` в registry и держит собственный horizontal size/layout path, так что общий runtime visibility refresh больше не может вернуть его к старому `hide on override/vehicle/possess` поведению.
- Group aura state теперь привязан к identity юнита (`UnitGUID`), а не только к самому frame object: dispel-color cache и safe `AuraWatch` сбрасывают tracked/init state при unit switch, а queued incremental payload не доезжает от старого юнита к новому reused frame.
- Slash/settings/debug control plane дальше сжат к owner services: `/roth` теперь строит dispatch и help из одного command registry, Settings reload идёт через `ns.persistence`, а Blizzard restore/status route проходят через `ns.groupFrameService`, а не через ранний capture плоского `ns.func` surface.
- `core/frame_registry.lua` и `core/mover_runtime.lua` получили большой object-first refactor: `ns.registry.art|bars|units|orbs` теперь публикует canonical category lists, registry умеет апгрейдить seeded string entries до actual frame objects, а mover registration больше не стартует из post-factum name guessing как единственного owner path.
- `embeds/rLib/dragframe.lua` больше не плодит duplicate frame ownership в legacy lists: `CreateDragFrame` / `CreateDragResizeFrame` dedupe-ят compat arrays и сразу регистрируют frame через canonical mover service, так что новый mover surface и старый `/rabs`/snap path смотрят на один и тот же набор frame objects.
- Legacy action-bar mover writers сведены к одному compat bridge: `bar2-5`, `leave_vehicle`, `micromenu`, `petbar`, `stancebar` используют `moverRuntime.AttachLegacyDragFrame(...)`, а object writers в `boss/party/raid/castbar` paths тоже регистрируют сами frames, а не только их global names.
- Registry boundary дальше сужен уже на consumer-слое: `core/frame_registry.lua` теперь даёт explicit `ResolveFrame()` / `GetCategory()` / `ForEachEntry()`, поэтому `core/action_bar_background.lua` и `core/mover_runtime.lua` больше не держат собственные name-driven lookup loops поверх registry.
- Reset/reload owner path ещё сильнее поджат к service boundary: `core/lib.lua` больше не держит backup reset path мимо `ns.settingsActions`, а `core/transfer.lua` после import использует `ns.persistence.ReloadUI()` вместо прямого `ReloadUI()` call-site.
- `/roth` help теперь группирует команды по ролям (`Settings`, `Diagnostics`, `Movers`), так что slash surface яснее отражает user-vs-debug boundary и не смешивает owner intent только в одном плоском списке help strings.

## Подтверждённо сделано

### 1. Combat-lockdown фиксы для layout-path

- Micromenu layout теперь откладывает защищённые изменения до `PLAYER_REGEN_ENABLED`; hooks на `UpdateMicroButton` и `UpdateMicroButtons` больше не пишут layout прямо в combat (`core/micromenu_bar.lua:156-160`, `209-249`).
- Stance bar width refresh тоже переведён на post-combat path (`core/stance_bar.lua:65-92`, `109-143`).
- Bags bar перестал напрямую перестраивать wrapper и anchor-связи в combat; layout side effects откладываются и потом безопасно воспроизводятся (`core/bags_bar.lua:55-103`).

### 2. Убран необратимый kill path у default castbar'ов Blizzard

- Player castbar больше не убивается через `UnregisterAllEvents()` / `Show = Hide`; policy теперь сидит на post-hook `UpdateShownState` и работает как visual-only слой (`core/unit_policy.lua:33-55`).
- Unit policy переапплаится и после загрузки Blizzard unit/UI addons, чтобы не зависеть от load order (`core/frame_policy_bootstrap.lua:25-35`).
- Pet castbar тоже переведён на reversible path через `SetAndUpdateShowCastbar(false)` с простым `Hide()` только как fallback (`units/pet.lua:164-174`).

### 3. Default BuffFrame / aura styling реально отрезан от legacy runtime

- В `rButtonTemplate` выключен default Blizzard aura styling path.
- Legacy entrypoints `StyleBuffButtons`, `StyleDebuffButtons`, `StyleTempEnchants`, `StyleAllAuraButtons` больше не используются как owner-path для default BuffFrame (`modules/Roth_UI_rButtonTemplate/core.lua:442-510`).

### 4. Action-bar ownership уже сильно вытащен из legacy embedded stack

- `Roth_UI.toc` теперь грузит `core/action_bar_*` runtime напрямую (`Roth_UI.toc:83-91`).
- В embedded `modules/Roth_UI_rActionBarStyler` больше не лежат старые `bar1/bar2/bar3/bar4/bar5/dock/background/extrabar` владельцы; там остались только residual helper-модули (`modules/Roth_UI_rActionBarStyler/*`).
- `core/bar_runtime_registry.lua` стал реальным owner/service слоем для layout/shell/dock контрактов (`core/bar_runtime_registry.lua:19`, `259-306`).

### 5. Registry ownership вынесен в namespace-owned сервисы

- `core/frame_registry.lua` теперь даёт canonical `ForEachFrame(...)` и держит legacy globals только как compatibility mirror (`core/frame_registry.lua:16-17`, `81`, `164`).
- Action-bar runtime тоже завязан на owner registry/service, а не на россыпь optional fallback'ов (`core/bar_runtime_registry.lua:19`, `259-306`).

### 6. ExtraAction / ZoneAbility переведены на holder/follower модель

- Extra stack больше не должен владеть Blizzard container как «своим» баром.
- Holder следует за `ExtraAbilityContainer` / `ZoneAbilityFrame` и не перехватывает secure lifecycle напрямую (`core/extrabar_holder.lua:49`, `71-150`).

### 7. Group/frame policy стек реально разрезан

- Вынесен `core/group_header_visibility.lua` как отдельный helper-service для visibility driver / hidden parent park path (`core/group_header_visibility.lua:7-79`).
- Вынесены отдельные слои `core/font_policy.lua`, `core/group_policy.lua`, `core/unit_policy.lua`, `core/frame_policy_bootstrap.lua`, `core/blizzard_restore_debug.lua`.
- Shared post-combat deferral и player-character resolution теперь централизованы в `core/frame_policy.lua`, а `group_policy.lua`, `unit_policy.lua` и `blizzard_restore_debug.lua` больше не держат свои почти одинаковые regen-hook / `UnitFullName("player")` scaffolds.
- `core/frame_policy.lua` перестал быть старым большим монолитом; он заметно уменьшился до shared/policy helper слоя.

### 8. Safe watcher и settings для group aura path появились

- Появился addon-owned safe `AuraWatch` путь через `AuraUtil.ForEachAura(... HELPFUL|PLAYER ...)` (`core/group_aura_watch.lua:7-8`).
- В settings уже есть party/raid aura-watch toggles и raid native aura icon toggles (`core/settings_groups.lua:192-194`, `264-289`).
- `core/unit_misc_runtime.lua` больше не full-scan'ит harmful auras на каждый `UNIT_AURA`: path держит tracked dispellable `auraInstanceID` cache, использует `updateInfo.addedAuras / updatedAuraInstanceIDs / removedAuraInstanceIDs` и оставляет полный scan только как full/force refresh fallback (`core/unit_misc_runtime.lua:139-608`).
- `/roth aurastats` снова backed runtime-реализацией: `ns.GetSimpleAuraStats()` / `ns.ResetSimpleAuraStats()` теперь публикуют ingress/queue/full-vs-incremental counters для live smoke и профилировки (`core/unit_misc_runtime.lua:191-198`, `units/party.lua:271-276`, `units/raid.lua:613-617`).

### 9. Появился единый deferred scheduler

- `core/deferred_scheduler.lua` теперь централизует отложенный orchestration вместо россыпи локальных `C_Timer.After(...)` на normal path (`core/deferred_scheduler.lua:27-37`).

### 10. Target / mini castbar runtime серьёзно переписан

- `core/target_castbar.lua` уже держит cast identity, separate fail/interrupted visual state и post-state sync (`core/target_castbar.lua:247-675`).
- `targettarget` переведён на standalone castbar path (`units/targettarget.lua:158-163`, `core/lib.lua:1278-1366`).

### 11. Persistence control plane уже частично централизован

- `sv_store.lua` публикует owner-level transfer/reset/rebuild API (`core/sv_store.lua:1412-1475`).
- `config.lua` и init/bootstrap уже опираются на owner service сильнее, чем раньше (`config.lua:931-1000`, `1411`).
- Это ещё **не финал**, но переход уже реально произошёл.

### 12. Legacy kill/override path у default `RuneFrame` убран

- `oUF/elements/rune_orbs.lua` больше не делает `_G.RuneFrame.Show = _G.RuneFrame.Hide` и не занимается ручным restore через `Show = nil`.
- Ownership дефолтного DK rune frame перенесён в `core/unit_policy.lua`: hide path теперь visual-only, сидит на post-hook'ах `PlayerFrame_UpdateArt` и `RuneFrame:Show()`, а restore идёт через Blizzard art refresh вместо ad-hoc `Show()`.

### 13. Slash/settings control plane и persistence mirrors дочищены

- `/roth options`, `/roth config` и `/roth resettemplates` теперь идут через `ns.settingsActions`, а `core/slashcmd.lua` больше не держит прямой legacy fallback на `ns.panel` и не вызывает `ns.db.resetTemplates` из normal path.
- `core/settings_orbs.lua` тоже делегирует reset template library в `ns.settingsActions`, поэтому UI и slash используют один entrypoint.
- compatibility wrappers `ns.OpenOptionsPanel` / `ns.OpenOrbsOptions` и embedded `ns.panel` bridge убраны: legacy bootstrap'ы больше не прокидывают мёртвую panel surface, а `units/player.lua` не держит orphan helper на уже несуществующий config panel.
- `core/bar_runtime_registry.lua` больше не использует internal `legacyFrameName` vocabulary: named-frame fallback теперь живёт под нейтральным `frameName`, а `EnsureDescriptor()` мигрирует старые descriptors без изменения runtime behavior.
- `core/frame_registry.lua` больше не экспортирует `_G.Roth_UI_Art` / `_G.Roth_UI_Bars` / `_G.Roth_UI_Units` / `_G.Roth_UI_Orbs`: mover/debug/runtime consumers уже сидят на canonical `ns.frameRegistry`, поэтому global mirror surface снят из normal path.
- compatibility mirrors `ns.cfgSaved`, `db.char` и `db.glob` убраны из runtime sync/reset path; canonical config/orb stores теперь читаются через owner services (`ns.persistence` / `ns.store`), а orb template UI оставляет только `db.list.template` как локальный cache списка.
- legacy persistence globals `Roth_UI_Config` / `Roth_UI_DB_CHAR` / `Roth_UI_DB_GLOB` удалены и из reset path в `core/sv_store.lua`: после migration cleanup они больше нигде не используются как runtime vocabulary.
- `config.lua` больше не публикует мёртвые wrappers `ns.GetConfigStore` / `ns.SetConfigStore` / `ns.GetConfigSchemaInfo` / `ns.GetConfigSchemaPolicy`: текущий код уже ходит напрямую через owner/service surfaces (`ns.configPersistence`, `ns.persistence`, `ns.store`), поэтому лишний public shim снят.
- `core/sv_store.lua` больше не держит lowercase/compat alias surface (`getConfig`, `setConfig`, `getOrbChar`, `getTemplates`, `getOrbConfig*`, `ConfigGet`, `ConfigSet`), а текущие consumers (`db.lua`, `debug_commands.lua`, `lib.lua`, `settings_*`, `orb_runtime.lua`) теперь требуют только canonical `ns.store` API.
- `core/sv_store.lua` больше не тянет orb schema/policy/reconcile через `ns.db` как service boundary: aggregate persistence-слой читает canonical descriptors и owner service `ns.orbPersistence` напрямую, без старых schema/reconcile bridge-paths.
- `core/db.lua` свернул внутренние char/global store wrappers в local helpers: `GetCharStore`, `SetCharStore`, `GetGlobalStore`, `SetGlobalStore`, `GetStores` больше не висят как лишний public DB surface и остаются чисто внутренним glue-слоем orb domain.

### 14. Persistence runtime/control-plane split пошёл дальше

- `core/persistence_runtime_state.lua` теперь отдельно владеет volatile runtime-state buckets, runtime-log storage и migration/purge для legacy `_debug/_log/_pendingReload/...` ключей.
- `core/persistence_control_plane.lua` теперь отдельно владеет public `ns.persistence` facade и lifecycle bootstrap (`ADDON_LOADED` / `PLAYER_LOGIN` / `PLAYER_LOGOUT`), поэтому `sv_store.lua` больше не смешивает low-level store/path API с control-plane orchestration.
- `core/persistence_control_plane.lua` теперь собирает свой facade от canonical `ns.store` / `ns.persistenceRuntime` exports, а не от россыпи `ns.GetPersistenceStores` / `ns.SVRebuildRuntime` / `ns.GetRuntime*` glue как primary owner path.
- `Roth_UI.toc` грузит эти новые слои вокруг `core/sv_store.lua`, а сам `core/sv_store.lua` сжат до `1029` строк и теперь заметно ближе к роли store facade, а не «всего persistence сразу».

### 15. Descriptor/schema/drift registry тоже вынесен из sv_store

- `core/persistence_schema_registry.lua` теперь отдельно владеет persistence descriptors, domain registry validation, schema catalog, drift policy/state, sanitize/reconcile orchestration и orb schema metadata exports для `ns.store`.
- `Roth_UI.toc` грузит этот модуль между `core/sv_store.lua` и `core/persistence_control_plane.lua`, поэтому low-level store/path слой поднимается раньше, а public control plane по-прежнему получает уже собранный schema/reconcile surface.
- `core/sv_store.lua` после этого сжат до `534` строк и остался в роли roots/path/value access слоя; главный persistence долг теперь больше сидит в `config.lua`, `core/db.lua` и новом `core/persistence_schema_registry.lua`, а не в одном смешанном файле.

### 16. Orb persistence owner вынесен из db.lua

- `core/orb_persistence_owner.lua` теперь отдельно владеет orb schema targets, schema patching, sanitize/reconcile pipeline и canonical `db:RunPersistencePipeline()` / `ns.orbPersistence.ReconcileStores()` orchestration.
- `core/db.lua` больше не держит у себя `GetOrbSchemaTargets`, `EnsureDB`, `SanitizeStores`, `ReconcileStores` и реализацию pipeline owner-path; этот файл снова ближе к defaults/template/list consumer слою.
- `Roth_UI.toc` грузит `core/orb_persistence_owner.lua` сразу после `core/db.lua`, а сам `core/db.lua` после extraction сжат до `731` строк.

### 17. Config persistence owner вынесен из config.lua

- `core/config_persistence_owner.lua` теперь отдельно владеет canonical config reconcile path, schema patching, runtime-only proxy fields, read-only unit config views и persistence metadata exports для `ns.configPersistence`.
- `config.lua` снова держит только defaults/schema definition и в конце лишь передаёт собранный defaults table в `configOwner.InitializeConfigDefaults(cfg)` вместо того, чтобы самому быть owner service.
- `core/sv_store.lua` больше не лезет в скрытый `ns._AttachCfgProxy`: config cache resync теперь идёт через canonical `ns.configPersistence.AttachCfgProxy`, а descriptor fallback в `core/persistence_schema_registry.lua` тоже указывает на реальный owner file.

### 18. Orb template lifecycle и consumer API дальше вытащены из db.lua

- `core/orb_persistence_owner.lua` теперь держит не только schema/reconcile, но и `ADDON_LOADED` bootstrap для orb/template stores, reset flag path, reset-to-default flow и template `load/save/delete` CRUD через `ns.orbPersistence`.
- `core/db.lua` больше не держит `ADDON_LOADED` handler, template reset path, template CRUD и legacy orb load/reset control plane; файл снова остаётся каталогом defaults/template presets и option lists.
- `core/settings_orbs.lua`, `core/settings_actions.lua`, `core/orb_runtime.lua`, `units/player.lua` и orb sanitize path в `core/persistence_schema_registry.lua` теперь идут напрямую через `ns.orbPersistence`; временные `db.load*` / `db.save*` aliases и `db.list.template` cache сняты из normal path.
- `core/persistence_schema_registry.lua` больше не репортит orb-owner fallback как `core/db.lua`: descriptor/schema/drift metadata теперь по умолчанию указывают на `core/orb_persistence_owner.lua`.

### 19. Canonical root/domain access вынесен из sv_store

- `core/persistence_root_store.lua` теперь отдельно владеет canonical account/char roots, domain root access и replace/reset flows для `ns.store`.
- `Roth_UI.toc` грузит этот слой между `core/persistence_runtime_state.lua` и `core/sv_store.lua`, поэтому path/value facade поднимается уже поверх готового root owner.
- `core/sv_store.lua` после extraction снова держит только path/value helpers, orb compat read/write path и runtime save counters, без root normalize/reset ownership.

### 20. Owner-specific persistence metadata bridges поджаты

- `core/persistence_schema_registry.lua` больше не публикует owner-specific metadata helpers (`GetConfigDescriptor`, `GetOrbDescriptor`, `GetOrbSchemaInfo`, `GetOrbSchemaPolicy`, `GetOrbPersistenceInfo`) через `ns.store`; наружу оставлен только aggregate `GetPersistenceDescriptors()`.
- `core/persistence_control_plane.lua` теперь строит storage labels от aggregate descriptors, а не от пары отдельных store bridges.
- orb metadata больше не собирается как hidden bridge внутри aggregate слоя: owner сам держит schema targets/info/policy vocabulary, а registry/drift слой читает этот contract через `ns.orbPersistence`.

### 21. Drift/reconcile orchestration вынесен из schema registry

- `core/persistence_reconcile_service.lua` теперь отдельно владеет drift policy/state, sanitize path и reconcile orchestration вместо того, чтобы держать этот хвост внутри `core/persistence_schema_registry.lua`.
- `Roth_UI.toc` грузит reconcile service сразу после `core/persistence_schema_registry.lua`, поэтому `persistence_control_plane.lua` по-прежнему получает уже собранные `storeApi.SanitizeStores` / `storeApi.ReconcileStores`.
- `core/persistence_schema_registry.lua` после split снова держит только descriptors, domain registry и schema info/catalog слой, без drift/sanitize/reconcile tail.

### 22. Frame-policy recovery vocabulary поджата

- `core/frame_policy.lua` теперь публикует отдельный `framePolicy.groupFrames` service для Blizzard group-frame recovery helpers вместо того, чтобы держать этот набор только плоским списком на корневом policy surface.
- `core/group_policy.lua` и `core/blizzard_restore_debug.lua` теперь читают group-frame restore helpers из `framePolicy.groupFrames`, а не тянут каждый helper по отдельности из общего `framePolicy` namespace.
- Runtime behavior не менялся: это structural cleanup ради более ясной service/recovery vocabulary в frame-policy stack.

### 23. Orb schema ownership доведён до owner service

- `core/orb_persistence_owner.lua` теперь сам публикует `GetPersistenceInfo()`, `GetSchemaInfo()` и `GetSchemaPolicy()`, так что orb owner больше не зависит от aggregate `ns.GetPersistenceSchemaInfo()` ради собственного reconcile return-path.
- `core/persistence_schema_registry.lua` теперь поднимает orb descriptor/schema info/policy через `ns.orbPersistence` и держит только defensive fallback, а не primary metadata assembly на `_orbDbOwner`/`GetOrbSchemaTargets`.
- `core/persistence_reconcile_service.lua` больше не строит orb drift policy от отдельного schema-target bridge; drift layer читает owner policy через registry surface и не тянет убранный `storeApi.GetOrbSchemaTargets`.

### 24. Orb reconcile compat bridge снят из aggregate registry path

- `core/persistence_schema_registry.lua` больше не пробрасывает orb reconcile через `storeApi.ReconcileOrbStores`; aggregate registry теперь признаёт owner-only path и зовёт только `ns.orbPersistence.ReconcileStores()`.
- `core/orb_persistence_owner.lua` больше не экспортирует `storeApi.ReconcileOrbStores`, так что bridge-path не остаётся живым в normal runtime только «на всякий случай».
- Это уменьшает persistence surface и делает текущий backlog честнее: в `todo.md` для persistence остаётся vocabulary/report cleanup, а не старый reconcile bridge.

### 25. Aggregate schema/drift/doctor vocabulary поджат до одного node map

- `core/persistence_schema_registry.lua` теперь публикует canonical `GetPersistenceSchemaNodeKeys()` и `GetPersistenceSchemaCatalog(info)`, так что aggregate слой имеет один стабильный порядок и один сборщик schema nodes вместо локальных копий в каждом consumer'е.
- `core/persistence_reconcile_service.lua` теперь строит drift-state по этому же node vocabulary, а не по своей ручной таблице `config/orbChar/orbGlobal`.
- `core/sv_doctor.lua` теперь собирает schema report через canonical `report.nodes[key]` map, оставляя flat aliases только как compat surface; report больше не расходится с drift-state по per-node `drift`, когда effective target patch приходит из policy mismatch.

### 26. Control-plane scan/label contract подтянут к тому же node vocabulary

- `core/persistence_control_plane.lua` теперь публикует `GetScanStores()` и `GetStorageLabels()` как canonical `nodes` map с flat aliases только как compatibility wrapper, вместо двух полностью отдельных flat payloads.
- `core/sv_doctor.lua` теперь сканирует persistence stores generic loop'ом по `GetPersistenceSchemaNodeKeys()`, так что diagnostic scan path больше не держит свой ручной `config/orbChar/orbGlobal` branching.
- В результате static debt в persistence сузился до решения про сам compat surface (`nodes` only vs `nodes + flat aliases`), а не до очередного дублирования словаря между control plane и doctor.

### 27. Internal diagnostics больше не зависят от flat compat aliases

- `core/sv_doctor.lua` теперь и в `SVDoctorScan()`, и в `SVTestReport()` читает scan stores/labels через canonical node map helper, а не через `stores.config` / `labels.config` как primary path.
- После этого flat aliases в persistence diagnostics остались только на public boundary `persistenceApi.GetScanStores()` / `GetStorageLabels()` и больше не нужны внутренним consumer'ам аддона.

### 28. Public persistence diagnostics тоже сведены к одному node contract

- `core/persistence_control_plane.lua` больше не дублирует `config` / `orbChar` / `orbGlobal` рядом с `nodes`: `GetScanStores()` и `GetStorageLabels()` теперь отдают только canonical `nodes` payload.
- `core/sv_doctor.lua` больше не держит fallback на flat scan payload и не публикует schema report entry сразу в двух видах (`report.nodes[key]` и `report[key]`); diagnostic boundary теперь реально живёт на одном node vocabulary.
- Это закрывает последний чисто статический compat shim в persistence diagnostics: дальше в этом слое остаётся уже не vocabulary cleanup, а только live smoke и более крупный structural split.

### 29. Descriptor/domain registry слой вынесен из schema registry

- Новый `core/persistence_domain_registry.lua` теперь отдельно владеет persistence descriptors, domain registry validation и canonical `GetPersistenceStores()` map.
- `core/persistence_schema_registry.lua` после этого снова держит только schema node keys, schema catalog и `GetPersistenceSchemaInfo()/GetPersistenceSchemaCatalog(...)`, не смешивая их с registry/reconcile wiring.
- Load order обновлён в `Roth_UI.toc`, так что schema registry поднимается уже поверх готового registry service, а aggregate persistence слой стал заметно уже по ответственности.

### 30. Drift policy/state вынесены из reconcile service

- Новый `core/persistence_drift_service.lua` теперь отдельно владеет `GetPersistenceDriftPolicy()`, `GetPersistenceDriftState()` и `IsPersistenceDriftAccepted(...)`, а также canonical drift-node builder'ом.
- `core/persistence_reconcile_service.lua` после этого снова держит только sanitize/reconcile orchestration и использует drift-layer как dependency вместо локального policy/state конструктора.
- Load order в `Roth_UI.toc` обновлён так, что reconcile service поднимается уже поверх готовых schema и drift services.

### 31. Persistence report слой вынесен из SV doctor

- Новый `core/persistence_report_service.lua` теперь отдельно владеет schema/drift report builder'ом и печатью `PersistenceSchemaReport(...)`.
- `core/sv_doctor.lua` после этого снова держит только SavedVariables scan/store/test path и использует report-layer как dependency, вместо смешивания scan logic с schema/drift reporting.
- После этого статический persistence stack в `Roth_UI` уже разложен на root/domain/schema/drift/reconcile/report/control-plane слои; дальше основной незакрытый хвост в этом блоке — live smoke, а не очередной очевидный ownership split.

### 32. Blizzard party restore path снова стал реальным, а не фиктивным

- `core/frame_policy.lua` больше не держит пустой `ReapplyBlizzardPartyFrames()`: path теперь реально поднимает Blizzard party stack через штатные `PartyFrame`/`CompactPartyFrame` update entrypoints, при необходимости генерирует `CompactPartyFrame` и refresh'ит members/layout.
- Там же исправлен `IsAddOnEnabled(...)`: char-specific `GetAddOnEnableState` теперь реально может вернуть `false`, так что group-policy restore path снова видит отключённые Blizzard addons вместо always-true результата.
- `core/group_policy.lua` и `core/blizzard_restore_debug.lua` больше не возвращают `CompactPartyFrame` под `UIParent` как normal parent. Compact party container снова привязывается к `PartyFrame`, как и в Blizzard lifecycle.
- Show/restore helpers больше не пробивают Blizzard `CompactPartyFrame:ShouldShow()` своим безусловным `Show()` / `ForceShow()`: compact party path теперь остаётся скрытым, когда Edit Mode настроен на обычные party frames.

### 33. Action-bar registry теперь считает effective visibility, а не wrapper illusion

- `core/bar_runtime_registry.lua` теперь умеет читать `descriptor.visibilityFrame`, поэтому `GetVisibleAuxRowCount()` и `GetBottomClusterLayout()` больше не считают aux bars видимыми только потому, что outer wrapper показан, пока secure holder уже скрыт state driver'ом.
- `core/action_bar_bar2.lua`, `core/action_bar_bar3.lua`, `core/action_bar_bar4.lua` и `core/action_bar_bar5.lua` теперь регистрируют свои inner secure holders как canonical `visibilityFrame`.
- Это поджимает backlog по action-bar ownership boundary: artwork/dock/runtime listeners теперь видят effective visibility shell'ов ближе к реальному Blizzard state, а не к wrapper-only proxy состоянию.

### 34. Mover/layout cluster вынесен из `core/lib.lua`

- Новый `core/mover_runtime.lua` теперь отдельно держит mover persistence, tooltip/mousewheel logic и drag/runtime exports (`ns.SaveMoverLayout`, `func.applyDragFunctionality`, `func.SetMoverUnlocked`, `func.ResetMoverLayout`, `func.simpleDragFunc`).
- `Roth_UI.toc` грузит этот слой сразу после `core/lib.lua`, так что текущие consumers сохраняют тот же public contract без сдвига runtime boundary.

### 35. Shared castbar runtime и aux-bar visibility metadata восстановлены

- `core/target_castbar.lua` снова существует как реальный shared runtime: `ns.TargetCastbarRuntime` больше не пропадает из load order из-за zero-byte файла, а `units/target.lua`, `units/focus.lua` и `units/boss.lua` опять получают один identity-safe contract для interrupt/fail/channel visual state.
- Aux-bar descriptors теперь публикуют `role = "aux"` и явный `visibilityFrame` как в wrapper fallback path (`core/action_bar_bar2.lua`, `core/action_bar_bar3.lua`, `core/action_bar_bar4.lua`, `core/action_bar_bar5.lua`), так и в `secureOwnerBars` path (`core/action_bar_secure_runtime.lua`).
- Это убирает ложный runtime picture для `BarRuntimeRegistry`: shell width, artwork tier и visible aux-row counting теперь читают effective visibility owner сразу после register, а не только после позднего `ApplyVisibilityDriver(...)`/state-driver refresh.

### 36. Mover settings/debug path теперь идёт через один runtime service

- `core/mover_runtime.lua` теперь экспортирует явные runtime methods (`SetUnlocked`, `ResetLayout`, `SaveLayout`, `ClearLayout`, `ApplySavedLayout`) поверх уже существующего mover owner logic.
- `core/settings_actions.lua`, `core/settings_general.lua` и `core/debug_commands.lua` больше не дублируют mover traversal/drag-handle/reset behavior через `frameRegistry`, `_G.rLib.activeDragFrames` и raw `frame.dragframe` fallback path.
- Root cause здесь был не в самих mover frame-ах, а в том, что control planes жили на нескольких несовместимых contracts в зависимости от порядка загрузки; теперь unlock/lock/reset и Settings-driven `framesLocked` идут через один `ns.moverRuntime` surface.

### 37. Legacy AuraWatch contract снят из normal path

- Старый `func.createAuraWatch` удалён из `core/lib.lua`, а локальный dead-copy `createAuraWatch` удалён из `units/raid.lua`.
- `units/focus.lua` больше не держит commented-out references на мёртвый AuraWatch path.
- После этого group aura/watch story в `Roth_UI` стала однозначной: normal path идёт только через safe watcher из `core/group_aura_watch.lua`, а не через второй legacy contract, который уже не должен был жить в коде после secret-value hardening.
- `core/lib.lua` после extraction похудел до `1850` строк и снова ближе к unit/aura/castbar helper-слою вместо смеси UI helper'ов с mover persistence/runtime.

### 35. Staged regressions around group restore, mover load order, and bar visibility were normalized

- `core/frame_policy.lua` снова держит реальный `ReapplyBlizzardPartyFrames()` и корректный `IsAddOnEnabled(...)` contract вместо staged stub/always-true regression.
- `core/group_policy.lua` и `core/blizzard_restore_debug.lua` больше не переносят `CompactPartyFrame` под `UIParent` и не форсят `Show()` мимо `CompactPartyFrame:ShouldShow()`.
- `core/mover_runtime.lua` восстановлен как отдельный module, `Roth_UI.toc` снова грузит его после `core/lib.lua`, а pasted mover block убран из `core/lib.lua`.
- `core/bar_runtime_registry.lua` снова использует `descriptor.visibilityFrame`, поэтому dock/background/art tier читают effective holder visibility вместо wrapper-only shell state.

### 36. Secure aux-bar foundation now has a real runtime contract for bar2/bar3

- `core/action_bar_secure_runtime.lua` больше не ограничивается one-shot spawn: secure aux bars теперь поднимают binding refresh helper (`PLAYER_LOGIN`, `UPDATE_BINDINGS`, combat replay на `PLAYER_REGEN_ENABLED`) и реапплаят override bindings через один owner path.
- После spawn secure `bar2/bar3` сразу регистрируются в `BarRuntimeRegistry` и в shared proxy visibility manager, поэтому `secureOwnerBars` path реально входит в тот же Settings-driven visibility contract, что и fallback wrappers.
- Runtime notify loop теперь шлёт `bindings`/`layout` изменения для secure aux bars, так что dock/background consumers получают честный сигнал при bind/layout refresh.
- `core/action_bar_multibar_visibility.lua` dedupe-ит managed frame registration, поэтому повторный register/refresh не плодит несколько записей на один и тот же secure/fallback frame.

### 37. Secure aux-bar runtime now covers bar4/bar5 as well

- `core/action_bar_secure_runtime.lua` теперь знает Blizzard action-page contract для `MultiBarRight`/`MultiBarLeft` (`RIGHT_ACTIONBAR_PAGE = 3`, `LEFT_ACTIONBAR_PAGE = 4`) и использует correct binding prefixes `MULTIACTIONBAR3BUTTON` / `MULTIACTIONBAR4BUTTON` для Roth-owned secure buttons.
- Secure runtime умеет поднимать не только `bar2/bar3`, но и `bar4/bar5`, включая `bar4.combineBar4AndBar5` path: combined right-side stack теперь можно тестировать под тем же `secureOwnerBars` feature flag, не возвращаясь к Blizzard button skeleton.
- `core/action_bar_bar4.lua` и `core/action_bar_bar5.lua` теперь действительно переключаются на secure owner path при `secureOwnerBars = true`, вместо того чтобы всегда оставаться на wrapper fallback.

### 38. Settings control plane is now fail-closed on save/apply and exposes secureOwnerBars in normal UI

- `core/settings_main.lua` больше не запускает `apply(...)` после failed store write: `ui:SetConfigValue(...)` теперь проверяет return value `SetConfigValue(...)`, печатает явную ошибку и only-then выполняет live apply.
- Тот же слой теперь печатает user-facing `/reload required` message только после успешного сохранения reload-bound setting.
- В `Settings` registry добавлена `Action Bars` subcategory, а `secureOwnerBars` больше не живёт только в debug slash path: normal Settings UI теперь может включать/выключать secure aux-bar feature flag.
- `core/settings_general.lua` добавляет user-facing `Reload UI` button, чтобы pending-reload settings не оставались в подвешенном состоянии без явного entrypoint.
- `core/settings_target.lua` переведён с blind direct write на fail-closed `ui:SetConfigValue(...)` contract для target castbar semantic colors.

### 39. Main/override protected ownership paths are now quarantined instead of lying dormant in code

- `core/action_bar_bar1.lua` больше не держит legacy relayout/reparent path для Blizzard main bar/buttons. Ship mode теперь честно оставляет `MainActionBar/MainMenuBar` Blizzard-owned и only registers it in `BarRuntimeRegistry`.
- `core/action_bar_overridebar.lua` больше не создаёт `rABS_OverrideBar`, не зовёт `OverrideActionBar:SetParent(...)`, не чистит anchors и не relayout-ит `OverrideActionBarButton1..6`.
- Override surface сведён к thin follower model: post-hooks на `OnShow`, `OnHide`, `CalcSize`, `UpdateSkin` только держат registry/listeners в курсе layout/visibility state Blizzard-owned `OverrideActionBar`.
- `core/bar_runtime_registry.lua` теперь по умолчанию резолвит `overridebar` к `OverrideActionBar`, а не к Roth wrapper frame, которого в ship mode больше не существует.

### 40. Native aura border path is now secret-safe for `isHarmfulAura`

- `core/lib.lua` больше не ветвится напрямую по `data.isHarmfulAura` в `ApplyAuraBorder(...)`.
- Aura border logic сначала проверяет, что `isHarmfulAura` доступен и не помечен secret value, и только потом решает harmful/helpful branch.
- Это выравнивает native aura border path с уже существующим secret-safe contract в `core/unit_misc_runtime.lua`, не дожидаясь live producer-proof для поля `isHarmfulAura`.

### 41. Secure bars testbed now includes the main bar foundation

- `core/action_bar_secure_runtime.lua` теперь умеет поднимать `bar1` как owner-created `SecureHandlerStateTemplate` + LAB button stack, а не только aux bars.
- Main secure bar использует Blizzard-compatible secure page driver: normal `[bar:2..6]` paging, temp shapeshift/bonus remap через secure `_onstate-page` snippet и current-page `ACTIONBUTTON1..12` bindings.
- `core/action_bar_bar1.lua` теперь реально переключается на secure owner path при `secureOwnerBars = true`, а fallback Blizzard-owned register-only path остаётся только для ship mode без feature flag.
- User-facing wording тоже синхронизирована: Settings UI и slash help больше не обещают “secure aux bars only”, потому что `bar1` уже входит в testbed.

### 42. Secure bar buttons now follow the addon’s basic display settings

- `core/action_bar_secure_runtime.lua` больше не оставляет LAB buttons на library defaults только потому, что runtime path secure.
- Secure buttons теперь получают explicit config/display glue: `keyBoundTarget`, `clickOnDown`, macro/hotkey visibility через `UpdateConfig(...)`, плюс direct alpha policy для macro/hotkey/count/cooldown regions.
- Это уменьшает drift между fallback Blizzard button path и `secureOwnerBars` path: включение secure runtime больше не должно само по себе менять базовый contract для hotkeys/macro names/stack count/cooldown visibility.

### 43. Secure bars now separate proxy wrapper ownership from secure runtime state ownership

- `core/action_bar_secure_runtime.lua` больше не использует один и тот же frame как proxy-managed visibility surface и как `SecureHandlerStateTemplate` state-driver surface.
- Owner-created bars теперь состоят из outer wrapper frame + inner secure holder: proxy visibility (`RegisterManagedMultiBarFrame`) живёт на wrapper, а secure visibility/page drivers живут на holder.
- Это убирает прямую гонку `SetShown(...)` vs `RegisterStateDriver(...)` на одном объекте внутри `secureOwnerBars` path и приближает runtime к backlog target “one visibility owner per surface dimension”.
- `core/settings_general.lua` заодно держит action-bar mouseover controls в `Action Bars` subcategory, чтобы UI contour совпадал с техническим ownership boundary.

### 44. Secure main bar now actually owns override/vehicle action pages

- `core/action_bar_secure_runtime.lua` больше не скрывает main secure bar на `[overridebar][vehicleui][possessbar]` while simultaneously wiring a secure page driver for those same states.
- Main bar visibility driver теперь оставляет secure `bar1` живым вне `petbattle`, а override/vehicle/possess remap идёт через existing secure `_onstate-page` snippet.
- В результате `secureOwnerBars` уже реально использует owner-created main LAB bar как action-page surface для override/vehicle-sensitive states instead of keeping that path logically dead.
- Blizzard override shell/status widgets всё ещё follower-owned; этот slice закрывает именно action-page ownership, а не полный visual shell rewrite.

### 45. Settings reset/reload now go through one owner action surface

- Коммит `f492371` ([`core/settings_actions.lua`](core/settings_actions.lua)) централизовал session reload рядом с existing reset owner path: `core/settings_actions.lua` теперь публикует `ReloadSession()` с combat gate и явной availability check.
- `core/settings_general.lua` больше не держит свой fallback ladder (`settingsActions -> ns.func -> persistence`) и не вызывает `ReloadUI()` напрямую; обе кнопки Settings dispatch only в `settingsActions`.
- `core/slashcmd.lua` при этом остаётся thin dispatcher: user-facing Settings entrypoints идут в `settingsActions`, diagnostic/admin surface остаётся в `debugCommands`, без нового дублирования orchestration.

### 46. Aura diff hot paths were tightened instead of rescanning by habit

- Коммит `dfe51e5` ([`core/unit_misc_runtime.lua`](core/unit_misc_runtime.lua)) убрал ложный full-refresh path для safe `AuraWatch`: пустой incremental payload больше не считается `nilPayload` причиной для полного rescan.
- `core/group_aura_watch.lua` и `core/unit_misc_runtime.lua` теперь dedupe-ят repeated `updatedAuraInstanceIDs` / `removedAuraInstanceIDs`, так что merged queue больше не раздувает hot path лишними `GetAuraDataByAuraInstanceID(...)` и повторными removals.
- `/roth aurastats` теперь печатает отдельные `group/watch ...AuraIDDeduped` и `watchNoopPayloads` counters, поэтому perf smoke наконец показывает, сколько работы реально экономится на diff path, а не только сколько payload пришло.

### 47. Multibar proxy visibility now routes through the owner registry

- `core/bar_runtime_registry.lua` теперь хранит `descriptor.proxyVisible` и собирает effective visibility driver поверх existing state-driver contract, вместо того чтобы оставлять proxy visibility отдельным wrapper-only layer.
- `core/action_bar_multibar_visibility.lua` больше не пытается быть самостоятельным visibility owner для managed multibars: proxy refresh сначала идёт через `BarRuntimeRegistry.SetProxyVisibility(...)`, и только non-owner fallback path остаётся на raw `SetShown(...)`.
- Это поджимает backlog item про “one visibility owner per action-bar surface”: secure holder по-прежнему владеет runtime state, но proxy on/off теперь меняет тот же owner contract, а не спорит с ним вторым слоем.
- `core/extrabar_holder.lua` заодно перестал резолвить holder layout по скрытому `ExtraActionBarFrame`; thin-wrapper path теперь смотрит только на реально shown Blizzard bar или shared `ExtraAbilityContainer`, не притворяясь owner hidden Blizzard surface.

### 48. Group-frame recovery helpers now live on one coherent service surface

- Коммит `88afb2b` ([`core/frame_policy.lua`](core/frame_policy.lua)) не меняет runtime behavior, но снимает реальный vocabulary debt из `todo` section 9: `group_policy.lua` и `blizzard_restore_debug.lua` больше не зависят от смеси `framePolicy.*` и `framePolicy.groupFrames.*` для одного и того же recovery flow.
- `core/frame_policy.lua` теперь публикует на `groupFrames` те же safe helper references (`SafeCall`, `SafeCallMethod`, `SafeSetParent`, `ForceShow`, `FrameName`, `IsForbidden`, `ParkFrame`, `DeferUntilOutOfCombat`, `IsAddOnEnabled`, `IsRothEnabled`) alongside уже существующим group-frame restore surface.
- В результате group-frame consumers зависят от одного subsystem service, а не от hidden knowledge о том, какие helpers ещё торчат на root `framePolicy`.

### 49. Focus and boss now share an explicit mini target-frame scaffold

- `units/mini_target_scaffold.lua` теперь владеет общим artwork/health/power/text/castbar skeleton для mini target-like frames вместо того, чтобы держать эту конструкцию продублированной в `units/focus.lua` и `units/boss.lua`.
- `Roth_UI.toc` грузит scaffold явно до `focus.lua` / `boss.lua`, поэтому этот shared builder больше не живёт как скрытый side effect одного unit file для другого.
- `units/focus.lua` и `units/boss.lua` теперь оставляют у себя только unit-specific behavior: portrait/threat/auras/focus castbar bind у focus и boss-specific power text / spawn loop / castbar gate у boss.
- Это не большой unit-frame rewrite, а ровно тот bounded static slice, который можно было честно закрыть без live-клиента: будущие visual/safety fixes для этого scaffold теперь вносятся в одном месте.

## Что не перенесено сюда как «done»

Ниже не считается завершённым и поэтому **осталось в новом `todo.md`**:

- всё, что требует live retest в клиенте;
- частично закрытые архитектурные зоны (`persistence`, `group aura perf`, legacy mirrors, monolith split);

## Appendix A — все строки `done`, вынесенные из старого todo

Ниже сохранены **все** строки со статусом `done` из исходного `todo.md` с номерами строк старого файла.

- `todo.archive.md:7` 1. `done` - сверить live `!BugGrabber` ошибки с текущими `core/*` ownership paths.
- `todo.archive.md:8` 2. `done` - закрыть protected micromenu layout path: не дергать `SetWidth/SetHeight/SetPoint` на `rABS_MicroMenu` из `UpdateMicroButton` во время combat lockdown.
- `todo.archive.md:9` 3. `done` - закрыть такой же protected width-refresh path для `rABS_StanceBar`, где `OnShow/OnHide` и `UPDATE_SHAPESHIFT_*` могли вести в `frame:SetWidth()` в бою.
- `todo.archive.md:10` 4. `done` - закрыть protected bag layout path: `BagsBar:Layout()` больше не должен менять `rABS_BagFrame` и anchoring сумок прямо в combat lockdown.
- `todo.archive.md:11` 5. `done` - убрать необратимый `PlayerCastingBarFrame` kill path: default Blizzard player castbar теперь управляется через reversible policy (`SetAndUpdateShowCastbar`) вместо `UnregisterAllEvents()` / `Show = Hide`, чтобы Edit Mode и overlay castbars не ломались.
- `todo.archive.md:12` 6. `done` - убрать такой же irreversible hide path для `PetCastingBarFrame`: default pet castbar больше не убивается через `UnregisterAllEvents()` / `Show = Hide`, а скрывается reversible `SetAndUpdateShowCastbar(false)` fallback'ом на обычный `Hide()`.
- `todo.archive.md:13` 7. `done` - закрыть все legacy entrypoints в `rButtonTemplate`, которые ещё могли напрямую стилизовать default Blizzard aura buttons (`StyleBuffButtons`, `StyleDebuffButtons`, `StyleTempEnchants`, `StyleAllAuraButtons`); default BuffFrame path теперь целиком no-op на стороне Roth.
- `todo.archive.md:15` 9. `done` - убрать addon-owned direct `SetAndUpdateShowCastbar(...)` path для `PlayerCastingBarFrame`; теперь Roth only post-hook'ом re-hide'ит default castbar вне Edit Mode и не лезет в Blizzard castbar state machine напрямую.
- `todo.archive.md:27` - `done`: `core/micromenu_bar.lua` теперь держит combat gate + post-combat replay для layout refresh; hooks от `UpdateMicroButton` / `UpdateMicroButtons` больше не могут напрямую дёрнуть `SetWidth`/`SetHeight`/`SetPoint` на защищённом `rABS_MicroMenu` в бою.
- `todo.archive.md:28` - `done`: `core/stance_bar.lua` теперь тоже откладывает width refresh до `PLAYER_REGEN_ENABLED`; shapeshift- и button-visibility hooks больше не пишут `SetWidth()` в защищённый wrapper прямо в combat lockdown.
- `todo.archive.md:29` - `done`: `core/bags_bar.lua` теперь откладывает `BagsBar:Layout()` side effects до выхода из боя; secure wrapper и re-anchor сумок больше не обновляются прямо из bag layout hook в combat lockdown.
- `todo.archive.md:30` - `done`: `core/unit_policy.lua` теперь управляет default `PlayerCastingBarFrame` через reversible `SetAndUpdateShowCastbar(...)`, а `units/player.lua` больше не делает `UnregisterAllEvents()` / `Show = Hide`; Blizzard Edit Mode и overlay player castbars остаются живыми.
- `todo.archive.md:31` - `done`: follow-up для `core/unit_policy.lua`: Roth больше не вызывает `PlayerCastingBarFrame:SetAndUpdateShowCastbar(...)` сам. Вместо этого policy стала visual-only, сидит на post-hook'e `UpdateShownState` и пропускает Blizzard Edit Mode path без прямого вмешательства в castbar state machine.
- `todo.archive.md:32` - `done`: `core/frame_policy_bootstrap.lua` теперь реапплаит unit policy и после `ADDON_LOADED("Blizzard_UIPanels_Game")`, чтобы default player castbar policy не зависела от load order этого Blizzard addon.
- `todo.archive.md:33` - `done`: `units/pet.lua` больше не уничтожает runtime default `PetCastingBarFrame`; старый kill path заменён на reversible `SetAndUpdateShowCastbar(false)` с простым `Hide()` только как legacy fallback.
- `todo.archive.md:34` - `done`: в `modules/Roth_UI_rButtonTemplate/core.lua` отрезаны и прямые legacy entrypoints на default Blizzard aura buttons; теперь no-op не только `StyleAllAuraButtons`, но и `StyleBuffButtons` / `StyleDebuffButtons` / `StyleTempEnchants`.
- `todo.archive.md:36` - `done`: введён `ns.ActionBarShell` service в `modules/Roth_UI_rActionBarStyler/core/dock.lua`.
- `todo.archive.md:37` - `done`: `dock.lua` и `background.lua` больше не вычисляют нижний shell напрямую через legacy consumers; теперь bar1/bar2/bar3 регистрируются в одном shell adapter, а `multibar_visibility.lua` шлёт shell refresh.
- `todo.archive.md:38` - `done`: `modules/Roth_UI_rActionBarStyler/core/extrabar.lua` переведён в holder-only/follower path: direct `SetScale` / `ClearAllPoints` / `SetPoint` на `ExtraActionBarFrame` убраны, holder теперь следует за `ExtraAbilityContainer`.
- `todo.archive.md:39` - `done`: extra-stack sync теперь слушает `ExtraAbilityContainer`/`ZoneAbilityFrame` и не держит старый `0.35s` outro retry.
- `todo.archive.md:41` - `done`: persistence runtime consumers поджаты к одному API: `core/db.lua` и `core/slashcmd.lua` теперь идут через `ns.store`, а `core/lib.lua`/`core/settings_general.lua` больше не делают direct reset legacy globals мимо `ns.ResetPersistenceRoots()`.
- `todo.archive.md:43` - `done`: вынесен общий `GroupHeaderVisibility` helper для party/raid visibility driver logic; локальные дубли `ApplyVisibilityDriver` и party-only hidden parent park path убраны из `units/party.lua` и `units/raid.lua`.
- `todo.archive.md:44` - `done`: safe queued group debuff recolor возвращён для party/raid через `func.QueueGroupAuraColorUpdate`; мы не трогаем secret payload напрямую и не оживляем старый oUF aura blob.
- `todo.archive.md:45` - `done`: `raid.lua` больше не hard-disable'ит native Buffs/Debuffs path; raid aura frames теперь могут работать через current oUF/C_UnitAuras path и styled `SetupNativeAuraFrame`, если `units.raid.auras.show = true`.
- `todo.archive.md:47` - `done`: `frame_policy.lua` разрезан на shared/bootstrap слой + `group_policy.lua` + `unit_policy.lua` + `blizzard_restore_debug.lua`.
- `todo.archive.md:48` - `done`: глобальный font runtime вынесен из `core/frame_policy.lua` в отдельный `core/font_policy.lua`; startup coordinator больше не смешивает Blizzard frame bootstrap с global font mutation.
- `todo.archive.md:49` - `done`: startup event coordinator для frame policies вынесен из `core/frame_policy.lua` в отдельный `core/frame_policy_bootstrap.lua`; `frame_policy.lua` теперь оставлен shared helper/service слоем без собственного event wiring.
- `todo.archive.md:50` - `done`: normal runtime group/unit policy больше не живёт в одном монолите с Blizzard restore/debug logic; обычный path перестал сам менять addon enable state, а тяжёлый restore остался отдельным debug/recovery entrypoint.
- `todo.archive.md:51` - `done`: raid structure теперь умеет безопасно rebuild'иться вне боя, поэтому native raid auras можно реально включать/выключать из settings без `/reload`.
- `todo.archive.md:52` - `done`: в `settings_groups.lua` добавлены raid aura toggles для native icon rows.
- `todo.archive.md:53` - `done`: старый group `AuraWatch` blob заменён на addon-owned safe watcher через `AuraUtil.ForEachAura(..., \"HELPFUL|PLAYER\", ..., true)` и `spellId`, без `UnpackAuraData`-зависимости.
- `todo.archive.md:54` - `done`: в `settings_groups.lua` добавлены toggles для party/raid safe `AuraWatch`.
- `todo.archive.md:55` - `done`: введён единый deferred scheduler service; ключевые retry-paths в `frame_policy`, `target_castbar`, `settings_general` и `extrabar` переведены с raw `C_Timer.After(0/0.2)` на один orchestration слой.
- `todo.archive.md:56` - `done`: `sv_store.lua` больше не держит собственный fallback builder как normal runtime path; canonical persistence теперь жёстко опирается на owner API из `config.lua`.
- `todo.archive.md:57` - `done`: bars `2-5` переведены на wrapper+secure-holder visibility model: proxy visibility остаётся на named outer frame, а secure state driver сидит на internal holder.
- `todo.archive.md:58` - `done`: mover/debug frame lists вынесены в namespace-owned `core/frame_registry.lua`; `slashcmd.lua`, `settings_general.lua`, `core/lib.lua`, `units/party.lua`, `units/raid.lua`, `units/boss.lua` больше не используют direct global tables как primary runtime owner.
- `todo.archive.md:59` - `done`: `core/frame_registry.lua` теперь принимает и dot-, и colon-call contract для `Register/GetList/ForEachSelection`, а оставшиеся party/raid/boss/castbar registry writers переведены на canonical `frameRegistry` path; legacy `Roth_UI_Units` / `Roth_UI_Bars` остаются только mirror surface.
- `todo.archive.md:60` - `done`: `core/frame_registry.lua` теперь публикует `ForEachFrame(...)`, а `settings_general.lua`, `settings_actions.lua`, `debug_commands.lua` и оставшиеся party/raid/boss/lib registry writers больше не держат normal-path fallback на `_G.Roth_UI_*` или optional `frameRegistry` guards.
- `todo.archive.md:62` - `done`: `BarRuntimeRegistry` теперь трактуется как обязательный owner не только в bar modules, но и в `dock.lua`, `background.lua`, `multibar_visibility.lua` и action-bar settings apply-path; optional fallback на `type(barRuntimeRegistry)` для normal path убран.
- `todo.archive.md:63` - `done`: action-bar shell/layout runtime физически вынесен из legacy `modules/Roth_UI_rActionBarStyler` XML stack в `core/action_bar_multibar_visibility.lua`, `core/action_bar_dock.lua`, `core/action_bar_background.lua`; legacy bundle теперь грузит bar wrappers/buttons, а shell/layout orchestration живёт в основном addon load order.
- `todo.archive.md:64` - `done`: основной action-bar shell cluster тоже вынесен из legacy XML stack в `core/action_bar_bar1.lua`, `core/action_bar_bar2.lua`, `core/action_bar_bar3.lua`, `core/action_bar_bar4.lua`, `core/action_bar_bar5.lua`, `core/action_bar_overridebar.lua`; embedded `rActionBarStyler` теперь держит только styling/helpers (`hide_blizzart`, `slashcmd`, `spellflyout`, `cooldown`), а shell/layout owner грузится напрямую из `Roth_UI.toc`.
- `todo.archive.md:65` - `done`: ship-mode ownership metadata обновлена под новый reality: `core/bar_runtime_registry.lua` больше не помечает shell/layout owner как `legacy_rABS`, а фиксирует core wrapper/dock/background ownership.
- `todo.archive.md:66` - `done`: старый local targettarget castbar glue с ручными callback/hide retry больше не нужен и убран; unit больше не висит на почти пустом oUF callback path.
- `todo.archive.md:67` - `done`: `units/targettarget.lua` больше не полагается на почти мёртвый oUF callback path для `targettarget`; этот bar теперь реально включён через `func.EnableStandaloneCastbar(\"targettarget\")`, потому что upstream oUF не регистрирует castbar events для `*target` units.
- `todo.archive.md:68` - `done`: `core/unit_misc_runtime.lua` больше не держит отдельный `C_Timer.After(0)` для group aura recolor queue; flush этого hot path теперь тоже идёт через `ns.defer`.
- `todo.archive.md:69` - `done`: persistence metadata/config-root consumers поджаты к `ns.store`: `core/db.lua` больше не держит собственные hardcoded storage ids как primary source, а `core/settings_main.lua`, `core/slashcmd.lua`, `core/orb_runtime.lua` больше не читают `ns.cfgSaved` как normal fallback path.
- `todo.archive.md:71` - `done`: публичный config-store contract больше не переопределяется load order-ом: owner API (`ns.GetConfigStore`, `ns.SetConfigStore`, `ns.GetConfigPersistenceInfo`) теперь публикуется из `config.lua`, а `core/sv_store.lua` оставлен backend-реализацией `ns.store`.
- `todo.archive.md:72` - `done`: введён `core/bar_runtime_registry.lua`; `settings_general.lua` теперь ищет action-bar frames для live mouseover refresh через namespace-owned registry, а legacy `rABS_*` globals остались только fallback path.
- `todo.archive.md:73` - `done`: fallback knowledge по `rABS_*` mouseover frames перенесён из `settings_general.lua` в `core/bar_runtime_registry.lua`; `settings_general.lua` и `dock.lua` теперь резолвят bar frames через owner registry API вместо локальных legacy-name таблиц.
- `todo.archive.md:74` - `done`: `ActionBarShell` больше не держит второй runtime frame registry для bottom-cluster layout; role/frame metadata теперь читается из `core/bar_runtime_registry.lua`, а shell остаётся thin listener/layout facade поверх owner registry.
- `todo.archive.md:75` - `done`: managed multi-bar visibility metadata (`PROXY_SHOW_ACTIONBAR_*`) больше не живёт локально в `bar2..bar5.lua`; proxy keys теперь регистрируются в `core/bar_runtime_registry.lua` descriptors, а `multibar_visibility.lua` умеет резолвить frame+proxy set по bar key.
- `todo.archive.md:76` - `done`: `bar1..bar3` больше не делают вторую регистрацию через `ActionBarShell.RegisterFrame`; role metadata теперь задаётся сразу в `BarRuntimeRegistry:RegisterFrame(...)`, а пустой shell registration path убран.
- `todo.archive.md:77` - `done`: `micromenu` / `bags` / `stancebar` больше не держат отдельную регистрацию в `ActionBarDock`; нижний dock теперь резолвит эти frames через `core/bar_runtime_registry.lua` descriptors (`dockSlot`) и остаётся pure layout service.
- `todo.archive.md:78` - `done`: refresh/orchestration для action-bar layout больше не ходит primary path-ом через direct `ActionBarDock.Refresh()` / `ActionBarShell.NotifyChanged()` calls из legacy модулей; `rActionBarStyler` теперь шлёт layout/visibility notifications через listeners в `core/bar_runtime_registry.lua`.
- `todo.archive.md:79` - `done`: visibility contracts для `bar1..5`, `micromenu`, `bags`, `stancebar`, `petbar`, `leave_vehicle` вынесены в `core/bar_runtime_registry.lua`; legacy bar-модули теперь в основном вызывают owner helper `ApplyVisibilityDriver(...)`, а не держат собственные state-driver строки в каждом файле.
- `todo.archive.md:80` - `done`: special-case mouseover refresh для `extrabar` больше не живёт в отдельном `ns.barMouseoverRefreshers`; `settings_general.lua` теперь сначала спрашивает owner registry `RefreshMouseover()`, а `extrabar.lua` регистрирует свой custom refresher через `BarRuntimeRegistry`.
- `todo.archive.md:81` - `done`: `overridebar.lua` больше не трактует Blizzard `LeaveButton` как fallback action button; override exit subframe теперь явно скрывается post-hook-ами (`OnShow` / `CalcSize` / `UpdateSkin`), а owner surface для exit остаётся за `leave_vehicle.lua`.
- `todo.archive.md:82` - `done`: `overridebar.lua` теперь реапплаит Roth layout как явный owner-follower path после Blizzard `CalcSize()` / `UpdateSkin()` и синхронизирует wrapper visibility с `OverrideActionBar:IsShown()`, вместо одноразового init-layout без последующего контроля.
- `todo.archive.md:83` - `done`: внутри `rActionBarStyler` `BarRuntimeRegistry` больше не рассматривается как optional dependency; bar/special-bar modules теперь требуют owner registry как обязательный контракт вместо набора `if ns and ns.BarRuntimeRegistry ...` fallback-веток.
- `todo.archive.md:84` - `done`: изолированный `leave_vehicle` surface вынесен из legacy `modules/Roth_UI_rActionBarStyler/rActionBar.xml` в отдельный `core/leave_vehicle_bar.lua`; этот secure button больше не живёт внутри main legacy shell stack и теперь грузится как отдельный workstream поверх owner registry.
- `todo.archive.md:85` - `done`: `extrabar` holder/follower runtime вынесен из legacy `rActionBarStyler` XML stack в отдельный `core/extrabar_holder.lua`; этот surface теперь живёт как самостоятельный owner-follow module поверх `ExtraAbilityContainer` и `BarRuntimeRegistry`, а не как часть legacy shell bundle.
- `todo.archive.md:86` - `done`: `petbar` вынесен из legacy `rActionBarStyler` XML stack в отдельный `core/pet_action_bar.lua`; этот special surface теперь грузится как самостоятельный owner module поверх `BarRuntimeRegistry`, а не как часть legacy shell bundle.
- `todo.archive.md:87` - `done`: `stancebar` вынесен из legacy `rActionBarStyler` XML stack в отдельный `core/stance_bar.lua`; dock/runtime ownership при этом остался на owner registry, а сам surface перестал жить внутри legacy shell bundle.
- `todo.archive.md:88` - `done`: `micromenu` и `bags` вынесены из legacy `rActionBarStyler` XML stack в отдельные `core/micromenu_bar.lua` и `core/bags_bar.lua`; нижний dock теперь собирает cluster из owner registry и больше не зависит от их проживания внутри legacy shell XML.
- `todo.archive.md:89` - `done`: `core/hide_endcaps.lua` переведён с собственного timer-sweep на `ns.defer.RunSeries`; raw timers в проекте теперь централизованы в `core/deferred_scheduler.lua`.
- `todo.archive.md:90` - `done`: persistence registry/schema/drift metadata в `core/sv_store.lua` теперь строится от `GetConfigDescriptor()` / `GetOrbDescriptor()`, а не от повторяющихся локальных owner/path/variable констант в нескольких helper'ах.
- `todo.archive.md:91` - `done`: orb persistence metadata теперь публикуется owner service-ом из `core/sv_store.lua` (`GetOrbPersistenceInfo/GetOrbSchemaInfo/GetOrbSchemaPolicy`); `core/db.lua` больше не собирает schema/persistence info вручную из descriptor + hardcoded fallback strings.
- `todo.archive.md:92` - `done`: diagnostic persistence consumers поджаты к owner services: `sv_doctor.lua` теперь берёт canonical stores через `ns.persistence` when available и строит storage labels из descriptors, а `debug_commands.lua` предпочитает `persistence.GetConfigRoot()` вместо локального store fallback.
- `todo.archive.md:93` - `done`: transfer export path больше не падает обратно на `ns.EnsureCanonicalPersistenceStores()`; `core/transfer.lua` теперь берёт canonical roots через `ns.persistence.GetCanonicalStores()` или `ns.store.GetCanonicalStores()`.
- `todo.archive.md:94` - `done`: boundary между `config.lua` и `core/sv_store.lua` оформлен явным owner service `ns.configPersistence`; `sv_store.lua` теперь берёт canonical roots/config schema/reconcile через один owner contract вместо россыпи `ns.EnsureCanonicalPersistenceStores` / `ns.SetCanonical*` / `ns.GetConfigSchema*`.
- `todo.archive.md:95` - `done`: raw canonical root owner вынесен из `config.lua` в отдельный `core/config_persistence_owner.lua`; `config.lua` теперь отвечает за config schema/defaults/proxy/reconcile поверх owner service, а `sv_store.lua` требует `ns.configPersistence` как обязательный контракт.
- `todo.archive.md:96` - `done`: после extraction boundary убраны лишние optional branches: `sv_store.lua` больше не трактует config schema owner как optional path, а `sv_doctor.lua` больше не ходит в legacy canonical-root fallback поверх нового owner service.
- `todo.archive.md:97` - `done`: `core/sv_store.lua` теперь публикует namespace-owned `ns.persistence` facade для reset/reconcile/schema-report/runtime-rebuild/root-replacement/runtime-state access.
- `todo.archive.md:98` - `done`: `settings_general.lua`, `core/lib.lua`, `core/slashcmd.lua`, `core/transfer.lua`, `core/group_policy.lua`, `core/unit_policy.lua` больше не ходят в reset/reconcile/rebuild flows через разрозненные `ns.ResetPersistenceRoots` / `ns.ReconcilePersistenceStores` / `ns.SVRebuildRuntime` как primary consumer path; normal path теперь идёт через `ns.persistence`.
- `todo.archive.md:99` - `done`: `core/settings_main.lua` больше не держит fallback на `ns.GetConfigStore/ns.SetConfigStore`, а `core/sv_doctor.lua` больше не читает config/doctor runtime через legacy global entrypoints как primary path; оба consumer'а теперь опираются на owner store/service surfaces.
- `todo.archive.md:100` - `done`: введён `storeApi.GetOrbConfig(orbType)`; `core/orb_runtime.lua`, `units/player.lua` и orb-tag accessors в `core/tags.lua` больше не читают один и тот же char store через смесь `ns.store.GetOrbCharRoot()` / `db:GetCharStore()` / `db.char` как primary path.
- `todo.archive.md:103` - `done`: `core/target_castbar.lua` теперь держит explicit cast context (`UnitGUID`, cast/castbar ids, `spellID`, start/end ms) и не применяет stale stop/fail/interrupt visuals, если `target` уже указывает на другую цель или на новый активный каст.
- `todo.archive.md:105` - `done`: `focus.lua` больше не оставляет castbar на голом oUF lifecycle; focus castbar теперь тоже bind'ится к identity-safe runtime из `core/target_castbar.lua`.
- `todo.archive.md:106` - `done`: для `boss` добавлен addon-owned mini castbar path: default `units.boss.castbar`, self-anchor support в `core/lib.lua` через `af = "$parent"`, и bind runtime по `boss1..N`.
- `todo.archive.md:108` - `done`: standalone poller для `targettarget` теперь хотя бы делит active visual contract с shared runtime: channel/non-interrupt/empower state и overlay refresh больше не живут на completely separate color path.
- `todo.archive.md:110` - `done`: введён `core/settings_actions.lua`; user-facing reset/export/import entrypoints теперь живут в одном service вместо direct вызовов из нескольких control planes.
- `todo.archive.md:111` - `done`: `core/settings_transfer.lua` и `/roth export|import` переведены на `ns.settingsActions`, поэтому transfer UI больше не открывается прямыми ad-hoc вызовами из Settings/slash.
- `todo.archive.md:112` - `done`: полный factory reset теперь тоже имеет один canonical entrypoint: Settings button и новый `/roth svreset` / `/roth factoryreset` идут через один service, а `core/lib.lua` оставлен compatibility facade.
- `todo.archive.md:113` - `done`: введён `core/debug_commands.lua`; diagnostic/admin actions (`schema`, `settingsschema`, `smoke`, `aurastats`, `svcheck`, `svreconcile`, `svrebuild`, `blizzrestore`, `blizzstatus`, `log`, `debug`, `perf`) теперь живут в отдельном service вместо размазанной логики внутри slash parser.
- `todo.archive.md:114` - `done`: `/roth` теперь тоньше как control plane: `core/slashcmd.lua` в основном парсит команды и делегирует debug/admin работу в `ns.debugCommands`, а user-facing actions оставляет за `ns.settingsActions`.
- `todo.archive.md:115` - `done`: mover/admin surface (`unlock*`, `lock*`, `reset*`, `dump`) тоже переведён на `ns.debugCommands`, поэтому `slashcmd.lua` больше не держит собственные mover selection/reset helpers и локальную persistence dump orchestration.
- `todo.archive.md:116` - `done`: `modules/Roth_UI_rActionBarStyler/core/background.lua` больше не фильтрует Edit Mode refresh по мёртвому `self == MainActionBar` guard на mixin method; main-bar artwork теперь обновляется через реальный `EditModeActionBarSystemMixin:RefreshBarArt` hook и helper по `MainBar` system contract.
- `todo.archive.md:117` - `done`: `core/transfer.lua` больше не использует `ns.SanitizePersistenceStores` / `ns.EnsureCanonicalPersistenceStores` как primary export path; transfer export/import теперь идёт через расширенный `ns.persistence` service (`Sanitize`, `GetCanonicalStores`, `RunDoctor`) и оставляет direct owner calls только compatibility fallback.
- `todo.archive.md:118` - `done`: orb config resolution полностью сведён к owner store service: `storeApi.GetOrbConfig()` теперь умеет возвращать defaults fallback сам, `core/tags.lua` и `units/player.lua` больше не делают локальный fallback на `db.char`/`db:GetOrbDefaults()`, а `core/db.lua` template-save/load path читает текущий char store через owner API вместо direct `db.char` cache.
- `todo.archive.md:119` - `done`: `core/settings_orbs.lua` больше не знает про raw orb char root/defaults root и legacy alias cleanup для `value.bot`; alias-aware read/write и defaults fallback вынесены в `storeApi.GetOrbConfigValue/SetOrbConfigValue` внутри `core/sv_store.lua`, а orb settings UI остался thin consumer-слоем.
- `todo.archive.md:120` - `done`: `core/settings_main.lua` больше не держит собственный config-store fallback engine с `GetConfigRoot/SetConfigRoot/WritePath`; normal Settings UI path теперь идёт через `storeApi.GetConfigValue/SetConfigValue`, а storage knowledge остаётся внутри `core/sv_store.lua`.
- `todo.archive.md:121` - `done`: `core/settings_target.lua` и key admin writes в `core/debug_commands.lua` больше не пишут config через прямой `ns.SVSet`; target castbar color contract, `framesLocked` и Blizzard-restore toggles теперь идут через `storeApi.SetConfigValue`, а `core/orb_runtime.lua` больше не тянет весь config root ради чтения `font`.
- `todo.archive.md:122` - `done`: mover persistence helpers в `core/lib.lua` больше не читают и не пишут `movers.*` через raw `ns.SVGet/ns.SVSet`; normal path теперь тоже идёт через `storeApi.GetConfigValue/SetConfigValue`.
- `todo.archive.md:123` - `done`: diagnostic/persistence control plane поджат к одному owner service: `core/sv_store.lua` теперь реально публикует `persistence.GetConfigRoot/GetDebugState/GetLog/ClearLog/GetScanStores/GetStorageLabels`, а `core/debug_commands.lua` и `core/sv_doctor.lua` больше не держат собственные fallback-деревья для config root/doctor state/scan labels.
- `todo.archive.md:124` - `done`: `debug_commands.lua`, `settings_actions.lua`, `settings_general.lua`, `core/lib.lua`, `group_policy.lua` и `unit_policy.lua` больше не трактуют `ns.persistence` / `SetConfigValue` как optional normal-path dependency; control plane теперь идёт через обязательные owner methods (`ResetAndReload`, `RebuildRuntime`, `ReportSchema`, `RunDoctor`, `Reconcile`).
- `todo.archive.md:125` - `done`: `init.lua` больше не прогревает runtime config через legacy `ns.GetConfigStore()`; bootstrap теперь требует owner service `ns.persistence.GetConfigRoot()`, а `ns.cfgSaved` явно остаётся только compatibility mirror.
- `todo.archive.md:126` - `done`: export/import orchestration тоже поджат к owner service: `core/sv_store.lua` теперь публикует `persistence.GetTransferRoots/ApplyTransferRoots`, а `core/transfer.lua` больше не оркестрирует sanitize + canonical root selection + replace/reconcile/rebuild через россыпь fallback-веток.
- `todo.archive.md:127` - `done`: action-bar ownership boundary формализован в ship mode: `core/bar_runtime_registry.lua` теперь владеет explicit ownership matrix + shell/dock API (`GetBottomClusterLayout`, `GetVisibleAuxRowCount`, `GetArtworkTier`, `ResolveDockMember`), `dock.lua` оставлен pure layout consumer-слоем, а `background.lua` больше не зависит от локального `ActionBarShell` geometry/tier logic.
