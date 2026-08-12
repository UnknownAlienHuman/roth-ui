local addonName, ns = ...

local runtime = ns.secureActionBarRuntime or {}
ns.secureActionBarRuntime = runtime

local root = _G.Roth_UI or ns
if type(root) == "table" then
  root.secureActionBarRuntime = runtime
end

local LAB = LibStub("LibActionButton-1.0-GE", true)
if not LAB then
  return
end

local barRegistry = assert(ns and ns.BarRuntimeRegistry, "Roth_UI.secure_action_bar_runtime: ns.BarRuntimeRegistry is required")
local RegisterManagedMultiBarFrame = assert(ns.RegisterManagedMultiBarFrame, "Roth_UI.secure_action_bar_runtime: RegisterManagedMultiBarFrame is required")
local NotifyBarRuntimeChanged = assert(barRegistry.NotifyChanged, "Roth_UI.secure_action_bar_runtime: bar runtime NotifyChanged is required")

local GetBindingKey = GetBindingKey
local SetOverrideBindingClick = SetOverrideBindingClick
local ClearOverrideBindings = ClearOverrideBindings
local RegisterStateDriver = RegisterStateDriver
local UnregisterStateDriver = UnregisterStateDriver
local InCombatLockdown = InCombatLockdown
local CreateFrame = CreateFrame
local UIParent = UIParent
local ipairs = ipairs
local pairs = pairs
local select = select

runtime.bars = runtime.bars or {}
runtime.buttons = runtime.buttons or setmetatable({}, { __mode = "k" })
runtime.pendingBindingRefresh = runtime.pendingBindingRefresh or false
runtime.bindingHelper = runtime.bindingHelper or nil

local AUX_BAR_DEFS = {
  bar2 = {
    page = 6,
    bindingPrefix = "MULTIACTIONBAR1BUTTON",
    frameName = "Roth_UISecureBar2",
    role = "aux",
    proxyKeys = { "PROXY_SHOW_ACTIONBAR_2" },
  },
  bar3 = {
    page = 5,
    bindingPrefix = "MULTIACTIONBAR2BUTTON",
    frameName = "Roth_UISecureBar3",
    role = "aux",
    proxyKeys = { "PROXY_SHOW_ACTIONBAR_3" },
  },
  bar4 = {
    page = 3,
    bindingPrefix = "MULTIACTIONBAR3BUTTON",
    frameName = "Roth_UISecureBar4",
    role = "aux",
    proxyKeys = { "PROXY_SHOW_ACTIONBAR_4" },
  },
  bar5 = {
    page = 4,
    bindingPrefix = "MULTIACTIONBAR4BUTTON",
    frameName = "Roth_UISecureBar5",
    role = "aux",
    proxyKeys = { "PROXY_SHOW_ACTIONBAR_5" },
  },
}

local MAIN_BAR_PAGES = 18
local MAIN_BAR_PAGE_DRIVER = "[overridebar][vehicleui][possessbar] possess; [shapeshift] 11; [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; [bonusbar:5] 11; 1"
local AUX_BAR_VISIBILITY_DRIVER = "[petbattle][overridebar][vehicleui][possessbar,@vehicle,exists] hide; show"
local MAIN_BAR_VISIBILITY_DRIVER = "[petbattle] hide; show"

local function GetBarsConfig()
  return (root and root.cfg and root.cfg.bars) or (ns and ns.cfg and ns.cfg.bars) or {}
end

function runtime.IsEnabled()
  return GetBarsConfig().secureOwnerBars == true
end

local function ResolveSkinConfig()
  return root and root.actionButtonSkinConfig or nil
end

local function GetShowMacroName()
  local barsCfg = GetBarsConfig()
  local showMacroName = barsCfg.showMacroName
  if showMacroName == nil then
    showMacroName = barsCfg.showName
  end
  return showMacroName == true
end

local function ApplyTextAlpha(fontString, visible)
  if fontString and fontString.SetAlpha then
    fontString:SetAlpha(visible and 1 or 0)
  end
end

local function BuildButtonConfig(button)
  return {
    keyBoundTarget = button and button.keyBoundTarget or false,
    clickOnDown = type(GetCVarBool) == "function" and GetCVarBool("ActionButtonUseKeyDown") or false,
    outOfRangeColoring = "button",
    showGrid = false,
    hideElements = {
      macro = not GetShowMacroName(),
      hotkey = GetBarsConfig().showHotkey ~= true,
      equipped = true,
      border = false,
      borderIfEmpty = true,
    },
  }
end

local function ApplyButtonDisplayState(button)
  local barsCfg = GetBarsConfig()
  ApplyTextAlpha(button and button.Name, GetShowMacroName())
  ApplyTextAlpha(button and button.HotKey, barsCfg.showHotkey == true)
  ApplyTextAlpha(button and button.Count, barsCfg.showStackCount == true)
  if button and button.cooldown and button.cooldown.SetAlpha then
    button.cooldown:SetAlpha(barsCfg.showCooldown == false and 0 or 1)
  end
end

local function ApplyButtonConfig(button)
  if not button then
    return
  end
  if type(button.UpdateConfig) == "function" then
    button:UpdateConfig(BuildButtonConfig(button))
  end
  ApplyButtonDisplayState(button)
end

local function StyleButton(button)
  local skinConfig = ResolveSkinConfig()
  if not (button and skinConfig and _G.rButtonTemplate and _G.rButtonTemplate.StyleActionButton) then
    ApplyButtonConfig(button)
    return
  end
  _G.rButtonTemplate:StyleActionButton(button, skinConfig)
  ApplyButtonConfig(button)
  runtime.buttons[button] = true
end

function runtime.RestyleAll()
  for button in pairs(runtime.buttons) do
    StyleButton(button)
  end
end

local function ShouldCombineBar4AndBar5(cfg)
  return type(cfg) == "table" and cfg.combineBar4AndBar5 == true
end

local function GetProxyKeys(key, cfg)
  if key == "bar4" and ShouldCombineBar4AndBar5(cfg) then
    return { "PROXY_SHOW_ACTIONBAR_4" }
  end

  local def = AUX_BAR_DEFS[key]
  return def and def.proxyKeys or nil
end

local function ApplyBindings(key, bar)
  if InCombatLockdown and InCombatLockdown() then
    runtime.pendingBindingRefresh = true
    if runtime.bindingHelper then
      runtime.bindingHelper:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
    return false
  end
  if not (bar and bar.buttons and ClearOverrideBindings and SetOverrideBindingClick and GetBindingKey) then
    return false
  end

  runtime.pendingBindingRefresh = false
  if runtime.bindingHelper then
    runtime.bindingHelper:UnregisterEvent("PLAYER_REGEN_ENABLED")
  end
  ClearOverrideBindings(bar)
  for index = 1, #bar.buttons do
    local button = bar.buttons[index]
    local bindingAction = button and button.keyBoundTarget
    if type(bindingAction) == "string" and bindingAction ~= "" then
      local buttonName = button:GetName()
      for keyNumber = 1, select("#", GetBindingKey(bindingAction)) do
        local keyBinding = select(keyNumber, GetBindingKey(bindingAction))
        if keyBinding and keyBinding ~= "" then
          SetOverrideBindingClick(bar, false, keyBinding, buttonName)
        end
      end
    end
  end
  if type(key) == "string" and key ~= "" then
    NotifyBarRuntimeChanged(key, "bindings")
  end
  return true
end

local function UpdateVisibilityDriver(frame, driver)
  if InCombatLockdown and InCombatLockdown() then
    return false
  end
  if not (frame and RegisterStateDriver and UnregisterStateDriver) then
    return false
  end

  if type(driver) ~= "string" or driver == "" then
    driver = AUX_BAR_VISIBILITY_DRIVER
  end
  UnregisterStateDriver(frame, "visibility")
  RegisterStateDriver(frame, "visibility", driver)
  return true
end

local function UpdatePageDriver(frame)
  if InCombatLockdown and InCombatLockdown() then
    return false
  end
  if not (frame and RegisterStateDriver and UnregisterStateDriver) then
    return false
  end

  UnregisterStateDriver(frame, "page")
  frame:SetAttribute("_onstate-page", [[
    if newstate == "possess" or newstate == "11" then
      if HasVehicleActionBar() then
        newstate = GetVehicleBarIndex()
      elseif HasOverrideActionBar() then
        newstate = GetOverrideBarIndex()
      elseif HasTempShapeshiftActionBar() then
        newstate = GetTempShapeshiftBarIndex()
      elseif HasBonusActionBar() and GetActionBarPage() == 1 then
        newstate = GetBonusBarIndex()
      else
        newstate = 12
      end
    end

    self:SetAttribute("state", newstate)
    control:ChildUpdate("state", newstate)
  ]])
  RegisterStateDriver(frame, "page", MAIN_BAR_PAGE_DRIVER)
  frame:SetAttribute("page", MAIN_BAR_PAGE_DRIVER)
  return true
end

local function BuildDimensions(key, cfg)
  local size = cfg.buttons.size
  local margin = cfg.buttons.margin
  local padding = cfg.padding

  if key == "bar1" then
    return 12 * size + 11 * margin + 2 * padding, size + 2 * padding
  end

  if key == "bar2" or key == "bar3" then
    if cfg.uselayout2x6 then
      return 6 * size + 5 * margin + 2 * padding, 2 * size + margin + 2 * padding
    end
    return 12 * size + 11 * margin + 2 * padding, size + 2 * padding
  end

  if key == "bar4" and ShouldCombineBar4AndBar5(cfg) then
    if cfg.vert == true then
      return 12 * size + 11 * margin + 2 * padding, 2 * size + margin + 2 * padding
    end
    return 2 * size + margin + 2 * padding, 12 * size + 11 * margin + 2 * padding
  end

  if cfg.vert == true then
    return 12 * size + 11 * margin + 2 * padding, size + 2 * padding
  end
  return size + 2 * padding, 12 * size + 11 * margin + 2 * padding
end

local function CreateBarFrame(name, key, cfg)
  local width, height = BuildDimensions(key, cfg)
  local frame = CreateFrame("Frame", name, UIParent)
  frame:SetSize(width, height)
  frame:SetPoint(cfg.pos.a1, cfg.pos.af, cfg.pos.a2, cfg.pos.x, cfg.pos.y)
  frame:SetScale(cfg.scale or 1)
  frame.buttons = {}

  local holder = CreateFrame("Frame", nil, frame, "SecureHandlerStateTemplate")
  holder:SetAllPoints(frame)
  holder:SetAttribute("_onstate-vis", [[
    if not newstate then return end
    if newstate == "show" then
      self:Show()
    else
      self:Hide()
    end
  ]])
  frame.holder = holder
  return frame
end

local function CreateMainBarFrame(cfg)
  local frame = CreateBarFrame("Roth_UISecureBar1", "bar1", cfg)
  frame.ignoreFramePositionManager = true
  return frame
end

local function CreateActionButton(bar, page, bindingPrefix, slotIndex, buttonIndex, cfg)
  local buttonName = bar:GetName() .. "Button" .. buttonIndex
  local button = LAB:CreateButton(buttonIndex, buttonName, bar.holder or bar, {})
  button:SetState(0, "action", (page - 1) * 12 + slotIndex)
  button:SetAttribute("LABdisableDragNDrop", true)
  button.keyBoundTarget = bindingPrefix .. slotIndex
  button:SetSize(cfg.buttons.size, cfg.buttons.size)
  button:Show()
  button:UpdateAction()
  StyleButton(button)
  return button
end

local function CreateMainActionButton(bar, slotIndex, cfg)
  local buttonName = bar:GetName() .. "Button" .. slotIndex
  local button = LAB:CreateButton(slotIndex, buttonName, bar.holder or bar, {})
  button:SetState(0, "action", slotIndex)
  for page = 1, MAIN_BAR_PAGES do
    button:SetState(page, "action", (page - 1) * 12 + slotIndex)
  end
  button:SetAttribute("LABdisableDragNDrop", true)
  button.keyBoundTarget = "ACTIONBUTTON" .. slotIndex
  button:SetSize(cfg.buttons.size, cfg.buttons.size)
  button:Show()
  button:UpdateAction()
  StyleButton(button)
  return button
end

local function BuildButtonSpecs(key, cfg)
  local def = AUX_BAR_DEFS[key]
  if not def then
    return {}
  end

  local specs = {}
  for slotIndex = 1, 12 do
    specs[#specs + 1] = {
      page = def.page,
      bindingPrefix = def.bindingPrefix,
      slotIndex = slotIndex,
    }
  end

  if key == "bar4" and ShouldCombineBar4AndBar5(cfg) then
    local secondaryDef = AUX_BAR_DEFS.bar5
    for slotIndex = 1, 12 do
      specs[#specs + 1] = {
        page = secondaryDef.page,
        bindingPrefix = secondaryDef.bindingPrefix,
        slotIndex = slotIndex,
      }
    end
  end

  return specs
end

local function LayoutButtons(bar, key, cfg)
  local size = cfg.buttons.size
  local margin = cfg.buttons.margin
  local padding = cfg.padding

  for index = 1, #bar.buttons do
    local button = bar.buttons[index]
    button:ClearAllPoints()

    if key == "bar1" then
      button:SetPoint("BOTTOMLEFT", bar.holder or bar, "BOTTOMLEFT", padding + (index - 1) * (size + margin), padding)
    elseif key == "bar2" or key == "bar3" then
      if cfg.uselayout2x6 and index > 6 then
        local rowIndex = index - 6
        button:SetPoint("BOTTOMLEFT", bar.holder or bar, "BOTTOMLEFT", padding + (rowIndex - 1) * (size + margin), padding + size + margin)
      else
        button:SetPoint("BOTTOMLEFT", bar.holder or bar, "BOTTOMLEFT", padding + (index - 1) * (size + margin), padding)
      end
    elseif key == "bar4" and ShouldCombineBar4AndBar5(cfg) then
      local localIndex = ((index - 1) % 12) + 1
      local isSecondaryBar = index > 12
      if cfg.vert == true then
        local y = padding + (isSecondaryBar and 0 or size + margin)
        button:SetPoint("BOTTOMLEFT", bar.holder or bar, "BOTTOMLEFT", padding + (localIndex - 1) * (size + margin), y)
      else
        local x = -(padding + (isSecondaryBar and (size + margin) or 0))
        local y = -(padding + (localIndex - 1) * (size + margin))
        button:SetPoint("TOPRIGHT", bar.holder or bar, "TOPRIGHT", x, y)
      end
    elseif cfg.vert == true then
      button:SetPoint("LEFT", bar.holder or bar, "LEFT", padding + (index - 1) * (size + margin), 0)
    else
      button:SetPoint("TOPRIGHT", bar.holder or bar, "TOPRIGHT", -padding, -(padding + (index - 1) * (size + margin)))
    end
  end
end

local function RefreshBindings()
  if not runtime.IsEnabled() then
    return false
  end
  if InCombatLockdown and InCombatLockdown() then
    runtime.pendingBindingRefresh = true
    if runtime.bindingHelper then
      runtime.bindingHelper:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
    return false
  end

  runtime.pendingBindingRefresh = false
  if runtime.bindingHelper then
    runtime.bindingHelper:UnregisterEvent("PLAYER_REGEN_ENABLED")
  end
  for key, bar in pairs(runtime.bars) do
    ApplyBindings(key, bar)
  end
  return true
end

local function EnsureBindingHelper()
  if runtime.bindingHelper then
    return runtime.bindingHelper
  end

  local helper = CreateFrame("Frame")
  helper:RegisterEvent("PLAYER_LOGIN")
  helper:RegisterEvent("UPDATE_BINDINGS")
  helper:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" and not runtime.pendingBindingRefresh then
      helper:UnregisterEvent("PLAYER_REGEN_ENABLED")
      return
    end
    RefreshBindings()
  end)
  runtime.bindingHelper = helper
  return helper
end

function runtime.SpawnAuxBar(key)
  if not runtime.IsEnabled() then
    return nil
  end

  local barsCfg = GetBarsConfig()
  local cfg = barsCfg and barsCfg[key]
  if type(cfg) ~= "table" or not cfg.enable then
    return nil
  end

  if key == "bar5" then
    local bar4Cfg = barsCfg and barsCfg.bar4
    if ShouldCombineBar4AndBar5(bar4Cfg) then
      return runtime.bars.bar4
    end
  end

  if runtime.bars[key] then
    return runtime.bars[key]
  end

  local def = AUX_BAR_DEFS[key]
  if not def then
    return nil
  end

  EnsureBindingHelper()

  local bar = CreateBarFrame(def.frameName, key, cfg)
  local buttonSpecs = BuildButtonSpecs(key, cfg)
  for index, spec in ipairs(buttonSpecs) do
    bar.buttons[index] = CreateActionButton(bar, spec.page, spec.bindingPrefix, spec.slotIndex, index, cfg)
  end

  barRegistry:RegisterFrame(key, bar, {
    role = def.role,
    proxyKeys = GetProxyKeys(key, cfg),
    visibilityFrame = bar.holder or bar,
  })
  LayoutButtons(bar, key, cfg)
  UpdateVisibilityDriver(bar.holder or bar, AUX_BAR_VISIBILITY_DRIVER)
  RegisterManagedMultiBarFrame(key)
  ApplyBindings(key, bar)

  bar.__buttonBarFaderButtons = bar.buttons
  bar.mouseover = cfg.mouseover

  if cfg.mouseover and cfg.mouseover.enable and type(_G.rButtonBarFader) == "function" then
    _G.rButtonBarFader(bar, bar.buttons, cfg.mouseover.fadeIn, cfg.mouseover.fadeOut)
  end
  if cfg.userplaced and cfg.userplaced.enable and ns.func and ns.func.applyDragFunctionality then
    ns.func.applyDragFunctionality(bar)
  end

  runtime.bars[key] = bar
  NotifyBarRuntimeChanged(key, "layout")
  return bar
end

function runtime.SpawnMainBar()
  if not runtime.IsEnabled() then
    return nil
  end

  local barsCfg = GetBarsConfig()
  local cfg = barsCfg and barsCfg.bar1
  if type(cfg) ~= "table" or not cfg.enable then
    return nil
  end

  if runtime.bars.bar1 then
    return runtime.bars.bar1
  end

  EnsureBindingHelper()

  local bar = CreateMainBarFrame(cfg)
  for slotIndex = 1, 12 do
    bar.buttons[slotIndex] = CreateMainActionButton(bar, slotIndex, cfg)
  end

  barRegistry:RegisterFrame("bar1", bar, {
    role = "main",
    visibilityFrame = bar.holder or bar,
    visibilityDriver = MAIN_BAR_VISIBILITY_DRIVER,
  })
  LayoutButtons(bar, "bar1", cfg)
  barRegistry:ApplyVisibilityDriver("bar1", bar.holder or bar)
  UpdatePageDriver(bar.holder or bar)
  ApplyBindings("bar1", bar)

  bar.__buttonBarFaderButtons = bar.buttons
  bar.mouseover = cfg.mouseover

  if cfg.mouseover and cfg.mouseover.enable and type(_G.rButtonBarFader) == "function" then
    _G.rButtonBarFader(bar, bar.buttons, cfg.mouseover.fadeIn, cfg.mouseover.fadeOut)
  end
  if cfg.userplaced and cfg.userplaced.enable and ns.func and ns.func.applyDragFunctionality then
    ns.func.applyDragFunctionality(bar)
  end

  runtime.bars.bar1 = bar
  NotifyBarRuntimeChanged("bar1", "layout")
  return bar
end
