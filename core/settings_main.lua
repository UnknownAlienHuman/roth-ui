local addonName = ...
local ns = assert(_G.Roth_UI, "Roth_UI_Options: main Roth_UI namespace is required")

ns.SettingsUI = ns.SettingsUI or {}
local ui = ns.SettingsUI

local type = type
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local tonumber = tonumber
local string_format = string.format
local string_upper = string.upper
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown

local safety = ns and ns.safety
local TryCall = safety and safety.TryCall
local storeApi = assert(ns and ns.store, "Roth_UI: ns.store is required by settings_main.lua")
local GetConfigValue = assert(storeApi.GetConfigValue, "Roth_UI: store GetConfigValue is required by settings_main.lua")
local SetConfigValue = assert(storeApi.SetConfigValue, "Roth_UI: store SetConfigValue is required by settings_main.lua")
assert(type(TryCall) == "function", "Roth_UI: safety.TryCall is required by settings_main.lua")

ui.builders = ui.builders or {}
ui.builderOrder = ui.builderOrder or {}
ui.categories = ui.categories or {}
ui.categorySpecs = ui.categorySpecs or {}
ui.settings = ui.settings or {}
ui.registered = ui.registered or false

local CATEGORY_SPECS = {
  { key = "root",       name = "Roth UI" },
  { key = "bars",       name = "Action Bars", parentKey = "root" },
  { key = "target",     name = "Target",     parentKey = "root" },
  { key = "orb_health", name = "Health Orb", parentKey = "root" },
  { key = "orb_power",  name = "Power Orb",  parentKey = "root" },
  { key = "party",      name = "Party",      parentKey = "root" },
  { key = "raid",       name = "Raid",       parentKey = "root" },
  { key = "data_bars",  name = "Data Bars",  parentKey = "root" },
}

local function ReadPath(root, path)
  if type(root) ~= "table" or type(path) ~= "table" then
    return nil
  end

  local node = root
  for i = 1, #path do
    if type(node) ~= "table" then
      return nil
    end
    node = node[path[i]]
  end
  return node
end

local function PathToString(path)
  if type(path) ~= "table" then
    return nil
  end
  return table.concat(path, ".")
end

local function GuessVarType(defaultValue)
  local valueType = type(defaultValue)
  if valueType == "boolean" then
    return Settings.VarType.Boolean
  elseif valueType == "number" then
    return Settings.VarType.Number
  end
  return Settings.VarType.String
end

local function NormalizeBooleanValue(value, fallback)
  if type(value) == "boolean" then
    return value
  end
  if type(value) == "number" then
    return value ~= 0
  end
  if type(value) == "string" then
    local normalizer = ns and ns.IsRothEnabled
    if type(normalizer) == "function" then
      return normalizer(value)
    end
    local lowered = value:lower()
    if lowered == "false" or lowered == "0" or lowered == "off" or lowered == "no" or lowered == "blizzard" then
      return false
    end
    if lowered == "true" or lowered == "1" or lowered == "on" or lowered == "yes" or lowered == "roth" then
      return true
    end
  end
  return fallback == true
end

local function NormalizeNumberValue(value, fallback)
  local numeric = tonumber(value)
  if type(numeric) == "number" then
    return numeric
  end
  return tonumber(fallback) or 0
end

local function NormalizeCategoryKey(categoryOrKey)
  if type(categoryOrKey) == "string" then
    return categoryOrKey
  end
  for key, category in pairs(ui.categories) do
    if category == categoryOrKey then
      return key
    end
  end
  return nil
end

local function EnsureRegenQueue()
  if ui.regenFrame then
    return
  end

  ui.pendingCombatCallbacks = ui.pendingCombatCallbacks or {}
  ui.regenFrame = CreateFrame("Frame")
  ui.regenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
  ui.regenFrame:SetScript("OnEvent", function()
    local pending = ui.pendingCombatCallbacks
    ui.pendingCombatCallbacks = {}
    for _, callback in pairs(pending) do
      TryCall(callback)
    end
  end)
end

function ui:RegisterBuilder(name, builder)
  if type(name) ~= "string" or name == "" or type(builder) ~= "function" then
    return false
  end

  if not self.builders[name] then
    self.builderOrder[#self.builderOrder + 1] = name
  end
  self.builders[name] = builder
  return true
end

function ui:EnsureSettingsLoaded()
  if _G.Settings then
    return true
  end

  C_AddOns.LoadAddOn("Blizzard_Settings")

  return _G.Settings ~= nil
end

function ui:GetConfigDefault(path, fallback)
  local defaults = ns and ns.cfgDefaults
  local value = ReadPath(defaults, path)
  if value ~= nil then
    return value
  end
  return fallback
end

function ui:GetConfigValue(path, fallback)
  local defaultValue = self:GetConfigDefault(path, fallback)
  return GetConfigValue(path, defaultValue)
end

function ui:SetConfigValue(path, value, opts)
  opts = (type(opts) == "table") and opts or {}
  local previousValue = GetConfigValue(path, nil)
  local ok = SetConfigValue(path, value, {
    markPendingReload = opts.reloadRequired == true,
  })

  if ok ~= true then
    local label = PathToString(path) or "setting"
    print(("Roth_UI: failed to save '%s'. Change was not applied."):format(label))
    return false
  end

  if opts.reloadRequired == true and previousValue ~= value then
    local label = PathToString(path) or "setting"
    print(("Roth_UI: '%s' saved. /reload required."):format(label))
  end

  if type(opts.apply) == "function" then
    opts.apply(value)
  end

  return true
end

function ui:RunOutOfCombat(key, callback)
  if type(callback) ~= "function" then
    return false
  end

  if not (InCombatLockdown and InCombatLockdown()) then
    TryCall(callback)
    return true
  end

  EnsureRegenQueue()
  self.pendingCombatCallbacks[key or tostring(callback)] = callback
  return false
end

function ui:CreateDropdownOptions(itemsSource)
  local items = itemsSource
  if type(itemsSource) == "function" then
    items = itemsSource()
  end

  if type(items) ~= "table" then
    return {}
  end

  local container = Settings.CreateControlTextContainer()
  local normalized = {}
  for i = 1, #items do
    local item = items[i]
    if type(item) == "table" then
      local label = item.label or item.text or item.key or tostring(item.value)
      local entry = container:Add(item.value, label, item.tooltip)
      entry.disabled = item.disabled
      entry.warning = item.warning
      entry.recommend = item.recommend
      normalized[#normalized + 1] = entry
    end
  end

  return normalized
end

function ui:ColorToHex(color, fallback)
  color = (type(color) == "table") and color or fallback or { r = 1, g = 1, b = 1 }

  local r = tonumber(color.r or color[1]) or tonumber(fallback and (fallback.r or fallback[1])) or 1
  local g = tonumber(color.g or color[2]) or tonumber(fallback and (fallback.g or fallback[2])) or 1
  local b = tonumber(color.b or color[3]) or tonumber(fallback and (fallback.b or fallback[3])) or 1

  if _G.CreateColor then
    return _G.CreateColor(r, g, b):GenerateHexColor()
  end

  r = math.floor((r * 255) + 0.5)
  g = math.floor((g * 255) + 0.5)
  b = math.floor((b * 255) + 0.5)
  return string_format("ff%02x%02x%02x", r, g, b)
end

function ui:HexToColor(hexColor, fallback)
  if type(hexColor) == "string" and hexColor ~= "" and _G.CreateColorFromHexString then
    local color = _G.CreateColorFromHexString(hexColor)
    if color then
      local r, g, b = color:GetRGB()
      return {
        r = r,
        g = g,
        b = b,
        a = tonumber(fallback and fallback.a) or 1,
      }
    end
  end

  return {
    r = tonumber(fallback and (fallback.r or fallback[1])) or 1,
    g = tonumber(fallback and (fallback.g or fallback[2])) or 1,
    b = tonumber(fallback and (fallback.b or fallback[3])) or 1,
    a = tonumber(fallback and fallback.a) or 1,
  }
end

function ui:RegisterSettingMetadata(spec, setting)
  local categoryKey = NormalizeCategoryKey(spec.category)
  self.settings[spec.variable] = {
    variable = spec.variable,
    categoryKey = categoryKey,
    label = spec.label,
    tooltip = spec.tooltip,
    varType = spec.varType,
    path = PathToString(spec.path),
    reloadRequired = spec.reloadRequired == true,
    setting = setting,
  }
end

function ui:AddProxySetting(spec)
  local category = self.categories[spec.category]
  assert(category, "Roth_UI: unknown settings category key: " .. tostring(spec.category))
  assert(type(spec.variable) == "string" and spec.variable ~= "", "Roth_UI: settings variable is required")

  local defaultValue = spec.defaultValue
  if defaultValue == nil then
    defaultValue = self:GetConfigDefault(spec.path)
  end
  local varType = spec.varType or GuessVarType(defaultValue)

  local rawGetValue = spec.get or function()
    return self:GetConfigValue(spec.path, defaultValue)
  end

  local getValue = function()
    local value = rawGetValue()
    if varType == Settings.VarType.Boolean then
      return NormalizeBooleanValue(value, defaultValue)
    elseif varType == Settings.VarType.Number then
      return NormalizeNumberValue(value, defaultValue)
    end
    if value == nil then
      return defaultValue
    end
    return value
  end

  local setValue = spec.set or function(value)
    if varType == Settings.VarType.Boolean then
      value = NormalizeBooleanValue(value, defaultValue)
    elseif varType == Settings.VarType.Number then
      value = NormalizeNumberValue(value, defaultValue)
    end
    self:SetConfigValue(spec.path, value, {
      reloadRequired = spec.reloadRequired == true,
      apply = spec.apply,
    })
  end

  local setting = Settings.RegisterProxySetting(
    category,
    spec.variable,
    varType,
    spec.label,
    defaultValue,
    getValue,
    setValue
  )

  self:RegisterSettingMetadata({
    variable = spec.variable,
    category = spec.category,
    label = spec.label,
    tooltip = spec.tooltip,
    varType = varType,
    path = spec.path,
    reloadRequired = spec.reloadRequired,
  }, setting)

  return setting, category
end

function ui:AddCheckbox(spec)
  local setting, category = self:AddProxySetting(spec)
  Settings.CreateCheckbox(category, setting, spec.tooltip)
  return setting
end

function ui:AddSlider(spec)
  local setting, category = self:AddProxySetting(spec)
  local options = Settings.CreateSliderOptions(spec.minValue or 0, spec.maxValue or 1, spec.step or 0.1)
  if spec.labelFormatter and options and options.SetLabelFormatter and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, spec.labelFormatter)
  end
  Settings.CreateSlider(category, setting, options, spec.tooltip)
  return setting
end

function ui:AddDropdown(spec)
  local setting, category = self:AddProxySetting(spec)
  Settings.CreateDropdown(category, setting, function()
    return self:CreateDropdownOptions(spec.options)
  end, spec.tooltip)
  return setting
end

function ui:AddColorSwatch(spec)
  local setting, category = self:AddProxySetting(spec)
  Settings.CreateColorSwatch(category, setting, spec.tooltip)
  return setting
end

function ui:AddButton(spec)
  local category = self.categories[spec.category]
  assert(category, "Roth_UI: unknown settings category key for button: " .. tostring(spec.category))
  assert(type(spec.buttonText) == "string" and spec.buttonText ~= "", "Roth_UI: buttonText is required")
  assert(type(spec.onClick) == "function", "Roth_UI: button onClick is required")

  local initializer
  if type(CreateSettingsButtonInitializer) == "function" then
    initializer = CreateSettingsButtonInitializer(
      spec.label or "",
      spec.buttonText,
      spec.onClick,
      spec.tooltip,
      spec.addSearchTags ~= false
    )
  else
    local data = {
      name = spec.label or "",
      buttonText = spec.buttonText,
      buttonClick = spec.onClick,
      tooltip = spec.tooltip,
    }
    initializer = Settings.CreateElementInitializer("SettingButtonControlTemplate", data)
  end

  Settings.RegisterInitializer(category, initializer)
  return initializer
end

function ui:GetDebugSnapshot()
  local snapshot = {
    registered = self.registered == true,
    categories = {},
    settings = {},
  }

  for _, spec in ipairs(CATEGORY_SPECS) do
    local category = self.categories[spec.key]
    snapshot.categories[#snapshot.categories + 1] = {
      key = spec.key,
      name = spec.name,
      parentKey = spec.parentKey,
      id = category and category.GetID and category:GetID() or nil,
    }
  end

  local variables = {}
  for variable in pairs(self.settings) do
    variables[#variables + 1] = variable
  end
  table.sort(variables)

  for i = 1, #variables do
    local meta = self.settings[variables[i]]
    snapshot.settings[#snapshot.settings + 1] = {
      variable = meta.variable,
      categoryKey = meta.categoryKey,
      label = meta.label,
      path = meta.path,
      varType = meta.varType,
      reloadRequired = meta.reloadRequired,
    }
  end

  return snapshot
end

function ui:Open(categoryKey, scrollToElementName)
  self:Register()

  local category = self.categories[categoryKey]
  if not category or not Settings or not Settings.OpenToCategory then
    return false
  end

  local categoryID = category.GetID and category:GetID() or category
  local okA = TryCall(Settings.OpenToCategory, categoryID, scrollToElementName)
  local okB = TryCall(Settings.OpenToCategory, categoryID, scrollToElementName)
  return (okA == true) or (okB == true)
end

function ui:Register()
  if self.registered then
    return true
  end

  if not self:EnsureSettingsLoaded() then
    return false
  end

  for i = 1, #CATEGORY_SPECS do
    local spec = CATEGORY_SPECS[i]
    local category
    if spec.parentKey then
      category = Settings.RegisterVerticalLayoutSubcategory(self.categories[spec.parentKey], spec.name)
    else
      category = Settings.RegisterVerticalLayoutCategory(spec.name)
      if category and category.SetShouldSortAlphabetically then
        category:SetShouldSortAlphabetically(false)
      end
    end

    self.categories[spec.key] = category
    self.categorySpecs[spec.key] = spec
  end

  for i = 1, #self.builderOrder do
    local builderName = self.builderOrder[i]
    local builder = self.builders[builderName]
    if type(builder) == "function" then
      builder(self)
    end
  end

  Settings.RegisterAddOnCategory(self.categories.root)
  self.registered = true
  return true
end

local function ContinueOnOwnAddonLoaded(callback)
  if EventUtil and type(EventUtil.ContinueOnAddOnLoaded) == "function" then
    EventUtil.ContinueOnAddOnLoaded(addonName, callback)
    return
  end

  local frame = CreateFrame("Frame")
  frame:RegisterEvent("ADDON_LOADED")
  frame:SetScript("OnEvent", function(self, _, loadedAddon)
    if loadedAddon ~= addonName then
      return
    end
    self:UnregisterEvent("ADDON_LOADED")
    callback()
  end)
end

ContinueOnOwnAddonLoaded(function()
  ui:Register()
end)
