# Roth_UI — План рефакторинга v5

Обновлено: 2026-03-18

## Стратегия

Аддон сломан из-за **двойного владения** (dual ownership) между legacy stack и новым core stack.
Предыдущие попытки починки чинили симптомы, не убирая корень — два параллельных стека.

**Три принципа:**
1. **oUF делает всё что может** — unit frames, health, power, castbar, auras, indicators, range, ClassPower, Runes
2. **Action bars по паттерну ElvUI** — LAB buttons, state drivers, единый shell owner, combat defer
3. **Persistence максимально просто** — 2-3 файла вместо 8, один read/write path

**Порядок:** Сначала hotfix (P0), потом ownership consolidation (P1-P2), потом cleanup (P3+).

Подробная карта аддона и зависимостей: `addon_map.md`

---

## Фаза 0 — Emergency hotfix (аддон должен загрузиться без ошибок)

### 0.1 `[NOT DONE]` Fix init order crash — settings_general.lua:13

- **Симптом:** `settings_general.lua:13` делает `assert(ns and ns.settingsActions, ...)`, но `settings_actions.lua` грузится позже (TOC строка 75 vs 69). Также: строка 3 требует `ns.SettingsUI`, строка 10 — `ns.BarRuntimeRegistry`.
- **Корень:** TOC порядок: settings_general.lua (строка 69), settings_actions.lua (строка 75). Assert выполняется при файловой загрузке, не при вызове функции.
- **Фикс:** В `Roth_UI.toc` перенести `core/settings_actions.lua` ПЕРЕД `core/settings_general.lua`. Конкретно: строку 75 перенести перед строкой 69.
- **Альтернативный фикс:** Заменить жёсткий assert на lazy resolve:

```lua
-- БЫЛО (settings_general.lua:13):
local settingsActions = assert(ns and ns.settingsActions, "...")

-- СТАЛО:
local function GetSettingsActions()
  return ns and ns.settingsActions
end
-- В местах использования: GetSettingsActions().DoSomething()
```

- **Дополнительно найдено:** `settings_general.lua:3` делает `assert(ns.SettingsUI)`, а `settings_main.lua` (строка 68) грузится перед ней — это ОК, если settings_main.lua создаёт ns.SettingsUI. Проверить что settings_main.lua реально устанавливает ns.SettingsUI.
- **Done when:** `/reload` не падает, Settings UI открывается.

### 0.2 `[NOT DONE]` Унифицировать bar code path'ы

- **Симптом:** Огромные bars, layout развал, рамки вылезают за экран.
- **Корень:** bar2-5 имеют 3 code path'а, но реально работает только один:
  - Path A: `secureActionBarRuntime` (LAB кнопки) — **ВЫКЛЮЧЕН** (secureOwnerBars=false в config.lua:622)
  - Path B: `disableProtectedActionBarOwnership` — **АКТИВЕН** (init.lua:12 ставит true, "emergency combat fallback")
  - Path C: CreateFrame `rABS_*`, reparent Blizzard кнопок — **МЁРТВЫЙ КОД** (Path B перехватывает раньше)
  - bar1 особый: только Path A или прямая регистрация MainActionBar (нет Path B/C)
  - overridebar: только прямая регистрация OverrideActionBar (нет 3 path'ов)
  - Dock members (bags, micromenu, pet, stance): имеют Path B ветку
- **Важно:** ВСЕ action_bar_barN.lua + overridebar гейтятся `cfg.embeds.rActionBarStyler == false → return`.
- **rActionBarStyler/hide_blizzart.lua** — только ПРЯЧЕТ Blizzard фреймы, НЕ пишет geometry.

#### Реализация

**Шаг 1:** Включить Path A — в `config.lua` изменить `secureOwnerBars = true` (строка 622).

**Шаг 2:** Убрать Path B — в `init.lua` удалить строку 12 (`disableProtectedActionBarOwnership = true`).

**Шаг 3:** Удалить мёртвый код Path C из всех action_bar_barN.lua. В каждом файле (bar2-5) удалить блок после `if ns.disableProtectedActionBarOwnership then ... end` — весь код до конца файла (CreateFrame rABS_*, reparent Blizzard buttons).

**Шаг 4:** Упростить action_bar_barN.lua до вызова secure runtime:

```lua
-- БЫЛО (action_bar_bar2.lua, 133 строки с 3 path'ами):
if secureActionBarRuntime and secureActionBarRuntime.IsEnabled() then
  -- Path A: LAB buttons
elseif ns.disableProtectedActionBarOwnership then
  -- Path B: Blizzard as-is
else
  -- Path C: rABS_* reparent (мёртвый код)
end

-- СТАЛО (~20 строк):
local function InitBar2()
  if not secureActionBarRuntime then return end
  secureActionBarRuntime.SpawnAuxBar({
    barName = "bar2",
    blizzardBar = "MultiBarBottomLeft",
    page = 6,
    numButtons = 12,
  })
end

ns.ListenForLoaded(InitBar2)
```

**Паттерн ElvUI (ActionBars.lua):**
```lua
-- ElvUI — ОДИН код для всех bars, отличаются только настройки:
function AB:PositionAndSizeBar(barName)
  local bar = AB.handledBars[barName]
  local db = bar.db
  -- visibility
  RegisterStateDriver(bar, "visibility", db.visibility)
  -- page driver
  RegisterStateDriver(bar, "page", AB:GetPage(barName, ...))
  -- button layout (universal)
  for i, button in ipairs(bar.buttons) do
    AB:HandleButton(bar, button, i, ...)
  end
end
-- Каждый bar — просто вызов общей функции с config table
```

**Шаг 5:** Обновить bar_runtime_registry.DEFAULT_DESCRIPTORS — заменить legacy frame names (`rABS_*`) на реальные имена (`Roth_UISecureBar*`).

- **Риски:**
  - ★ Включение Path A может сломать button bindings. Тестировать: `/click ActionButton1` в макросе.
  - ★ Проверить `InCombatLockdown()` — не вызывается ли при загрузке.
  - ★ Проверить гейт `cfg.embeds.rActionBarStyler` — должен быть true для работы bar файлов.
- **Done when:** Один code path в каждом bar файле. Bars отображаются корректно.

### 0.3 `[NOT DONE]` ★ Fix GetCVarBool deprecated API (НОВОЕ — CRITICAL)

- **Симптом:** Action bar buttons НЕ реагируют на нажатие (click-on-down сломан).
- **Корень:** `core/action_bar_secure_runtime.lua:103` использует `GetCVarBool()`, которая удалена в WoW 12.x:
```lua
-- СЕЙЧАС (строка 103):
clickOnDown = type(GetCVarBool) == "function" and GetCVarBool("ActionButtonUseKeyDown") or false,
-- type(GetCVarBool) == "nil" в 12.x → ВСЕГДА false
```
- **Фикс:**
```lua
-- СТАЛО:
local function GetCVarBoolSafe(name)
  local val = C_CVar.GetCVar(name)
  return val == "1" or val == "true"
end

clickOnDown = GetCVarBoolSafe("ActionButtonUseKeyDown"),
```
- **Blizzard API (12.x):**
  - `C_CVar.GetCVar(name)` → returns string ("0"/"1") — корректный API
  - `GetCVarBool(name)` → **УДАЛЁН** в 12.x
  - `C_CVar.SetCVar(name, value)` → set CVar
- **Done when:** Кнопки реагируют на click-on-down когда CVar включён.

### 0.4 `[NOT DONE]` Fix dock member references

- **Симптом:** Bottom cluster (bags, micromenu, pet, stance) может не собираться.
- **Корень:** `action_bar_dock.lua` использует `barRuntimeRegistry.ResolveDockMember()` — если registry пуст (Path B не регистрирует dock members), dock ничего не находит.

#### Нюанс: dock members при Path A

При включении Path A (шаг 0.2), secure_runtime создаёт bar фреймы. Но dock members (bags, micromenu, etc.) не создаются через secure_runtime — они имеют свои файлы (bags_bar.lua, micromenu_bar.lua, etc.). Эти файлы:
1. Гейтятся `cfg.embeds.rActionBarStyler`
2. Создают свои контейнеры
3. Регистрируются в barRuntimeRegistry

**Фикс:** Убедиться что dock members регистрируются в barRuntimeRegistry с корректными именами. Проверить `action_bar_dock.lua` — какие frame names он ожидает.

- **Done when:** Bottom dock собирается: bars + bags + micromenu + pet + stance в ряд.

### 0.5 `[NOT DONE]` Single mover system

- **Симптом:** Позиции сохраняются в двух местах, при reset одна система может не сброситься.
- **Корень:** `mover_runtime.lua` (новый) + `rLib/dragframe.lua` (legacy) работают параллельно. mover_runtime вызывает `AttachLegacyDragFrame()` для визуала, но dragframe имеет свой position persistence.
- **Фикс:** В `mover_runtime.lua` убрать мост к dragframe. Mover_runtime сам управляет:
  1. Drag overlay (визуал)
  2. OnDragStart / OnDragStop
  3. SavePosition / RestorePosition (SV)
  4. Category system (art, bars, units, orbs)

**Паттерн ElvUI (Movers.lua):**
```lua
-- ElvUI: E:CreateMover(parent, name, text, snapOffset, postdrag, moverTypes, holdConfig)
function E:CreateMover(parent, name, text, snapOffset, postdrag, moverTypes, ...)
  local mover = CreateFrame('Button', name, E.UIParent)
  mover:SetFrameLevel(parent:GetFrameLevel() + 1)
  mover:SetClampedToScreen(true)
  mover:SetMovable(true)
  mover:EnableMouse(true)
  mover:RegisterForDrag('LeftButton')
  mover.parent = parent

  mover:SetScript('OnDragStart', function(self)
    if InCombatLockdown() then return end  -- ★ combat safe
    self:StartMoving()
  end)

  mover:SetScript('OnDragStop', function(self)
    self:StopMovingOrSizing()
    E:SaveMoverPosition(name)  -- единственная точка сохранения
  end)

  -- Position restore
  local x, y, anchor = E:GetMoverPosition(name)
  if x then
    mover:ClearAllPoints()
    mover:SetPoint(anchor, E.UIParent, anchor, x, y)
  end

  parent:ClearAllPoints()
  parent:SetPoint(E.InversePoints[anchor], mover, E.InversePoints[anchor])

  E.CreatedMovers[name] = mover
end
```

**★ Нюанс (НОВОЕ):** Mover restoration не проверяет `InCombatLockdown()`. При rebuild party/raid headers (которые вызывают mover restoration) в бою → taint. Все mover frame SetPoint/SetParent вызовы должны использовать `ns.defer.Schedule()`.

- **Done when:** Одна система сохранения позиций. `/rothui reset` сбрасывает всё.

### 0.6 `[NOT DONE]` Simplify persistence (этап 1)

- **Симптом:** 8 файлов persistence, однонаправленная цепочка зависимостей (root_store → config_owner), неочевидный init flow.
- **Фикс (этап 1 — минимальный):** Не рефакторить всё сразу. Убрать только явные дубли:
  - `persistence_drift_service.lua` → merge в `persistence_reconcile_service.lua`
  - `persistence_report_service.lua` → merge в `sv_doctor.lua`
  - `persistence_domain_registry.lua` → inline в `persistence_control_plane.lua`
  - `persistence_schema_registry.lua` → inline в `persistence_control_plane.lua`
- **Результат:** 8 файлов → 4 файла (config_persistence_owner, persistence_root_store, sv_store, persistence_control_plane).

#### Порядок merge

1. Прочитать persistence_drift_service.lua — скопировать функции в persistence_reconcile_service.lua
2. Прочитать persistence_report_service.lua — скопировать в sv_doctor.lua
3. Прочитать persistence_domain_registry.lua и persistence_schema_registry.lua — inline в persistence_control_plane.lua
4. Удалить файлы, обновить TOC
5. Проверить ns.persistence facade — должен работать без удалённых файлов

**Нюанс:** Не менять API facade (ns.persistence.*). Внутренняя реструктуризация, внешний API стабилен.

- **Done when:** Init flow работает с меньшим количеством файлов.

### 0.7 `[NOT DONE]` ★ Fix event cleanup in party/raid frames (НОВОЕ)

- **Симптом:** Memory leak и потенциальные callback errors на stale frames при rebuild header'ов.
- **Корень:** Party/Raid unit frames регистрируют events (UNIT_THREAT_SITUATION_UPDATE, UNIT_AURA) в style function, но НЕ unregisterят при header park/destroy.

#### Детали

**units/party.lua строки 267-276:**
```lua
self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", func.checkThreat)
self:RegisterEvent("UNIT_AURA", func.QueueGroupAuraColorUpdate)
-- HookScript cleanup handles UNIT_THREAT но НЕ UNIT_AURA
```

**units/raid.lua ~строка 150:**
```lua
-- Threat event регистрируется в style function
-- Нет unregister при header rebuild (RebuildPartyStructureRuntime)
```

**Фикс:** Добавить полный event cleanup при park/destroy:
```lua
-- В style function добавить OnHide cleanup:
self:HookScript("OnHide", function(frame)
  frame:UnregisterEvent("UNIT_THREAT_SITUATION_UPDATE")
  frame:UnregisterEvent("UNIT_AURA")
end)

-- Или: в group_header_visibility.Park() добавить frame:UnregisterAllEvents()
```

**Нюанс:** oUF сам управляет событиями через element Enable/Disable. Проблема в ДОПОЛНИТЕЛЬНЫХ event регистрациях вне oUF element pattern (threat, aura watch).

- **Done when:** Rebuild party/raid headers не оставляет stale event listeners.

---

## Фаза 1 — Action Bar Ownership (паттерн ElvUI)

### 1.1 `[NOT DONE]` Единый shell owner для bar1-5

- **Цель:** Каждый bar (1-5) имеет ОДНОГО владельца (core/action_bar_barN.lua).
- **Текущее состояние:**
  - bar1: НЕ создаёт frame, регистрирует Blizzard MainActionBar в registry (только Path A или прямая рег.)
  - bar2-5: 3 code path'а, но реально работает Path B (Blizzard as-is). Path A выключен (secureOwnerBars=false). Path C мёртвый код (init.lua:12 disableProtectedActionBarOwnership=true)
- **Целевое:** Каждый barN файл — thin wrapper вызывающий `secureActionBarRuntime.SpawnAuxBar(config)`.

#### secure_runtime.lua API (уже реализован)

```lua
-- Создание bar frame:
local bar = secureActionBarRuntime.CreateBarFrame(barName, numButtons, template)

-- Spawn main bar (bar1):
secureActionBarRuntime.SpawnMainBar({
  barName = "bar1",
  numButtons = 12,
  pageDriver = MAIN_BAR_PAGE_DRIVER,
})

-- Spawn aux bar (bar2-5):
secureActionBarRuntime.SpawnAuxBar({
  barName = "bar2",
  blizzardBar = "MultiBarBottomLeft",
  page = 6,
  numButtons = 12,
})

-- Button config:
local buttonConfig = secureActionBarRuntime.BuildButtonConfig(barName)
-- buttonConfig содержит: showGrid, clickOnDown, flyoutDirection, etc.

-- Apply to all buttons:
for i, button in ipairs(bar.buttons) do
  button:UpdateConfig(buttonConfig)
end
```

#### Реализация по шагам

**bar1:**
```lua
-- core/action_bar_bar1.lua целевой:
local function InitBar1()
  secureActionBarRuntime.SpawnMainBar({
    barName = "bar1",
    numButtons = 12,
    pageDriver = "[overridebar][vehicleui][possessbar] possess; [shapeshift] 13; [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; [bonusbar:5] 11; 1",
  })
  barRuntimeRegistry.RegisterFrame("bar1", Roth_UISecureBar1)
end
ns.ListenForLoaded(InitBar1)
```

**bar2-5 (общий паттерн):**
```lua
-- core/action_bar_bar2.lua целевой:
local function InitBar2()
  secureActionBarRuntime.SpawnAuxBar({
    barName = "bar2",
    blizzardBar = "MultiBarBottomLeft",
    page = BOTTOMLEFT_ACTIONBAR_PAGE,  -- Blizzard constant = 6
    numButtons = 12,
  })
  barRuntimeRegistry.RegisterFrame("bar2", Roth_UISecureBar2)
end
ns.ListenForLoaded(InitBar2)
```

**API Blizzard (bar pages):**
```lua
-- Константы страниц:
BOTTOMLEFT_ACTIONBAR_PAGE = 6   -- MultiBarBottomLeft
BOTTOMRIGHT_ACTIONBAR_PAGE = 5  -- MultiBarBottomRight
RIGHT_ACTIONBAR_PAGE = 3        -- MultiBarRight
LEFT_ACTIONBAR_PAGE = 4         -- MultiBarLeft

-- Vehicle/Override:
GetVehicleBarIndex()             -- returns bar index when in vehicle
GetOverrideBarIndex()            -- returns bar index when override active
GetTempShapeshiftBarIndex()      -- returns bar index for temp shapeshift
GetBonusBarIndex()               -- returns bonus bar index
GetActionBarPage()               -- returns number (current page)
```

- **Done when:** Каждый bar file < 30 строк. Один code path.

### 1.2 `[NOT DONE]` Единый visibility owner

- **Сейчас:** `multibar_visibility.lua` (TOC 105) и `secure_runtime.lua` (TOC 106) оба могут вызывать `RegisterStateDriver()` на одних фреймах.
- **Целевое:** Visibility driver только в `secure_runtime.lua`.

#### Паттерн: secure state driver

```lua
-- oUF/ElvUI используют один RegisterStateDriver per frame:
RegisterStateDriver(bar, "visibility", visibilityCondition)
-- visibilityCondition — secure condition string:
-- "[petbattle][vehicleui] hide; [combat] show; show"
-- "[overridebar] hide; [vehicleui] hide; show"

-- Page driver:
RegisterStateDriver(bar, "page", pageCondition)
-- pageCondition:
-- "[overridebar] " .. GetOverrideBarIndex() .. "; [vehicleui] " .. GetVehicleBarIndex() .. "; 1"
```

**Нюанс:** `RegisterStateDriver()` можно вызвать только вне combat. Если аддон загружается в бою (reload), нужен defer:
```lua
local function ApplyDrivers(bar)
  if InCombatLockdown() then
    ns.defer.Schedule(function() ApplyDrivers(bar) end)
    return
  end
  RegisterStateDriver(bar, "visibility", bar.visibilityCondition)
  RegisterStateDriver(bar, "page", bar.pageCondition)
end
```

- **Done when:** Один file задаёт visibility для каждого bar. Нет race condition.

### 1.3 `[NOT DONE]` Единый dock owner

- action_bar_dock.lua — единственный owner нижнего кластера (main bar + aux bars + dock members).
- dock.lua читает из barRuntimeRegistry.
- **Фикс:** Dock должен явно получать frame references, не гадать через registry lookup.

#### Паттерн: dock layout

```lua
-- Целевой dock layout:
local function LayoutDock()
  local members = {
    barRuntimeRegistry.ResolveFrame("bar1"),
    barRuntimeRegistry.ResolveFrame("bar2"),
    barRuntimeRegistry.ResolveFrame("bar3"),
    -- dock members:
    barRuntimeRegistry.ResolveFrame("micromenu"),
    barRuntimeRegistry.ResolveFrame("bags"),
    barRuntimeRegistry.ResolveFrame("pet"),
    barRuntimeRegistry.ResolveFrame("stance"),
  }

  -- Position: anchor to UIParent bottom center
  local anchor = members[1]
  if anchor then
    anchor:ClearAllPoints()
    anchor:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, cfg.bars.bottomOffset or 4)
  end

  -- Stack horizontally:
  for i = 2, #members do
    local prev = members[i-1]
    local frame = members[i]
    if frame and prev then
      frame:ClearAllPoints()
      frame:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", cfg.bars.spacing or 2, 0)
    end
  end
end
```

- **Done when:** Dock assembles correctly с корректным spacing.

### 1.4 `[NOT DONE]` Единый art owner

- `action_bar_background.lua` — владеет art overlay (exp/rep bar background, bar border art).
- `bars.lua` содержит exp/rep bar код — но exp/rep bars уже есть в `oUF/elements/`.
- **Фикс:** Art overlay — в `action_bar_background.lua`. Exp/Rep bars — в `oUF/elements/`.

#### Нюанс: Experience/Reputation bar двойная реализация

```
oUF/elements/experience.lua  → oUF element (vehicle-aware, correct pattern)
oUF/elements/reputation.lua  → oUF element
core/bars.lua:60-350          → ещё одна реализация (Enable/Disable/Update)
```

**Фикс:** Удалить Exp/Rep из bars.lua. Оставить `oUF/elements/` версии. Они vehicle-aware и следуют стандартному oUF element lifecycle.

**Проверить:** что `oUF/elements/experience.lua` корректно интегрируется с action_bar_background.lua art overlay (positioning).

- **Done when:** Art overlay не конфликтует с Exp/Rep bars.

### 1.5 `[NOT DONE]` Combat defer — единый паттерн

- **Сейчас:** Разные файлы делают combat check по-разному:
  - `action_bar_bar2.lua:95-98` — свой helper + pending flag
  - `secure_runtime.lua:167-172` — свой pendingBindingRefresh + bindingHelper frame
  - `settings_general.lua` — проверяет InCombatLockdown() но не откладывает
  - `deferred_scheduler.lua` — универсальный ns.defer.Schedule() (уже есть!)

**Паттерн ElvUI:**
```lua
-- ElvUI: всё через один defer:
function AB:PositionAndSizeBar(barName)
  if InCombatLockdown() then
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
      self:UnregisterEvent("PLAYER_REGEN_ENABLED")
      self:PositionAndSizeBar(barName)
    end)
    return
  end
  -- ... do the actual work
end
```

#### Roth_UI уже имеет deferred_scheduler

```lua
-- core/deferred_scheduler.lua предоставляет:
ns.defer.Schedule(function() ... end)  -- выполнит после выхода из combat

-- Но НЕ все файлы его используют. Найдены прямые InCombatLockdown() проверки без defer:
-- action_bar_bar2.lua:95-98 — свой helper + pending
-- secure_runtime.lua:167-172 — свой pendingBindingRefresh + bindingHelper
-- settings_general.lua — проверяет InCombatLockdown но не откладывает
```

**Фикс:** Централизовать defer через deferred_scheduler:
```lua
-- Единый паттерн для всех bar/frame операций:
local function SafeBarOperation(key, operation)
  if InCombatLockdown() then
    ns.defer.Schedule(function() SafeBarOperation(key, operation) end)
    return
  end
  operation()
end
```

**API Blizzard:**
- `InCombatLockdown()` — returns true if in combat (protected frames locked)
- Event `PLAYER_REGEN_ENABLED` — fires when combat ends (frames unlocked)
- Event `PLAYER_REGEN_DISABLED` — fires when combat starts (frames locked)
- `ADDON_ACTION_BLOCKED` — fires when addon tries protected operation in combat

- **Применить:** ко всем bar layout/position/visibility операциям.
- **Done when:** Нет ADDON_ACTION_BLOCKED при смене layout в бою.

### 1.6 `[NOT DONE]` ExtraAction/ZoneAbility — thin wrapper

- Roth владеет только: holder, art overlay, optional mouseover.
- Roth НЕ владеет: runtime parent, secure lifecycle, core visibility.
- Убрать `SetScale/ClearAllPoints/SetPoint` на Blizzard frame из normal path.

#### Нюанс: extrabar_holder.lua

`core/extrabar_holder.lua` создаёт holder frame и follower pattern. Проверить:
1. Не ломает ли reparent `ExtraAbilityContainer` в combat?
2. `ZoneAbilityFrame` — тоже protected, нужен ли отдельный holder?

**Паттерн ElvUI (ExtraAction):**
```lua
-- ElvUI НЕ создаёт holder. Только:
-- 1. Mover для позиционирования
-- 2. Skin (backdrop, border)
-- 3. Visibility — оставляет Blizzard
AB:CreateMover(ExtraAbilityContainer, "BossButton", L["Boss Button"])
```

**Рекомендация:** Упростить extrabar_holder до mover + skin, без reparent.

### 1.7 `[NOT DONE]` Vehicle/Override/Possess matrix

- Прогнать: vehicle enter/exit, possess, override bar, extra action, zone ability, quick keybind.

#### Полная матрица событий

| Событие | bar1 | bar2-5 | override | extra | dock |
|---------|------|--------|----------|-------|------|
| UNIT_ENTERED_VEHICLE | page→vehicle | hide | — | — | hide pet/stance |
| UNIT_EXITED_VEHICLE | page→1 | show | — | — | show pet/stance |
| Override bar active | page→override | hide | show | — | — |
| Possess active | page→possess | hide | — | — | — |
| Pet battle | hide | hide | hide | hide | hide |
| Bonus bar (druid) | page→bonus | show | — | — | — |

**API:**
- `HasVehicleActionBar()` → boolean
- `HasOverrideActionBar()` → boolean
- `HasTempShapeshiftActionBar()` → boolean
- `HasBonusActionBar()` → boolean
- `GetVehicleBarIndex()` → number
- `GetOverrideBarIndex()` → number
- `GetTempShapeshiftBarIndex()` → number
- `GetBonusBarIndex()` → number
- `GetActionBarPage()` → number (current page)

**Secure runtime page driver уже обрабатывает это:**
```lua
MAIN_BAR_PAGE_DRIVER = "[overridebar][vehicleui][possessbar] possess; [shapeshift] 11; [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; [bonusbar:5] 11; 1"
```

**Нюанс:** `[possessbar]` и `[vehicleui]` — разные состояния. ElvUI обрабатывает их отдельно:
```lua
-- ElvUI fullConditions:
format('[overridebar] %d; [vehicleui][possessbar] %d;', GetOverrideBarIndex(), GetVehicleBarIndex())
```

Roth_UI secure_runtime использует `possess` как общий state и потом в `_onstate-page` resolvit через `HasVehicleActionBar()` и т.д. — это корректно, но сложнее для отладки.

- Done when: Ни один transition не ломает button stability.

### 1.8 `[NOT DONE]` Удалить legacy rActionBarStyler module полностью

- **Условие:** ТОЛЬКО после того как 1.1-1.7 стабильны.
- **Фикс:** Удалить `modules/Roth_UI_rActionBarStyler/` целиком.
- **Перенести предварительно** (в фазе 0.2):
  - `hide_blizzart.lua` → `core/hide_blizzard_bars.lua`
  - `cooldown.lua` → `core/cooldown_style.lua`
  - `spellflyout.lua` → `core/spellflyout_style.lua`

**Нюанс:** rActionBarStyler/slashcmd.lua дублирует core/slashcmd.lua (подтверждено). Удалить без переноса.

- Done when: Модуль удалён, аддон работает без него.

---

## Фаза 2 — Unit Frames: делегировать oUF

### 2.1 `[ЧАСТИЧНО СДЕЛАНО]` Аудит: что lib.lua делает вместо oUF

Предварительный аудит выполнен (см. addon_map.md §6). Основные выводы:
- **Уже oUF:** Indicators (Combat, Leader, RaidTarget, ReadyCheck) в units/*.lua — ОК
- **Создаёт oUF elements:** lib.createCastbar, createBuffs, createDebuffs, createPortrait, createAlternativePowerBar — упростить до PostCreate/PostUpdate
- **Дублирует oUF:** RefreshUnitHealthBar, range driver, checkThreat — заменить на oUF elements
- **Не дублирует (утилиты):** secret guards, font helpers, icon helpers, formatting — оставить
- **Aura duration:** ~10 KB custom tracking поверх oUF Auras — перенести в PostUpdate
- **Проверено:** HealthPrediction — не используется в Roth_UI; RestingIndicator — уже oUF elem (player.lua:975); PvPIndicator — уже oUF elem (player.lua:979); Vehicle swap — обработан в oUF elements (exp/rep/runes) и action_bar_bg/bar2, НЕ в lib.lua

#### Финальный список замен

| lib.lua функция | Размер | Замена | oUF element |
|-----------------|--------|--------|-------------|
| `createCastbar()` | ~100 строк | PostCreate castbar layout | `self.Castbar` |
| `createBuffs()` | ~80 строк | PostCreateButton для icon styling | `self.Buffs` |
| `createDebuffs()` | ~80 строк | PostCreateButton для icon styling | `self.Debuffs` |
| `createPortrait()` | ~40 строк | Inline в style function | `self.Portrait` |
| `createAlternativePowerBar()` | ~60 строк | Inline в style function | `self.AlternativePower` |
| `RefreshUnitHealthBar()` | ~80 строк | Удалить (oUF Health обновляет) | `self.Health` |
| range driver | ~50 строк | Удалить (oUF Range) | `self.Range` |
| `checkThreat()` | ~40 строк | Удалить (oUF ThreatIndicator) | `self.ThreatIndicator` |
| aura duration tracking | ~300 строк | PostUpdate в oUF Auras | `self.Buffs.PostUpdate` |
| health/power formatters | ~100 строк | Оставить (утилиты для tags) | — |
| secret value guards | ~80 строк | Оставить (12.x необходимость) | — |
| font/icon helpers | ~60 строк | Оставить | — |

**Итого:** ~900 строк удалить/заменить, ~240 строк оставить. lib.lua: 2351 → ~1400 → после 2.8 split ~600 строк.

- **Done when:** Есть финальный чёткий список "функция X → заменить на oUF element Y".

### 2.2 `[NOT DONE]` Переписать style function в units.lua

- **Сейчас:** units.lua — пустой контейнер (только `ns.unit = CreateFrame("Frame")`). Каждый unit файл сам делает `oUF:RegisterStyle()` + `oUF:Spawn()` и создаёт всё (health bars, power bars, indicators).
- **Цель:** Shared style function в units.lua задаёт oUF elements.

#### Паттерн oUF: Style Function

```lua
-- oUF вызывает style function для каждого фрейма:
oUF:RegisterStyle("Roth", function(self, unit, isChild)
  -- self = Frame, unit = "player"/"target"/etc., isChild = for headers

  -- Обязательно: размер фрейма
  self:SetSize(cfg.units[unit].width, cfg.units[unit].height)

  -- Health — oUF автоматически регистрирует UNIT_HEALTH, обновляет bar
  local Health = CreateFrame("StatusBar", nil, self)
  Health:SetAllPoints()
  Health:SetStatusBarTexture(cfg.healthTexture)
  Health.colorClass = true      -- oUF окрасит по классу
  Health.colorReaction = true   -- oUF окрасит по реакции (враг/нейтрал)
  Health.colorHealth = true     -- fallback зелёный
  -- Smoothing (Retail native):
  if StatusBarInterpolation then
    Health.smoothing = StatusBarInterpolation.ExponentialEaseOut
  else
    Health.Smooth = true  -- oUF_Smooth fallback
  end
  self.Health = Health           -- ★ имя поля = имя oUF element

  -- Power — oUF автоматически регистрирует UNIT_POWER_UPDATE
  local Power = CreateFrame("StatusBar", nil, self)
  Power:SetHeight(cfg.units[unit].powerHeight)
  Power:SetPoint("BOTTOMLEFT")
  Power:SetPoint("BOTTOMRIGHT")
  Power:SetStatusBarTexture(cfg.powerTexture)
  Power.colorPower = true       -- oUF окрасит по типу ресурса
  Power.frequentUpdates = true  -- OnUpdate для smooth
  self.Power = Power

  -- Castbar — oUF автоматически обрабатывает UNIT_SPELLCAST_*
  if unit == "target" or unit == "focus" or unit == "boss" then
    local Castbar = CreateFrame("StatusBar", nil, self)
    Castbar:SetSize(200, 20)
    Castbar.Text = Castbar:CreateFontString(nil, "OVERLAY")
    Castbar.Time = Castbar:CreateFontString(nil, "OVERLAY")
    Castbar.Icon = Castbar:CreateTexture(nil, "OVERLAY")
    Castbar.Spark = Castbar:CreateTexture(nil, "OVERLAY")
    Castbar.Shield = Castbar:CreateTexture(nil, "OVERLAY")
    Castbar.timeToHold = 0.8
    -- PostCastStart/PostCastStop — custom coloring
    Castbar.PostCastStart = ns.CastbarPostStart
    Castbar.PostChannelStart = ns.CastbarPostStart
    Castbar.PostCastFail = ns.CastbarPostFail
    Castbar.PostCastInterruptible = ns.CastbarPostStart
    self.Castbar = Castbar
  end

  -- Range — oUF автоматически проверяет UnitInRange
  self.Range = {
    insideAlpha = 1,
    outsideAlpha = 0.4,
  }

  -- ThreatIndicator
  local Threat = self:CreateTexture(nil, "OVERLAY")
  Threat:SetAllPoints()
  self.ThreatIndicator = Threat

  -- oUF auto-enables all elements found on self
end)

oUF:SetActiveStyle("Roth")
```

#### Нюанс: разные стили для разных unit'ов

oUF `RegisterStyle` может быть вызван несколько раз:
```lua
oUF:RegisterStyle("Roth_Player", playerStyleFunc)
oUF:RegisterStyle("Roth_Target", targetStyleFunc)
oUF:RegisterStyle("Roth_Mini", miniStyleFunc)

oUF:SetActiveStyle("Roth_Player")
oUF:Spawn("player", "Roth_UIPlayerFrame")

oUF:SetActiveStyle("Roth_Target")
oUF:Spawn("target", "Roth_UITargetFrame")

oUF:SetActiveStyle("Roth_Mini")
oUF:Spawn("targettarget", "Roth_UITargetTargetFrame")
oUF:Spawn("focus", "Roth_UIFocusFrame")
```

#### ★ oUF:Factory wrapper

Все spawn вызовы должны быть внутри `oUF:Factory()`:
```lua
oUF:Factory(function(self)
  self:RegisterStyle("Roth_Player", playerStyleFunc)
  self:SetActiveStyle("Roth_Player")
  self:Spawn("player", "Roth_UIPlayerFrame")

  self:RegisterStyle("Roth_Target", targetStyleFunc)
  self:SetActiveStyle("Roth_Target")
  self:Spawn("target", "Roth_UITargetFrame")

  -- ... etc
end)
```

oUF:Factory гарантирует выполнение после PLAYER_LOGIN и после инициализации всех oUF internals.

#### Что уже хорошо в Roth_UI

`units/mini_target_scaffold.lua` — создаёт `self.Health`, `self.Power`, tags через `self:Tag()`. Это **правильный oUF паттерн**. Используется для: targettarget, pettarget, focustarget, pet, focus. Нужно только вынести в shared style function и убрать lib.lua зависимости.

- Unit files (target.lua, focus.lua, etc.) содержат только unique layout/art.
- **Done when:** mini units (tt, ft, pt, pet) используют oUF elements вместо lib.lua helpers.

### 2.3 `[NOT DONE]` Castbar — через oUF Castbar element (ВСЕ unit frames)

- **Сейчас:** ТРИ отдельных castbar реализации:
  1. `target_castbar.lua` (703 строки) — target/focus/boss
  2. `player.lua` строки ~500-600 — player castbar (свой runtime)
  3. `lib.lua:createCastbar()` — generic oUF castbar creator
- **Цель:** oUF Castbar element для ВСЕХ unit frames с PostUpdate hooks для Roth art.

#### oUF Castbar element API

```lua
-- oUF Castbar автоматически обрабатывает:
-- UNIT_SPELLCAST_START, _STOP, _FAILED, _INTERRUPTED
-- UNIT_SPELLCAST_CHANNEL_START, _STOP, _UPDATE
-- UNIT_SPELLCAST_EMPOWER_START, _STOP, _UPDATE
-- UNIT_SPELLCAST_INTERRUPTIBLE, _NOT_INTERRUPTIBLE
-- UNIT_SPELLCAST_DELAYED

-- Castbar element fields (set by oUF):
element.casting         -- true if casting
element.channeling      -- true if channeling
element.empowering      -- true if empowering
element.notInterruptible -- true if can't be interrupted
element.spellID         -- current spell ID
element.castID          -- unique cast ID
element.delay           -- cast delay (pushback)
element.holdTime        -- time to hold after fail

-- Sub-widgets:
element.Text            -- FontString: spell name
element.Time            -- FontString: cast time
element.Icon            -- Texture: spell icon
element.Spark           -- Texture: spark indicator
element.Shield          -- Texture: non-interruptible indicator
element.SafeZone        -- Texture: latency indicator
element.Pips            -- Table: empowered cast stage pips

-- Callbacks:
element.PostCastStart = function(self, unit, name, castID, spellID) end
element.PostCastStop = function(self, unit, name, castID, spellID) end
element.PostCastFail = function(self, unit, name, castID, spellID) end
element.PostChannelStart = function(self, unit, name) end
element.PostChannelStop = function(self, unit, name) end
element.PostCastInterruptible = function(self, unit) end
element.PostCastNotInterruptible = function(self, unit) end
```

#### Что переносить из target_castbar.lua

```lua
-- Roth добавляет semantic coloring — это PostUpdate:
local colors = {
  interruptibleCast = { r = 0.3, g = 0.6, b = 1.0 },
  interruptibleChannel = { r = 0.3, g = 0.8, b = 0.3 },
  nonInterruptible = { r = 0.7, g = 0.7, b = 0.7 },
  failedOrInterrupted = { r = 1.0, g = 0.3, b = 0.3 },
}

-- ★ НЮАНС (НОВОЕ): color resolution ДОЛЖНА поддерживать oUF ColorMixin:
local function ResolveColor(color)
  if not color then return 1, 1, 1 end
  if type(color.GetRGB) == "function" then
    return color:GetRGB()  -- oUF 13.x ColorMixin
  end
  return color.r or color[1] or 1, color.g or color[2] or 1, color.b or color[3] or 1
end

local function CastbarPostStart(castbar, unit, name, castID, spellID)
  local notInterruptible = castbar.notInterruptible
  local color
  if castbar.channeling then
    color = notInterruptible and colors.nonInterruptible or colors.interruptibleChannel
  else
    color = notInterruptible and colors.nonInterruptible or colors.interruptibleCast
  end
  castbar:SetStatusBarColor(ResolveColor(color))

  -- Roth art: backdrop glow
  if castbar.RothGlow then
    local r, g, b = ResolveColor(color)
    castbar.RothGlow:SetVertexColor(r, g, b, 0.3)
    castbar.RothGlow:Show()
  end
end

local function CastbarPostFail(castbar, unit, name, castID, spellID)
  castbar:SetStatusBarColor(ResolveColor(colors.failedOrInterrupted))
end

-- В style function:
self.Castbar.PostCastStart = CastbarPostStart
self.Castbar.PostChannelStart = CastbarPostStart
self.Castbar.PostCastFail = CastbarPostFail
self.Castbar.PostCastInterruptible = CastbarPostStart  -- recolor
self.Castbar.PostCastNotInterruptible = CastbarPostStart  -- recolor
```

**Нюанс:** target_castbar.lua содержит custom Roth art (backdrop, glow, overlay). Этот visual code нужно сохранить в style function, но убрать ручной event tracking.

**Из 703 строк target_castbar.lua:**
- ~200 строк — event tracking (заменяет oUF) → УДАЛИТЬ
- ~150 строк — color/tinting logic → ПЕРЕНЕСТИ в PostUpdate callbacks (~40 строк)
- ~200 строк — visual setup (textures, positioning) → ПЕРЕНЕСТИ в style function
- ~150 строк — settings integration → УПРОСТИТЬ

**Player castbar (player.lua ~500-600):**
- ~100 строк — СВОЙ castbar runtime → ЗАМЕНИТЬ на self.Castbar oUF element
- player.lua castbar может использовать ТЕ ЖЕ PostUpdate callbacks что и target

- **Убрать:** Весь ручной UNIT_SPELLCAST_* tracking из target_castbar.lua И player.lua.
- **Done when:** ВСЕ castbars (target, focus, boss, player, targettarget) через oUF element.

### 2.4 `[NOT DONE]` Auras — через oUF Auras element

- **Сейчас:** `group_aura_watch.lua` + ручной iteration в lib.lua.
- **Цель:** oUF Auras element для всех unit frames.

#### oUF Auras element API

```lua
-- Setup в style function:
local Buffs = CreateFrame("Frame", nil, self)
Buffs:SetPoint("TOPLEFT", self, "TOPRIGHT", 2, 0)
Buffs:SetSize(16 * num_per_row, 16 * max_rows)

Buffs.num = 32            -- max buffs shown
Buffs.size = 16           -- icon size
Buffs.spacing = 2         -- gap between icons
Buffs.initialAnchor = "TOPLEFT"
Buffs.growthX = "RIGHT"
Buffs.growthY = "DOWN"
Buffs.filter = "HELPFUL"  -- only show helpful auras
Buffs.showStealableBuffs = true
Buffs.minCount = 2        -- min stacks to show count text

-- Icon styling:
Buffs.PostCreateButton = function(self, button)
  button.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  button.Overlay:SetTexture(mediapath .. "aura_border")
  button.Cooldown:SetReverse(true)
end

-- Per-aura update:
Buffs.PostUpdateButton = function(self, button, unit, data, position)
  -- Custom duration overlay, dispel glow, etc.
  if data.dispelName then
    local color = oUF.colors.dispel[data.dispelName]
    if color then
      button.Overlay:SetVertexColor(color:GetRGB())
    end
  end
end

-- Custom filter (replaces group_aura_watch):
Debuffs.FilterAura = function(self, unit, data)
  -- data.name, data.spellId, data.isHarmful, data.dispelName, etc.
  -- ★ НЮАНС (НОВОЕ): проверка secret value для spellId
  if issecretvalue and issecretvalue(data.spellId) then return false end
  if ns.auraWhitelist[data.spellId] then return true end
  if data.isBossAura then return true end
  if data.isHarmful and data.dispelName then return true end
  return false
end

self.Buffs = Buffs
self.Debuffs = Debuffs
```

#### group_aura_watch.lua — что с ним делать

`group_aura_watch.lua` делает custom aura tracking для party/raid:
- Whitelist/blacklist фильтрация
- Debuff type coloring (magic/poison/disease/curse)
- Boss debuff highlighting
- Full harmful scan (performance issue)

**Рекомендация:** Перенести фильтрацию в `Auras.FilterAura` callback. Это устраняет full scan — oUF уже итерирует.

**★ Performance:** oUF Auras element использует инкрементальные обновления через `UNIT_AURA` payload (12.x). `group_aura_watch.lua` делает full scan через `AuraUtil.ForEachAura()` — это O(N) per unit per update.

#### ★ НЮАНС (НОВОЕ): Secret value guard в raid aura filter

**units/raid.lua строки 50-75** — customFilter() не проверяет `spellID` на secret:
```lua
-- СЕЙЧАС:
if(spellID == 25771) then  -- ← может упасть если spellID secret
  ret = true
end
if (whitelist[spellID]) then  -- ← table access на secret value
  ret = true
end

-- ФИКС: добавить guard:
local IsSecret = ns.safety and ns.safety.IsSecret or issecretvalue
if IsSecret and IsSecret(spellID) then return false end
```

- **Done when:** Aura display на всех unit frames через oUF.

### 2.5 `[NOT DONE]` Range — через oUF Range element

- **Сейчас:** Свой range driver + oUF Range смешаны.
- **Цель:** oUF Range element как baseline. Roth настраивает insideAlpha/outsideAlpha.

#### oUF Range element API

```lua
-- Минимальный setup:
self.Range = {
  insideAlpha = 1,       -- alpha when in range
  outsideAlpha = 0.4,    -- alpha when out of range
}

-- oUF автоматически:
-- 1. Регистрирует OnUpdate poller
-- 2. Вызывает UnitInRange(unit) + UnitIsConnected(unit)
-- 3. Применяет alpha через frame:SetAlpha()

-- Для party/raid — особенно полезно для out-of-range greying
```

**Нюанс:** oUF Range element использует OnUpdate poller (не event). Это нормально — `UnitInRange()` не имеет события, только polling.

**Нюанс Roth_UI:** lib.lua имеет свой range driver с дополнительной spell-based проверкой. Для большинства случаев `UnitInRange()` достаточно. Если нужна spell-based — Override:

```lua
self.Range.Override = function(self, event)
  local element = self.Range
  local unit = self.unit
  if UnitIsConnected(unit) then
    local inRange = UnitInRange(unit)
    self:SetAlpha(inRange and element.insideAlpha or element.outsideAlpha)
  else
    self:SetAlpha(element.outsideAlpha)
  end
end
```

- **Done when:** Один range driver (oUF).

### 2.6 `[NOT DONE]` ★ ClassPower — oUF element вместо bars.lua per-class

- **Сейчас:** `core/bars.lua` содержит ~700 строк с 6 отдельными per-class реализациями (ComboPoints, Chi, HolyPower, SoulShards, ArcaneCharges, Runes).
- **Цель:** oUF ClassPower element (единый) + oUF Runes element (DK).

#### oUF ClassPower API

```lua
-- oUF ClassPower автоматически определяет класс и ресурс:
-- Rogue/Druid → Combo Points
-- Monk → Chi
-- Paladin → Holy Power
-- Warlock → Soul Shards
-- Mage → Arcane Charges
-- Evoker → Essence

-- Setup в player style function:
local ClassPower = {}
local MAX_POINTS = 10  -- max combo points with talents

for i = 1, MAX_POINTS do
  ClassPower[i] = CreateFrame("StatusBar", nil, self)
  ClassPower[i]:SetSize(cfg.classPower.width, cfg.classPower.height)
  ClassPower[i]:SetStatusBarTexture(mediapath .. "classbar_fill")

  -- Background
  ClassPower[i].bg = ClassPower[i]:CreateTexture(nil, "BORDER")
  ClassPower[i].bg:SetAllPoints()
  ClassPower[i].bg:SetTexture(mediapath .. "classbar_bg")
  ClassPower[i].bg:SetAlpha(0.3)

  -- Position relative to orbs:
  if i == 1 then
    ClassPower[i]:SetPoint("LEFT", orbFrame, "RIGHT", 4, 0)
  else
    ClassPower[i]:SetPoint("LEFT", ClassPower[i-1], "RIGHT", 2, 0)
  end
end

-- Callback: Roth custom styling
ClassPower.PostUpdate = function(element, cur, max, hasMaxChanged, powerType)
  -- Show active, dim inactive
  for i = 1, max do
    element[i]:Show()
    element[i]:SetAlpha(i <= cur and 1 or 0.3)
  end
  for i = max + 1, #element do
    element[i]:Hide()
  end

  -- Roth art: resize container based on max points
  if hasMaxChanged then
    local container = element[1]:GetParent()
    container:SetWidth(max * (cfg.classPower.width + 2) - 2)
  end
end

self.ClassPower = ClassPower

-- oUF auto-registers:
-- UNIT_POWER_FREQUENT (combo points)
-- UNIT_POWER_UPDATE (other resources)
-- PLAYER_TALENT_UPDATE (max changes)
-- UNIT_DISPLAYPOWER (power type changes)
```

#### oUF ClassPower — class-specific data (из oUF classpower.lua)

| Класс | Ресурс | Режим | Условие |
|-------|--------|-------|---------|
| Demon Hunter | Soul Fragments | Aura | Spec 3 + Void Meta |
| Druid | Combo Points | Power | Energy present |
| Evoker | Essence | Power | — |
| Mage | Arcane Charges | Power | Spec 1 (Arcane) |
| Monk | Chi Orbs | Power | Spec 3 (Windwalker) |
| Paladin | Holy Power | Power | — |
| Rogue | Combo Points | Power | — |
| Shaman | Maelstrom | Aura | Spec 2 + Talent |
| Warlock | Soul Shards | Power | Spec 3 (Destruction) special |

#### oUF Runes element (Death Knight)

```lua
-- Отдельный element для DK runes:
local Runes = {}
for i = 1, 6 do
  Runes[i] = CreateFrame("StatusBar", nil, self)
  Runes[i]:SetSize(20, 20)
  Runes[i]:SetStatusBarTexture(mediapath .. "rune_fill")
  Runes[i]:SetStatusBarColor(0.77, 0.12, 0.23)  -- blood color

  Runes[i].bg = Runes[i]:CreateTexture(nil, "BORDER")
  Runes[i].bg:SetAllPoints()
  Runes[i].bg:SetTexture(mediapath .. "rune_bg")

  if i == 1 then
    Runes[i]:SetPoint("LEFT", orbFrame, "RIGHT", 4, 0)
  else
    Runes[i]:SetPoint("LEFT", Runes[i-1], "RIGHT", 2, 0)
  end
end

Runes.sortOrder = "asc"   -- sort by cooldown remaining (ready first)
Runes.colorSpec = true     -- auto-color by DK spec

self.Runes = Runes
-- oUF auto-registers RUNE_POWER_UPDATE
```

**Что удалить из bars.lua:**
- Строки ~350-1074: ВСЕ per-class реализации (~700 строк)
- Строки ~60-350: Exp/Rep bars (дубль oUF/elements/) (~290 строк)
- **Оставить:** строки 1-60 (init + utility) — если нужны

**Результат:** bars.lua ~1074 строк → ~60 строк или полное удаление файла.

- **Done when:** oUF ClassPower отображает class resources для всех классов. bars.lua удалён или minimal.

### 2.7 `[NOT DONE]` Player frame — orbs остаются custom

- **Player orbs** — это custom rendering (не StatusBar), oUF не может их заменить.
- **Но:** Health/Power VALUE UPDATES должны приходить через oUF Health/Power element.

#### Паттерн: oUF PostUpdate → Orb Bridge

```lua
-- В player style function:
local Health = CreateFrame("StatusBar", nil, self)
Health:SetSize(1, 1)  -- invisible — orbs render separately
Health:SetAlpha(0)     -- hide the StatusBar itself

Health.PostUpdate = function(element, unit, cur, max)
  -- Secret value safety (12.x):
  if issecretvalue(cur) or issecretvalue(max) then
    -- Secret values: нельзя делать арифметику/сравнение
    -- Orb fill использует SetAlphaFromBoolean или DurationObject
    -- Или просто показать "full" state
    return
  end
  -- Bridge: feed oUF values into orb renderer
  if ns.orbRuntime and ns.orbRuntime.UpdateHealth then
    ns.orbRuntime.UpdateHealth(cur, max)
  end
end

self.Health = Health  -- oUF manages events & updates

-- Same for Power:
local Power = CreateFrame("StatusBar", nil, self)
Power:SetSize(1, 1)
Power:SetAlpha(0)

Power.PostUpdate = function(element, unit, cur, max)
  if issecretvalue(cur) or issecretvalue(max) then return end
  if ns.orbRuntime and ns.orbRuntime.UpdatePower then
    ns.orbRuntime.UpdatePower(cur, max)
  end
end

self.Power = Power
```

**Нюанс:** player.lua сейчас (строки 62-72) инициализирует параметры, подключает orb rendering и напрямую читает UnitHealth/UnitPower. После рефакторинга oUF Health/Power elements будут единственным источником UNIT_HEALTH/UNIT_POWER_UPDATE.

**Нюанс secret values:** В 12.x health/power значения могут быть secret. oUF Health element передаёт raw values в PostUpdate. Orb renderer должен проверять `issecretvalue()`:
```lua
-- API:
issecretvalue(val)       -- returns true if val is secret
canaccessvalue(val)      -- returns true if secret is currently accessible
-- Safe sinks (работают с secrets):
StatusBar:SetValue(secretVal)           -- OK
frame:SetAlphaFromBoolean(secretBool)   -- OK
-- Unsafe operations (ОШИБКА с secrets):
local x = secretVal + 1     -- ERROR
if secretVal > 0 then end   -- ERROR
tostring(secretVal)          -- ERROR
```

- **Done when:** Orb rendering питается oUF events, а не ручными UNIT_HEALTH/UNIT_POWER handlers.

### 2.8 `[NOT DONE]` Разбить lib.lua

- **После фаз 2.1-2.7** lib.lua станет значительно меньше.
- Оставить: color utilities, formatting, Roth-specific helpers.
- Вынести: oUF-дублированные функции (удалить).

#### Целевая структура после split

```
core/lib.lua                    → ~600 строк: только утилиты
  ├── Secret value guards (IsSecretValue, SafeUnitHealth, etc.)
  │    ★ После 5.2: только ns.safety.IsSecret(), удалить func.IsSecretValue
  ├── Font helpers (createFontString, ResolveFontPath)
  ├── Icon helpers (createIconTexture)
  ├── Color utilities (colorHexCache, class colors)
  └── Number formatting (shortNumbers, abbreviate)

УДАЛЕНО из lib.lua:
  ├── createCastbar() → inline в style function (2.3)
  ├── createBuffs/createDebuffs() → inline в style function (2.4)
  ├── createPortrait() → inline в style function
  ├── createAlternativePowerBar() → inline в style function
  ├── RefreshUnitHealthBar() → удалить (oUF Health)
  ├── range driver → удалить (oUF Range) (2.5)
  ├── checkThreat() → удалить (oUF ThreatIndicator)
  ├── aura duration tracking → PostUpdate callbacks (2.4)
  └── drag/mover functions → mover_runtime only (0.4)
```

- **Цель:** lib.lua ≤ 15 KB.

### 2.9 `[NOT DONE]` ★ HealthPrediction — добавить для party/raid

- **Сейчас:** Не используется в Roth_UI.
- **Цель:** Добавить для party/raid frames (heal prediction bars).
- **Приоритет:** Низкий. Делать ПОСЛЕ стабилизации 2.1-2.8.

#### oUF HealthPrediction API

```lua
-- oUF HealthPrediction element:
local myBar = CreateFrame("StatusBar", nil, self.Health)
myBar:SetPoint("TOP")
myBar:SetPoint("BOTTOM")
myBar:SetPoint("LEFT", self.Health:GetStatusBarTexture(), "RIGHT")
myBar:SetWidth(200)
myBar:SetStatusBarTexture(E.media.blankTex)
myBar:SetStatusBarColor(0, 0.8, 0, 0.4)

local otherBar = CreateFrame("StatusBar", nil, self.Health)
otherBar:SetPoint("TOP")
otherBar:SetPoint("BOTTOM")
otherBar:SetPoint("LEFT", myBar:GetStatusBarTexture(), "RIGHT")
otherBar:SetWidth(200)
otherBar:SetStatusBarTexture(E.media.blankTex)
otherBar:SetStatusBarColor(0, 0.6, 0, 0.4)

local absorbBar = CreateFrame("StatusBar", nil, self.Health)
-- ... similar setup

self.HealthPrediction = {
  myBar = myBar,
  otherBar = otherBar,
  absorbBar = absorbBar,
  maxOverflow = 1.05,  -- 5% overflow allowed
}
-- oUF auto-registers UNIT_HEAL_PREDICTION, UNIT_ABSORB_AMOUNT_CHANGED
```

- **Done when:** Heal prediction overlays на party/raid frames.

### 2.10 `[NOT DONE]` ★ oUF_Smooth → StatusBarInterpolation (Retail)

- **Сейчас:** `modules/Roth_UI_oUFModules/oUF_Smooth.lua` — legacy smoothing module.
- **Цель:** На Retail использовать нативную `StatusBarInterpolation`.

#### Реализация

```lua
-- В каждом style function где создаётся StatusBar:
if StatusBarInterpolation then
  -- Retail 12.x: native API
  Health.smoothing = StatusBarInterpolation.ExponentialEaseOut
  Power.smoothing = StatusBarInterpolation.ExponentialEaseOut
  -- oUF_Smooth НЕ нужен
else
  -- Classic: use oUF_Smooth legacy
  Health.Smooth = true
  Power.Smooth = true
end
```

**ElvUI делает именно так:**
```lua
-- ElvUI Health bar configuration:
if E.Retail then
  health.smoothing = (db.health.smoothbars and StatusBarInterpolation.ExponentialEaseOut)
    or StatusBarInterpolation.Immediate
    or nil
else
  E:SetSmoothing(health, db.health.smoothbars)
end
```

**Нюанс:** Если StatusBarInterpolation используется, oUF_Smooth.lua может конфликтовать (оба хукают SetValue). Нужно гарантировать что oUF_Smooth НЕ активен когда StatusBarInterpolation доступен.

- **Done when:** Health/Power bars плавно анимируются на Retail без oUF_Smooth.

---

## Фаза 3 — Persistence & Settings

### 3.1 `[NOT DONE]` Упростить persistence до 3 файлов

- **Целевая структура:**
  - `core/sv_store.lua` — low-level API (GetPath, SetPath, EnsurePath)
  - `core/config_persistence_owner.lua` — config domain (defaults merge, schema patches, proxy)
  - `core/orb_persistence_owner.lua` — orb domain (templates, char state)
- **Удалить/merge:**
  - persistence_runtime_state → inline в config_persistence_owner
  - persistence_root_store → merge в sv_store
  - persistence_domain_registry → inline в config_persistence_owner
  - persistence_schema_registry → inline в config_persistence_owner
  - persistence_drift_service → merge в reconcile service → inline в config_persistence_owner
  - persistence_reconcile_service → inline в config_persistence_owner
  - persistence_control_plane → оставить как thin facade (50 строк max) или убрать
  - persistence_report_service → merge в sv_doctor

#### Паттерн ElvUI (persistence)

```lua
-- ElvUI: 3 уровня SV
-- ElvDB          — global (synced across all chars)
-- ElvPrivateDB   — char-locked (never synced)
-- ElvCharacterDB — per-char profile (transferable)

-- Defaults deep-copy:
function E:CopyTable(currentTable, defaultTable)
  if type(currentTable) ~= "table" then currentTable = {} end
  for option, value in pairs(defaultTable) do
    if type(value) == "table" then
      currentTable[option] = E:CopyTable(currentTable[option], value)
    elseif currentTable[option] == nil then
      currentTable[option] = value
    end
  end
  return currentTable
end

-- Init:
function E:Initialize()
  E.db = E:CopyTable(ElvCharacterDB.profile or {}, P)
  E.global = E:CopyTable(ElvDB.global or {}, G)
  E.private = E:CopyTable(ElvPrivateDB.profile or {}, V)
end
```

**Рекомендация для Roth_UI:**
```lua
-- Целевой sv_store.lua:
local sv = {}
ns.sv = sv

function sv.Init()
  Roth_UI_DB = Roth_UI_DB or {}
  Roth_UI_DB.account = Roth_UI_DB.account or {}
  Roth_UI_DB.account.settings = DeepMerge(Roth_UI_DB.account.settings or {}, DEFAULTS)
  Roth_UI_DB_Char = Roth_UI_DB_Char or {}
end

function sv.Get(path)
  return ResolvePath(Roth_UI_DB, path)
end

function sv.Set(path, value)
  SetPath(Roth_UI_DB, path, value)
end
```

**Нюанс:** Сохранить schema version check (cfg.__version = 60) и migration patches (v1→v17). Они нужны для backward compatibility.

- **Done when:** Persistence работает на 3-4 файлах. Нет циркулярных зависимостей.

### 3.2 `[NOT DONE]` Один reset entrypoint

- **Сейчас:** Reset logic в settings_general, settings_actions, slashcmd, lib.lua.
- **Цель:** Одна функция `ns.persistence.FactoryReset()` → wipe SV → reload.
- **Все entry points** (settings UI button, slash command) вызывают эту одну функцию.

```lua
-- Целевой API:
function ns.persistence.FactoryReset()
  Roth_UI_DB = nil
  Roth_UI_DB_Char = nil
  ReloadUI()
end

-- Slash command:
-- /rothui reset → ns.persistence.FactoryReset()

-- Settings UI button:
-- onClick → ns.persistence.FactoryReset()
```

- **Done when:** `/rothui reset` и Settings UI кнопка вызывают одну функцию.

### 3.3 `[NOT DONE]` Settings UI — чистые Blizzard Settings

- **Сейчас:** `settings_main.lua` уже использует Blizzard Settings framework — хорошо.
- **Фикс:** Убрать дубли apply logic между settings_*.lua и slash commands.

#### Blizzard Settings Framework API

```lua
-- Регистрация категории:
local category = Settings.RegisterCanvasLayoutCategory(frame, "Roth UI")
Settings.RegisterAddOnCategory(category)

-- Регистрация setting:
local setting = Settings.RegisterAddOnSetting(
  category,
  variable,   -- "roth_ui_frame_lock"
  variableKey, -- "frameLock"
  variableTbl, -- ns.cfg
  type,        -- Settings.VarType.Boolean
  name,        -- "Lock Frames"
  defaultValue -- false
)

-- Callback при изменении:
Settings.SetOnValueChangedCallback(variable, function(setting, value)
  ns.ApplySettingChange("frameLock", value)
end)

-- Создание checkbox:
Settings.CreateCheckbox(category, setting, tooltip)

-- Создание slider:
local setting = Settings.RegisterAddOnSetting(...)
local options = Settings.CreateSliderOptions(min, max, step)
Settings.CreateSlider(category, setting, options, tooltip)

-- Создание dropdown:
local function GetOptions()
  local container = Settings.CreateControlTextContainer()
  container:Add("option1", "Label 1")
  container:Add("option2", "Label 2")
  return container:GetData()
end
Settings.CreateDropdown(category, setting, GetOptions, tooltip)
```

- **Settings пишет** через `ns.SVSet(path, value)`.
- **Settings читает** через `ns.cfg[key]` (proxy).
- **Apply** через один callback: `settings → ns.ApplySettingChange(key, value)`.

#### ★ НЮАНС (НОВОЕ): settings_main.lua regen frame leak

`core/settings_main.lua ~строки 90-110` — `EnsureRegenQueue()` создаёт frame с listener PLAYER_REGEN_ENABLED, который НИКОГДА не unregister'ится:
```lua
-- СЕЙЧАС:
ui.regenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
ui.regenFrame:SetScript("OnEvent", function()
  -- processes pending callbacks
end)
-- Frame живёт вечно, listener не снимается

-- ФИКС: unregister после обработки очереди:
ui.regenFrame:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_REGEN_ENABLED")
  -- process pending callbacks
  -- re-register only if queue not empty
end)
```

- **Done when:** Settings UI и slash commands не дублируют write/apply logic.

### 3.4 `[NOT DONE]` Orb persistence — чистый single-owner

- **Сейчас:** player.lua читает из 4 точек: `ns.cfg` (settings proxy), `ns.db` (orb database), `ns.store.GetOrbConfig()` (store API), `ns.orbPersistence.RunPipeline()` (orb persistence owner).
- **Цель:** Один accessor: `ns.orbs.Get(orbType, key)` и `ns.orbs.Set(orbType, key, value)`.

#### Детализация 4 access points

```lua
-- player.lua:47-55 — ResolveOrbConfig использует ns.store:
local function ResolveOrbConfig(orbType)
  if type(storeApi) == "table" and type(storeApi.GetOrbConfig) == "function" then
    return storeApi.GetOrbConfig(orbType)
  end
  return nil
end

-- player.lua:10 — ns.db (orb database defaults):
local db = ns.db

-- player.lua:8 — ns.cfg (global settings):
local cfg = ns.cfg

-- player.lua:12 — ns.orbPersistence:
local orbPersistence = ns and ns.orbPersistence
```

**Целевой API:**
```lua
-- ns.orbs — единый accessor:
local orbs = {}
ns.orbs = orbs

function orbs.Get(orbType, key)
  -- Priority: char override → account template → default
  local charOverride = Roth_UI_DB_Char and Roth_UI_DB_Char.orbs
  local charOrb = charOverride and charOverride[orbType]
  if charOrb and charOrb[key] ~= nil then return charOrb[key] end

  local templates = Roth_UI_DB and Roth_UI_DB.account and Roth_UI_DB.account.templates
  local tmpl = templates and templates[orbType]
  if tmpl and tmpl[key] ~= nil then return tmpl[key] end

  return ns.db[orbType] and ns.db[orbType][key]
end

function orbs.Set(orbType, key, value)
  Roth_UI_DB_Char = Roth_UI_DB_Char or {}
  Roth_UI_DB_Char.orbs = Roth_UI_DB_Char.orbs or {}
  Roth_UI_DB_Char.orbs[orbType] = Roth_UI_DB_Char.orbs[orbType] or {}
  Roth_UI_DB_Char.orbs[orbType][key] = value
end

function orbs.GetTemplate(orbType)
  -- Returns full merged config for orbType:
  local result = {}
  -- Layer 1: defaults
  if ns.db[orbType] then
    for k, v in pairs(ns.db[orbType]) do result[k] = v end
  end
  -- Layer 2: account template
  local templates = Roth_UI_DB and Roth_UI_DB.account and Roth_UI_DB.account.templates
  local tmpl = templates and templates[orbType]
  if tmpl then
    for k, v in pairs(tmpl) do result[k] = v end
  end
  -- Layer 3: char override
  local charOrb = Roth_UI_DB_Char and Roth_UI_DB_Char.orbs and Roth_UI_DB_Char.orbs[orbType]
  if charOrb then
    for k, v in pairs(charOrb) do result[k] = v end
  end
  return result
end
```

- **Done when:** player.lua работает с одним orb API.

---

## Фаза 4 — Policy & Registry Cleanup

### 4.1 `[NOT DONE]` frame_policy.lua → разбить по ролям

- `core/frame_policy.lua` → только unit frame visibility policy
- `core/group_policy.lua` → party/raid policy (уже есть)
- `core/font_policy.lua` → global font application (уже есть)
- `core/blizzard_restore_debug.lua` → debug only (уже есть)
- **Удалить из frame_policy:** всё что уже перенесено в отдельные файлы.

#### Нюанс: frame_policy и oUF:DisableBlizzard

oUF имеет встроенный `oUF:DisableBlizzard(unit)` для скрытия Blizzard unit frames:
```lua
-- oUF blizzard.lua handles:
-- player → PlayerFrame
-- pet → PetFrame
-- target → TargetFrame
-- focus → FocusFrame
-- boss1-5 → BossTargetFrameContainer
-- party1-5 → PartyFrame + CompactPartyFrameMember
-- arena1-3 → CompactArenaFrame

-- Что делает oUF:DisableBlizzard():
-- 1. Unregisters all events on Blizzard frame
-- 2. Hides frame or sets alpha=0
-- 3. Parents to hiddenParent
-- 4. Hooks SetParent to prevent re-parenting
-- 5. Clears sub-widget events
```

**Рекомендация:** Для unit frames — использовать `oUF:DisableBlizzard()` (oUF делает это автоматически при Spawn). Для action bars — свой `hide_blizzard_bars.lua` (oUF не управляет bars).

#### ★ НЮАНС (НОВОЕ): ParkFrame hidden parent forbidden check

`core/frame_policy.lua ~строка 128` — `ParkFrame()` не проверяет `IsForbidden(hiddenParent)`:
```lua
-- СЕЙЧАС:
local function ParkFrame(frame)
  if not frame or IsForbidden(frame) then return end
  SafeSetParent(frame, GetHiddenParent())  -- hiddenParent не проверяется
end

-- ФИКС:
local function ParkFrame(frame)
  if not frame or IsForbidden(frame) then return end
  local hp = GetHiddenParent()
  if IsForbidden(hp) then return end
  SafeSetParent(frame, hp)
end
```

### 4.2 `[NOT DONE]` Global registries → namespace registries

- **Перевести:**
  - `Roth_UI_Bars` → `ns.registry.bars`
  - `Roth_UI_Orbs` → `ns.registry.orbs`
  - `Roth_UI_Units` → `ns.registry.units`
  - `Roth_UI_Art` → `ns.registry.art`
- **Делать вместе** с mover/reset/unlock logic.

**Нюанс:** `frame_registry.lua` уже создаёт `ns.frameRegistry` с категориями. Проверить, не дублируют ли globals `frame_registry` функционал.

### 4.3 `[NOT DONE]` Group runtime — party/raid lifecycle

- Нормализовать: header generation, hidden parent, custom visibility driver, deferred apply.
- Не плодить вторую lifecycle-модель поверх oUF headers.
- oUF:SpawnHeader() — основной API.

#### oUF SpawnHeader API

```lua
-- party:
oUF:Factory(function(self)
  self:SetActiveStyle("Roth_Group")
  local partyHeader = self:SpawnHeader(
    "Roth_UIPartyHeader",
    nil,  -- template (nil = default SecureGroupHeaderTemplate)
    "custom [@raid6,exists] hide; [group:party] show; hide",
    "showParty", true,
    "showPlayer", true,
    "showSolo", false,
    "yOffset", -30,
    "maxColumns", 1,
    "unitsPerColumn", 5,
    "oUF-initialConfigFunction", [[
      self:SetWidth(200)
      self:SetHeight(40)
    ]]
  )
end)

-- raid:
oUF:Factory(function(self)
  self:SetActiveStyle("Roth_Raid")
  local raidHeader = self:SpawnHeader(
    "Roth_UIRaidHeader",
    nil,
    "custom [@raid6,exists] show; hide",
    "showRaid", true,
    "groupFilter", "1,2,3,4,5,6,7,8",
    "groupBy", "GROUP",
    "groupingOrder", "1,2,3,4,5,6,7,8",
    "maxColumns", 8,
    "unitsPerColumn", 5,
    "columnAnchorPoint", "LEFT",
    "columnSpacing", 5,
    "yOffset", -5,
    "oUF-initialConfigFunction", [[
      self:SetWidth(80)
      self:SetHeight(30)
    ]]
  )
end)
```

**Нюанс:** visibility condition `"custom [condition] show; hide"` — prefix `custom` важен для oUF, без него не работает conditional visibility.

#### ★ НЮАНС (НОВОЕ): Race condition в party header spawn

**units/party.lua строки 340-380** — `SpawnPartyHeader()` может race с `RebuildPartyStructureRuntime()`:
```lua
-- Если spawn вернёт nil (oUF internal failure), partyHeader = nil
-- ApplyEnabled() делает: if not partyHeader then SetActivePartyHeader(SpawnPartyHeader())
-- Но первый spawn не обнулил partyHeader → infinite loop

-- ФИКС: добавить nil-check после spawn:
local header = SpawnPartyHeader()
if not header then
  ns.logger.Warn("Failed to spawn party header")
  return
end
SetActivePartyHeader(header)
```

#### ★ НЮАНС (НОВОЕ): group_policy.lua taint с CompactRaidFrameManager

**core/group_policy.lua строки 50-55:**
```lua
-- СЕЙЧАС: прямой вызов Blizzard функции
CompactRaidFrameManager_UpdateShown()  -- может вызвать taint

-- ФИКС: обернуть в TryCall:
if type(_G.CompactRaidFrameManager_UpdateShown) == "function" then
  ns.safety.TryCall(_G.CompactRaidFrameManager_UpdateShown)
end
```

### 4.4 `[NOT DONE]` ★ Edit Mode совместимость

- **Blizzard Edit Mode** (12.x) управляет позициями Blizzard frames. Roth_UI перехватывает эти frames.
- **Потенциальные проблемы:**
  - Edit Mode может сбросить позиции Roth-перемещённых frames
  - Roth movers могут конфликтовать с Edit Mode grid

#### API и hooks

```lua
-- Проверка активности Edit Mode:
EditModeManagerFrame:IsEditModeActive()

-- Events:
EventRegistry:RegisterCallback("EditMode.Enter", function()
  -- Hide Roth movers, potentially show default grid
end)
EventRegistry:RegisterCallback("EditMode.Exit", function()
  -- Restore Roth movers
end)

-- ElvUI подход:
hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
  -- 1. Hide all ElvUI movers
  -- 2. Show notification "Use /elvui to move ElvUI frames"
end)
hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
  -- 1. Restore ElvUI layout
end)
```

**Минимальный фикс:** Показать предупреждение при входе в Edit Mode:
```lua
EventRegistry:RegisterCallback("EditMode.Enter", function()
  print("|cFF00FF00Roth UI:|r Use /roth unlock to move Roth frames")
end)
```

- **Done when:** Edit Mode open/close не ломает Roth_UI layout.

---

## Фаза 5 — Quality & Cleanup

### 5.1 `[NOT DONE]` Media audit

- Построить map: used assets / legacy-only / dead assets.
- Почистить package size, obsolete art.

**Как проверить:** `grep -rn "media\\\\" _Addons/Roth_UI/*.lua` + `ls media/` → diff = dead assets.

### 5.2 `[NOT DONE]` Secret vocabulary cleanup

- Централизовать secret-check wrappers.
- Одна точка: `ns.safety.IsSecret()`.

#### Нюанс: дублирование secret checks

Найдено 4 независимых определения IsSecretValue:
1. `core/safety.lua` → `ns.safety.IsSecret` (canonical)
2. `core/lib.lua:66-71` → `func.IsSecretValue` (wrapper over safety)
3. `core/target_castbar.lua:38-47` → локальный `IsSecretValue` (полностью независимый)
4. `core/tags.lua:60` → `local IsSecretValue = func.IsSecretValue or safety.IsSecret`

**Фикс:** Удалить все кроме `ns.safety.IsSecret()`. Все файлы используют:
```lua
local IsSecret = ns.safety.IsSecret
-- или для обратной совместимости:
local IsSecret = assert(ns.safety and ns.safety.IsSecret, "safety.IsSecret required")
```

### 5.3 `[NOT DONE]` Dormant code cleanup

- Убрать fallback-only paths без owner.
- Убрать compatibility shims для давно удалённого кода.

**Найденные dormant items:**
1. `oUF/elements/rune_orbs.lua` — на диске, НЕ в TOC → удалить файл
2. `charspecific.lua` — disabled (early return) → решить: удалить или включить
3. `_G.RothUI = {}` в lib.lua:48 — пустой глобал, нигде не используется → удалить
4. `_G.IsAddOnLoadedCompat` в lib.lua:59-61 — shim → проверить использование, вероятно удалить
5. Path C code в action_bar_bar2-5.lua — мёртвый код → удалить (если не сделано в 0.2)
6. `bar_runtime_registry.DEFAULT_DESCRIPTORS` legacy frame names — обновить

### 5.4 `[NOT DONE]` Удалить rButtonTemplate legacy module

- **Условие:** После стабилизации action bars (фаза 1 complete).
- Перенести нужный код в core/button_style.lua.

**Нюанс:** `rButtonTemplate` предоставляет глобальный `_G.rButtonTemplate` table с методом `StyleActionButton()`. Secure runtime (строка 138-143) использует его. Нужно:
1. Перенести `StyleActionButton` в core/button_style.lua
2. Обновить secure_runtime.lua ссылку

### 5.5 `[NOT DONE]` ★ init.lua color compat — проверка конфликта

- `init.lua:26-66` — `Roth_MakeColor()` обёрткa + oUF color bootstrap
- oUF 13.x нативно использует ColorMixin objects
- **Нужно проверить:** `type(oUF.colors.power[0])` — если это ColorMixin, обёртка не нужна
- Если конфликт: удалить Roth_MakeColor, использовать oUF colors as-is

### 5.6 `[NOT DONE]` ★ Nameplate support (future consideration)

- oUF поддерживает nameplates через `oUF:SpawnNamePlates()`
- ElvUI активно использует это для custom nameplates
- Roth_UI пока НЕ имеет nameplate модуля
- **Не блокирует рефакторинг**, но после стабилизации unit frames — natural next step

```lua
-- Возможная будущая реализация:
oUF:Factory(function(self)
  self:RegisterStyle("Roth_NamePlate", function(frame, unit)
    local Health = CreateFrame("StatusBar", nil, frame)
    Health:SetAllPoints()
    Health:SetStatusBarTexture(mediapath .. "nameplate_health")
    Health.colorClass = true
    Health.colorReaction = true
    frame.Health = Health

    local Name = frame:CreateFontString(nil, "OVERLAY")
    Name:SetPoint("BOTTOM", frame, "TOP", 0, 2)
    frame:Tag(Name, "[roth:name]")

    local Castbar = CreateFrame("StatusBar", nil, frame)
    Castbar:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    Castbar:SetSize(frame:GetWidth(), 8)
    Castbar.Text = Castbar:CreateFontString(nil, "OVERLAY")
    Castbar.PostCastStart = ns.CastbarPostStart
    frame.Castbar = Castbar
  end)

  self:SetActiveStyle("Roth_NamePlate")
  self:SpawnNamePlates("Roth_UI",
    function(nameplate, event, unit) end,  -- added callback
    function(nameplate, event, unit) end   -- removed callback
  )
end)
```

### 5.7 `[NOT DONE]` ★ Orb font resolution performance (НОВОЕ)

- **Симптом:** CPU burn при частых orb refresh'ах.
- **Корень:** `core/orb_text_controller.lua ~строка 50` вызывает `func.ResolveFontPath()` на каждом обновлении вместо кэширования.

**Фикс:** Кэшировать resolved font path при инициализации orb или при смене настроек:
```lua
-- СЕЙЧАС:
local function UpdateText(orbFrame)
  local font = func.ResolveFontPath(cfg.orbFont)  -- вызов каждый update
  orbFrame.text:SetFont(font, size, flags)
end

-- СТАЛО:
local cachedFont = nil
local function InvalidateFontCache()
  cachedFont = nil
end
local function GetFont()
  if not cachedFont then
    cachedFont = func.ResolveFontPath(cfg.orbFont)
  end
  return cachedFont
end
-- Вызывать InvalidateFontCache() при смене настроек font
```

---

## Safe Sequencing (порядок выполнения)

```
Фаза 0: Emergency Hotfix
  0.1 Fix init order → settings загружаются
  0.2 Kill dead code paths → один owner (Path A LAB)
  0.3 ★ Fix GetCVarBool → keybinds работают (НОВОЕ)
  0.4 Fix dock references → bottom cluster на месте
  0.5 Single mover → нет двойной записи
  0.6 Simplify persistence → меньше файлов
  0.7 ★ Fix event cleanup party/raid → нет stale listeners (НОВОЕ)

Фаза 1: Action Bar Ownership
  1.1 Shell owner per bar → ElvUI pattern
  1.2 Visibility owner → state drivers
  1.3 Dock owner → единый
  1.4 Art owner → единый (+ удалить Exp/Rep из bars.lua)
  1.5 Combat defer → нет ADDON_ACTION_BLOCKED
  1.6 ExtraAction thin wrapper
  1.7 Vehicle/Override matrix
  1.8 Delete legacy rActionBarStyler

Фаза 2: Unit Frames → oUF
  2.1 Audit lib.lua vs oUF (ЧАСТИЧНО СДЕЛАНО)
  2.2 Rewrite style function + oUF:Factory
  2.3 Castbar → oUF element (ALL: target + player + focus + boss)
  2.4 Auras → oUF element (+ secret value guard в filter)
  2.5 Range → oUF element
  2.6 ★ ClassPower → oUF element (заменяет ~700 строк bars.lua)
  2.7 Player orbs ← oUF events
  2.8 Split lib.lua
  2.9 HealthPrediction для party/raid (низкий приоритет)
  2.10 ★ oUF_Smooth → StatusBarInterpolation (Retail)

Фаза 3: Persistence & Settings
  3.1 Persistence 8→3 files
  3.2 Single reset entrypoint
  3.3 Settings Blizzard-only (+ fix regen frame leak)
  3.4 Orb single-owner API

Фаза 4: Policy & Registry
  4.1 Split frame_policy (+ fix ParkFrame forbidden check)
  4.2 Global → namespace registries
  4.3 Group runtime normalize (+ fix party spawn race + group_policy taint)
  4.4 ★ Edit Mode совместимость

Фаза 5: Quality
  5.1 Media audit
  5.2 Secret cleanup
  5.3 Dormant code cleanup
  5.4 Delete rButtonTemplate
  5.5 ★ init.lua color compat check
  5.6 ★ Nameplate support future
  5.7 ★ Orb font resolution performance (НОВОЕ)
```

---

## Правила работы

1. **Не рефакторить по папкам** — рефакторить по ownership clusters.
2. **Не чинить симптомы** — убирать dual-ownership root cause.
3. **Не трогать P8 items** до закрытия P0-P1 блокеров.
4. **oUF — авторитет** для unit frame logic. Если oUF element делает то же — удалять свой код.
5. **ElvUI — референс** для action bar pattern. Дизайн свой, архитектура от них.
6. **Один owner на surface** — всегда. Нет exceptions.
7. **Combat defer** — обязательно для любых frame operations.
8. **Blizzard Settings Framework** — для settings UI. Не изобретать своё.
9. **oUF:Factory()** — все spawn вызовы внутри Factory.
10. **StatusBarInterpolation** — на Retail вместо oUF_Smooth.
11. **ClassPower unified** — oUF ClassPower вместо per-class bars.lua.
12. **ColorMixin safety** — все color resolvers должны поддерживать `:GetRGB()`.
13. **C_CVar вместо GetCVarBool** — deprecated API удалён в 12.x.
14. **Secret guard в aura filters** — spellID может быть secret в combat.

---

## Live Verification Checklist

### Базовая загрузка
- `[ ]` `/reload` без Lua errors
- `[ ]` `/console scriptErrors 1` — чисто
- `[ ]` нет `ADDON_ACTION_BLOCKED`
- `[ ]` нет secret-value runtime ошибок

### Action bars
- `[ ]` main bar в нормальном контейнере с корректным art
- `[ ]` bars 2-3 видимы и не ломают layout
- `[ ]` bars 4-5 (right) на своих местах
- `[ ]` micromenu / bags / stance / pet / leave vehicle в доке
- `[ ]` vehicle enter/exit
- `[ ]` possess
- `[ ]` override bar
- `[ ]` ExtraAction encounter button
- `[ ]` ZoneAbility coexistence
- `[ ]` Quick Keybind mode
- `[ ]` ★ click-on-down CVar работает (НОВОЕ)

### Unit frames
- `[ ]` Player orbs отображаются корректно
- `[ ]` Target frame видим и обновляется
- `[ ]` Party frames при /invite
- `[ ]` Raid frames в LFR/raid
- `[ ]` Boss frames в encounter
- `[ ]` Focus frame при /focus

### Castbars
- `[ ]` target interruptible cast
- `[ ]` target non-interruptible cast
- `[ ]` target channel
- `[ ]` target empower
- `[ ]` target failed/interrupted cast
- `[ ]` ★ player castbar
- `[ ]` targettarget castbar
- `[ ]` focus castbar
- `[ ]` boss castbars
- `[ ]` recolor из settings

### Class resources
- `[ ]` Rogue/Druid combo points (ClassPower)
- `[ ]` Monk chi (ClassPower)
- `[ ]` Paladin holy power (ClassPower)
- `[ ]` Warlock soul shards (ClassPower)
- `[ ]` Mage arcane charges (ClassPower)
- `[ ]` DK runes (Runes element)
- `[ ]` Evoker essence (ClassPower)
- `[ ]` Max resource changes (talents)

### Settings & Persistence
- `[ ]` Settings UI открывается
- `[ ]` Settings сохраняются при /reload
- `[ ]` Settings загружаются при login
- `[ ]` Factory reset работает
- `[ ]` Export/Import работает
- `[ ]` Mover unlock/lock/reset

### Edit Mode
- `[ ]` Edit Mode open/close не ломает layout
- `[ ]` Roth frames не конфликтуют с Edit Mode системой
- `[ ]` Предупреждение при входе в Edit Mode

### Smoothing
- `[ ]` Health bars плавно анимируются на Retail
- `[ ]` Power bars плавно анимируются на Retail
- `[ ]` Нет конфликта oUF_Smooth + StatusBarInterpolation

### Event cleanup (НОВОЕ)
- `[ ]` Party header rebuild не оставляет stale listeners
- `[ ]` Raid header rebuild не оставляет stale listeners
- `[ ]` settings_main regen frame unregister'ит event после обработки

### Taint safety (НОВОЕ)
- `[ ]` CompactRaidFrameManager_UpdateShown() не taint'ит
- `[ ]` ParkFrame hidden parent checked for forbidden
- `[ ]` Mover restoration deferred in combat

---

## Reference Map

### _Info
- `_Info/KB/core/BlizzardUI_SubsystemRouter.md`
- `_Info/KB/nodes/BlizzardUI_ActionBars.md`
- `_Info/KB/nodes/BlizzardUI_UnitFrames.md`
- `_Info/KB/core/BlizzardUI_HookDecisionTree.md`
- `_Info/KB/core/BlizzardUI_security.md`

### Blizzard UI Code
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66384/Blizzard_ActionBar`
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66384/Blizzard_EditMode`
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66384/Blizzard_UnitFrame`
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66384/Blizzard_ZoneAbility`
- `C:\Tools\WoW_Dev_Tools\wow-ui-source/Blizzard_UI_12.0.1.66384/Blizzard_NamePlateUI`

### Reference Addons
- `_Reference/ReferenceAddonsFull/ElvUI/ElvUI/Game/Shared/Modules/ActionBars/ActionBars.lua`
- `_Reference/ReferenceAddonsFull/ElvUI/ElvUI/Game/Shared/Modules/UnitFrames/UnitFrames.lua`
- `_Reference/ReferenceAddonsFull/ElvUI/ElvUI/Game/Shared/Modules/UnitFrames/Elements/Health.lua`
- `_Reference/ReferenceAddonsFull/ElvUI/ElvUI/Game/Shared/Modules/UnitFrames/Elements/Power.lua`
- `_Reference/ReferenceAddonsFull/ElvUI/ElvUI/Game/Shared/Modules/UnitFrames/Elements/CastBar.lua`
- `_Reference/ReferenceAddonsFull/ElvUI/ElvUI/Game/Shared/Modules/UnitFrames/Elements/Auras.lua`
- `_Reference/ReferenceAddonsFull/ElvUI/ElvUI/Game/Shared/Modules/UnitFrames/Elements/ClassBars.lua`
- `_Reference/ReferenceAddonsFull/ElvUI/ElvUI/Game/Shared/Modules/UnitFrames/Units/Player.lua`
- `_Reference/ReferenceAddonsFull/ElvUI/ElvUI/Game/Shared/Modules/NamePlates/NamePlates.lua`
- `_Reference/ReferenceAddonsFull/ElvUI/ElvUI_Libraries/Game/Shared/LibActionButton-1.0/LibActionButton-1.0.lua`
- `_Reference/ReferenceAddonsFull/oUF/ouf.lua`
- `_Reference/ReferenceAddonsFull/oUF/elements/castbar.lua`
- `_Reference/ReferenceAddonsFull/oUF/elements/auras.lua`
- `_Reference/ReferenceAddonsFull/oUF/elements/health.lua`
- `_Reference/ReferenceAddonsFull/oUF/elements/power.lua`
- `_Reference/ReferenceAddonsFull/oUF/elements/range.lua`
- `_Reference/ReferenceAddonsFull/oUF/elements/classpower.lua`
- `_Reference/ReferenceAddonsFull/oUF/elements/runes.lua`
- `_Reference/ReferenceAddonsFull/oUF/elements/portrait.lua`
- `_Reference/ReferenceAddonsFull/oUF/elements/tags.lua`
- `_Reference/ReferenceAddonsFull/oUF/elements/healthprediction.lua`

### Internal
- `addon_map.md` — карта аддона и зависимостей v4
- `todo.archive.md` — архив предыдущих сессий (детали, НЕ статус)
