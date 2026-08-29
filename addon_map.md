# Roth_UI — Карта аддона и зависимостей v4

Обновлено: 2026-03-18

## Архитектурный обзор

```
┌─────────────────────────────────────────────────────────────┐
│                         Roth_UI                             │
│                   (oUF layout + Diablo UI)                  │
├────────────┬──────────────┬──────────────┬──────────────────┤
│  Unit      │  Action Bars │  Orbs        │  Settings &      │
│  Frames    │  & Dock      │  (Health/    │  Persistence     │
│  (oUF)     │  (LAB)       │   Power)     │  (Blizzard API)  │
├────────────┼──────────────┼──────────────┼──────────────────┤
│  oUF       │  LAB-1.0-GE  │  Custom      │  SV + Blizzard   │
│  Elements  │  LibKeyBound │  Rendering   │  Settings        │
│  Castbar   │  StateDriver │  3D Models   │  Framework       │
└────────────┴──────────────┴──────────────┴──────────────────┘
       │              │              │               │
       ▼              ▼              ▼               ▼
┌─────────────────────────────────────────────────────────────┐
│              Внешние зависимости                            │
│  oUF · LibActionButton · LibSharedMedia · LibKeyBound       │
│  LibStub · CallbackHandler                                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 1. Слои загрузки (Load Order из TOC)

### Слой 0: Библиотеки
```
embeds/rLib/rLib.xml          → core, grid, snapguides, dragframe (legacy mover), framefader, slashcmd
Libs/LibStub                  → dependency resolver
Libs/CallbackHandler-1.0      → event callback pattern
Libs/LibActionButton-1.0-GE   → action button wrapper (LAB)
Libs/LibSharedMedia-3.0        → font/texture registry
Libs/LibKeyBound-1.0           → keybinding UI (10 файлов: core + 9 locale)
```

#### rLib детали
- `rLib/core.lua` — базовый фреймворк, глобальный `rLib` table
- `rLib/grid.lua` — alignment grid overlay для позиционирования
- `rLib/snapguides.lua` — snap guides для drag'а
- `rLib/dragframe.lua` — **LEGACY mover**: создаёт drag overlays, cursor tracking, position persistence → КОНФЛИКТ с core/mover_runtime.lua
- `rLib/framefader.lua` — mouseover fade animation, экспортирует `rButtonBarFader()`
- `rLib/slashcmd.lua` — base slash command infrastructure

#### LibActionButton-1.0-GE
- Fork стандартного LAB для Galaxy Edition
- Экспортирует: `LAB:CreateButton()`, `button:SetState()`, `button:UpdateConfig()`, `button:UpdateAction()`
- Содержит TODO/XXX комментарии (строки 482, 570, 792, 1596, 1617, 3053) — но это внешняя библиотека, не трогать

### Слой 1: Инициализация
```
init.lua                       → глобальный ns, _G.Roth_UI, color compat, callback infra
```
**init.lua содержит:**
- Строка 8: `_G.Roth_UI = Roth_UI` — глобальный ns для module-addons
- Строка 12: `Roth_UI.disableProtectedActionBarOwnership = true` — **★ ПРОБЛЕМА: активирует Path B для всех bars**
- Строки 15-16: `ns.oUF`, `ns.rLib` — external lib refs
- Строки 26-41: `Roth_MakeColor()` — color compat для oUF 13.x (GetRGB() support)
- Строки 45-66: oUF color bootstrap — power colors с GetRGB() fallback
- Строки 82-141: Callback system — `ListenForLoaded()`, `ListenForMediaChange()`, `InitConfig()`
- Строки 98-101: `EnsureConfigRoot()` — requires ns.persistence (assert)

#### ★ Нюанс: init.lua color compat vs oUF native ColorMixin
oUF 13.x использует `ColorMixin` objects нативно (с `:GetRGB()`). Roth's `Roth_MakeColor()` обёртка добавляет `GetRGB()` к plain {r,g,b} tables. **Потенциальный конфликт:** если oUF внутренне ожидает ColorMixin метатаблицу, Roth's plain table с GetRGB() function может сломать `color:IsEqualTo()` или `color:SetAtlas()`. Проверить через `type(oUF.colors.power[0])` — если это полноценный ColorMixin, Roth_MakeColor обёртка не нужна.

### Слой 2: oUF элементы + дефолты
```
oUF/elements/target_border.lua → oUF custom element: boss/rare border glow on target
oUF/elements/experience.lua    → oUF custom element: experience bar (vehicle-aware)
                                  ★ ДУБЛЬ: bars.lua строки ~60-200 тоже реализуют Experience bar
oUF/elements/reputation.lua    → oUF custom element: reputation bar
                                  ★ ДУБЛЬ: bars.lua строки ~200-350 тоже реализуют Reputation bar
# НЕ В TOC: oUF/elements/rune_orbs.lua — мёртвый файл на диске (УДАЛИТЬ)
defaults/party.lua             → party layout defaults (spacing, sizing, art)
defaults/raid.lua              → raid layout defaults (spacing, sizing, indicators)
```

#### ★ Нюанс: experience.lua / reputation.lua двойная регистрация
Файлы `oUF/elements/experience.lua` и `oUF/elements/reputation.lua` регистрируют oUF elements через `oUF:AddElement()`. Но `core/bars.lua` тоже содержит Experience и Reputation bar код (строки ~60-350) и регистрирует их КАК oUF elements. Нужно выбрать ОДНУ реализацию. Рекомендация: оставить `oUF/elements/` версии (они vehicle-aware и следуют стандартному oUF element pattern), удалить из bars.lua.

### Слой 3: Persistence инфраструктура
```
core/safety.lua                  → secret value guards (IsSecret, TryCall, TryMethod),
                                    serialization helpers (IsSerializablePrimitive,
                                    SanitizeSerializableInPlace)
core/deferred_scheduler.lua      → deferred task queue (ns.defer.Schedule)
core/group_header_visibility.lua → group header secure visibility conditions
                                    ★ Содержит secure condition strings для party/raid show/hide
                                    Формат: "[group:party] show; hide" etc.
                                    Используется: party.lua, raid.lua при oUF:SpawnHeader()
core/config_persistence_owner.lua→ ★ config ownership, defaults merge, SV init,
                                    schema patches (v1→v17), cfg proxy (22 KB)
config.lua                       → ★ defaults definition (cfg table v60, 31 KB)
charspecific.lua                 → per-char overrides (DISABLED — early return на строке 2)
core/persistence_runtime_state.lua → volatile runtime buckets (non-persistent cache)
                                    ★ Хранит transient state: "какой bar active",
                                    "is mover unlocked" — НЕ сохраняется в SV
core/persistence_root_store.lua    → canonical SV root accessors
core/sv_store.lua                  → path/value API over SV (GetPath, SetPath, EnsurePath)
core/persistence_domain_registry.lua   → domain metadata (config, orbs)
core/persistence_schema_registry.lua   → schema definitions (migration version)
core/persistence_drift_service.lua     → drift detection (config deviation from defaults)
core/persistence_reconcile_service.lua → store reconciliation (merge conflicts)
core/persistence_control_plane.lua     → ★ public ns.persistence facade
core/persistence_report_service.lua    → diagnostic reports (debug-only)
core/sv_doctor.lua                     → SV repair utility
```

### Слой 4: Core Runtime
```
core/logger.lua                → logging (ns.logger.Info/Warn/Error)
core/movegrid.lua              → alignment grid toggle
core/hide_endcaps.lua          → MainMenuBar endcap art toggle
core/bootstrap.lua             → ★ fires InitConfig(), lifecycle trigger (ADDON_LOADED→PLAYER_LOGIN)
core/orb_text_controller.lua   → orb text display logic (format, abbreviate, font resolve)
                                  ★ НЮАНС: ResolveFontPath() вызывается каждый update,
                                  нет кэширования → CPU burn (fix: cache font path)
core/db.lua                    → ★ orb database: defaults, textures, templates (970 строк)
core/orb_persistence_owner.lua → orb SV ownership (char state read/write)
core/frame_registry.lua        → ★ namespace frame registry: ns.frameRegistry
                                  (категории: art, bars, units, orbs)
core/bar_runtime_registry.lua  → ★ action bar metadata & ownership registry:
                                  ns.BarRuntimeRegistry, DEFAULT_DESCRIPTORS,
                                  RegisterFrame, ResolveFrame, ApplyVisibilityDriver,
                                  NotifyChanged, ResolveDockMember
```

### Слой 5: Bars & Settings
```
core/leave_vehicle_bar.lua     → vehicle leave button (гейт: embeds.rActionBarStyler)
core/extrabar_holder.lua       → ExtraAction/ZoneAbility holder + follower (гейт: embeds.rActionBarStyler)
core/pet_action_bar.lua        → pet action bar (гейт: embeds.rActionBarStyler)
core/stance_bar.lua            → stance/shapeshift bar (гейт: embeds.rActionBarStyler)
core/micromenu_bar.lua         → micro menu bar (гейт: embeds.rActionBarStyler)
core/bags_bar.lua              → bags bar (гейт: embeds.rActionBarStyler)
core/orb_runtime.lua           → orb visual runtime: fill animation, color application, model update
core/settings_main.lua         → ★ Blizzard Settings framework UI: category registration,
                                  RegisterCanvasLayoutCategory, RegisterAddOnCategory
                                  ★ НЮАНС: EnsureRegenQueue() creates PLAYER_REGEN_ENABLED
                                  listener that NEVER unregisters (minor event leak)
core/settings_general.lua      → general settings (frame lock, show/hide, font)
                                  ★ CRASH: строка 13 assert(ns.settingsActions) — loads before settings_actions
                                  ★ CRASH: строка 3 assert(ns.SettingsUI) — OK если settings_main создаёт
                                  ★ CRASH: строка 10 requires ns.BarRuntimeRegistry — OK (TOC 60)
core/target_castbar.lua        → standalone castbar runtime (703 строки, semantic color, custom art)
                                  ★ ДУБЛИРУЕТ oUF Castbar event tracking (~200 строк)
                                  ★ НЮАНС: color resolution не поддерживает oUF ColorMixin
                                  (строки 93-95, нет GetRGB() fallback)
core/settings_target.lua       → target castbar settings (colors, size, position)
core/settings_groups.lua       → party/raid settings (enable, layout, aura filter)
core/settings_orbs.lua         → orb settings (texture, color, text format)
core/transfer.lua              → settings export/import (serialize/deserialize)
core/settings_actions.lua      → ★ settings action handlers (reset, apply, ns.settingsActions)
core/settings_transfer.lua     → transfer UI (export/import panel)
core/debug_commands.lua        → debug slash commands (/rothui debug, /rothui dump)
core/slashcmd.lua              → main slash commands (/rothui, /rothui reset, /rothui unlock)
```

### Слой 6: Lib & Policies
```
core/lib.lua                   → ★ МОНОЛИТ: helper functions (56 KB, 2351 строк)
core/mover_runtime.lua         → ★ frame mover persistence (22 KB): AttachLegacyDragFrame,
                                  SavePosition, RestorePosition, category system
                                  ★ НЮАНС: restoration не проверяет InCombatLockdown()
                                  (party/raid header rebuild в бою → taint)
core/unit_value_runtime.lua    → health/power value formatters (shortNumbers, abbreviate)
core/unit_misc_runtime.lua     → unit misc helpers (group role, classification)
core/group_aura_watch.lua      → group aura tracking: whitelist/blacklist filter,
                                  debuff type coloring, boss debuff highlight,
                                  ★ PERFORMANCE: full harmful scan (AuraUtil.ForEachAura)
core/frame_policy.lua          → frame visibility/hide policies (ShowFrame, HideFrame, ParkFrame)
                                  ★ НЮАНС: ParkFrame не проверяет IsForbidden(hiddenParent)
core/font_policy.lua           → global font application (apply font to all registered frames)
core/group_policy.lua          → party/raid policy: SafeLoadAddOn, SafeSetParent,
                                  SafeCallMethod, ParkFrame, IsRothEnabled
                                  ★ НЮАНС: CompactRaidFrameManager_UpdateShown() может taint
                                  (прямой вызов без TryCall обёртки)
core/unit_policy.lua           → unit frame policy (target, focus visibility)
core/frame_policy_bootstrap.lua→ policy init orchestration (wire up all policies)
core/blizzard_restore_debug.lua→ Blizzard frame restore debug (diagnostic tool)
core/tags.lua                  → oUF tag definitions: [roth:name], [roth:hp], [roth:pp],
                                  [roth:level], class coloring, secret-safe formatting
core/bars.lua                  → ★ class resource bars (34 KB, 1074 строки):
                                  Chi, HolyPower, Runes, ComboPoints, ArcaneCharges,
                                  SoulShards, Experience bar, Reputation bar
                                  ★ oUF ClassPower element заменяет ВСЕ class resources —
                                  огромное упрощение (см. §6a)
core/units.lua                 → ns.unit контейнер (пустой; spawn/style — в units/*.lua)
```

### Слой 7: Unit Frames
```
units/target.lua               → target unit frame: oUF style + castbar + portrait + auras
units/targettarget.lua         → target-of-target: uses mini_target_scaffold
units/pet.lua                  → pet frame: uses mini_target_scaffold
units/mini_target_scaffold.lua → ★ shared mini frame builder: Health, Power, Name, Tags
                                  (правильный oUF паттерн — self.Health = health)
units/focus.lua                → focus frame: uses mini_target_scaffold + castbar
units/pettarget.lua            → pet target: uses mini_target_scaffold
units/focustarget.lua          → focus target: uses mini_target_scaffold
units/party.lua                → party group header: oUF:SpawnHeader, threat coloring,
                                  aura filter, deferred spawn (combat safety)
                                  ★ НЮАНС: event cleanup — UNIT_AURA не unregister'ится при
                                  header park/destroy (stale listener leak)
                                  ★ НЮАНС: race condition — SpawnPartyHeader() может вернуть
                                  nil, но partyHeader не обнуляется → infinite loop на rebuild
units/raid.lua                 → raid group header (24 KB): oUF:SpawnHeader, arena prep,
                                  aura filter, threat coloring, deferred spawn
                                  ★ НЮАНС: threat event не cleanup'ится при header rebuild
                                  ★ НЮАНС: customFilter() не проверяет spellID на
                                  issecretvalue() → может упасть в combat (12.x)
units/boss.lua                 → boss frames: 5 boss unit frames, castbar, target_border
units/player.lua               → ★ player frame + orbs (32 KB, 1049 строк)
                                  ★ Player castbar: custom, НЕ oUF Castbar element
                                  ★ Напрямую читает UnitHealth/UnitPower для orbs
                                  ★ 4 persistence accessors (cfg, db, store, orbPersistence)
```

### Слой 8: Action Bars (новый стек)
```
core/action_bar_multibar_visibility.lua → multi-bar visibility driver
                                  ★ КОНФЛИКТ: грузится до secure_runtime (TOC 105 vs 106),
                                  оба могут регистрировать state drivers → race condition
core/action_bar_secure_runtime.lua      → ★ secure bar management (549 строк):
                                  LAB integration, CreateBarFrame, SpawnMainBar, SpawnAuxBar,
                                  page/visibility drivers, button config, bindings,
                                  ★ ВЫКЛЮЧЕН дефолтом (secureOwnerBars=false)
                                  ★ CRITICAL: строка 103 — GetCVarBool() УДАЛЁН в 12.x,
                                  clickOnDown ВСЕГДА false (keybind broken)
                                  Фикс: C_CVar.GetCVar("ActionButtonUseKeyDown") == "1"
core/action_bar_bar1.lua                → main action bar: only Path A or direct registration
core/action_bar_overridebar.lua         → override bar: direct registration only
core/action_bar_bar2.lua                → bottom left bar: 3 code paths (133 строки)
core/action_bar_bar3.lua                → bottom right bar: 3 code paths
core/action_bar_bar4.lua                → right bar 1: 3 code paths + combineBar4AndBar5
core/action_bar_bar5.lua                → right bar 2: 3 code paths + combined mode check
core/action_bar_dock.lua                → bottom dock layout: uses barRuntimeRegistry
core/action_bar_background.lua          → bar artwork/background: exp/rep art overlay
```

### Слой 9: Legacy модули (embedded)
```
modules/Roth_UI_oUFModules/    → oUF_Smooth (smoothing animation library)
                                  ★ Retail 12.x: StatusBarInterpolation.ExponentialEaseOut —
                                  нативная альтернатива, используемая зрелыми Retail UI-реализациями.
                                  oUF_Smooth может быть НЕ нужен на Retail.
modules/Roth_UI_rActionBarStyler/ → ★ LEGACY:
  rActionBar.xml               → загружает: hide_blizzart, slashcmd, spellflyout, cooldown
  hide_blizzart.lua            → прячет Blizzard bars (НЕ пишет geometry)
  slashcmd.lua                 → slash commands (дублирует core/slashcmd.lua — подтверждено)
  spellflyout.lua              → flyout button styling
  cooldown.lua                 → cooldown text/spiral styling
  гейт: cfg.embeds.rActionBarStyler
modules/Roth_UI_rButtonTemplate/  → core.lua: глобальный _G.rButtonTemplate{} + StyleActionButton()
  гейт: cfg.embeds.rButtonTemplate
modules/Roth_UI_rButtonTemplate_Roth/ → theme.lua: Roth-specific button theme (Diablo skin)
  гейт: cfg.embeds.rButtonTemplate
```

---

## 2. Карта зависимостей: кто от кого зависит

### Ядро persistence (8 файлов — ПЕРЕУСЛОЖНЕНО)
```
config_persistence_owner ◄─── config.lua (defaults)
         │
         ▼
persistence_root_store ──────► ns.configPersistence (однонаправленная зависимость)
         │
         ├── sv_store
         ├── persistence_runtime
         └── persistence_domain

persistence_control_plane (facade)
         │
         ├── persistence_reconcile_service
         ├── persistence_drift_service
         └── persistence_report_service
                  │
                  ▼
             sv_doctor (repair)
```
**Проблема:** 8 файлов persistence для простого SV store. Однонаправленная цепочка зависимостей (root_store → config_owner), но сложный порядок инициализации и размазанная ответственность.

### Settings система
```
settings_main ──► Blizzard Settings Framework (RegisterCanvasLayoutCategory)
     │              ★ НЮАНС: regen frame listener NEVER unregisters
     │
     ├── settings_general  ──► [CRASH: requires settings_actions, loads before it (TOC 69 vs 75)]
     │                         [requires ns.SettingsUI (TOC 68 — OK если settings_main создаёт)]
     │                         [requires ns.BarRuntimeRegistry (TOC 60 — OK)]
     ├── settings_target   ──► target_castbar (runtime config)
     ├── settings_groups   ──► group_policy, group_header_visibility
     ├── settings_orbs     ──► orb_runtime, db
     ├── settings_actions  ──► persistence (reset/apply), ns.settingsActions table
     └── settings_transfer ──► transfer (export/import)
```
**Проблема:** settings_general загружается до settings_actions, но требует ns.settingsActions через assert.

### Init / Lifecycle
```
TOC load → init.lua (ns setup, _G.Roth_UI, color compat)
         → [Layers 0-9 sequential load]

ADDON_LOADED event:
  → bootstrap.lua → InitConfig()
    → EnsureConfigRoot() (persistence facade)
    → configLoaded = true
    → fire loadedCallbacks[]

PLAYER_LOGIN event:
  → bootstrap.lua lifecycle trigger
  → frame_policy_bootstrap applies policies
  → font_policy applies fonts

PLAYER_ENTERING_WORLD event:
  → party.lua deferred spawn
  → raid.lua deferred spawn + arena prep
  → player.lua model visibility
```

#### ★ Нюанс: oUF Factory не используется
oUF предоставляет `oUF:Factory(function(oUF) ... end)` для отложенной инициализации до PLAYER_LOGIN. Roth_UI вместо этого использует свой bootstrap.lua → InitConfig() → loadedCallbacks.

**oUF Factory гарантирует:**
1. Все oUF internals инициализированы
2. PLAYER_LOGIN уже произошёл
3. Корректный порядок style → spawn

**Рекомендация:** Обернуть все `oUF:RegisterStyle()` + `oUF:Spawn()` вызовы в `oUF:Factory()`:
```lua
-- Вместо текущего (в каждом units/*.lua):
oUF:RegisterStyle("Roth_Target", targetStyle)
oUF:SetActiveStyle("Roth_Target")
oUF:Spawn("target", "Roth_UITargetFrame")

-- Рекомендуется:
oUF:Factory(function(self)
  self:RegisterStyle("Roth_Target", targetStyle)
  self:SetActiveStyle("Roth_Target")
  self:Spawn("target", "Roth_UITargetFrame")
end)
```

### Action bars (code path'ы + legacy модуль)

**Все action_bar_barN.lua + overridebar гейтятся `cfg.embeds.rActionBarStyler == false → return`**
**init.lua:12 устанавливает `disableProtectedActionBarOwnership = true` (emergency combat fallback)**

```
┌─────────────────────────────────────────────────────────────┐
│  core/action_bar_bar2..5.lua — 3 пути выполнения:          │
│                                                             │
│  Path A: secureActionBarRuntime.IsEnabled()                 │
│    → LAB:CreateButton(), Roth_UISecureBar* фреймы           │
│    → (единый LAB/secure-owner паттерн, гейт: cfg.bars.secureOwnerBars=false) │
│    → НЕАКТИВЕН (secureOwnerBars=false в config.lua:622)     │
│                                                             │
│  Path B: ns.disableProtectedActionBarOwnership  ★ АКТИВЕН   │
│    → Регистрирует Blizzard фреймы as-is в barRuntimeReg    │
│    → init.lua:12 ставит flag=true, это ФАКТИЧЕСКИЙ дефолт  │
│                                                             │
│  Path C: CreateFrame("rABS_*")  ★ МЁРТВЫЙ КОД              │
│    → Репарентит Blizzard кнопки в rABS_* фреймы             │
│    → НИКОГДА НЕ ВЫПОЛНЯЕТСЯ (Path B перехватывает раньше)   │
│                                                             │
│  bar1 — особый: только Path A или прямая регистрация        │
│    MainActionBar, НЕТ Path B/C                              │
│  overridebar — особый: только прямая регистрация            │
│    OverrideActionBar, НЕТ 3 path'ов                         │
└─────────────────────────────────────────────────────────────┘

┌──────────────────────────────┐
│  rActionBarStyler/ (legacy)  │
│   hide_blizzart.lua — ПРЯЧЕТ Blizzard bars (НЕ пишет geometry) │
│   spellflyout.lua — стиль flyout                            │
│   cooldown.lua — стиль cooldown                             │
│   slashcmd.lua — slash commands (ДУБЛЬ core/slashcmd)       │
│   гейт: cfg.embeds.rActionBarStyler                         │
└──────────────────────────────┘

┌──────────────────────────────┐
│  rButtonTemplate/ (legacy)   │
│   core.lua — глобальный _G.rButtonTemplate{} + StyleActionButton() │
│   ★ secure_runtime.lua:138 использует _G.rButtonTemplate    │
│   гейт: cfg.embeds.rButtonTemplate                          │
│  rButtonTemplate_Roth/       │
│   theme.lua — Roth-specific button theme (Diablo art)       │
└──────────────────────────────┘

         ▼ Все пути в итоге работают с:
   ┌─────────────────────────────────────────────┐
   │  Blizzard MainActionBar + ActionButton1..12  │
   │  (PROTECTED — нельзя reparent в combat)      │
   └─────────────────────────────────────────────┘
```
**Проблема:** Три code path'а в bar2-5 усложняют maintenance, при том что реально работает только Path B (Blizzard as-is). Path C (rABS_* reparent) — мёртвый код. Path A (LAB secure) отключён дефолтом (secureOwnerBars=false). Dock members (bags, micromenu, pet, stance) тоже имеют Path B ветку. bar1 и overridebar — только прямая регистрация.

### Unit frames (oUF layout)
```
units.lua (ns.unit контейнер, пустой)
Каждый unit файл сам: oUF:RegisterStyle() + oUF:Spawn()
     │
     ├── player.lua ──► orb_runtime, db, orb_persistence_owner
     │                   lib.lua (health/power/value helpers)
     │                   mover_runtime, OrbTextController
     │                   ★ Читает 4 persistence accessor'а
     │                   ★ Player castbar: свой runtime, НЕ oUF Castbar
     │
     ├── target.lua ──► lib.lua, target_castbar, mover_runtime
     ├── party.lua  ──► group_policy, group_aura_watch, defaults/party
     │                   ★ UNIT_AURA listener leak при header rebuild
     │                   ★ Race condition при spawn failure
     ├── raid.lua   ──► group_policy, group_aura_watch, defaults/raid
     │                   ★ Threat event not cleaned on header rebuild
     │                   ★ spellID secret check missing in filter
     ├── boss.lua   ──► target_castbar, lib.lua, target_border element
     ├── focus.lua  ──► mini_target_scaffold, target_castbar (optional)
     └── [pet, tt, ft, pt] ──► mini_target_scaffold, lib.lua
```
**Проблема:** player.lua — монолит 32KB, напрямую читает 4 разных persistence accessor'а (ns.cfg, ns.db, ns.store, ns.orbPersistence). lib.lua — монолит 56KB, содержит всё от unit helpers до secret guards.

### Mover система (ДВОЙНАЯ)
```
embeds/rLib/dragframe.lua     → legacy: creates drag overlays, cursor tracking,
                                 position save/restore to SV
core/mover_runtime.lua        → new: persistence, categories, saved layout,
                                 AttachLegacyDragFrame (bridge to dragframe)
                                 ★ НЮАНС: restoration не defers InCombatLockdown()
```
**Проблема:** Две системы движения фреймов работают параллельно. mover_runtime.AttachLegacyDragFrame использует dragframe визуал, но они могут сохранять позиции независимо.

---

## 3. Ownership Matrix: текущее состояние

| Домен            | Должен владеть   | Сейчас владеет            | Конфликт?  |
|------------------|-------------------|---------------------------|------------|
| Bar shell        | core/action_bar_* | Path B active (Blizzard as-is), Path C мёртв, Path A выключен | ★ ДА    |
| Bar visibility   | bar_runtime_reg   | bar_runtime + multibar_vis| ★ ДА       |
| Bar dock         | action_bar_dock   | dock ← barRuntimeRegistry (legacy names) | КОСВЕННО   |
| Bar artwork      | action_bar_bg     | bg + bars.lua (Exp/Rep)   | ★ ДА       |
| Config SV        | persistence_cp    | 8 файлов persistence      | СЛОЖНОСТЬ  |
| Orb SV           | orb_persist_owner | orb_owner + db + sv_store + store API | СЛОЖНОСТЬ  |
| Unit frames      | oUF + units/*.lua | oUF + lib.lua монолит     | СМЕШАННОЕ  |
| Movers           | mover_runtime     | mover_runtime + dragframe | ★ ДА       |
| Settings UI      | settings_main     | settings_* + slashcmd     | ДУБЛИ      |
| Reset/Apply      | settings_actions  | settings_actions + lib + slashcmd | ДУБЛИ      |
| Secret checks    | ns.safety         | safety + lib.lua + target_castbar + tags | 4 ДУБЛЯ   |
| Blizzard hide    | frame_policy      | frame_policy + hide_blizzart.lua | ДУБЛИ     |
| Class resources  | oUF ClassPower    | bars.lua per-class custom  | ★ ДУБЛЬ   |
| Exp/Rep bars     | oUF elements      | oUF/elements/ + bars.lua   | ★ ДУБЛЬ   |
| Player castbar   | oUF Castbar       | player.lua custom runtime  | ★ ДУБЛЬ   |
| Target castbar   | oUF Castbar       | target_castbar.lua 703 строк | ★ ДУБЛЬ |
| Smoothing        | oUF/StatusBarInterp | oUF_Smooth module         | ПРОВЕРИТЬ  |
| CVar access      | C_CVar            | GetCVarBool (removed 12.x) | ★ BROKEN  |
| Color resolution | oUF ColorMixin    | Roth_MakeColor plain tables | ПРОВЕРИТЬ |

---

## 4. Файлы-монолиты (требуют разбиения)

| Файл              | Размер  | Строки | Проблема                                      |
|--------------------|---------|--------|-----------------------------------------------|
| core/lib.lua       | 56 KB   | 2351   | Всё: unit helpers, secret guards, formatters, oUF element creators  |
| core/bars.lua      | 34 KB   | 1074   | Class resource bars (Chi/HolyPower/Runes/Combo) + Exp/Rep |
| config.lua         | 31 KB   | ~1622  | Defaults + schema + all unit configs (v60)     |
| units/player.lua   | 32 KB   | 1049   | Player + orbs + class bars + all indicators    |
| units/raid.lua     | 24 KB   | ~800   | Raid layout + aura + visibility + deferred + arena |
| core/mover_runtime | 22 KB   | ~700   | Mover persistence + categories + apply + bridge |
| core/config_p_own  | 22 KB   | ~700   | Config ownership + reconcile + schema patches  |
| core/target_castbar| ~20 KB  | 703    | Castbar runtime + color + art + settings       |

---

## 5. Детальный breakdown монолитов

### 5a. core/lib.lua (56 KB, 2351 строк)

```
Строки 1-100:    INIT + Secret Value Guards
  ├── ns.func = CreateFrame("Frame")
  ├── _G.RothUI = {} (★ пустой глобал, нигде не используется)
  ├── ns.IsAddOnLoadedCompat = C_AddOns.IsAddOnLoaded
  ├── _G.IsAddOnLoadedCompat shim (★ нужен ли?)
  ├── func.IsSecretValue(v) — wrapper over issecretvalue/_nativeIsSecret
  ├── func.SafeUnitHealth(unit) — secret-safe UnitHealth
  ├── func.SafeUnitHealthMax(unit) — secret-safe UnitHealthMax
  ├── func.SafeUnitPower(unit, powerType) — secret-safe UnitPower
  └── func.SafeUnitPowerMax(unit, powerType) — secret-safe UnitPowerMax

Строки ~100-300:  Font & Icon Helpers
  ├── func.createFontString(parent, font, size, flags) — create FontString
  ├── func.ResolveFontPath(name) — LSM font resolve
  ├── func.createIconTexture(parent, size) — create icon texture
  └── func.SetFontFamily(fontstring, font) — update font family

Строки ~300-600:  oUF Element CREATORS (★ ДУБЛИРУЮТ oUF — упростить)
  ├── func.createHealthBar(self, cfg) — creates self.Health StatusBar (~80 строк)
  ├── func.createPowerBar(self, cfg) — creates self.Power StatusBar (~60 строк)
  ├── func.createCastbar(self, cfg) — creates self.Castbar StatusBar (~100 строк)
  ├── func.createBuffs(self, cfg) — creates self.Buffs frame (~80 строк)
  ├── func.createDebuffs(self, cfg) — creates self.Debuffs frame (~80 строк)
  ├── func.createPortrait(self, cfg) — creates self.Portrait model (~40 строк)
  └── func.createAlternativePowerBar(self, cfg) — creates self.AlternativePower (~60 строк)

Строки ~600-900:  oUF Element DUPLICATION (★ УДАЛИТЬ — oUF делает это)
  ├── func.RefreshUnitHealthBar(frame, unit) — manual health bar update (~80 строк)
  ├── func.range driver — manual UnitInRange check + alpha (~50 строк)
  ├── func.checkThreat(frame, unit) — manual UnitThreatSituation check (~40 строк)
  └── func.colorByClass(frame, unit) — manual class color application

Строки ~900-1200: Aura Duration Tracking (★ ПЕРЕНЕСТИ в PostUpdate)
  ├── Duration overlay creation per aura button
  ├── Timer text formatting
  ├── Cooldown spiral management
  └── OnUpdate для duration ticking

Строки ~1200-1600: Drag / Mover Functions
  ├── func.applyDragFunctionality(frame, category) — ★ bridge to dragframe (legacy)
  ├── cursor position tracking
  └── drag start/stop handlers

Строки ~1600-2000: Formatting & Color Utilities
  ├── Number abbreviation (1k, 1m, 1b)
  ├── Class color cache
  ├── Reaction color helper
  ├── Health percentage formatting
  └── Power type name mapping

Строки ~2000-2351: Misc Helpers
  ├── Unit classification (elite, rare, boss)
  ├── Sound playback (target change)
  └── Frame utility wrappers
```

**Целевой split:**
- Удалить: строки 300-900 (oUF element creators + duplicated update logic)
- Перенести: строки 900-1200 (aura duration → oUF PostUpdate callbacks)
- Перенести: строки 1200-1600 (drag → mover_runtime only)
- Оставить: строки 1-100, 100-300, 1600-2351 (утилиты)
- Итог: ~600 строк

### 5b. core/bars.lua (34 KB, 1074 строки)

```
Строки 1-60:     INIT + Secret Value Guards + utility functions
Строки ~60-200:   Experience Bar oUF element (Enable/Disable/Update)
                   ★ ДУБЛЬ oUF/elements/experience.lua — удалить из bars.lua
Строки ~200-350:  Reputation Bar oUF element (Enable/Disable/Update)
                   ★ ДУБЛЬ oUF/elements/reputation.lua — удалить из bars.lua
Строки ~350-500:  ComboPoints element (★ ЗАМЕНИТЬ на oUF ClassPower)
Строки ~500-650:  Chi element (Monk, ★ ЗАМЕНИТЬ на oUF ClassPower)
Строки ~650-800:  HolyPower element (Paladin, ★ ЗАМЕНИТЬ на oUF ClassPower)
Строки ~800-900:  SoulShards element (Warlock, ★ ЗАМЕНИТЬ на oUF ClassPower)
Строки ~900-1000: ArcaneCharges element (Mage, ★ ЗАМЕНИТЬ на oUF ClassPower)
Строки ~1000-1074: Runes element (DK, ★ ЗАМЕНИТЬ на oUF ClassPower + Runes)
```

**Нюанс:** oUF ClassPower element обрабатывает ВСЕ class resources через единый интерфейс. Зрелые oUF layouts используют именно его. Roth_UI реализует каждый класс отдельно — это ~700 строк которые заменяются ~30 строками ClassPower setup.

### 5c. units/player.lua (32 KB, 1049 строк)

```
Строки 1-56:      INIT + 4 persistence accessors (cfg, db, storeApi, orbPersistence, orbText)
Строки ~57-72:     initUnitParameters(self) — frame setup, drag, click handlers
Строки ~72-120:    createAngelFrame / createDemonFrame — Diablo art overlays
Строки ~120-300:   Orb visual creation (health orb, power orb):
  ├── Health orb: custom StatusBar + 3D model + glow/overlay textures
  ├── Power orb: custom StatusBar + 3D model + glow/overlay textures
  └── Orb positioning and sizing from config
Строки ~300-500:   Class bar creation:
  ├── Chi, HolyPower, ComboPoints, Runes, SoulShards, ArcaneCharges
  ├── Calls bars.lua functions to create oUF elements
  └── Positioned relative to orbs
Строки ~500-700:   Indicators:
  ├── CombatIndicator (oUF ✓)
  ├── RestingIndicator (oUF ✓, строка 975)
  ├── PvPIndicator (oUF ✓, строка 979)
  ├── Player castbar (custom, NOT oUF Castbar element)
  │    ★ Отдельный runtime от target_castbar — ещё одна дублирующая реализация
  └── Custom threat glow
Строки ~700-850:   Update handlers:
  ├── Health update → orb fill (★ НАПРЯМУЮ вызывает UnitHealth)
  ├── Power update → orb fill (★ НАПРЯМУЮ вызывает UnitPower)
  ├── Dead/ghost state
  └── Vehicle enter/exit
Строки ~850-1000:  Style function + oUF:Spawn:
  ├── oUF:RegisterStyle("Roth_Player", styleFunc)
  ├── oUF:SetActiveStyle("Roth_Player")
  └── oUF:Spawn("player", "Roth_UIPlayerFrame")
Строки ~1000-1049: Post-spawn hooks + mover attachment
```

**Нюанс:** Player.lua напрямую вызывает UnitHealth/UnitPower для orb updates вместо использования oUF Health/Power PostUpdate. Это дублирование event handling. Также player castbar — ТРЕТЬЯ реализация castbar (после target_castbar.lua и lib.createCastbar).

### 5d. core/target_castbar.lua (703 строки)

```
Строки 1-30:      INIT + constants (hold time, fallback colors)
Строки 30-80:     Color resolution (semantic colors from settings)
                   ★ НЮАНС: строки 93-95 не поддерживают ColorMixin (:GetRGB())
Строки 80-200:    ApplyBarTint, ApplyCastState — visual state machine
Строки 200-400:   Event handlers:
  ├── UNIT_SPELLCAST_START → CastStart (★ oUF Castbar does this)
  ├── UNIT_SPELLCAST_STOP → CastStop
  ├── UNIT_SPELLCAST_FAILED → CastFail
  ├── UNIT_SPELLCAST_INTERRUPTED → CastInterrupt
  ├── UNIT_SPELLCAST_CHANNEL_START → ChannelStart
  ├── UNIT_SPELLCAST_CHANNEL_STOP → ChannelStop
  ├── UNIT_SPELLCAST_INTERRUPTIBLE → Recolor
  └── UNIT_SPELLCAST_NOT_INTERRUPTIBLE → Recolor
Строки 400-550:   OnUpdate tick (progress bar, time text, spark position)
Строки 550-650:   Visual setup (textures, backdrop, glow, overlay)
Строки 650-703:   Settings integration (read colors from cfg, apply)
```

**Итого из 703 строк:**
- ~200 строк — event tracking → УДАЛИТЬ (oUF Castbar handles)
- ~150 строк — color/tinting logic → ПЕРЕНЕСТИ в PostUpdate (~40 строк)
- ~200 строк — visual setup → ПЕРЕНЕСТИ в style function
- ~150 строк — settings + misc → УПРОСТИТЬ

---

## 6. Что делает oUF и что Roth_UI не должен дублировать

| Функционал           | oUF элемент          | Roth сейчас                          | Статус           |
|----------------------|----------------------|--------------------------------------|------------------|
| Health bar           | Health               | Orbs (custom) + lib.RefreshHealthBar | ЧАСТИЧНО oUF     |
| Power bar            | Power                | Orbs (custom) + lib.SafeUnitPower    | ЧАСТИЧНО oUF     |
| Castbar              | Castbar              | lib.createCastbar() + target_castbar.lua + player.lua custom | ★ 3 ДУБЛЯ |
| Auras (buffs/debuffs)| Auras                | lib.createBuffs/createDebuffs + custom duration | ЧАСТИЧНО oUF |
| Aura watch (group)   | —                    | group_aura_watch.lua (custom)        | REVIEW           |
| Health predict       | HealthPrediction     | Не используется в Roth_UI            | МОЖНО ДОБАВИТЬ   |
| Range check          | Range                | lib.lua: свой range driver + oUF Range | ДУБЛЬ, НАДО oUF |
| Portrait             | Portrait             | lib.createPortrait() создаёт oUF elem | ЧАСТИЧНО oUF   |
| AltPower             | AlternativePower     | lib.createAlternativePowerBar()      | ЧАСТИЧНО oUF     |
| Threat               | ThreatIndicator      | lib.checkThreat() свой handler       | НАДО oUF elem    |
| Combat indicator     | CombatIndicator      | Уже через oUF (units/)              | ОК               |
| Leader indicator     | LeaderIndicator      | Уже через oUF (party.lua)           | ОК               |
| Raid target icon     | RaidTargetIndicator  | Уже через oUF (units/)              | ОК               |
| Ready check          | ReadyCheckIndicator  | Уже через oUF (party.lua)           | ОК               |
| Resting indicator    | RestingIndicator     | Уже через oUF (player.lua:975)       | ОК               |
| PvP indicator        | PvPIndicator         | Уже через oUF (player.lua:979)       | ОК               |
| Unit colors          | oUF:CreateColor()    | Свои color tables + oUF.colors       | СМЕШАНО          |
| Blizzard disable     | oUF:DisableBlizzard()| frame_policy.lua + hide_blizzart.lua | ДУБЛЬ            |
| Frame spawning       | oUF:Spawn/Header     | units.lua                            | ОК               |
| Vehicle swap         | UNIT_ENTERED_VEHICLE | oUF elements (exp/rep) + action_bar_bg | ОК             |
| **ClassPower**       | **ClassPower**       | **bars.lua per-class (~700 строк)**  | **★ ДУБЛЬ**      |
| **Runes**            | **Runes**            | **bars.lua custom runes (~74 строки)**| **★ ДУБЛЬ**      |
| **Experience**       | **—** (custom elem)  | **oUF/elements/exp + bars.lua**      | **★ 2 ДУБЛЯ**    |
| **Reputation**       | **—** (custom elem)  | **oUF/elements/rep + bars.lua**      | **★ 2 ДУБЛЯ**    |
| GroupRole indicator  | GroupRoleIndicator   | Не используется                      | МОЖНО ДОБАВИТЬ   |
| Resurrect indicator  | ResurrectIndicator   | Не используется                      | МОЖНО ДОБАВИТЬ   |
| Smoothing            | StatusBarInterpolation | oUF_Smooth module (legacy)         | ПРОВЕРИТЬ        |

### 6a. ★ oUF ClassPower — главное упрощение bars.lua

oUF ClassPower element **автоматически** обрабатывает:
- Combo Points (все классы)
- Chi (Monk)
- Holy Power (Paladin)
- Soul Shards (Warlock)
- Arcane Charges (Mage)
- Essence (Evoker)
- Runes (Death Knight) — через отдельный Runes element

**oUF ClassPower API:**
```lua
-- В style function:
local ClassPower = {}
for i = 1, 10 do  -- max possible (combo points with talents)
  ClassPower[i] = CreateFrame("StatusBar", nil, self)
  ClassPower[i]:SetSize(12, 12)
  ClassPower[i]:SetStatusBarTexture(mediapath .. "classbar_fill")

  -- Positioning
  if i > 1 then
    ClassPower[i]:SetPoint("LEFT", ClassPower[i-1], "RIGHT", 2, 0)
  else
    ClassPower[i]:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
  end
end

-- oUF callbacks:
ClassPower.PostUpdate = function(element, cur, max, hasMaxChanged, powerType)
  -- Custom styling: Roth orb art, size adjustments
  for i = 1, max do
    element[i]:SetShown(true)
    if i <= cur then
      element[i]:SetAlpha(1)
    else
      element[i]:SetAlpha(0.3)
    end
  end
  for i = max + 1, #element do
    element[i]:SetShown(false)
  end
end

self.ClassPower = ClassPower
-- oUF auto-detects class and registers events
```

**После замены на oUF ClassPower:** ~700 строк → ~30 строк setup + ~20 строк PostUpdate

### 6b. ★ oUF_Smooth vs StatusBarInterpolation

**Retail 12.x** предоставляет нативную интерполяцию:
```lua
-- Native Retail pattern:
if E.Retail then
  health.smoothing = StatusBarInterpolation.ExponentialEaseOut
else
  E:SetSmoothing(health, true)  -- custom smoothing for Classic
end
```

**Рекомендация:** На Retail использовать `StatusBarInterpolation.ExponentialEaseOut`.

---

## 7. Проверенные внешние паттерны (без копирования кода)

| Паттерн                        | External reference             | Roth_UI план                    |
|--------------------------------|--------------------------------|---------------------------------|
| Module registration            | E:NewModule()                  | ns:NewModule() или простой table|
| Combat defer                   | InCombatLockdown() → defer     | ns.defer.Schedule() (уже есть)  |
| Settings → Refresh chain       | db change → UpdateButtonSettings| settings → ns.ApplyBarLayout()  |
| Bar creation                   | LAB:CreateButton() per bar     | secure_runtime (уже реализован) |
| State driver                   | RegisterStateDriver(bar,page)  | secure_runtime (уже реализован) |
| Mover system                   | E:CreateMover(bar, id, label)  | mover_runtime (упростить)       |
| Handled bars registry          | AB.handledBars = {}            | bar_runtime_registry (есть)     |
| Button config table            | bar.buttonConfig → UpdateConfig| BuildButtonConfig (есть)        |
| Fade parent (mouseover)        | AB.fadeParent                  | rButtonBarFader (есть)          |
| Three-tier SV                  | GlobalDB/PrivateDB/CharacterDB | Roth_UI_DB/Roth_UI_DB_Char     |
| DeepCopy defaults              | E:CopyTable(sv, defaults)      | DeepMerge (есть)               |
| Hidden parent frame            | E.HiddenFrame → SetParent      | group_policy.ParkFrame (есть)  |
| Position string                | 'POINT,Anchor,RelPt,X,Y'      | mover_runtime (похожий формат) |
| ClassPower unified element     | UF:GetClassPower_Construct()   | bars.lua per-class (заменить)  |
| oUF Factory for spawn          | oUF:Factory(function() end)    | bootstrap.lua (заменить)       |
| StatusBarInterpolation         | health.smoothing = ...         | oUF_Smooth (заменить на native)|
| Construct/Configure separation | Construct_*() + Configure_*()  | Нет (всё в style function)     |
| CVar access                    | C_CVar.GetCVar()               | GetCVarBool (★ BROKEN — fix)   |

### 7a. ★ Construct/Configure pattern

Зрелые UI-реализации разделяют **создание** виджетов (Construct) и **настройку** (Configure). Это позволяет обновлять layout без пересоздания фреймов:

```lua
-- Construct: один раз при создании фрейма
function UF:Construct_HealthBar(frame, bg, text, textPos)
  local health = CreateFrame('StatusBar', '$parent_HealthBar', frame)
  health:SetFrameLevel(10)
  health.PostUpdate = UF.PostUpdateHealth
  health.PostUpdateColor = UF.PostUpdateHealthColor
  if bg then
    health.bg = health:CreateTexture(nil, 'BORDER')
    health.bg:SetAllPoints()
  end
  if text then
    health.value = UF:CreateRaisedText(frame.RaisedElementParent)
  end
  health:CreateBackdrop(nil, nil, nil, nil, true)
  return health
end

-- Configure: при каждом изменении настроек
function UF:Configure_HealthBar(frame, powerUpdate)
  local db = frame.db
  local health = frame.Health
  health:SetColorTapping(true)
  health:SetColorDisconnected(true)
  -- Smoothing
  if E.Retail then
    health.smoothing = (db.health.smoothbars and StatusBarInterpolation.ExponentialEaseOut) or nil
  end
  -- Text position
  health.value:ClearAllPoints()
  health.value:Point(db.health.position, ...)
  frame:Tag(health.value, db.health.text_format or '')
  -- Colors
  health.colorSmooth = UF.db.colors.colorhealthbyvalue
  health.colorClass = UF.db.colors.healthclass
  -- Size
  health:ClearAllPoints()
  health:Point("TOPLEFT", frame, ...)
  health:Point("BOTTOMRIGHT", frame, ...)
end
```

**Рекомендация для Roth_UI:** Не обязательно копировать полностью, но разделение "создание один раз" vs "настройка при изменении" упростит settings → apply chain. Сейчас Roth_UI пересоздаёт фреймы при смене настроек — это неэффективно и может ломать secure state.

---

## 8. oUF Element Lifecycle (reference)

```
oUF:RegisterStyle(name, styleFunc)
oUF:SetActiveStyle(name)
oUF:Spawn(unit, frameName) or oUF:SpawnHeader(...)
         │
         ▼
styleFunc(self, unit, isChild)    ← создаёт виджеты, назначает на self
         │
         ▼
initObject(unit, style, ...)      ← oUF internal
         │
         ▼
for each registered element:
  element.Enable(self, unit)      ← регистрирует events, возвращает true
         │
         ▼
on event fire:
  element.Update(self, event, unit) ← основной update handler
         │
         ├── PreUpdate callback (optional)
         ├── Core update logic (StatusBar:SetValue, etc.)
         └── PostUpdate callback (optional) ← ЗДЕСЬ Roth добавляет custom logic

element.Disable(self)             ← cleanup при disable
```

### oUF element fields pattern:
```lua
self.Health            -- StatusBar → oUF Health element
self.Health.colorClass -- boolean → oUF colors by class
self.Health.colorReaction -- boolean → oUF colors by reaction
self.Health.colorHealth -- boolean → fallback green
self.Health.colorSmooth -- boolean → gradient red→yellow→green
self.Health.Smooth     -- boolean → smooth animation (oUF_Smooth, legacy)
self.Health.smoothing  -- StatusBarInterpolation → native smooth (Retail)
self.Health.PostUpdate -- function(element, unit, cur, max) → custom callback
self.Health.Override   -- function → полная замена Update logic

self.Power             -- StatusBar → oUF Power element
self.Power.colorPower  -- boolean → oUF colors by power type
self.Power.frequentUpdates -- boolean → OnUpdate instead of event-only
self.Power.displayAltPower -- boolean → show alternative power bar

self.Castbar           -- StatusBar → oUF Castbar element
self.Castbar.Text      -- FontString → spell name
self.Castbar.Time      -- FontString → cast time
self.Castbar.Icon      -- Texture → spell icon
self.Castbar.Spark     -- Texture → spark indicator
self.Castbar.Shield    -- Texture → non-interruptible indicator
self.Castbar.SafeZone  -- Texture → latency indicator (player only)
self.Castbar.Pips      -- Table → empowered cast stage pips
self.Castbar.timeToHold -- number → seconds to hold after fail (default 0)
self.Castbar.PostCastStart -- function → after cast begins
self.Castbar.PostCastStop -- function → after cast ends
self.Castbar.PostCastFail -- function → after cast fails
self.Castbar.PostCastInterruptible -- function → cast became interruptible
self.Castbar.PostCastNotInterruptible -- function → cast became non-interruptible
self.Castbar.PostChannelStart -- function → after channel begins

self.Range             -- table → oUF Range element
self.Range.insideAlpha  -- number → alpha when in range
self.Range.outsideAlpha -- number → alpha when out of range

self.ThreatIndicator   -- Texture/Frame → oUF ThreatIndicator element
self.ThreatIndicator.feedbackUnit -- string → threat towards whom

self.ClassPower        -- table of StatusBars → oUF ClassPower element
self.ClassPower.PostUpdate -- function(element, cur, max, hasMaxChanged, powerType)

self.Runes             -- table of StatusBars → oUF Runes element (DK only)
self.Runes.sortOrder   -- "asc"/"desc" → sort by cooldown remaining
self.Runes.colorSpec   -- boolean → color by specialization

self.Auras/Buffs/Debuffs -- Frame → oUF Auras element
  .num                 -- max icons
  .size                -- icon size
  .spacing             -- gap
  .initialAnchor       -- "TOPLEFT", "BOTTOMLEFT", etc.
  .growthX             -- "RIGHT"/"LEFT"
  .growthY             -- "UP"/"DOWN"
  .filter              -- "HELPFUL"/"HARMFUL"
  .FilterAura          -- function(self, unit, data) → return bool
  .PostCreateButton    -- function(self, button) → icon styling
  .PostUpdateButton    -- function(self, button, unit, data, position)

self.HealthPrediction  -- table → heal prediction overlays
  .myBar               -- StatusBar → own heals
  .otherBar            -- StatusBar → other heals
  .absorbBar           -- StatusBar → absorb shields
  .healAbsorbBar       -- StatusBar → heal absorbs
  .maxOverflow         -- number → max overflow (default 1.05)
```

---

## 9. Найденные нюансы

### 9a. IsSecretValue определён 4 раза

| Файл | Строка | Определение | Зависимость |
|------|--------|-------------|-------------|
| core/safety.lua | — | `ns.safety.IsSecret` | `_G.issecretvalue` или `_G.IsSecretValue` |
| core/lib.lua | 66-71 | `func.IsSecretValue` | safety.IsSecret или _nativeIsSecret |
| core/target_castbar.lua | 38-47 | local `IsSecretValue` | ns.func или _G.issecretvalue или safety |
| core/tags.lua | 60 | local `IsSecretValue` | func.IsSecretValue или safety.IsSecret |

**Решение:** Удалить все кроме `ns.safety.IsSecret()`.

### 9b. _G.RothUI пустой глобал

`lib.lua:48` создаёт `RothUI = {}` — пустая глобальная таблица. Нигде не используется. `_G.Roth_UI` (init.lua:8) — это настоящий глобальный ns.

### 9c. rActionBarStyler/slashcmd.lua дублирует core/slashcmd.lua

Подтверждено: оба файла регистрируют slash commands. Legacy модуль дублирует функционал.

### 9d. multibar_visibility race condition

`action_bar_multibar_visibility.lua` (TOC строка 105) грузится перед `action_bar_secure_runtime.lua` (TOC строка 106). Оба могут вызывать `RegisterStateDriver()` на одних и тех же frames. Secure runtime перезаписывает, но при Path B (current) multibar_visibility — единственный writer.

### 9e. oUF Factory pattern не используется

Описано в §2 Init / Lifecycle.

### 9f. config.lua schema version

`config.lua` использует schema version 60 (cfg version). Persistence reconcile service проверяет версию и применяет migration patches (v1→v17). При рефакторинге persistence — убедиться что version check сохранён.

### 9g. charspecific.lua disabled

`charspecific.lua` в TOC (строка 40), но содержит early return. Per-char overrides disabled. Либо удалить файл, либо включить функционал.

### 9h. oUF_Smooth module vs native StatusBarInterpolation

Описано в §6b.

### 9i. bar_runtime_registry DEFAULT_DESCRIPTORS

`bar_runtime_registry.lua` содержит DEFAULT_DESCRIPTORS с legacy frame names:
- `rAbs_MainMenuBar` (bar1)
- `rABS_MultiBarBottomLeft` (bar2)
- `rABS_MultiBarBottomRight` (bar3)
- `rABS_MultiBarRight` (bar4)
- `rABS_MultiBarLeft` (bar5)

Эти frames НИКОГДА не создаются при Path B (current). Нужно обновить на реальные frame names после включения Path A.

### 9j. Dual oUF color system

`init.lua:45-66` bootstrap'ит oUF.colors.power с `Roth_MakeColor()` wrapper. Описано в §1 Слой 1 нюанс.

### 9k. ★ Player castbar — третья реализация

Player frame (player.lua строки ~500-600) содержит СВОЙ castbar runtime, отдельный от:
1. `core/target_castbar.lua` (target/focus/boss castbar)
2. `core/lib.lua:createCastbar()` (generic oUF castbar creator)

Все три должны быть заменены на единый oUF Castbar element с PostUpdate callbacks.

### 9l. ★ Experience/Reputation двойная реализация

- `oUF/elements/experience.lua` — oUF element, vehicle-aware
- `oUF/elements/reputation.lua` — oUF element
- `core/bars.lua` строки ~60-350 — ещё одна реализация тех же bars

Нужно выбрать одну. Рекомендация: оставить oUF/elements/ версии.

### 9m. ★ Edit Mode совместимость

Blizzard Edit Mode (12.x) управляет позициями Blizzard frames. Roth_UI перехватывает эти frames. **Потенциальные проблемы:**
- Edit Mode может сбросить позиции Roth-перемещённых frames
- `EditModeManagerFrame:IsEditModeActive()` — проверка активности
- `EventRegistry:RegisterCallback("EditMode.Enter", callback)` / `"EditMode.Exit"` — hooks

Зрелая UI-реализация решает это через:
```lua
-- Addon-owned frames изолируются от Blizzard Edit Mode:
if EditModeManagerFrame then
  hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
    -- Hide Roth movers, show Blizzard
  end)
  hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
    -- Restore Roth movers
  end)
end
```

### 9n. ★ Nameplate support (future)

oUF поддерживает nameplates через `oUF:SpawnNamePlates()`. Зрелые oUF layouts используют этот путь. Roth_UI пока НЕ имеет nameplate модуля, но oUF инфраструктура готова.

### 9o. ★ group_aura_watch performance

`core/group_aura_watch.lua` делает full harmful scan через `AuraUtil.ForEachAura()` на каждом unit в группе. Для 40-man raid это 40 × N debuffs per update.

**Оптимизация:** Использовать oUF Auras.FilterAura (oUF уже итерирует):
```lua
Debuffs.FilterAura = function(self, unit, data)
  return data.isBossAura or ns.auraWhitelist[data.spellId]
end
```

### 9p. ★ GetCVarBool removed in 12.x (НОВОЕ — CRITICAL)

`core/action_bar_secure_runtime.lua:103` использует `GetCVarBool()` — функция УДАЛЕНА в WoW 12.x:
```lua
-- СЕЙЧАС (всегда false):
clickOnDown = type(GetCVarBool) == "function" and GetCVarBool("ActionButtonUseKeyDown") or false,

-- ФИКС:
clickOnDown = C_CVar.GetCVar("ActionButtonUseKeyDown") == "1",
```
**Импакт:** Кнопки не реагируют на click-on-down, keybind feel сломан.

### 9q. ★ target_castbar color resolution не поддерживает ColorMixin (НОВОЕ)

`core/target_castbar.lua:93-95` — color table access не поддерживает oUF 13.x ColorMixin:
```lua
-- СЕЙЧАС:
local r = color and (color.r or color[1]) or 1
-- Если color — ColorMixin, color[1] может не работать (нет __index для числовых ключей)

-- ФИКС:
local function ResolveColor(color)
  if not color then return 1, 1, 1 end
  if type(color.GetRGB) == "function" then return color:GetRGB() end
  return color.r or color[1] or 1, color.g or color[2] or 1, color.b or color[3] or 1
end
```

### 9r. ★ Event leak в party/raid frames (НОВОЕ)

**units/party.lua:267-276** — регистрирует UNIT_AURA в style function, cleanup handles только UNIT_THREAT:
```lua
self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", func.checkThreat)
self:RegisterEvent("UNIT_AURA", func.QueueGroupAuraColorUpdate)
-- HookScript cleanup only handles UNIT_THREAT, NOT UNIT_AURA
```

**units/raid.lua ~150** — threat event не cleanup'ится при header rebuild.

**Фикс:** Добавить OnHide cleanup или explicit UnregisterEvent.

### 9s. ★ Mover restoration не defers InCombatLockdown (НОВОЕ)

`core/mover_runtime.lua` — position restore при party/raid header rebuild может taint в combat.

**Фикс:** Wrap в ns.defer.Schedule().

### 9t. ★ ParkFrame hidden parent not forbidden-checked (НОВОЕ)

`core/frame_policy.lua ~128` — `GetHiddenParent()` result не проверяется через `IsForbidden()`.

### 9u. ★ group_policy CompactRaidFrameManager taint (НОВОЕ)

`core/group_policy.lua:50-55` — прямой вызов `CompactRaidFrameManager_UpdateShown()` может taint.

**Фикс:** Обернуть в `ns.safety.TryCall()`.

### 9v. ★ Party header spawn race condition (НОВОЕ)

`units/party.lua:340-380` — если SpawnPartyHeader() вернёт nil, partyHeader остаётся stale, rebuild loop.

### 9w. ★ settings_main regen frame listener leak (НОВОЕ)

`core/settings_main.lua ~90-110` — PLAYER_REGEN_ENABLED listener на regen frame никогда не unregister'ится.

### 9x. ★ Orb text font resolution not cached (НОВОЕ)

`core/orb_text_controller.lua ~50` — `ResolveFontPath()` вызывается каждый update. Нужен кэш.

---

## 10. Целевая архитектура (куда идём)

```
┌────────────────────────────────────────────────────────┐
│                      Roth_UI                           │
├──────────────┬──────────────┬──────────┬───────────────┤
│  oUF Layout  │  Action Bars │  Orbs    │  Settings     │
│  (thin       │  (secure     │  (custom │  (Blizzard    │
│   style fn)  │   owner)     │   render)│   Settings    │
│              │              │          │   Framework)  │
├──────────────┼──────────────┼──────────┼───────────────┤
│              │              │          │               │
│ oUF:Spawn()  │ LAB:Create() │ Custom   │ Settings.     │
│ oUF:Spawn    │ RegisterState│ StatusBar│ RegisterAddOn │
│  Header()   │  Driver()    │ + 3D     │ Setting()     │
│              │              │          │               │
│ oUF elements:│ Movers:      │ SV:      │ SV:           │
│  Health      │  Roth mover  │  account │  account.     │
│  Power       │  (single     │  .orbs + │   settings    │
│  Castbar     │   system)    │  char.   │               │
│  Auras       │              │  orbs    │               │
│  Portrait    │ Dock:        │          │               │
│  Range       │  единый owner│          │               │
│  Indicators  │              │          │               │
│  ClassPower  │              │          │               │
│  Runes       │              │          │               │
│  HealthPred  │              │          │               │
└──────────────┴──────────────┴──────────┴───────────────┘
```

### Принципы целевой архитектуры:
1. **oUF делает всё что может** — Health, Power, Castbar, Auras, Portrait, Range, Indicators, ClassPower, Runes, HealthPrediction
2. **Action bars через единый LAB/secure-owner паттерн** — LAB buttons, state drivers, единый mover, combat defer
3. **Persistence — максимум 3 файла** — sv_store (API), config_owner (config domain), orb_owner (orb domain)
4. **Один mover** — убрать legacy dragframe, оставить mover_runtime
5. **Settings — Blizzard Settings Framework** — уже частично готово
6. **Никакого dual-ownership** — один owner на каждую surface
7. **Secret value guards — одна точка** — ns.safety.IsSecret(), все остальные через неё
8. **oUF Factory** — все spawn вызовы внутри oUF:Factory()
9. **Native smoothing** — StatusBarInterpolation на Retail, oUF_Smooth только для Classic
10. **ClassPower unified** — oUF ClassPower вместо 6 отдельных per-class реализаций
11. **C_CVar вместо GetCVarBool** — deprecated API удалён в 12.x
12. **ColorMixin safety** — все color resolvers поддерживают `:GetRGB()`
