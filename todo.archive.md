# ARCHIVE: NOT DONE
#
# Содержимое ниже — исторический архив. До новой валидации все ранее отмеченные
# статусы (done, partial, pending, ixed in code) считаются НЕ СДЕЛАНЫ
# и требуют повторного подтверждения в клиенте.

# Roth_UI - подробный engineering todo

Обновлено: 2026-03-13

## Session steps - 2026-03-13

1. `done` - сверить live `!BugGrabber` ошибки с текущими `core/*` ownership paths.
2. `done` - закрыть protected micromenu layout path: не дергать `SetWidth/SetHeight/SetPoint` на `rABS_MicroMenu` из `UpdateMicroButton` во время combat lockdown.
3. `done` - закрыть такой же protected width-refresh path для `rABS_StanceBar`, где `OnShow/OnHide` и `UPDATE_SHAPESHIFT_*` могли вести в `frame:SetWidth()` в бою.
4. `done` - закрыть protected bag layout path: `BagsBar:Layout()` больше не должен менять `rABS_BagFrame` и anchoring сумок прямо в combat lockdown.
5. `done` - убрать необратимый `PlayerCastingBarFrame` kill path: default Blizzard player castbar теперь управляется через reversible policy (`SetAndUpdateShowCastbar`) вместо `UnregisterAllEvents()` / `Show = Hide`, чтобы Edit Mode и overlay castbars не ломались.
6. `done` - убрать такой же irreversible hide path для `PetCastingBarFrame`: default pet castbar больше не убивается через `UnregisterAllEvents()` / `Show = Hide`, а скрывается reversible `SetAndUpdateShowCastbar(false)` fallback'ом на обычный `Hide()`.
7. `done` - закрыть все legacy entrypoints в `rButtonTemplate`, которые ещё могли напрямую стилизовать default Blizzard aura buttons (`StyleBuffButtons`, `StyleDebuffButtons`, `StyleTempEnchants`, `StyleAllAuraButtons`); default BuffFrame path теперь целиком no-op на стороне Roth.
8. `pending` - перепроверить в клиенте, воспроизводится ли ещё `BuffFrame` secret-taint на текущем исходнике, потому что статически default aura styling уже выключен и legacy entrypoints тоже отрезаны.
9. `done` - убрать addon-owned direct `SetAndUpdateShowCastbar(...)` path для `PlayerCastingBarFrame`; теперь Roth only post-hook'ом re-hide'ит default castbar вне Edit Mode и не лезет в Blizzard castbar state machine напрямую.
10. `pending` - live retest: открыть/закрыть Edit Mode при включённом Roth player frame и убедиться, что больше не появляется `CastingBarFrame.lua:722` / `StopFinishAnims` forbidden-table trace.

## Исполнительное обновление - 2026-03-13

Этот верхний блок надо читать первым.

Ниже в файле уже есть большой архив аудита, повторные backlog-блоки и appendix-разделы.
Я их не удаляю, потому что там накоплены полезные детали, но рабочий порядок для текущего completion pass теперь задаётся именно здесь.

## Текущий implementation pass - 2026-03-13

- `done`: `core/micromenu_bar.lua` теперь держит combat gate + post-combat replay для layout refresh; hooks от `UpdateMicroButton` / `UpdateMicroButtons` больше не могут напрямую дёрнуть `SetWidth`/`SetHeight`/`SetPoint` на защищённом `rABS_MicroMenu` в бою.
- `done`: `core/stance_bar.lua` теперь тоже откладывает width refresh до `PLAYER_REGEN_ENABLED`; shapeshift- и button-visibility hooks больше не пишут `SetWidth()` в защищённый wrapper прямо в combat lockdown.
- `done`: `core/bags_bar.lua` теперь откладывает `BagsBar:Layout()` side effects до выхода из боя; secure wrapper и re-anchor сумок больше не обновляются прямо из bag layout hook в combat lockdown.
- `done`: `core/unit_policy.lua` теперь управляет default `PlayerCastingBarFrame` через reversible `SetAndUpdateShowCastbar(...)`, а `units/player.lua` больше не делает `UnregisterAllEvents()` / `Show = Hide`; Blizzard Edit Mode и overlay player castbars остаются живыми.
- `done`: follow-up для `core/unit_policy.lua`: Roth больше не вызывает `PlayerCastingBarFrame:SetAndUpdateShowCastbar(...)` сам. Вместо этого policy стала visual-only, сидит на post-hook'e `UpdateShownState` и пропускает Blizzard Edit Mode path без прямого вмешательства в castbar state machine.
- `done`: `core/frame_policy_bootstrap.lua` теперь реапплаит unit policy и после `ADDON_LOADED("Blizzard_UIPanels_Game")`, чтобы default player castbar policy не зависела от load order этого Blizzard addon.
- `done`: `units/pet.lua` больше не уничтожает runtime default `PetCastingBarFrame`; старый kill path заменён на reversible `SetAndUpdateShowCastbar(false)` с простым `Hide()` только как legacy fallback.
- `done`: в `modules/Roth_UI_rButtonTemplate/core.lua` отрезаны и прямые legacy entrypoints на default Blizzard aura buttons; теперь no-op не только `StyleAllAuraButtons`, но и `StyleBuffButtons` / `StyleDebuffButtons` / `StyleTempEnchants`.
- `note`: live `!BugGrabber` всё ещё содержит старые `BuffFrame` secret-taint записи, но текущий source уже не стайлит default BuffFrame aura anchors и вообще не допускает legacy default-aura styling entrypoints. Дальше нужен именно live retest, а не ещё один слепой static patch.
- `done`: введён `ns.ActionBarShell` service в `modules/Roth_UI_rActionBarStyler/core/dock.lua`.
- `done`: `dock.lua` и `background.lua` больше не вычисляют нижний shell напрямую через legacy consumers; теперь bar1/bar2/bar3 регистрируются в одном shell adapter, а `multibar_visibility.lua` шлёт shell refresh.
- `done`: `modules/Roth_UI_rActionBarStyler/core/extrabar.lua` переведён в holder-only/follower path: direct `SetScale` / `ClearAllPoints` / `SetPoint` на `ExtraActionBarFrame` убраны, holder теперь следует за `ExtraAbilityContainer`.
- `done`: extra-stack sync теперь слушает `ExtraAbilityContainer`/`ZoneAbilityFrame` и не держит старый `0.35s` outro retry.
- `note`: старый `extrabar.pos` / `userplaced` путь больше не трактуется как owner-контракт для Blizzard container; если когда-нибудь понадобится жёстко своё положение extra stack, это уже отдельный secure replacement этап.
- `done`: persistence runtime consumers поджаты к одному API: `core/db.lua` и `core/slashcmd.lua` теперь идут через `ns.store`, а `core/lib.lua`/`core/settings_general.lua` больше не делают direct reset legacy globals мимо `ns.ResetPersistenceRoots()`.
- `note`: это ещё не финальная чистка persistence; canonical bootstrap всё ещё живёт в `config.lua`, а `sv_store.lua` пока сохраняет bootstrap/emergency fallback path.
- `done`: вынесен общий `GroupHeaderVisibility` helper для party/raid visibility driver logic; локальные дубли `ApplyVisibilityDriver` и party-only hidden parent park path убраны из `units/party.lua` и `units/raid.lua`.
- `done`: safe queued group debuff recolor возвращён для party/raid через `func.QueueGroupAuraColorUpdate`; мы не трогаем secret payload напрямую и не оживляем старый oUF aura blob.
- `done`: `raid.lua` больше не hard-disable'ит native Buffs/Debuffs path; raid aura frames теперь могут работать через current oUF/C_UnitAuras path и styled `SetupNativeAuraFrame`, если `units.raid.auras.show = true`.
- `note`: `AuraWatch` для raid всё ещё сознательно выключен; это отдельный старый contract и его не надо смешивать с native raid auras.
- `done`: `frame_policy.lua` разрезан на shared/bootstrap слой + `group_policy.lua` + `unit_policy.lua` + `blizzard_restore_debug.lua`.
- `done`: глобальный font runtime вынесен из `core/frame_policy.lua` в отдельный `core/font_policy.lua`; startup coordinator больше не смешивает Blizzard frame bootstrap с global font mutation.
- `done`: startup event coordinator для frame policies вынесен из `core/frame_policy.lua` в отдельный `core/frame_policy_bootstrap.lua`; `frame_policy.lua` теперь оставлен shared helper/service слоем без собственного event wiring.
- `done`: normal runtime group/unit policy больше не живёт в одном монолите с Blizzard restore/debug logic; обычный path перестал сам менять addon enable state, а тяжёлый restore остался отдельным debug/recovery entrypoint.
- `done`: raid structure теперь умеет безопасно rebuild'иться вне боя, поэтому native raid auras можно реально включать/выключать из settings без `/reload`.
- `done`: в `settings_groups.lua` добавлены raid aura toggles для native icon rows.
- `done`: старый group `AuraWatch` blob заменён на addon-owned safe watcher через `AuraUtil.ForEachAura(..., \"HELPFUL|PLAYER\", ..., true)` и `spellId`, без `UnpackAuraData`-зависимости.
- `done`: в `settings_groups.lua` добавлены toggles для party/raid safe `AuraWatch`.
- `done`: введён единый deferred scheduler service; ключевые retry-paths в `frame_policy`, `target_castbar`, `settings_general` и `extrabar` переведены с raw `C_Timer.After(0/0.2)` на один orchestration слой.
- `done`: `sv_store.lua` больше не держит собственный fallback builder как normal runtime path; canonical persistence теперь жёстко опирается на owner API из `config.lua`.
- `done`: bars `2-5` переведены на wrapper+secure-holder visibility model: proxy visibility остаётся на named outer frame, а secure state driver сидит на internal holder.
- `done`: mover/debug frame lists вынесены в namespace-owned `core/frame_registry.lua`; `slashcmd.lua`, `settings_general.lua`, `core/lib.lua`, `units/party.lua`, `units/raid.lua`, `units/boss.lua` больше не используют direct global tables как primary runtime owner.
- `done`: `core/frame_registry.lua` теперь принимает и dot-, и colon-call contract для `Register/GetList/ForEachSelection`, а оставшиеся party/raid/boss/castbar registry writers переведены на canonical `frameRegistry` path; legacy `Roth_UI_Units` / `Roth_UI_Bars` остаются только mirror surface.
- `done`: `core/frame_registry.lua` теперь публикует `ForEachFrame(...)`, а `settings_general.lua`, `settings_actions.lua`, `debug_commands.lua` и оставшиеся party/raid/boss/lib registry writers больше не держат normal-path fallback на `_G.Roth_UI_*` или optional `frameRegistry` guards.
- `note`: legacy `_G.Roth_UI_Bars` / `_G.Roth_UI_Orbs` / `_G.Roth_UI_Units` / `_G.Roth_UI_Art` пока оставлены как compatibility mirror для slash/macro/debug surface, но canonical owner теперь `ns.frameRegistry`.
- `done`: `BarRuntimeRegistry` теперь трактуется как обязательный owner не только в bar modules, но и в `dock.lua`, `background.lua`, `multibar_visibility.lua` и action-bar settings apply-path; optional fallback на `type(barRuntimeRegistry)` для normal path убран.
- `done`: action-bar shell/layout runtime физически вынесен из legacy `modules/Roth_UI_rActionBarStyler` XML stack в `core/action_bar_multibar_visibility.lua`, `core/action_bar_dock.lua`, `core/action_bar_background.lua`; legacy bundle теперь грузит bar wrappers/buttons, а shell/layout orchestration живёт в основном addon load order.
- `done`: основной action-bar shell cluster тоже вынесен из legacy XML stack в `core/action_bar_bar1.lua`, `core/action_bar_bar2.lua`, `core/action_bar_bar3.lua`, `core/action_bar_bar4.lua`, `core/action_bar_bar5.lua`, `core/action_bar_overridebar.lua`; embedded `rActionBarStyler` теперь держит только styling/helpers (`hide_blizzart`, `slashcmd`, `spellflyout`, `cooldown`), а shell/layout owner грузится напрямую из `Roth_UI.toc`.
- `done`: ship-mode ownership metadata обновлена под новый reality: `core/bar_runtime_registry.lua` больше не помечает shell/layout owner как `legacy_rABS`, а фиксирует core wrapper/dock/background ownership.
- `done`: старый local targettarget castbar glue с ручными callback/hide retry больше не нужен и убран; unit больше не висит на почти пустом oUF callback path.
- `done`: `units/targettarget.lua` больше не полагается на почти мёртвый oUF callback path для `targettarget`; этот bar теперь реально включён через `func.EnableStandaloneCastbar(\"targettarget\")`, потому что upstream oUF не регистрирует castbar events для `*target` units.
- `done`: `core/unit_misc_runtime.lua` больше не держит отдельный `C_Timer.After(0)` для group aura recolor queue; flush этого hot path теперь тоже идёт через `ns.defer`.
- `done`: persistence metadata/config-root consumers поджаты к `ns.store`: `core/db.lua` больше не держит собственные hardcoded storage ids как primary source, а `core/settings_main.lua`, `core/slashcmd.lua`, `core/orb_runtime.lua` больше не читают `ns.cfgSaved` как normal fallback path.
- `note`: `ns.cfgSaved` всё ещё существует как compatibility/cache mirror и diagnostic surface, но normal consumer path теперь должен идти через `storeApi.GetConfigRoot` / `ns.SVGet`.
- `done`: публичный config-store contract больше не переопределяется load order-ом: owner API (`ns.GetConfigStore`, `ns.SetConfigStore`, `ns.GetConfigPersistenceInfo`) теперь публикуется из `config.lua`, а `core/sv_store.lua` оставлен backend-реализацией `ns.store`.
- `done`: введён `core/bar_runtime_registry.lua`; `settings_general.lua` теперь ищет action-bar frames для live mouseover refresh через namespace-owned registry, а legacy `rABS_*` globals остались только fallback path.
- `done`: fallback knowledge по `rABS_*` mouseover frames перенесён из `settings_general.lua` в `core/bar_runtime_registry.lua`; `settings_general.lua` и `dock.lua` теперь резолвят bar frames через owner registry API вместо локальных legacy-name таблиц.
- `done`: `ActionBarShell` больше не держит второй runtime frame registry для bottom-cluster layout; role/frame metadata теперь читается из `core/bar_runtime_registry.lua`, а shell остаётся thin listener/layout facade поверх owner registry.
- `done`: managed multi-bar visibility metadata (`PROXY_SHOW_ACTIONBAR_*`) больше не живёт локально в `bar2..bar5.lua`; proxy keys теперь регистрируются в `core/bar_runtime_registry.lua` descriptors, а `multibar_visibility.lua` умеет резолвить frame+proxy set по bar key.
- `done`: `bar1..bar3` больше не делают вторую регистрацию через `ActionBarShell.RegisterFrame`; role metadata теперь задаётся сразу в `BarRuntimeRegistry:RegisterFrame(...)`, а пустой shell registration path убран.
- `done`: `micromenu` / `bags` / `stancebar` больше не держат отдельную регистрацию в `ActionBarDock`; нижний dock теперь резолвит эти frames через `core/bar_runtime_registry.lua` descriptors (`dockSlot`) и остаётся pure layout service.
- `done`: refresh/orchestration для action-bar layout больше не ходит primary path-ом через direct `ActionBarDock.Refresh()` / `ActionBarShell.NotifyChanged()` calls из legacy модулей; `rActionBarStyler` теперь шлёт layout/visibility notifications через listeners в `core/bar_runtime_registry.lua`.
- `done`: visibility contracts для `bar1..5`, `micromenu`, `bags`, `stancebar`, `petbar`, `leave_vehicle` вынесены в `core/bar_runtime_registry.lua`; legacy bar-модули теперь в основном вызывают owner helper `ApplyVisibilityDriver(...)`, а не держат собственные state-driver строки в каждом файле.
- `done`: special-case mouseover refresh для `extrabar` больше не живёт в отдельном `ns.barMouseoverRefreshers`; `settings_general.lua` теперь сначала спрашивает owner registry `RefreshMouseover()`, а `extrabar.lua` регистрирует свой custom refresher через `BarRuntimeRegistry`.
- `done`: `overridebar.lua` больше не трактует Blizzard `LeaveButton` как fallback action button; override exit subframe теперь явно скрывается post-hook-ами (`OnShow` / `CalcSize` / `UpdateSkin`), а owner surface для exit остаётся за `leave_vehicle.lua`.
- `done`: `overridebar.lua` теперь реапплаит Roth layout как явный owner-follower path после Blizzard `CalcSize()` / `UpdateSkin()` и синхронизирует wrapper visibility с `OverrideActionBar:IsShown()`, вместо одноразового init-layout без последующего контроля.
- `done`: внутри `rActionBarStyler` `BarRuntimeRegistry` больше не рассматривается как optional dependency; bar/special-bar modules теперь требуют owner registry как обязательный контракт вместо набора `if ns and ns.BarRuntimeRegistry ...` fallback-веток.
- `done`: изолированный `leave_vehicle` surface вынесен из legacy `modules/Roth_UI_rActionBarStyler/rActionBar.xml` в отдельный `core/leave_vehicle_bar.lua`; этот secure button больше не живёт внутри main legacy shell stack и теперь грузится как отдельный workstream поверх owner registry.
- `done`: `extrabar` holder/follower runtime вынесен из legacy `rActionBarStyler` XML stack в отдельный `core/extrabar_holder.lua`; этот surface теперь живёт как самостоятельный owner-follow module поверх `ExtraAbilityContainer` и `BarRuntimeRegistry`, а не как часть legacy shell bundle.
- `done`: `petbar` вынесен из legacy `rActionBarStyler` XML stack в отдельный `core/pet_action_bar.lua`; этот special surface теперь грузится как самостоятельный owner module поверх `BarRuntimeRegistry`, а не как часть legacy shell bundle.
- `done`: `stancebar` вынесен из legacy `rActionBarStyler` XML stack в отдельный `core/stance_bar.lua`; dock/runtime ownership при этом остался на owner registry, а сам surface перестал жить внутри legacy shell bundle.
- `done`: `micromenu` и `bags` вынесены из legacy `rActionBarStyler` XML stack в отдельные `core/micromenu_bar.lua` и `core/bags_bar.lua`; нижний dock теперь собирает cluster из owner registry и больше не зависит от их проживания внутри legacy shell XML.
- `done`: `core/hide_endcaps.lua` переведён с собственного timer-sweep на `ns.defer.RunSeries`; raw timers в проекте теперь централизованы в `core/deferred_scheduler.lua`.
- `done`: persistence registry/schema/drift metadata в `core/sv_store.lua` теперь строится от `GetConfigDescriptor()` / `GetOrbDescriptor()`, а не от повторяющихся локальных owner/path/variable констант в нескольких helper'ах.
- `done`: orb persistence metadata теперь публикуется owner service-ом из `core/sv_store.lua` (`GetOrbPersistenceInfo/GetOrbSchemaInfo/GetOrbSchemaPolicy`); `core/db.lua` больше не собирает schema/persistence info вручную из descriptor + hardcoded fallback strings.
- `done`: diagnostic persistence consumers поджаты к owner services: `sv_doctor.lua` теперь берёт canonical stores через `ns.persistence` when available и строит storage labels из descriptors, а `debug_commands.lua` предпочитает `persistence.GetConfigRoot()` вместо локального store fallback.
- `done`: transfer export path больше не падает обратно на `ns.EnsureCanonicalPersistenceStores()`; `core/transfer.lua` теперь берёт canonical roots через `ns.persistence.GetCanonicalStores()` или `ns.store.GetCanonicalStores()`.
- `done`: boundary между `config.lua` и `core/sv_store.lua` оформлен явным owner service `ns.configPersistence`; `sv_store.lua` теперь берёт canonical roots/config schema/reconcile через один owner contract вместо россыпи `ns.EnsureCanonicalPersistenceStores` / `ns.SetCanonical*` / `ns.GetConfigSchema*`.
- `done`: raw canonical root owner вынесен из `config.lua` в отдельный `core/config_persistence_owner.lua`; `config.lua` теперь отвечает за config schema/defaults/proxy/reconcile поверх owner service, а `sv_store.lua` требует `ns.configPersistence` как обязательный контракт.
- `done`: после extraction boundary убраны лишние optional branches: `sv_store.lua` больше не трактует config schema owner как optional path, а `sv_doctor.lua` больше не ходит в legacy canonical-root fallback поверх нового owner service.
- `done`: `core/sv_store.lua` теперь публикует namespace-owned `ns.persistence` facade для reset/reconcile/schema-report/runtime-rebuild/root-replacement/runtime-state access.
- `done`: `settings_general.lua`, `core/lib.lua`, `core/slashcmd.lua`, `core/transfer.lua`, `core/group_policy.lua`, `core/unit_policy.lua` больше не ходят в reset/reconcile/rebuild flows через разрозненные `ns.ResetPersistenceRoots` / `ns.ReconcilePersistenceStores` / `ns.SVRebuildRuntime` как primary consumer path; normal path теперь идёт через `ns.persistence`.
- `done`: `core/settings_main.lua` больше не держит fallback на `ns.GetConfigStore/ns.SetConfigStore`, а `core/sv_doctor.lua` больше не читает config/doctor runtime через legacy global entrypoints как primary path; оба consumer'а теперь опираются на owner store/service surfaces.
- `done`: введён `storeApi.GetOrbConfig(orbType)`; `core/orb_runtime.lua`, `units/player.lua` и orb-tag accessors в `core/tags.lua` больше не читают один и тот же char store через смесь `ns.store.GetOrbCharRoot()` / `db:GetCharStore()` / `db.char` как primary path.
- `note`: это ещё не финальная чистка orb UI domain; compatibility fallback на `db.char` местами ещё оставлен, но уже не должен быть normal path.
- `note`: owner implementation всё ещё остаётся в `config.lua` + `sv_store.lua`, а `ns.persistence` пока именно service facade, не отдельный новый storage owner.
- `done`: `core/target_castbar.lua` теперь держит explicit cast context (`UnitGUID`, cast/castbar ids, `spellID`, start/end ms) и не применяет stale stop/fail/interrupt visuals, если `target` уже указывает на другую цель или на новый активный каст.
- `note`: это закрывает static identity guard, но не заменяет live matrix в клиенте; `interrupt/channel/empower/reverse-channel` всё ещё надо прогнать руками.
- `done`: `focus.lua` больше не оставляет castbar на голом oUF lifecycle; focus castbar теперь тоже bind'ится к identity-safe runtime из `core/target_castbar.lua`.
- `done`: для `boss` добавлен addon-owned mini castbar path: default `units.boss.castbar`, self-anchor support в `core/lib.lua` через `af = "$parent"`, и bind runtime по `boss1..N`.
- `note`: boss/focus теперь делят один runtime contract с `target`, но без отдельного settings surface; пока они живут на своих локальных `castbar.color` defaults/fallback colors.
- `done`: standalone poller для `targettarget` теперь хотя бы делит active visual contract с shared runtime: channel/non-interrupt/empower state и overlay refresh больше не живут на completely separate color path.
- `note`: у `targettarget` всё ещё нет event-grade fail/interrupted hold, потому что standalone path остаётся polling-only; это по-прежнему live/backlog item, а не закрытая часть refactor.
- `done`: введён `core/settings_actions.lua`; user-facing reset/export/import entrypoints теперь живут в одном service вместо direct вызовов из нескольких control planes.
- `done`: `core/settings_transfer.lua` и `/roth export|import` переведены на `ns.settingsActions`, поэтому transfer UI больше не открывается прямыми ad-hoc вызовами из Settings/slash.
- `done`: полный factory reset теперь тоже имеет один canonical entrypoint: Settings button и новый `/roth svreset` / `/roth factoryreset` идут через один service, а `core/lib.lua` оставлен compatibility facade.
- `done`: введён `core/debug_commands.lua`; diagnostic/admin actions (`schema`, `settingsschema`, `smoke`, `aurastats`, `svcheck`, `svreconcile`, `svrebuild`, `blizzrestore`, `blizzstatus`, `log`, `debug`, `perf`) теперь живут в отдельном service вместо размазанной логики внутри slash parser.
- `done`: `/roth` теперь тоньше как control plane: `core/slashcmd.lua` в основном парсит команды и делегирует debug/admin работу в `ns.debugCommands`, а user-facing actions оставляет за `ns.settingsActions`.
- `done`: mover/admin surface (`unlock*`, `lock*`, `reset*`, `dump`) тоже переведён на `ns.debugCommands`, поэтому `slashcmd.lua` больше не держит собственные mover selection/reset helpers и локальную persistence dump orchestration.
- `done`: `modules/Roth_UI_rActionBarStyler/core/background.lua` больше не фильтрует Edit Mode refresh по мёртвому `self == MainActionBar` guard на mixin method; main-bar artwork теперь обновляется через реальный `EditModeActionBarSystemMixin:RefreshBarArt` hook и helper по `MainBar` system contract.
- `done`: `core/transfer.lua` больше не использует `ns.SanitizePersistenceStores` / `ns.EnsureCanonicalPersistenceStores` как primary export path; transfer export/import теперь идёт через расширенный `ns.persistence` service (`Sanitize`, `GetCanonicalStores`, `RunDoctor`) и оставляет direct owner calls только compatibility fallback.
- `done`: orb config resolution полностью сведён к owner store service: `storeApi.GetOrbConfig()` теперь умеет возвращать defaults fallback сам, `core/tags.lua` и `units/player.lua` больше не делают локальный fallback на `db.char`/`db:GetOrbDefaults()`, а `core/db.lua` template-save/load path читает текущий char store через owner API вместо direct `db.char` cache.
- `done`: `core/settings_orbs.lua` больше не знает про raw orb char root/defaults root и legacy alias cleanup для `value.bot`; alias-aware read/write и defaults fallback вынесены в `storeApi.GetOrbConfigValue/SetOrbConfigValue` внутри `core/sv_store.lua`, а orb settings UI остался thin consumer-слоем.
- `done`: `core/settings_main.lua` больше не держит собственный config-store fallback engine с `GetConfigRoot/SetConfigRoot/WritePath`; normal Settings UI path теперь идёт через `storeApi.GetConfigValue/SetConfigValue`, а storage knowledge остаётся внутри `core/sv_store.lua`.
- `done`: `core/settings_target.lua` и key admin writes в `core/debug_commands.lua` больше не пишут config через прямой `ns.SVSet`; target castbar color contract, `framesLocked` и Blizzard-restore toggles теперь идут через `storeApi.SetConfigValue`, а `core/orb_runtime.lua` больше не тянет весь config root ради чтения `font`.
- `done`: mover persistence helpers в `core/lib.lua` больше не читают и не пишут `movers.*` через raw `ns.SVGet/ns.SVSet`; normal path теперь тоже идёт через `storeApi.GetConfigValue/SetConfigValue`.
- `done`: diagnostic/persistence control plane поджат к одному owner service: `core/sv_store.lua` теперь реально публикует `persistence.GetConfigRoot/GetDebugState/GetLog/ClearLog/GetScanStores/GetStorageLabels`, а `core/debug_commands.lua` и `core/sv_doctor.lua` больше не держат собственные fallback-деревья для config root/doctor state/scan labels.
- `done`: `debug_commands.lua`, `settings_actions.lua`, `settings_general.lua`, `core/lib.lua`, `group_policy.lua` и `unit_policy.lua` больше не трактуют `ns.persistence` / `SetConfigValue` как optional normal-path dependency; control plane теперь идёт через обязательные owner methods (`ResetAndReload`, `RebuildRuntime`, `ReportSchema`, `RunDoctor`, `Reconcile`).
- `done`: `init.lua` больше не прогревает runtime config через legacy `ns.GetConfigStore()`; bootstrap теперь требует owner service `ns.persistence.GetConfigRoot()`, а `ns.cfgSaved` явно остаётся только compatibility mirror.
- `done`: export/import orchestration тоже поджат к owner service: `core/sv_store.lua` теперь публикует `persistence.GetTransferRoots/ApplyTransferRoots`, а `core/transfer.lua` больше не оркестрирует sanitize + canonical root selection + replace/reconcile/rebuild через россыпь fallback-веток.
- `done`: action-bar ownership boundary формализован в ship mode: `core/bar_runtime_registry.lua` теперь владеет explicit ownership matrix + shell/dock API (`GetBottomClusterLayout`, `GetVisibleAuxRowCount`, `GetArtworkTier`, `ResolveDockMember`), `dock.lua` оставлен pure layout consumer-слоем, а `background.lua` больше не зависит от локального `ActionBarShell` geometry/tier logic.
- `next`: после этого нужен live-pass по mini castbars (`targettarget`, `focus`, `boss`) на overlap `interrupt/fail/stop/channel`; `targettarget` уже переведён на standalone path, но визуальный fail/interrupt contract всё ещё надо проверить в клиенте.
- `next`: следующий большой pass уже не про legacy `rActionBarStyler` shell split; теперь логичнее добивать `persistence` или оставшийся manual Blizzard-bar wrapper ownership drift.
- `next`: после этого вернуться к persistence/group aura backlog, потому что action bar ownership boundary станет заметно чище.

## Быстрый статус по подсистемам

- `yellow-red`: action bars.
  Shell/layout cluster уже вынесен в `core/action_bar_*`, а embedded `rActionBarStyler` больше не владеет bar shell runtime; главный оставшийся риск теперь в том, что Roth всё ещё вручную репарентит и раскладывает Blizzard bar surfaces через wrapper frames, а не в old-vs-new split.
- `yellow-red`: persistence/service ownership.
  Direct reset/reconcile/rebuild consumers уже сведены к `ns.persistence`, а runtime lookup drift и consumer fallback на `ns.cfgSaved` в основном убраны, но canonical roots/schema ownership всё ещё размазан между `config.lua`, `core/sv_store.lua` и `core/db.lua`.
- `yellow-red`: group aura stack.
  Safe debuff recolor, native raid auras и safe AuraWatch replacement уже на месте; остались mainly defaults/polish вопросы и старый dead watch code, который можно потом удалить.
- `yellow-red`: group header visibility/service ownership.
  Дубли visibility driver уже вынесены в общий helper, но aura/color runtime для group frames всё ещё не возвращён.
- `yellow-red`: `frame_policy.lua` / policy split.
  Основной runtime policy уже разрезан, но ещё остаётся дочистить shared helpers и старый Blizzard restore/debug toolbox.
- `yellow`: ExtraActionBar / ZoneAbility.
  Holder-path уже переведён на shared-container follower модель, но теперь надо отдельно дочистить stale config/UX assumptions вокруг старого `extrabar.pos` ownership.
- `yellow`: deferred refresh spray.
  Основные hot paths уже переведены на shared deferred scheduler; остаются только отдельные единичные таймеры вне этого ядра.
- `yellow`: target castbar.
  Основной target runtime уже вынесен, target cast identity guard добавлен, а targettarget callback drift закрыт; дальше нужен именно live-pass на races: interrupt, channel, empower, fail/stop overlap.
- `yellow`: focus/boss castbars.
  Focus уже сидит на том же identity-safe runtime, а boss наконец получил свой mini castbar path; дальше нужен только live-pass на visual overlap и spacing.
- `yellow`: targettarget standalone castbar.
  Active visual contract уже частично унифицирован с target/focus/boss runtime, но fail/interrupted hold и polling races всё ещё нельзя считать окончательно закрытыми без клиента.
- `yellow`: monolith split.
  `core/lib.lua`, `units/player.lua`, `core/bars.lua`, `config.lua` всё ещё держат слишком много разных доменов.
- `yellow`: global registries.
  Runtime ownership уже переведён в `ns.frameRegistry`; оставшийся долг - когда будет удобно, убрать compatibility mirror globals и дочистить legacy slash/debug assumptions.

## Что уже реально хорошо

- `confirmed-static`: target castbar уже вынесен из `units/target.lua` в `core/target_castbar.lua`; это правильный direction.
- `confirmed-static`: target auras уже сидят на native aura frame path, а не на старом небезопасном blind-scan подходе.
  Смотреть: `units/target.lua:201-233`, `core/lib.lua:551-569`.
- `confirmed-static`: часть Secret Value hardening уже вынесена из старого монолита в runtime-файлы.
  Смотреть: `core/unit_misc_runtime.lua`, `core/unit_value_runtime.lua`, `core/orb_runtime.lua`.
- `confirmed-static`: party/raid lifecycle уже не полностью в одном месте.
  Смотреть: `units/party.lua`, `units/raid.lua`, `core/frame_policy.lua`.
- `confirmed-static`: в аддоне уже есть полезные diagnostic surfaces.
  `slashcmd.lua` умеет `schema`, `svreconcile`, `aurastats`, `blizzstatus`, `smoke`.

## Что добавляю к старому backlog как самые важные текущие выводы

- `new-confirmed`: group aura/color возврат не надо проектировать с нуля.
  В `core/unit_misc_runtime.lua:171-189` уже есть Secret-aware `func.checkColors`, а в `core/lib.lua:450-559` уже есть native aura timer/border path для target-like frames.
  Реальная задача: собрать из этого безопасный group aura contract, а не снова оживлять старый oUF aura blob целиком.
- `new-confirmed`: oUF group header visibility надо нормализовать через один helper/service.
  Сейчас одинаковая логика driver cleanup/apply дублируется в `units/party.lua:325-343` и `units/raid.lua:656-660`.
- `new-confirmed`: settings apply-path и frame policy используют одинаковый retry-стиль, но без общего scheduler/service.
  Это уже не "несколько harmless таймеров", а повторяющийся orchestration pattern.
- `new-confirmed`: `core/lib.lua` всё ещё содержит unrelated domains в одном месте.
  Там одновременно aura timers, castbar spark polling, font registry, mover registry, reset helpers и др.
- `new-confirmed`: slash/runtime registry ещё не переведены в namespace-owned service.
  Сейчас глобальные списки создаются в `core/slashcmd.lua:71-107`, а потом пополняются из `core/lib.lua:1170-1171`, `units/party.lua:294`, `units/raid.lua:687`, `units/boss.lua:187`.

## Подтверждённые API и source notes

- `lookup_api("UnitCastingInfo")`:
  возвращает `castID` как 7-й return и `notInterruptible` как 8-й return.
- `lookup_api("UnitChannelInfo")`:
  возвращает `notInterruptible` как 7-й return, `spellID` как 8-й return, `isEmpowered` как 9-й return.
- `lookup_api("C_AddOns.IsAddOnLoaded")`:
  возвращает `loadedOrLoading, loaded`.
- `lookup_api("C_AddOns.LoadAddOn")`:
  возвращает `loaded, value`.
- `lookup_api("C_ActionBar.HasVehicleActionBar")`:
  возвращает `hasVehicleActionBar`.
- `lookup_api("C_ActionBar.GetOverrideBarSkin")`:
  возвращает `textureFileID`.
- `lookup_api("UnitVehicleSkin")`:
  возвращает `fileID`.
- `lookup_api("UnitHasVehicleUI")`:
  возвращает `boolean`.
- `lookup_api("RegisterStateDriver")` и `lookup_api("UnregisterStateDriver")` не дали match.
  Это всё ещё `unconfirmed` через MCP, но `confirmed-static` по Blizzard source и oUF docs:
  `Blizzard_RestrictedAddOnEnvironment/SecureStateDriver.lua`, `_Reference/ReferenceAddonsFull/oUF/ouf.lua:603-617`.
- `confirmed-static`: `MainActionBarMixin:AttachToFrame(frame)` и `ActionBarMixin:UpdateGridLayout()` подтверждают, что Blizzard считает action bars одной layout-system.
  Смотреть: `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_ActionBar/Shared/MainActionBar.lua:33-53`,
  `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_ActionBar/Shared/ActionBar.lua:93-141`.
- `confirmed-static`: `EditModeActionBarSystemMixin:UpdateSystemSetting*` подтверждает, что art/layout/rows/padding/visibility связаны одним system owner.
  Смотреть: `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_EditMode/Shared/EditModeSystemTemplates.lua:921-1169`.
- `confirmed-static`: `ExtraActionBar_Update()` добавляет `ExtraActionBarFrame` в `ExtraAbilityContainer`, а сам контейнер делает `frameToAdd:SetParent(self)`.
  Это прямое подтверждение shared-container модели для ExtraAction/ZoneAbility.
  Смотреть: `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_ActionBar/Shared/ExtraActionBar.lua:10-29`,
  `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_UIPanels_Game/Shared/ExtraAbilityContainer.lua:26-80`.

## Как реально идти по работе

1. Сначала закрыть ownership boundary по action bars и ExtraAction/ZoneAbility.
   Пока этого нет, остальные UI правки по нижнему кластеру будут снова расползаться между legacy и runtime.
2. Потом вернуть group aura/color pipeline в безопасной форме.
   Не реанимировать старый oUF aura blob целиком; брать safe pieces из `core/unit_misc_runtime.lua` и `core/lib.lua`.
3. После этого сжать persistence до одного owner service.
   Иначе settings/slash/transfer будут продолжать тащить внутрь себя storage knowledge.
4. Затем разрезать `frame_policy.lua` и вынести единый deferred refresh scheduler.
   Это уменьшит количество "повтори через 0 и 0.2" костылей по всему аддону.
5. Только после стабилизации поведения идти в monolith split, registry cleanup и media cleanup.

## Если надо быстро понять, какие разделы читать дальше

- Для доведения action bar стека:
  читать `PRIORITY 0`, `PRIORITY 1`, `PRIORITY 2`, appendix `E1`.
- Для group/oUF/runtime слоя:
  читать `PRIORITY 4`, `PRIORITY 5`, `PRIORITY 8`, appendix `E5`, `C6`.
- Для persistence/settings/slash:
  читать `PRIORITY 3`, `PRIORITY 6`, appendix `A6`.
- Для больших structural cleanup задач:
  читать `PRIORITY 7`, `PRIORITY 8`, `PRIORITY 10`, `PRIORITY 11`.

## Приоритетный backlog

# PRIORITY 0 - Зафиксировать ship mode до следующего implementation pass

## Проблема

Сейчас в проекте одновременно живут две разные стратегии:

- legacy strategy:
  Blizzard main/multi bars репарентятся и раскладываются вручную;
- new runtime strategy:
  новые `core/*` слои пытаются строить поверх этого modular policy/runtime.

Это нормально как стадия миграции, но плохо как бессрочное состояние.

## Что делать

- До начала новых фич по барам зафиксировать целевой режим.
- Для ближайшего доведения рекомендую `ship mode`:
  не добавлять новые bar features в legacy stack, а только стабилизировать ownership boundaries.
- Формально описать ownership matrix в начале implementation pass:
  `bar-shell owner`, `art owner`, `dock owner`, `settings owner`, `persistence owner`.

## Пример

```lua
ns.ownership = {
  actionShell = "legacy_rABS",
  actionArtwork = "background_runtime",
  bottomDock = "dock_runtime",
  persistence = "canonical_sv_store",
}
```

## Альтернатива

- `Long-term rewrite mode`: сразу уходить в свои addon-owned bars по модели единого LAB/secure-owner.
- Это правильнее архитектурно, но это уже отдельный крупный этап, а не "быстро доделать".

## Где смотреть

- `modules/Roth_UI_rActionBarStyler/core/bar1.lua:30-136`
- `modules/Roth_UI_rActionBarStyler/core/dock.lua:7-257`
- `modules/Roth_UI_rActionBarStyler/core/background.lua:238-396`

## Done when

- Есть письменное решение, какой слой за что отвечает.
- Новые bar-related правки больше не размазываются одновременно по legacy и new core.

# PRIORITY 1 - Action-bar shell cluster надо довести как единый refactor, а не по файлам

## Проблема

`confirmed-static`:

- `bar1.lua` делает `MainActionBar:AttachToFrame(frame)` или `SetParent(frame)`, потом сам двигает `ActionButton1..12`.
- `bar2.lua` / `bar3.lua` / `bar4.lua` / `bar5.lua` двигают `MultiBar*` и их кнопки.
- `dock.lua` вычисляет геометрию от legacy shell names.
- `background.lua` принимает решения по artwork, глядя на `MultiBarBottomLeft:IsShown()` / `MultiBarBottomRight:IsShown()` и хукая `EditModeActionBarSystemMixin`.

Это один связанный кластер, а не несколько независимых файлов.

## Почему это плохо

Blizzard сам считает action bars единой системой:

- `ActionBarMixin:UpdateGridLayout()` строит grid layout;
- `MainActionBarMixin:AttachToFrame()` хранит attach state;
- `EditModeActionBarSystemMixin` обновляет orientation / rows / icon size / padding / bar art / visible setting.

Если Roth одновременно владеет layout вручную, то любой future refactor может сломать Edit Mode, visibility, flyout direction или artwork refresh.

## Что делать

- Сначала развязать потребителей геометрии от legacy frame names.
- Вынести единый bar-shell adapter, который умеет отвечать:
  - каков bounds нижнего action cluster;
  - сколько сейчас видно action rows;
  - какой bar art variant должен быть активен.
- Только после этого решать, остаётся legacy owner или заменяется полностью.

## Пример

```lua
ns.barShell = ns.barShell or {}

function ns.barShell:GetBottomClusterBounds()
  local anchor = _G.rAbs_MainMenuBar or _G.MainActionBar or _G.MainMenuBar
  if not anchor or not anchor.GetLeft or not anchor.GetRight then
    return nil
  end
  return anchor:GetLeft(), anchor:GetRight(), anchor:GetTop()
end
```

## Альтернатива

- Полный переход на свои secure bars по модели единого LAB/secure-owner.
- Для "доделать сейчас" это слишком большой объём. Для "починить архитектуру правильно" это лучший long-term путь.

## Где смотреть

- `modules/Roth_UI_rActionBarStyler/core/bar1.lua:49-103`
- `modules/Roth_UI_rActionBarStyler/core/bar2.lua`
- `modules/Roth_UI_rActionBarStyler/core/bar3.lua`
- `modules/Roth_UI_rActionBarStyler/core/bar4.lua`
- `modules/Roth_UI_rActionBarStyler/core/bar5.lua`
- `modules/Roth_UI_rActionBarStyler/core/dock.lua:12-18`
- `modules/Roth_UI_rActionBarStyler/core/background.lua:238-394`
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_ActionBar/Shared/ActionBar.lua:93-141`
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_ActionBar/Shared/MainActionBar.lua:33-53`
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_EditMode/Shared/EditModeSystemTemplates.lua:921-1138`
- `_Info/KB/nodes/BlizzardUI_ActionBars.md`

## Done when

- `dock.lua` и `background.lua` больше не знают про `rAbs_MainMenuBar` / `rABS_*`.
- В проекте остаётся один bar-shell owner, а не смесь legacy + observer logic.

# PRIORITY 2 - ExtraActionBar и ZoneAbility надо окончательно перевести в holder-only модель

## Проблема

Комментарий в `extrabar.lua` правильный:

- "Keep Blizzard ownership of ExtraActionBarFrame itself."

Но код всё ещё делает:

- `ExtraActionBarFrame:SetScale(...)`
- `ExtraActionBarFrame:ClearAllPoints()`
- `ExtraActionBarFrame:SetPoint("CENTER", frame, "CENTER")`

Подтверждение:

- `modules/Roth_UI_rActionBarStyler/core/extrabar.lua:62-68`

## Почему это плохо

Blizzard реально двигает ExtraActionBar через shared container:

- `ExtraActionBar_Update()` делает `ExtraAbilityContainer:AddFrame(bar, ExtraActionButtonPriority)`;
- `ExtraAbilityContainerMixin:AddFrame()` сам вызывает `frameToAdd:SetParent(self)`;
- `ZoneAbilityFrameMixin:UpdateDisplayedZoneAbilities()` использует тот же `ExtraAbilityContainer`.

То есть ExtraAction и ZoneAbility это одна система контейнера, а не два независимых Roth-бара.

## Что делать

- Оставить Roth только owner'ом holder art, drag handle и mouseover frame.
- Не двигать `ExtraActionBarFrame` напрямую.
- Если нужен кастомный layout сверх Blizzard container, это уже отдельный secure replacement path.

## Пример

```lua
local function SyncExtraHolder()
  local holder = _G.rABS_ExtraBar
  local container = _G.ExtraAbilityContainer
  if not (holder and container) then
    return
  end

  holder:SetShown(container:IsShown())
end
```

## Альтернатива

- Если пользователь хочет жёстко своё положение extra button, надо строить свой owner-created secure button.
- Не надо маскировать это под "чуть-чуть поправим Blizzard frame".

## Где смотреть

- `modules/Roth_UI_rActionBarStyler/core/extrabar.lua:30-109`
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_ActionBar/Shared/ExtraActionBar.lua:10-29`
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_UIPanels_Game/Shared/ExtraAbilityContainer.lua:26-68`
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_ZoneAbility/ZoneAbility.lua:106-176`

## Done when

- В `extrabar.lua` больше нет `ClearAllPoints` / `SetPoint` / `SetScale` на `ExtraActionBarFrame`.
- Holder art следует за контейнером, а не пытается владеть контейнером.

# PRIORITY 3 - Persistence ownership надо сжать до одного сервиса

## Проблема

Сейчас persistence всё ещё имеет несколько полувладельцев:

- `core/sv_store.lua` строит fallback canonical stores;
- `core/db.lua` тоже умеет строить fallback stores;
- `core/settings_general.lua` умеет reset roots;
- `core/lib.lua` тоже умеет reset roots;
- `core/slashcmd.lua` умеет reconcile / schema / rebuild и частично живёт в том же домене.

## Что делать

- Сделать один persistence service, который владеет:
  - canonical root discovery;
  - reset;
  - reconcile;
  - schema report;
  - runtime rebuild.
- `db.lua` оставить только orb-domain API.
- `settings_general.lua` и `slashcmd.lua` должны только вызывать service API, а не знать про fallback globals.

## Пример

```lua
ns.persistence = ns.persistence or {}

function ns.persistence:ResetAll()
  ns.ResetPersistenceRoots()
  if ReloadUI then
    ReloadUI()
  end
end
```

## Альтернатива

- Мягкая чистка:
  оставить текущие fallback paths, но объявить `sv_store.lua` единственным root owner.
- Жёсткая чистка:
  убрать fallback construction из `db.lua` полностью.

## Где смотреть

- `core/sv_store.lua:22-92`
- `core/db.lua:43-132`
- `core/settings_general.lua:217-240`
- `core/lib.lua:2264-2302`
- `core/slashcmd.lua:289-447`

## Done when

- Любой reset / reconcile / export / import идёт через один service API.
- `db.lua` больше не создаёт canonical fallback roots сам.

# PRIORITY 4 - `frame_policy.lua` надо разрезать на реальные роли

## Проблема

`confirmed-static`: файл сейчас одновременно делает:

- group policy;
- unit policy;
- LoD для Blizzard frames;
- global font replacement;
- startup event orchestration.

Это слишком много для одного файла и одного ownership boundary.

## Что делать

- Разбить минимум на:
  - `core/group_policy.lua`
  - `core/unit_policy.lua`
  - `core/font_policy.lua`
- LoD/bootstrap path вынести в отдельный coordinator.
- Для LoD использовать уже подтверждённый паттерн:
  `C_AddOns.IsAddOnLoaded` + `EventUtil.ContinueOnAddOnLoaded`.

## Пример

```lua
local function ContinueOnBlizzardUnitFrames(callback)
  local _, loaded = C_AddOns.IsAddOnLoaded("Blizzard_UnitFrame")
  if loaded then
    callback()
    return
  end

  EventUtil.ContinueOnAddOnLoaded("Blizzard_UnitFrame", callback)
end
```

## Альтернатива

- Если не хочется дробить файл сразу, хотя бы ввести service tables:
  `func.groupPolicy`, `func.unitPolicy`, `func.fontPolicy`.

## Где смотреть

- `core/frame_policy.lua:619-845`
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_SharedXML/EventUtil.lua:71-79`
- `lookup_api("C_AddOns.IsAddOnLoaded")`
- `lookup_api("C_AddOns.LoadAddOn")`

## Done when

- Group toggles не знают ничего про fonts.
- Font application не знает ничего про Blizzard party/raid restore.
- LoD helpers живут отдельно от visual policy.

# PRIORITY 5 - Group runtime надо дожать до одной модели поверх oUF headers

## Проблема

Party, raid и range сейчас уже вынесены, но всё ещё похожи на три соседних subsystem'а:

- party header lifecycle: `units/party.lua`
- raid header lifecycle: `units/raid.lua`
- range driver lifecycle: `core/lib.lua`

При этом `party.lua` и `raid.lua` повторяют похожий visibility/combat-queue код.

## Что делать

- Вынести shared helpers для group headers:
  - `ApplyHeaderVisibility`
  - `ParkHeader`
  - `QueueHeaderEnableAfterCombat`
  - `RefreshHeaderRange`
- Формально решить, какой range driver основной.

Моя рекомендация:

- short-term:
  оставить оба режима (`blizzard` и `ouf`), но считать `ouf` более простой baseline;
- long-term:
  либо полностью жить на oUF Range element, либо полностью на своём driver;
  не держать это как вечный гибрид.

## Пример

```lua
local function ConfigureRange(frame, outsideAlpha)
  frame.Range = frame.Range or {}
  frame.Range.insideAlpha = 1
  frame.Range.outsideAlpha = outsideAlpha or 0.55
end
```

## Альтернатива

- Оставить свой Blizzard-style driver как основной.
- Это допустимо, если в live-тесте он реально даёт лучший UX и не создаёт event-noise.

## Где смотреть

- `units/party.lua:325-531`
- `units/raid.lua:656-813`
- `core/lib.lua:1977-2189`
- `_Reference/ReferenceAddonsFull/oUF/elements/range.lua:31-107`
- `lookup_api("UnitInRange")`
- `_Info/KB/nodes/BlizzardUI_UnitFrames.md`

## Done when

- В проекте есть одна group-runtime vocabulary.
- Party/raid не дублируют одни и те же queue/visibility helper'ы.
- Range policy меняется через один adapter.

# PRIORITY 6 - Settings UI и slash commands надо развести по ролям

## Проблема

Сейчас `settings_general.lua` и `slashcmd.lua` оба лезут в runtime orchestration:

- reset;
- schema/debug;
- smoke;
- export/import;
- bar refresh;
- Blizzard restore.

Это повышает связность и мешает понять, что является user-facing supported feature, а что purely diagnostic tool.

## Что делать

- Settings UI:
  только user-facing persisted options.
- Slash:
  только diagnostics / debug / repair commands.
- Оба слоя должны вызывать одни и те же service functions.

## Пример

```lua
ns.debugCommands = ns.debugCommands or {}

function ns.debugCommands.RunSchemaReport()
  if ns.PersistenceSchemaReport then
    ns.PersistenceSchemaReport(true)
  end
end
```

## Альтернатива

- Не убирать команды, а хотя бы генерировать `/roth` help из одного registry.

## Где смотреть

- `core/settings_general.lua:258-588`
- `core/slashcmd.lua:206-589`
- `core/settings_transfer.lua`
- `core/transfer.lua`

## Done when

- Любой action доступен из одного canonical service.
- Settings и slash больше не дублируют бизнес-логику.

# PRIORITY 7 - Target castbar надо закрыть live-проверкой и identity guard

## Проблема

`core/target_castbar.lua` уже выглядит хорошо, но есть два остаточных риска:

- визуал полагается на повторные опросы `UnitCastingInfo` / `UnitChannelInfo`;
- race между interrupt/fail/target swap без явного сохранённого cast identity всё ещё возможен.

`oUF` сам документирует похожую проблему на castbar boundary.

## Что делать

- При `PostCastStart` / `PostChannelStart` сохранять `castID` или `castBarID`, если он доступен.
- При interrupt/fail/update сверять событие с активной cast identity.
- Прогнать live matrix:
  normal cast, channel, empowered, interrupt, focus swap, target swap, fast recast.

## Пример

```lua
function runtime.PostCastStart(bar, unit)
  local _, _, _, _, _, _, castID, notInterruptible = UnitCastingInfo(unit)
  bar._rothCastID = castID
  bar._rothNotInterruptible = notInterruptible
  ApplyCurrentCastVisual(bar, unit, notInterruptible)
end
```

## Альтернатива

- Оставить текущую модель как есть, если live-проверка покажет, что для target-only сценария она достаточно стабильна.

## Где смотреть

- `core/target_castbar.lua:181-309`
- `core/target_castbar.lua:399-501`
- `_Reference/ReferenceAddonsFull/oUF/elements/castbar.lua:195-223`
- `_Reference/ReferenceAddonsFull/oUF/elements/castbar.lua:459-479`
- `lookup_api("UnitCastingInfo")`
- `lookup_api("UnitChannelInfo")`

## Done when

- Нет зависшего non-interrupt overlay после interrupt/channel transitions.
- Нет ложного текста `Interrupted` при быстром ретаргете.

# PRIORITY 8 - Отдельно почистить dormant code, media и legacy vocabulary

## Проблема

Есть код, который либо уже не используется, либо должен жить только как временный fallback:

- `core/unit_misc_runtime.lua:171-189` делает full harmful aura scan;
- в `units/party.lua` и `units/raid.lua` этот путь уже отключён;
- media пакет очень большой и наверняка содержит лишнее;
- legacy globals ещё упоминаются в reset/persistence paths.

## Что делать

- Либо удалить dormant aura scan path, либо явно пометить как `experimental-disabled`.
- Сделать инвентаризацию media и убрать реально неиспользуемые текстуры/шрифты.
- Прогнать один отдельный pass по legacy global vocabulary:
  `Roth_UI_Config`, `Roth_UI_DB_CHAR`, `Roth_UI_DB_GLOB`.

## Альтернатива

- Не удалять сразу, а оставить behind debug flag на время перехода.

## Где смотреть

- `core/unit_misc_runtime.lua:132-214`
- `units/party.lua:231-275`
- `units/raid.lua:608-625`
- `core/sv_store.lua:94-199`
- `core/lib.lua:2288-2295`

## Done when

- Нет неиспользуемого hot-path кода "на всякий случай".
- Legacy globals больше не являются normal runtime vocabulary.

## Live verification checklist для следующего implementation pass

- `/reload` без Lua errors.
- `/roth smoke full`
- `/roth schema`
- `/roth svreconcile`
- `/roth aurastats reset`
- включение/выключение party и raid без taint и без потери Blizzard fallback
- Edit Mode: изменить rows / icon size / hide bar art и проверить, что Roth не спорит с клиентом
- vehicle / override / possess / extra action / zone ability
- target castbar: interrupt, channel, empowered, retarget
- export/import/reset settings

## Что это за документ

Это не список абстрактных пожеланий, а статический аудит текущего состояния `Roth_UI`.

Цель документа:
- зафиксировать, что уже сделано хорошо;
- отделить реально незавершённые вещи от старых догадок;
- показать, что именно в коде сейчас плохое;
- дать подробный plan of attack: проблема -> почему это проблема -> варианты -> рекомендованное решение -> где смотреть примеры.

Ограничения этого прохода:
- это статический аудит кода, не live-тест в игре;
- всё, что помечено как `runtime-unconfirmed`, надо перепроверять в клиенте;
- всё, что помечено как `confirmed-static`, подтверждено текущим исходником.

## Что было просмотрено

Основные файлы addon:
- `Roth_UI.toc`
- `init.lua`
- `config.lua`
- `core/sv_store.lua`
- `core/db.lua`
- `core/lib.lua`
- `core/settings_general.lua`
- `core/frame_policy.lua`
- `core/target_castbar.lua`
- `modules/Roth_UI_rActionBarStyler/bootstrap.lua`
- `modules/Roth_UI_rActionBarStyler/core/bar1.lua`
- `modules/Roth_UI_rActionBarStyler/core/multibar_visibility.lua`
- `modules/Roth_UI_rButtonTemplate/bootstrap.lua`

Инженерные заметки `_Info`:
- `_Info/KB/core/BlizzardUI_SubsystemRouter.md`
- `_Info/KB/nodes/BlizzardUI_ActionBars.md`
- `_Info/KB/nodes/BlizzardUI_UnitFrames.md`

## Быстрые факты по аддону

- `confirmed-static`: в аддоне `79` Lua-файлов.
- `confirmed-static`: всего `308` файлов.
- `confirmed-static`: размер пакета `33.66 MB`.
- `confirmed-static`: в `media/` лежит `186` `.tga` и `10` `.ttf`.
- `confirmed-static`: в коде не найдено явных `TODO/FIXME/XXX/HACK` маркеров.

Вывод из последнего пункта:
- техдолг уже не маркирован комментариями;
- он сидит в архитектуре и пересекающихся ownership-моделях.

## Короткий диагноз

### Что уже сделано хорошо

1. Убран Ace-era bootstrap.
- `init.lua` и `config.lua` уже переводят аддон на более прямую модель runtime + SavedVariables.
- Это правильное направление.

2. Появился safety layer.
- Видно, что код уже осознаёт `Forbidden Tables`, `Secret Values`, сериализацию и sanitation.
- Это важно для Midnight.

3. Target castbar уже двигается в правильную сторону.
- `core/target_castbar.lua` больше не выглядит как старая попытка просто красить Blizzard art в лоб.
- Это уже отдельный semantic runtime слой.

4. Настройки уже не сводятся только к slash commands.
- Есть `settings_*` слой.
- Это хороший фундамент для нормального UX.

5. Persistence уже лучше, чем в старых версиях.
- Есть canonical root идея.
- Есть runtime-only state buckets.
- Есть sanitization.

### Что сейчас реально мешает закончить аддон

1. Главная проблема не в том, что не хватает ещё пары функций.
- Главная проблема в том, что один и тот же UI surface местами принадлежит сразу двум системам.

2. Самый опасный участок сейчас: action bars.
- Новый core уже существует.
- Но legacy actionbar stack всё ещё живой и всё ещё активно владеет Blizzard bars.

3. Вторая проблема: persistence ownership размазан.
- `config.lua`, `core/sv_store.lua`, `core/db.lua`, `core/lib.lua`, `core/settings_general.lua` все участвуют в одной и той же теме.

4. Третья проблема: `frame_policy.lua` делает слишком много.
- Это уже не policy-файл, а смесь policy/debug/recovery/compat.

## Главный вывод

Аддон не выглядит "сломано всё".
Он выглядит как проект, который уже близко к рабочему состоянию, но застрял на уровне ownership и границ между подсистемами.

Самая дорогая ошибка сейчас:
- продолжать чинить симптомы, не убрав двойное владение action bars и persistence.

## Рекомендуемая стратегия

Рекомендован не "один большой rewrite сразу", а гибридный план:

1. Сначала стабилизация.
- Заморозить legacy bar surface.
- Свести ownership к одному месту там, где это можно сделать быстро.
- Убрать дублирующие reset/persistence пути.

2. Потом cleanup.
- Разрезать `frame_policy.lua`.
- Разрезать unit-frame helpers.
- Убрать глобальные регистры.

3. Потом большая архитектурная развилка.
- Или оставить Blizzard bars почти нативными и только оформлять их.
- Или делать свои secure Roth-owned bars.

Рекомендация:
- краткосрочно: стабилизировать старую bar-систему без новых фич;
- среднесрочно: делать Roth-owned secure bars за feature flag;
- ExtraAction/ZoneAbility не переписывать в собственность Roth, а оставить Blizzard-owned.

---

# PRIORITY 0 - Зафиксировать ownership boundary

## Проблема

`confirmed-static`: `Roth_UI.toc` грузит одновременно:
- новый core stack;
- legacy embedded actionbar stack.

Подтверждение:
- `Roth_UI.toc`
- `modules/Roth_UI_rActionBarStyler/rActionBar.xml`
- `modules/Roth_UI_rButtonTemplate/rButton.xml`

`confirmed-static`: legacy модули не просто лежат в папке, а реально адаптируются под новый root namespace.

Подтверждение:
- `modules/Roth_UI_rActionBarStyler/bootstrap.lua:1-50`
- `modules/Roth_UI_rButtonTemplate/bootstrap.lua:1-49`

Оба bootstrap-файла:
- берут `root = _G.Roth_UI`;
- прокидывают `ns.cfg`, `ns.db`, `ns.func`, `ns.unit`, `ns.bars`;
- ставят metatable forwarding.

## Почему это плохо

- Нельзя надёжно чинить поведение, когда layout, visibility, skinning и persistence одновременно живут в старом и новом стекe.
- Любой фикс action bars может сломать mover, mouseover, proxy visibility, Edit Mode, vehicle/override.
- Код становится трудно reasoning-friendly: непонятно, какой слой является source of truth.

## Что делать

1. Ввести явный флаг ownership.
- Пример: `cfg.features.useLegacyBarModules`.

2. Разделить режимы запуска.
- Либо legacy bar modules грузятся.
- Либо грузится только новый bar path.
- Не оба одновременно.

3. Зафиксировать документом, кто чем владеет.

Минимальная ownership matrix:
- `config.lua` -> schema/defaults/canonical config roots
- `core/sv_store.lua` -> API доступа к SV
- `core/db.lua` -> только orb-domain клиент
- `core/frame_policy.lua` -> только policy, не recovery/debug kitchen sink
- `modules/Roth_UI_rActionBarStyler/*` -> либо временно legacy-only, либо на выход

## Варианты

### Вариант A - быстрый ship mode
- Оставить Blizzard bars.
- Не делать новый secure action bar engine прямо сейчас.
- Ограничиться стабилизацией, skinning и очисткой visibility ownership.

Плюсы:
- быстрее;
- меньше риск сломать половину UI за один проход.

Минусы:
- taint/fragility останутся выше;
- Edit Mode и action bar state будут и дальше хрупкими.

### Вариант B - правильный long-term путь
- Сделать Roth-owned secure bars.
- Не использовать Blizzard `ActionButton1..12` и `MultiBar*Button*` как основной layout skeleton.

Плюсы:
- чище ownership;
- меньше борьба с Blizzard layout;
- легче дальше развивать дизайн.

Минусы:
- дорого;
- нужен аккуратный migration path.

## Рекомендация

Рекомендован гибрид:
- сейчас жить как `A`, но без новых legacy bar features;
- параллельно готовить `B` под feature flag.

## Где смотреть

Текущий код:
- `Roth_UI.toc`
- `modules/Roth_UI_rActionBarStyler/bootstrap.lua`
- `modules/Roth_UI_rButtonTemplate/bootstrap.lua`

Документация:
- `_Info/KB/nodes/BlizzardUI_ActionBars.md`

## Done when

- старый и новый bar stack не работают одновременно для одной и той же bar surface;
- по `toc` и bootstrap-коду видно один источник ownership.

---

# PRIORITY 1 - Action bars всё ещё главный риск

## 1.1 Main bar всё ещё принадлежит legacy-модулю

### Проблема

`confirmed-static`: `modules/Roth_UI_rActionBarStyler/core/bar1.lua` до сих пор:
- берёт `MainActionBar` или `MainMenuBar`;
- создаёт свой holder frame;
- делает reparent/attach;
- двигает Blizzard buttons;
- меняет размеры и anchors `ActionButton1..12`;
- вешает свой visibility state driver.

Подтверждение:
- `modules/Roth_UI_rActionBarStyler/core/bar1.lua:22-136`

Самые рискованные места:
- `MainMenuBar:AttachToFrame(frame)` или `MainMenuBar:SetParent(frame)`
- `button:ClearAllPoints()`
- `button:SetPoint(...)`
- `RegisterStateDriver(..., "visibility", ...)`

### Почему это плохо

- Blizzard action buttons и bar containers остаются Blizzard-owned secure поверхностью.
- Roth одновременно хочет владеть layout, fade, mouseover, drag, visibility.
- Это типичный сценарий, где в обычном состоянии всё выглядит нормально, а ломается на vehicle/override/possess/Edit Mode.

### Что делать

1. Заморозить любые новые фичи в legacy `rActionBarStyler`.
2. Описать отдельно:
- layout ownership
- visibility ownership
- artwork ownership
- mover ownership
3. Оставить legacy-код только как временный compatibility layer.
4. Не добавлять туда новые системные зависимости.

### Практический путь

Короткий путь:
- сохранить текущий layout на время;
- убрать дубли visibility owner;
- не трогать больше reparenting beyond current baseline.

Правильный путь:
- сделать Roth-owned secure bars за флагом;
- мигрировать artwork и mover туда;
- Blizzard buttons перестать использовать как главный layout engine.

### Пример структуры нового решения

```lua
local bar = RothUI_CreateSecureBar("Bar1", cfg.bars.bar1)
bar:SetMover("bar1")
bar:SetArtwork(RothUI_ActionBarArt.Bar1)
bar:SetVisibilityProfile("main")
```

Это не готовый код, а target shape:
- ownership у Roth;
- Blizzard numbered buttons не являются layout source.

### Где смотреть

Текущий код:
- `modules/Roth_UI_rActionBarStyler/core/bar1.lua`
- `modules/Roth_UI_rButtonTemplate/core.lua`

Документация:
- `_Info/KB/nodes/BlizzardUI_ActionBars.md`

## 1.2 Multibar visibility сейчас почти наверняка имеет двух владельцев

### Проблема

`confirmed-static`: `modules/Roth_UI_rActionBarStyler/core/multibar_visibility.lua` сам решает, показывать frame или нет.

Подтверждение:
- `modules/Roth_UI_rActionBarStyler/core/multibar_visibility.lua:11-96`

Что именно делает файл:
- читает proxy values через `Settings.GetValue(...)`;
- держит список `managedFrames`;
- вызывает `frame:SetShown(...)`;
- обновляется на `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, `PLAYER_REGEN_ENABLED` и после `MultiActionBar_Update`.

Проблема не в самом файле, а в том, что рядом живут ещё bar-модули, которые сами управляют visibility.

### Почему это плохо

- Один слой говорит "скрыть, потому что proxy off".
- Другой говорит "показать, потому что мой state driver".
- В итоге бар может auto-hide или вести себя нестабильно после login/reload/combat transition.

### Что делать

1. Выбрать один visibility owner на каждую bar category.
2. Если legacy bars пока остаются:
- оставить secure visibility state только там, где без него нельзя;
- user config `enabled/disabled` сделать выше уровнем, без постоянной борьбы через `SetShown` в нескольких местах.
3. Вынести `managedFrames` coordinator в один модуль и не дублировать логику в bar-файлах.

### Где смотреть

- `modules/Roth_UI_rActionBarStyler/core/multibar_visibility.lua`
- `modules/Roth_UI_rActionBarStyler/core/bar1.lua`
- legacy bar4/bar5 модули

## Done when

- у каждой bar surface один visibility owner;
- бар больше не зависит от гонки между proxy refresh и отдельным state driver.

---

# PRIORITY 2 - Persistence ownership надо сжать до одной модели

## Проблема

`confirmed-static`: canonical persistence уже есть, но ownership всё ещё размазан.

Подтверждение по коду:
- `config.lua:985-1076` создаёт canonical roots и setter/getter слой;
- `config.lua:1435-1519` делает reconcile + proxy attach;
- `core/sv_store.lua:22-92` содержит fallback builder/setter для тех же root tables;
- `core/db.lua:43-128` содержит ещё один fallback путь для orb stores;
- `core/lib.lua:2288-2295` содержит fallback reset глобалов;
- `core/settings_general.lua:217-239` содержит ещё один reset fallback.

## Почему это плохо

- Непонятно, кто в системе главный владелец SavedVariables.
- Баг "settings не сохранились" можно искать сразу в пяти местах.
- Reset логика дублируется.
- Orb persistence всё ещё выглядит как второй диалект persistence внутри того же аддона.

## Что делать

1. Оставить `config.lua` единственным владельцем canonical roots.
2. Свести `core/sv_store.lua` к API-only роли:
- `Get`
- `Set`
- runtime buckets
- sanitation helpers
- без собственного fallback builder, если root owner уже инициализирован
3. Свести `core/db.lua` к orb-domain клиенту `ns.store`.
4. Оставить один reset entrypoint.
- Например: `ns.ResetPersistenceRoots()`
5. Удалить прямые fallback записи/обнуления глобалов вне единого persistence service.

## Минимальный target shape

```lua
ns.store = {
  getConfig = ns.GetConfigStore,
  setConfig = ns.SetCanonicalConfigStore,
  getTemplates = ns.GetCanonicalTemplateStore,
  setTemplates = ns.SetCanonicalTemplateStore,
  getOrbChar = ns.GetCanonicalOrbCharStore,
  setOrbChar = ns.SetCanonicalOrbCharStore,
}
```

## Что плохо прямо сейчас

### 2.1 `sv_store.lua` всё ещё умеет строить fallback canonical stores

Подтверждение:
- `core/sv_store.lua:32-64`
- `core/sv_store.lua:67-92`

Это делает файл умнее, чем нужно.
Если root owner уже определён в `config.lua`, второй builder не нужен как штатный путь.

### 2.2 `db.lua` всё ещё partially owns persistence vocabulary

Подтверждение:
- `core/db.lua:21-27`
- `core/db.lua:43-74`
- `core/db.lua:77-131`

Орбы должны быть доменом, а не параллельной системой хранения.

### 2.3 Reset размазан минимум в двух UI surfaces

Подтверждение:
- `core/lib.lua:2263-2302`
- `core/settings_general.lua:217-239`

## Варианты

### Вариант A - мягкая чистка
- Оставить fallback пути, но жёстко пометить их как bootstrap-only / emergency-only.
- Запретить их использовать как штатную логику.

### Вариант B - жёсткая чистка
- Удалить fallback builders из runtime path.
- Оставить только один canonical bootstrap path.

## Рекомендация

Сначала вариант A.
Причина:
- меньше риск внезапно убить совместимость старых SV;
- проще проверить rollback.

После live-стабилизации перейти к B.

## Done when

- один код строит корневые таблицы SV;
- один код делает reset;
- orb templates и orb char state живут через тот же store API, а не через отдельный persistence dialect.

---

# PRIORITY 3 - `frame_policy.lua` надо разрезать

## Проблема

`confirmed-static`: `core/frame_policy.lua` сейчас не просто переключает Roth/Blizzard frames.
Он ещё:
- трогает `C_AddOns`;
- трогает `C_CVar`;
- создаёт hidden parent и park logic;
- делает force-show;
- содержит compat/stub код для raid finder;
- местами выглядит как debug-recovery toolbox.

Подтверждение:
- `core/frame_policy.lua:44-50`
- `core/frame_policy.lua:52-80`
- `core/frame_policy.lua:83-113`
- `core/frame_policy.lua:120-160`
- `core/frame_policy.lua:169-245`

## Почему это плохо

- Policy layer должен быть тупым и предсказуемым.
- Recovery/debug logic не должен жить в normal runtime path.
- Чем больше в одном файле LoadOnDemand/CVar/AddOn enable/park/show/reparent, тем выше риск патч-регрессии.

## Что делать

Разбить минимум на три части:

1. `group_policy.lua`
- party/raid ownership
- show/hide policy

2. `unit_policy.lua`
- player/target/focus/pet ownership

3. `blizzard_restore_debug.lua`
- force show
- reload/recovery
- emergency restore
- compat stubs

## Отдельная проблема

`confirmed-static`: код уже умеет `EnableAddOn` и `LoadAddOn`.
Это допустимо как diagnostic/recovery path, но не как обычная runtime ветка.

Проверенные API, которые здесь уже используются и которые можно применять осознанно:

```lua
local loadedOrLoading = C_AddOns.IsAddOnLoaded("Blizzard_CompactRaidFrames")
if not loadedOrLoading then
  C_AddOns.LoadAddOn("Blizzard_CompactRaidFrames")
end
```

Проверенные API:
- `C_AddOns.IsAddOnLoaded`
- `C_AddOns.LoadAddOn`
- `C_AddOns.EnableAddOn`

## Рекомендация

В обычном runtime:
- не вызывать `EnableAddOn`;
- не менять addon enable state;
- не парковать лишние Blizzard frames без крайней необходимости;
- делать только минимальное Roth vs Blizzard переключение.

## Где смотреть

- `core/frame_policy.lua`
- `_Info/KB/nodes/BlizzardUI_UnitFrames.md`
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_UIParent/Mainline/UIParent.lua`

## Done when

- normal runtime policy читается отдельно от debug/recovery;
- обычное поведение больше не зависит от compat stub logic.

---

# PRIORITY 4 - Target castbar уже почти правильный, но его надо довести

## Что уже хорошо

`confirmed-static`: `core/target_castbar.lua` уже делает правильные вещи:
- выделяет semantic color states;
- отделяет interruptible/non-interruptible/fail state;
- держит свой overlay для non-interruptible;
- учитывает `Secret Value` случай и fallback path;
- не выглядит как прямое ковыряние Blizzard castbar art.

Подтверждение:
- `core/target_castbar.lua:23-102`
- `core/target_castbar.lua:116-179`
- `core/target_castbar.lua:252-348`
- `core/target_castbar.lua:359-501`

## Что ещё не закрыто

`runtime-unconfirmed`: в live всё ещё могут быть проблемы с:
- stale interruptibility state;
- interrupted/fail colour carry-over;
- channel vs cast distinction;
- empower path;
- reverse-channel end.

## Почему это всё ещё риск

Проблема castbar обычно не в одном цвете, а в identity matching:
- старт одного каста;
- прерывание другого;
- следующий каст уже начался;
- а UI ещё красится по старому state.

## Что делать

1. Сохранить текущую архитектуру.
- Она лучше старой.
- Переписывать её заново не надо.

2. Усилить identity tracking.
- если есть `castID`, использовать его;
- для channel использовать `spellID` и channel-state;
- stale visual events игнорировать, если они не совпадают с активным cast context.

3. Отдельно live-проверить:
- interruptible cast
- non-interruptible cast
- interruptible channel
- empower start/update/stop
- failed cast
- interrupted cast

## Проверенный API пример

```lua
local castName, _, _, _, _, _, castID, notInterruptible = UnitCastingInfo("target")
local channelName, _, _, _, _, _, channelNotInterruptible, spellID, isEmpowered = UnitChannelInfo("target")
```

Проверенные API:
- `UnitCastingInfo`
- `UnitChannelInfo`

## Альтернатива с меньшим риском

Если current custom contract окажется слишком хрупким:
- вернуться ближе к стандартному oUF castbar lifecycle;
- оставить кастомизацию только в post-callback cosmetic слое.

Это менее красиво архитектурно, но может быть дешевле по regression risk.

## Где смотреть

Текущий код:
- `core/target_castbar.lua`
- `units/target.lua`

Референсы:
- `_Reference/ReferenceAddonsFull/oUF/elements/castbar.lua`
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_UIPanels_Game/Mainline/CastingBarFrame.lua`

## Done when

- цвет/overlay/shield ведут себя стабильно на cast/channel/empower/interrupted/fail;
- нет stale state после быстрого sequence из нескольких каста.

---

# PRIORITY 5 - ExtraActionBar и ZoneAbility не надо забирать себе полностью

## Проблема

`runtime-unconfirmed`, но это high-risk зона:
- ExtraActionBar и ZoneAbility обычно опасны именно тем, что аддон хочет владеть ими как обычным кастомным баром.
- Для Midnight/современного Blizzard UI это плохой обмен.

## Рекомендация

Roth должен владеть только:
- holder position;
- декоративным art;
- optional mouseover art;
- может быть font/overlay оболочкой.

Roth не должен владеть:
- runtime parent ownership;
- core visibility state;
- secure action lifecycle.

## Проверенный API пример

```lua
if C_ActionBar.HasExtraActionBar() then
  local skinFileID = C_ActionBar.GetOverrideBarSkin()
  -- обновить только art/holder слой
end
```

Проверенные API:
- `C_ActionBar.HasExtraActionBar`
- `C_ActionBar.GetOverrideBarSkin`

## Что делать

1. Не писать новый "полноценный Roth extra bar engine".
2. Сделать thin wrapper вокруг Blizzard-owned runtime frame.
3. Проверить coexistence:
- encounter extra action
- zone ability
- quick keybind
- Edit Mode open/close

## Где смотреть

- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_ActionBar/Shared/ExtraActionBar.lua`
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_UIPanels_Game/Shared/ExtraAbilityContainer.lua`
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_ZoneAbility/ZoneAbility.lua`

## Done when

- ExtraAction и ZoneAbility не конфликтуют с holder/art слоем Roth;
- визуальная оболочка Roth не ломает Blizzard runtime ownership.

---

# PRIORITY 6 - Глобальные регистры надо убрать из normal API

## Проблема

`confirmed-static`: код по-прежнему опирается на глобальные списки и глобальные имена.

Подтверждение:
- `init.lua:7`
- `core/lib.lua:2280-2285`
- `core/settings_general.lua:148-182`

Что видно:
- `_G.Roth_UI` экспортируется как основной namespace;
- используются `Roth_UI_Art`, `Roth_UI_Bars`, `Roth_UI_Units`, `Roth_UI_Orbs`;
- mover/unlock/reset логика обходит эти глобальные списки.

## Почему это плохо

- Порядок инициализации становится неявным.
- Slash/UI/reset code зависит от глобальной мутации, а не от namespace registry.
- Такие регистры неудобно чистить и мигрировать.

## Что делать

1. Ввести namespace registry:
- `ns.registry.art`
- `ns.registry.bars`
- `ns.registry.units`
- `ns.registry.orbs`

2. Оставить `_G.Roth_UI` только как compatibility root для embedded legacy modules на время миграции.

3. После отключения legacy bootstrap убрать лишние глобальные списки.

## Где смотреть

- `init.lua`
- `core/lib.lua`
- `core/settings_general.lua`

## Done when

- mover/reset/settings обходят `ns.registry.*`, а не набор глобальных таблиц.

---

# PRIORITY 7 - Unit frame код нужен, но он слишком размножен

## Проблема

`confirmed-static`: unit-frame stack не выглядит мёртвым, но он слишком дублирует construction/style logic по разным файлам.

Следствие:
- мелкий фикс надо повторять в нескольких unit modules;
- styling drift между target/focus/pet/tt/focustarget почти гарантирован;
- safety/perf фиксы сложнее раскатывать последовательно.

## Что делать

Вынести общие builders в отдельный слой, например `core/unitframes/`:
- health bar builder
- power bar builder
- shared fontstring builder
- aura container builder
- portrait/border builder
- common tag/value updater

Пер-unit файлы должны оставить у себя только:
- уникальный layout;
- уникальный art;
- уникальные события/особые режимы.

## Что делать не надо

- не переписывать весь unit-frame stack сразу;
- не начинать с raid/party, если ещё не стабилизированы bars и frame policy.

## Где смотреть

Текущий код:
- `units/player.lua`
- `units/target.lua`
- `units/focus.lua`
- `units/pet.lua`

Референсы:
- `_Reference/ReferenceAddonsFull/oUF/ouf.lua`
- `_Reference/ReferenceAddonsFull/oUF/elements/auras.lua`
- `_Reference/ReferenceAddonsFull/oUF/elements/castbar.lua`

## Done when

- shared construction code больше не размазан по каждому unit file;
- типовой фикс стиля делается в одном месте.

---

# PRIORITY 8 - Aura/perf слой требует ещё одного прохода

## Проблема

`confirmed-static`: по коду видно, что aura-related runtime логика уже стала осторожнее, но performance story не закрыта до конца.

Особенно внимательно смотреть там, где есть повторные scans и derived-state logic.

## Почему это важно

- aura-путь очень легко превращается в постоянную мелкую нагрузку;
- особенно если ту же логику начать распространять на party/raid surfaces.

## Что делать

1. Найти все места, где ещё идёт полный scan аур.
2. Для group surfaces опираться на уже доставленную diff/data модель, а не на повторное сканирование.
3. Добавить дешёвый debug-инструмент для подсчёта частоты aura refresh path.

Пример полезного debug-интерфейса:
- `/roth perf aura`
- `/roth perf reset`
- `/roth perf dump`

## Где смотреть

- `core/unit_misc_runtime.lua`
- `_Info/KB/nodes/BlizzardUI_UnitFrames.md`
- `_Reference/ReferenceAddonsFull/oUF/elements/auras.lua`

## Done when

- target/focus path не генерирует лишние scans;
- group path не использует тяжёлую aura логику без необходимости.

---

# PRIORITY 9 - Settings UI и slash commands надо развести по ролям

## Проблема

`confirmed-static`: сейчас уже есть Settings UI, но часть control surface всё ещё живёт в slash/reset/debug стиле.

Проблема не в том, что slash команды есть.
Проблема в том, что они местами дублируют обычную настройку и reset-поведение.

## Что делать

Развести роли:

1. Settings UI
- всё, что пользователь меняет постоянно;
- normal config;
- позиционирование;
- визуальные опции.

2. Slash commands
- диагностика;
- debug;
- dump состояния;
- emergency reset;
- perf counters;
- migration tools.

## Что особенно важно

Reset settings должен быть один:
- одна функция;
- один persistence owner;
- одна reload policy.

## Где смотреть

- `core/settings_main.lua`
- `core/settings_general.lua`
- `core/slashcmd.lua`
- `core/lib.lua`

## Done when

- пользовательская настройка не дублируется в двух control planes;
- slash командами остаются в основном diagnostic/admin функции.

---

# PRIORITY 10 - Media package надо почистить отдельно

## Проблема

`confirmed-static`:
- пакет весит `33.66 MB`;
- в нём `186` `.tga`;
- в нём `10` `.ttf` и ещё `3` `.otf`.

Это не обязательно плохо для Diablo-style UI, но это уже достаточно много, чтобы делать медиа-аудит отдельно от логики.

## Что делать

1. Построить reference map:
- какие файлы реально используются;
- какие используются только legacy bar stack;
- какие нигде не используются.

2. Удалить dead assets.

3. Если какие-то actionbar variants уже obsolete, вынести их из default package.

4. Проверить fonts:
- какие реально доступны в Settings;
- какие зарегистрированы в LSM, но нигде не применяются.

Подтверждение по регистрации fonts/media:
- `core/lib.lua:2304-2333`

## Done when

- есть список используемых и неиспользуемых media;
- legacy-only art отделён от актуального art.

---

# PRIORITY 11 - Что уже можно сделать быстро, без большого rewrite

Это отдельный блок быстрых задач, которые реально дадут результат.

## Quick wins

1. Перенести reset logic в один entrypoint.
- Низкий риск.
- Высокая польза.

2. Заморозить legacy actionbar development и задокументировать ownership.
- Низкий риск.
- Очень высокая польза.

3. Разрезать `frame_policy.lua` на runtime и debug.
- Средний риск.
- Высокая польза.

4. Вынести global registries в `ns.registry`.
- Средний риск.
- Средняя/высокая польза.

5. Сделать live-проверку castbar state contract.
- Низкий риск.
- Высокая польза.

## Quick wins, которые не надо делать прямо сейчас

1. Полный rewrite всех unit frames.
- Слишком широко.

2. Полный дизайн-перерисовка action bars до фикса ownership.
- Это cosmetic before architecture.

3. Большой media cleanup до того, как понятно, какие legacy files ещё нужны.
- Иначе можно удалить то, что ещё используется.

---

# Runtime issues, которые надо проверить в игре

Ниже список вещей, которые статический код делает правдоподобными, но не доказывает окончательно:

- `runtime-unconfirmed`: bars 4/5 auto-hide или конфликтуют с настройками.
- `runtime-unconfirmed`: target castbar иногда сохраняет неверный state между кастаами.
- `runtime-unconfirmed`: ExtraAction/ZoneAbility holder может desync в нестандартных переходах.
- `runtime-unconfirmed`: normal settings save/reload ещё может ломаться в редких ветках reset/migration.
- `runtime-unconfirmed`: action buttons могут терять стабильность в vehicle/override/possess сценариях.

---

# Рекомендуемый порядок работы

1. Зафиксировать ownership policy по bars и persistence.
2. Отключить двойное владение legacy/new bar stack.
3. Свести reset/persistence к одному owner path.
4. Разрезать `frame_policy.lua`.
5. Добить target castbar live-проверкой.
6. Проверить ExtraAction/ZoneAbility как thin wrapper, а не как новый bar engine.
7. Перевести global registries в `ns.registry`.
8. После стабилизации решить, идём ли в Roth-owned secure bars.
9. Только потом резать unit-frame duplication и media package.

---

# Live verification checklist

Обязательный список на проверку после следующих правок:

- `/reload` без ошибок
- `/console scriptErrors 1`
- нет `ADDON_ACTION_BLOCKED`
- нет secret-value runtime ошибок
- target: interruptible cast
- target: non-interruptible cast
- target: interruptible channel
- target: empower
- interrupted cast
- failed cast
- ExtraAction encounter button
- ZoneAbility coexistence
- vehicle
- possess
- override bar
- Quick Keybind
- Edit Mode open/close
- settings save -> reload -> login
- party Roth on/off
- raid Roth on/off
- mover unlock/lock/reset

---

# Где брать примеры и подтверждения

Blizzard docs / routing:
- `_Info/KB/core/BlizzardUI_SubsystemRouter.md`
- `_Info/KB/nodes/BlizzardUI_ActionBars.md`
- `_Info/KB/nodes/BlizzardUI_UnitFrames.md`

Blizzard UI source:
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_ActionBar`
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_EditMode`
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_UIPanels_Game`
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_ZoneAbility`
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_UnitFrame`

oUF для unit frames и castbar lifecycle:
- `_Reference/ReferenceAddonsFull/oUF/ouf.lua`
- `_Reference/ReferenceAddonsFull/oUF/elements/castbar.lua`
- `_Reference/ReferenceAddonsFull/oUF/elements/auras.lua`

---

# Bottom line

Если коротко:

- аддон уже не на стадии "всё сломано";
- аддон на стадии "ядро уже местами хорошее, но ownership ещё грязный";
- самый ценный следующий шаг не новый cosmetic фикс;
- самый ценный следующий шаг: прекратить двойное владение action bars и persistence.

Если это сделать, дальше проект начнёт доделываться быстрее.
Если это не сделать, любой следующий фикс будет снова лечить симптомы, а не систему.

---

# Addendum - второй проход, более внимательная проверка

Ниже то, что подтвердилось только после второго, более узкого прохода по новым файлам.

## A1 - Legacy actionbar stack глубже и шире, чем выглядело сначала

Первый вывод \"legacy bars ещё живы\" был верный, но неполный.

`confirmed-static`: legacy `rActionBarStyler` владеет не только main bar, а почти всей bar-экосистемой:
- `bar1.lua`
- `bar2.lua`
- `bar3.lua`
- `bar4.lua`
- `bar5.lua`
- `bags.lua`
- `micromenu.lua`
- `petbar.lua`
- `stancebar.lua`
- `overridebar.lua`
- `leave_vehicle.lua`
- `background.lua`

Что именно подтверждено grep-поиском по `modules/**/*.lua`:
- множественные `SetParent(...)`
- множественные `ClearAllPoints()`
- множественные `SetPoint(...)`
- множественные `RegisterStateDriver(...)`

Это усиливает приоритет action bars ещё сильнее:
- здесь проблема уже не в одной bar1;
- здесь legacy слой реально формирует целый альтернативный shell для Blizzard bar surfaces.

Практический вывод:
- если трогать bars, нельзя мыслить только `bar1.lua`;
- надо считать, что весь `modules/Roth_UI_rActionBarStyler/core/*` является одной системой.

## A2 - `rButtonTemplate` надо отделять от `rActionBarStyler`

Это важное уточнение.

Во втором проходе видно, что не весь legacy stack одинаково плох.

`confirmed-static`: `modules/Roth_UI_rButtonTemplate/core.lua` уже использует более современный observer-подход:
- `EventRegistry:RegisterCallback("ActionButton.OnActionChanged", ...)`
- `hooksecurefunc(ActionBarActionButtonMixin, "UpdateAction", ...)`

Подтверждение:
- `modules/Roth_UI_rButtonTemplate/core.lua:349-399`

Это хорошо, потому что:
- button styling через observer/post-hook path можно потенциально сохранить;
- а вот layout/reparent/state-driver часть из `rActionBarStyler` гораздо опаснее.

Отдельный плюс:
- styling default BuffFrame фактически отключён ради stability/secret-value safety.
- `modules/Roth_UI_rButtonTemplate/core.lua:487-494`

Практический вывод:
- не надо выкидывать весь legacy stack одним движением;
- `rButtonTemplate` выглядит как кандидат на сохранение/перенос;
- `rActionBarStyler` layout ownership выглядит как кандидат на вынос или заморозку.

## A3 - Legacy background модуль уже владеет не только art, но и layout нового core

Это новое важное подтверждение.

`confirmed-static`: `modules/Roth_UI_rActionBarStyler/core/background.lua` не просто рисует background art.

Он также:
- определяет bar visual variant по состоянию Blizzard multibars;
- reposition/hide/show Roth experience/reputation bars;
- слушает `MultiActionBar_Update`;
- хукает `MainActionBarMixin` и `EditModeActionBarSystemMixin`.

Подтверждение:
- `modules/Roth_UI_rActionBarStyler/core/background.lua:201-336`
- `modules/Roth_UI_rActionBarStyler/core/background.lua:343-395`

Особенно важный кусок:
- `PlaceBarFrame(...)` делает `ClearAllPoints`, `SetPoint`, `SetSize`, `Show/Hide` на `Roth_UIExpBar` и `Roth_UIRepBar`.
- Эти бары создаются уже новым core в `core/bars.lua`.

Подтверждение по core:
- `core/bars.lua:272-313`

Значит сейчас есть cross-ownership:
- новый core создаёт exp/rep bars;
- legacy background модуль решает, где они живут и как они двигаются.

Это архитектурно плохо, потому что:
- bar visuals и bar domain logic не разделены;
- новая система уже частично зависит от старой.

Практический вывод:
- `background.lua` нельзя считать harmless cosmetic layer;
- это уже ownership module, который тоже надо включать в bar-migration plan.

## A4 - `extrabar.lua` ещё не дошёл до заявленной цели

Комментарий в коде правильный:
- \"Keep Blizzard ownership of ExtraActionBarFrame itself.\"

Но реализация пока только частично следует этому правилу.

`confirmed-static`: `modules/Roth_UI_rActionBarStyler/core/extrabar.lua` всё ещё:
- меняет размер кнопки;
- делает `ExtraActionBarFrame:SetScale(...)`;
- ставит `ignoreFramePositionManager = true`;
- делает `ExtraActionBarFrame:ClearAllPoints()`;
- делает `ExtraActionBarFrame:SetPoint("CENTER", frame, "CENTER")`.

Подтверждение:
- `modules/Roth_UI_rActionBarStyler/core/extrabar.lua:62-68`

То есть по факту сейчас это не чистый holder-only режим.

Практический вывод:
- курс взят правильный;
- но формулировку в todo надо читать строго: этот участок ещё не \"решён\", а только \"двигается в правильную сторону\".

При следующей доработке цель должна быть жёстче:
- Roth владеет holder/art;
- Blizzard runtime frame не получает новый layout owner без крайней необходимости.

## A5 - Глобальные регистры не просто существуют, а реально инициализируются как основной control surface

Первый проход это уже показал, но второй проход усилил вывод.

`confirmed-static`: `core/slashcmd.lua` прямо создаёт глобальные registry tables:
- `Roth_UI_Bars`
- `Roth_UI_Orbs`
- `Roth_UI_Units`
- `Roth_UI_Art`

Подтверждение:
- `core/slashcmd.lua:71-107`

Потом эти таблицы используются как основной control plane для:
- unlock
- lock
- reset
- mover traversal

Подтверждение:
- `core/slashcmd.lua:109-259`

И это не isolated слой:
- `units/boss.lua`
- `units/party.lua`
- `units/raid.lua`
добавляют туда свои элементы через `table.insert(...)`.

Практический вывод:
- проблема глобальных регистров сильнее, чем казалось;
- это не legacy-остаток на обочине;
- это активный runtime API.

## A6 - Абстракция persistence протекает в UI domain

Это новое и важное подтверждение.

`confirmed-static`: в `units/player.lua` orb model UI-код сам знает несколько вариантов доступа к данным:
- через `ns.store.GetOrbCharRoot()`
- через `db:GetCharStore()`
- через `db.char`

Подтверждение:
- `units/player.lua:717-725`

Это нехорошо, потому что UI-файл уже знает о:
- store API;
- db API;
- fallback storage field.

Это означает:
- abstraction leak;
- persistence refactor автоматически задевает player unit visuals.

Практический вывод:
- UI domain должен читать уже нормализованные orb settings через один accessor;
- unit files не должны знать о трёх путях получения одного и того же store.

## A7 - Aura/dispel logic не только потенциально тяжёлая, но ещё и хрупкая по поддержке

`confirmed-static`: `core/unit_misc_runtime.lua` делает полный harmful aura scan через:
- `AuraUtil.ForEachAura(unit, "HARMFUL", nil, HandleHarmfulAura, true)`

Подтверждение:
- `core/unit_misc_runtime.lua:171-189`

Кроме performance-вопроса, во втором проходе видно и вторую проблему:
- dispel capability зашита вручную в `RothUI:canDispelDebuff(...)`.

Подтверждение:
- `core/unit_misc_runtime.lua:191-214`

Почему это плохо:
- любая class/spec/gameplay правка делает такую таблицу потенциально устаревшей;
- логика становится не только hot-path, но и maintenance burden.

Практический вывод:
- этот код надо считать не просто \"может быть тяжёлым\", а ещё и \"может дрейфовать по корректности\".

## A8 - `core/bootstrap.lua` не выглядит проблемной зоной

Это полезное отрицательное подтверждение.

`confirmed-static`: `core/bootstrap.lua` очень маленький и делает только:
- `ClearPendingReloadHint()`
- `Roth_UI:InitConfig()`

Подтверждение:
- `core/bootstrap.lua:1-17`

То есть bootstrap сам по себе не является источником нынешнего техдолга.

Практический вывод:
- не надо тратить время на переписывание bootstrap;
- проблемы сидят ниже, в ownership и runtime layer.

## A9 - Новый `core/bars.lua` сам по себе выглядит полезным, но уже сцеплен со старым bar-art слоем

`confirmed-static`: `core/bars.lua` создаёт собственные Roth bars и orb-related surfaces.

Подтверждение:
- `core/bars.lua:272-313`
- `core/bars.lua:897-929`

Что это значит:
- новый core bars layer реально существует и не декоративный;
- но он уже partially coupled to legacy background behavior.

То есть миграция bars должна учитывать не только удаление legacy layout-кода, но и развязку:
- `core/bars.lua`
- `modules/.../background.lua`

## Обновлённый приоритет после второго прохода

После второго прохода приоритеты я бы уточнил так:

1. `P0` - action bar ownership boundary, включая `background.lua`
2. `P1` - persistence boundary и abstraction leaks
3. `P2` - global registries -> `ns.registry`
4. `P3` - `frame_policy.lua` split
5. `P4` - target castbar live verification
6. `P5` - aura/dispel runtime cleanup

## Что бы я НЕ считал проблемой после второго прохода

Чтобы не раздувать список искусственно:

1. `core/bootstrap.lua`
- выглядит нормально;
- это не hotspot.

2. `core/target_castbar.lua`
- выглядит не идеальным, но осмысленным и directionally correct;
- это не тот кусок, который надо переписывать с нуля.

3. `rButtonTemplate` observer layer
- выглядит заметно лучше, чем legacy layout modules;
- это не равноценный источник риска по сравнению с `rActionBarStyler`.

---

# Addendum 2 - refactor map после продолжения аудита

Этот блок отвечает уже не только на вопрос \"что плохо\", а на вопрос
\"что можно будет чинить отдельно, а что придётся мигрировать вместе\".

## R1 - Action bars надо считать одним связанным refactor cluster

После полного прохода по нечитанным legacy bar-модулям стало ясно:

`confirmed-static`: почти весь `modules/Roth_UI_rActionBarStyler/core/*` образует одну связанную систему, а не набор независимых модулей.

Подтверждённые ownership-heavy модули:
- `bar1.lua`
- `bar2.lua`
- `bar3.lua`
- `bar4.lua`
- `bar5.lua`
- `petbar.lua`
- `stancebar.lua`
- `overridebar.lua`
- `bags.lua`
- `micromenu.lua`
- `background.lua`
- `dock.lua`

Что у них общего:
- создают свои holder frames;
- репарентят Blizzard frames;
- двигают Blizzard buttons через `ClearAllPoints`/`SetPoint`;
- используют `RegisterStateDriver`;
- подключают drag/mouseover/dock ownership.

Практический вывод:
- bars нельзя безопасно рефакторить модуль-за-модулем без общей migration scheme;
- как минимум вместе должны рассматриваться:
  - `bar1/2/3`
  - `background.lua`
  - `dock.lua`
  - `bags.lua`
  - `micromenu.lua`
  - `stancebar.lua`

Почему:
- `dock.lua` уже связывает layout shell action bars с `micromenu/bags/stancebar`.
- `background.lua` зависит от видимости multibar shell и сам двигает exp/rep bars нового core.

## R2 - `dock.lua` это migration blocker, а не utility helper

`confirmed-static`: `modules/Roth_UI_rActionBarStyler/core/dock.lua` строит shared bottom dock, который:
- читает layout shell из `rAbs_MainMenuBar`, `rABS_MultiBarBottomLeft`, `rABS_MultiBarBottomRight`;
- потом перераскладывает `micromenu`, `bags`, `stancebar`.

Подтверждение:
- `dock.lua:12-16`
- `dock.lua:104-134`
- `dock.lua:158-241`

Это значит:
- нельзя переписать только micromenu или только bags и не трогать dock;
- нельзя убрать `rAbs_MainMenuBar` shell, пока dock на него опирается.

Новый приоритет внутри bar-refactor:
1. сначала убрать зависимость dock от legacy shell names;
2. потом переводить members dock на новый owner;
3. только потом убирать старые action shell frames.

## R3 - Есть модули, которые можно вынести отдельно

Не всё внутри legacy bars одинаково жёстко сцеплено.

### Относительно изолированные кандидаты

1. `leave_vehicle.lua`
- создаёт свой отдельный secure button;
- не репарентит крупные Blizzard bar containers;
- меньше связан с остальным shell.

Подтверждение:
- `leave_vehicle.lua:23-79`

2. `rButtonTemplate`
- уже строится вокруг observer/post-hook модели;
- опасность там сильно ниже, чем в layout ownership слое.

Практический вывод:
- при большом рефакторе их можно планировать как отдельные workstreams;
- не смешивать их с переписыванием main/multibar shell.

## R4 - Orb subsystem тоже надо считать единым cluster

После изучения `settings_orbs.lua`, `orb_runtime.lua`, `transfer.lua`, `sv_doctor.lua`, `units/player.lua` стало видно:

`confirmed-static`: orb subsystem уже сцепляет вместе:
- persistence
- UI settings
- runtime visual refresh
- template management
- import/export
- diagnostics
- player unit visuals

### Подтверждённые coupling points

1. `settings_orbs.lua`
- использует `ns.store`;
- при этом зовёт `ns.db` и его persistence pipeline;
- держит template selection и orb char/global values.

Подтверждение:
- `settings_orbs.lua:36-66`
- `settings_orbs.lua:83-132`
- `settings_orbs.lua:246-320`

2. `orb_runtime.lua`
- снова знает и про `ns.store`, и про `ns.db`, и про fallback `db.char`.

Подтверждение:
- `orb_runtime.lua:10-33`

3. `units/player.lua`
- model update внутри player orb снова знает несколько путей к char store.

Подтверждение:
- `player.lua:717-725`

4. `transfer.lua`
- импорт/экспорт работает с canonical root shape целиком;
- опирается на `ReplacePersistenceRoots`, `ReconcilePersistenceStores`, `SVRebuildRuntime`.

Подтверждение:
- `transfer.lua:58-89`
- `transfer.lua:197-240`

5. `sv_doctor.lua`
- сканирует именно canonical domains:
  - `Roth_UI_DB.account.settings`
  - `Roth_UI_DB.account.templates`
  - `Roth_UI_DB_Char.orbs`

Подтверждение:
- `sv_doctor.lua:201-235`

Практический вывод:
- orb subsystem нельзя рефакторить как \"только db.lua\" или \"только settings_orbs.lua\";
- придётся мигрировать вместе как минимум:
  - store API
  - db orb facade
  - orb runtime refresh
  - player orb visuals
  - templates
  - transfer/doctor tooling

## R5 - Settings apply-path уже кодирует runtime contracts

`confirmed-static`: Settings UI не просто пишет в SV, а уже знает, какие runtime entrypoints существуют.

Подтверждение:
- `settings_groups.lua:5-33`
- `settings_target.lua:28-60`

Примеры:
- `ns.ApplyPartyLayoutRuntime`
- `ns.RebuildPartyStructureRuntime`
- `ns.ApplyRaidLayoutRuntime`
- `ns.RefreshGroupRangeRuntime`
- `ns.TargetCastbarRuntime.ScheduleActiveRefresh`

Это означает:
- при рефакторе нельзя просто переименовать runtime functions и потом \"починить UI позже\";
- Settings apply-path уже часть публичного internal contract.

### Отдельное замечание по fallback path

`confirmed-static`: `settings_main.lua` в fallback-ветке пытается звать `ns.SetConfigStore(...)`.

Подтверждение:
- `settings_main.lua:204-221`

При этом canonical API в текущей архитектуре называется иначе.

Это выглядит как latent naming drift:
- в штатном режиме оно может не проявляться, если всегда есть `ns.SVSet`;
- но fallback path уже не такой надёжный, как кажется.

Это не обязательно текущий live bug, но это хороший кандидат в список \"почистить до большого рефактора\".

## R6 - Party/Raid/Boss migration завязаны на movers и global registries

`confirmed-static`: group/boss surfaces не просто спавнят oUF frames, а сразу встраиваются в старую mover/global registry модель.

Подтверждение:
- `party.lua:290-345`
- `raid.lua:677-727`
- `boss.lua:175-189`

Что это значит:
- `Roth_UI_Units` всё ещё не пассивный legacy-список;
- он используется как клей между spawning и mover/reset commands.

Практический вывод:
- migration `Roth_UI_Units -> ns.registry.units` должна идти вместе с:
  - drag frame creation
  - unlock/lock/reset commands
  - group anchor spawning

Если делать это отдельно и вслепую, легко потерять:
- `Roth_UIPartyDragFrame`
- `Roth_UIRaidAnchor`
- `Roth_UIBossFrame*`

## R7 - Party/Raid headers уже имеют собственную secure lifecycle-логику

`confirmed-static`: party и raid не являются простыми единичными frame surface.

Party:
- header generation;
- hidden parent parking;
- custom visibility driver application.

Подтверждение:
- `party.lua:284-359`

Raid:
- anchor + group headers;
- custom visibility driver;
- deferred apply on regen;
- arena visibility override.

Подтверждение:
- `raid.lua:652-759`

Практический вывод:
- group frames нельзя считать \"простым UI-слоем поверх frame_policy\";
- у них уже есть свой runtime lifecycle.

Поэтому безопасный порядок такой:
1. сначала описать group runtime API и ownership;
2. потом уже резать `frame_policy.lua`;
3. не наоборот.

## R8 - Safety layer выглядит устойчивой опорой и её лучше не трогать без необходимости

`confirmed-static`: `core/safety.lua` аккуратно централизует:
- secret detection;
- forbidden table detection;
- sanitization;
- safe copy;
- guarded calls.

Подтверждение:
- `safety.lua:58-203`

Практический вывод:
- при большом рефакторе это скорее stable foundation, чем источник проблемы;
- менять её стоит только если появится конкретный доказанный дефект.

## R9 - Move grid и session logger не выглядят как проблемные зоны

`confirmed-static`:
- `movegrid.lua` простой и локальный;
- `logger.lua` хранит только session runtime log и не лезет в SV.

Подтверждение:
- `movegrid.lua:104-133`
- `logger.lua:10-58`

Практический вывод:
- это не hot spots;
- их лучше не трогать в большом refactor pass.

## R10 - `charspecific.lua` фактически не участвует в текущих рисках

`confirmed-static`: `charspecific.lua` отключён по умолчанию и не даёт скрытых runtime override без явного флага.

Подтверждение:
- `charspecific.lua:1-14`

Практический вывод:
- это не часть текущего проблемного кластера;
- при планировании большого refactor pass его можно игнорировать.

## Обновлённая safe sequencing map

Если цель именно \"исправить в один заход и не наломать дров\", то безопаснее всего идти так:

1. Заморозить legacy bar feature work.
2. Развязать `dock.lua` от legacy action shell names.
3. Определить новый ownership для:
   - main action shell
   - multibar shell
   - background art
   - micromenu/bags/stance dock members
4. Только после этого мигрировать или отключать legacy bar modules.
5. Параллельно описать единый orb domain API:
   - one read path
   - one write path
   - one template path
   - one refresh path
6. Потом уже резать orb subsystem вместе:
   - `db.lua`
   - `settings_orbs.lua`
   - `orb_runtime.lua`
   - `units/player.lua`
   - `transfer.lua`
   - `sv_doctor.lua`
7. Затем переводить global registries в namespace registries.
8. Затем упрощать `frame_policy.lua`, уже опираясь на новый group runtime contract.

## Итоговое правило большого прохода

Не делать \"рефактор по папкам\".
Делать \"рефактор по ownership-clusters\".

В этом проекте реальный кластер сейчас такой:

1. `Action bar shell cluster`
- `rActionBarStyler core/*`
- `background.lua`
- `dock.lua`
- часть `core/bars.lua`

2. `Orb persistence cluster`
- `db.lua`
- `sv_store.lua`
- `settings_orbs.lua`
- `orb_runtime.lua`
- `units/player.lua`
- `transfer.lua`
- `sv_doctor.lua`

3. `Group runtime cluster`
- `party.lua`
- `raid.lua`
- `boss.lua`
- `frame_policy.lua`
- `settings_groups.lua`
- global mover registries

---

# Addendum 3 - подтверждения из Blizzard, внешних реализаций и oUF

Этот блок нужен для того, чтобы следующие решения были не просто логичными,
а согласованными с тем, как система реально устроена в текущем клиенте и в зрелых аддонах.

## E1 - Blizzard сам считает action bars системой из layout + visibility + art + Edit Mode

`confirmed-static`: в Blizzard `EditModeActionBarSystemMixin` action bars управляются как единая система:
- grid layout
- dividers
- bar art
- visibility rules
- edit mode position updates
- spell flyout direction

Подтверждение:
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_EditMode/Shared/EditModeSystemTemplates.lua:919-1185`

Что особенно важно:
- `UpdateSystemSettingOrientation`
- `UpdateSystemSettingNumRows`
- `UpdateSystemSettingNumIcons`
- `UpdateSystemSettingIconSize`
- `UpdateSystemSettingHideBarArt`
- `UpdateSystemSettingVisibleSetting`
- везде дальше вызываются refresh path и `UpdateActionBarLayout(...)`

Практический вывод:
- наш старый подход \"просто репарентить и переложить кнопки\" действительно конфликтует с моделью Blizzard;
- Blizzard сам ведёт эти бары как одну edit-mode-aware систему;
- значит наш безопасный путь либо:
  - пост-хуки и addon-owned overlays;
  - либо полностью свой secure bar owner.

Промежуточный полувладелец почти гарантированно будет хрупким.

## E2 - Blizzard ExtraAction и ZoneAbility реально делят один контейнер

`confirmed-static`: Blizzard `ExtraActionBar_Update()` вызывает:
- `ExtraAbilityContainer:AddFrame(bar, ExtraActionButtonPriority)`

Подтверждение:
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_ActionBar/Shared/ExtraActionBar.lua:10-29`

`confirmed-static`: `ExtraAbilityContainerMixin:AddFrame(...)` делает:
- `frameToAdd:SetParent(self)`
- приоритетную вставку
- update shown state

Подтверждение:
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_UIPanels_Game/Shared/ExtraAbilityContainer.lua:26-53`

`confirmed-static`: `ZoneAbilityFrameMixin:UpdateDisplayedZoneAbilities()` использует тот же контейнер и тот же механизм:
- `ExtraAbilityContainer:AddFrame(self, ZoneAbilityFramePriority)`
- `ExtraAbilityContainer:RemoveFrame(self, ZoneAbilityFramePriority)`

Подтверждение:
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_ZoneAbility/ZoneAbility.lua:168-176`

Что это значит для нас:
- гипотеза про shared container полностью подтверждена;
- ExtraAction и ZoneAbility действительно нельзя рассматривать как два независимых кастомных бара;
- holder/art-only стратегия для Roth здесь подтверждается Blizzard source.

## E3 - Зрелые LAB-based реализации используют собственные secure bars вместо Blizzard numbered layout

`confirmed-static`: зрелая LAB-based реализация строит бары через собственную bar abstraction и `LAB:CreateButton(...)`.

Что особенно важно:
- `CreateBar(id)` создаёт свой `SecureHandlerStateTemplate` bar;
- дальше через `LAB:CreateButton(...)` создаются собственные secure action buttons;
- layout, paging, visibility и mover ownership живут у единого bar owner.

Практический вывод:
- Option B из todo подтверждается зрелой реализацией;
- если делать long-term правильный путь, он должен быть ближе к:
  - owner-created bars
  - owner-created buttons
  - explicit secure snippets/state handling
- а не к длительной жизни на Blizzard `ActionButton1..12` skeleton.

## E4 - `rButtonTemplate` действительно движется в сторону официального safe path

`confirmed-static`: Blizzard `ActionButton.lua` сам построен вокруг:
- watcher frames
- callback registries
- post-style update surfaces
- range/usable event frames

Подтверждение:
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_ActionBar/Shared/ActionButton.lua:201-420`

Там есть:
- `CVarCallbackRegistry:RegisterCallback(...)`
- action event watcher frames
- range watcher frame
- usable watcher frame

Это хорошо коррелирует с тем, что делает наш `rButtonTemplate`:
- observer-style hooks
- `EventRegistry:RegisterCallback("ActionButton.OnActionChanged", ...)`
- `hooksecurefunc(mixin, "UpdateAction", ...)`

Практический вывод:
- button observer path у нас не случайно выглядит более здоровым;
- он действительно ближе к тому, как Blizzard и зрелые addons строят низкорисковые button updates.

## E5 - oUF group headers уже дают нам часть нужной модели, и её лучше не ломать

`confirmed-static`: oUF `SpawnHeader(...)` уже:
- строит secure group header;
- даёт `header:SetVisibility(...)`;
- использует `RegisterAttributeDriver(...)`;
- создаёт собственный initial config path;
- рассчитывает unit guessing / header type / child processing.

Подтверждение:
- `_Reference/ReferenceAddonsFull/oUF/ouf.lua:602-710`
- `_Reference/ReferenceAddonsFull/oUF/ouf.lua:638-710`

Практический вывод:
- у нас есть смысл не изобретать параллельную lifecycle-модель для party/raid сверх того, что уже умеет oUF;
- лучше поверх oUF headers строить thin Roth runtime/layout policy, а не ещё один mini-framework.

## E6 - oUF range element даёт нам более простой baseline, чем current split driver story

`confirmed-static`: oUF `Range` element сам использует:
- `UNIT_IN_RANGE_UPDATE`
- `UNIT_CONNECTION`
- для group units ещё `PARTY_MEMBER_ENABLE/DISABLE`

Подтверждение:
- `_Reference/ReferenceAddonsFull/oUF/elements/range.lua:76-107`

Практический вывод:
- наш Settings выбор между `blizzard` и `ouf` driver имеет смысл;
- но future refactor должен явно решить:
  - либо мы полностью доверяем oUF Range;
  - либо у нас свой driver;
  - но не размытая смесь полудрайверов и ad-hoc refresh callbacks.

## E7 - oUF castbar сам документирует ту же проблему, которую мы уже увидели

`confirmed-static`: oUF `CastInterruptible` прямо содержит комментарий:
- `ISSUE: we can't verify if this is for an active cast/channel/empower without castID`

Подтверждение:
- `_Reference/ReferenceAddonsFull/oUF/elements/castbar.lua:459-480`

А Blizzard castbar, в свою очередь, реально держит:
- `self.castID`
- `self.channeling`
- `self.reverseChanneling`
- `self.spellID`
- раздельные пути start/stop/fail/update

Подтверждение:
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_UIPanels_Game/Mainline/CastingBarFrame.lua:331-505`

Практический вывод:
- наш вывод про target castbar остаётся верным;
- это не надуманная проблема и не локальный баг Roth;
- это реальная сложность на границе oUF callbacks и Blizzard cast lifecycle.

## E8 - Hot-path рекомендации из docs подтверждают наши perf-опасения

`confirmed-static`: `_Info/KB/core/BlizzardUI_Performance_Modules.md` прямо рекомендует:
- не делать full rescans, если есть incremental payload;
- не создавать frames в hot handlers;
- не делать heavy string formatting в tight loops;
- batch updates.

Это подтверждает наш риск по:
- `AuraUtil.ForEachAura(...)` scan path
- лишним runtime coupling в event-driven surfaces

## E9 - Hook/security docs подтверждают, что большая часть legacy bar ownership уже за красной чертой

`confirmed-static`: `BlizzardUI_HookDecisionTree.md` и `BlizzardUI_security.md` вместе дают очень чёткий verdict:
- сначала callback registry
- потом post hook
- `SetAttribute` и скриптовая мутация secure frames в боевых путях под запретом
- тяжёлые мутации secure/protected surfaces высокорисковы

Практический вывод:
- репарентинг Blizzard bars и долгосрочное владение их layout не просто \"не очень красиво\";
- это уже против общего recommended model для безопасных аддонов.

## Обновлённый design rule set для будущего implementation pass

На основе текущего кода, Blizzard source, LAB-based реализаций и oUF evidence безопаснее всего держаться таких правил:

1. Blizzard secure/action surfaces:
- не брать в долгосрочное layout ownership без полного secure replacement;
- если не делаем replacement, то только observer + overlay + holder art.

2. ExtraAction/ZoneAbility:
- считать shared container system;
- не пытаться делать из них два независимых кастомных Roth бара.

3. Group headers:
- максимально опираться на oUF header model и visibility drivers;
- не плодить вторую lifecycle-модель рядом.

4. Castbar:
- сохранять explicit cast identity state;
- считать interruptible updates unreliable без castID.

5. Perf:
- incremental-first;
- не сканировать полный aura state, если можно жить на diff/update path.

---

# Recovery checkpoint - 2026-03-13 00:13 ET

IDE crash check:
- `todo.md` существует
- размер файла около `75 KB`
- последние addendum по Blizzard, LAB-based реализациям и oUF evidence не потерялись

Последние зафиксированные наблюдения после recovery-check:

## C1 - Tooltip/chat у Roth сейчас не образуют опасный cluster

`confirmed-static`: в самом аддоне нет отдельной сложной tooltip/chat integration subsystem.

Что реально найдено:
- прямые `GameTooltip` вызовы для mover/help UI
- прямые `GameTooltip` вызовы у data bars
- не найдено собственных `TooltipDataProcessor` hooks
- не найдено собственных `ChatFrameUtil` filters

Практический вывод:
- текущий код здесь не выглядит источником большого техдолга;
- future risk здесь только один: если позже добавлять tooltip/chat hooks, делать это строго через modern-safe surfaces.

Рекомендованный rule:
- tooltip -> `TooltipDataProcessor`
- chat -> `ChatFrameUtil.*Filter` / `EventRegistry` hyperlink callbacks

## C2 - Group range у Roth уже живёт как отдельный runtime driver

`confirmed-static`: в `core/lib.lua` уже есть полноценный range subsystem для party/raid:
- `ApplyGroupRangeAlpha`
- `SyncBlizzardRangeDriver`
- `RegisterBlizzardRangeDriver`
- `OnBlizzardRangeDriverEvent`
- `EnsureBlizzardRangeDriver`
- `func.ConfigureGroupRange`
- `func.RefreshGroupRangeFrame`
- `ns.RefreshGroupRangeRuntime`

Подтверждение:
- `core/lib.lua:2000-2190`

Практический вывод:
- range логика уже не просто cosmetic alpha;
- она часть `Group runtime cluster`;
- нельзя отдельно переписывать party/raid и надеяться, что range \"само подстроится\".

## C3 - `frame_policy` это coordinator поверх уже существующих runtime owners

`confirmed-static`: `ApplyGroupFramePolicy()` не владеет всей group системой сам по себе.

Что он реально делает:
- переключает Roth vs Blizzard
- зовёт `ns.ApplyPartyEnabled(useParty)`
- зовёт `ns.ApplyRaidEnabled(useRaid)`

Подтверждение:
- `core/frame_policy.lua:619-687`

Но party/raid runtime уже живут отдельно:
- party header lifecycle: `units/party.lua:403-531`
- raid header lifecycle: `units/raid.lua:760-813`
- range driver lifecycle: `core/lib.lua:2122-2190`

Практический вывод:
- `frame_policy.lua` надо упрощать, но не как будто это единственный owner;
- это orchestration layer над:
  - party runtime
  - raid runtime
  - range runtime

## C4 - Secret-safe numeric/tag layer выглядит уже достаточно зрелой

`confirmed-static`: `core/tags.lua` и `core/unit_value_runtime.lua` выглядят как скорее foundation, чем hot problem area.

Что подтверждено:
- safe wrappers вокруг `UnitHealth/UnitPower`
- fallback на percent APIs
- отсутствие арифметики на secret values без проверки
- кэшированные text/color writes
- safe tag overrides для oUF

Подтверждение:
- `core/tags.lua:49-760`
- `core/unit_value_runtime.lua:25-595`

Практический вывод:
- эту часть лучше сохранять и переиспользовать;
- главный риск проекта всё ещё в ownership/lifecycle, а не здесь.

## C5 - Но secret-vocabulary ещё не везде централизован

`confirmed-static`: secret checks всё ещё локально дублируются в нескольких модулях:
- `units/target.lua`
- `units/raid.lua`
- `oUF/elements/rune_orbs.lua`
- `oUF/elements/target_border.lua`
- `modules/oUF_Smooth.lua`
- `core/target_castbar.lua`

Практический вывод:
- это не urgent defect;
- это long-term cleanup target:
  - один shared safety vocabulary
  - меньше локальных `IsSecretValue` wrappers

## C6 - Blizzard compact aura path окончательно подтверждает future direction

`confirmed-static`: Blizzard compact frames реально используют incremental aura payload:
- `addedAuras`
- `updatedAuraInstanceIDs`
- `removedAuraInstanceIDs`

Подтверждение:
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66198/Blizzard_UnitFrame/Shared/CompactUnitFrame.lua:1854-1900`

Практический вывод:
- если Roth позже полезет глубже в party/raid aura logic, правильный путь только diff-based;
- full rescan path надо считать временным или локальным fallback.

