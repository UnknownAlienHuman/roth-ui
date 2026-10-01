local function fail(message)
  error(message, 2)
end

local function expect(condition, message)
  if not condition then fail(message) end
end

local inCombat = false
_G.InCombatLockdown = function() return inCombat end

local createdFrames = {}
_G.CreateFrame = function()
  local frame = { events = {}, scripts = {} }
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:UnregisterEvent(event) self.events[event] = nil end
  function frame:IsEventRegistered(event) return self.events[event] == true end
  function frame:SetScript(script, callback) self.scripts[script] = callback end
  createdFrames[#createdFrames + 1] = frame
  return frame
end

local settingsLoadCallback
_G.EventUtil = {
  ContinueOnAddOnLoaded = function(addonName, callback)
    expect(addonName == "Blizzard_Settings", "settings lifecycle watched the wrong addon")
    settingsLoadCallback = callback
  end,
}

local categoryCount = 0
local registeredCategories = 0
local openCount = 0
local function InstallSettingsMock()
  _G.Settings = {
    VarType = { Boolean = 1, Number = 2, String = 3 },
    RegisterVerticalLayoutCategory = function(name)
      categoryCount = categoryCount + 1
      local category = { id = categoryCount, name = name }
      function category:GetID() return self.id end
      function category:SetShouldSortAlphabetically(value) self.sort = value end
      return category
    end,
    RegisterVerticalLayoutSubcategory = function(parent, name)
      expect(type(parent) == "table", "subcategory parent was not registered")
      categoryCount = categoryCount + 1
      local category = { id = categoryCount, name = name, parent = parent }
      function category:GetID() return self.id end
      return category
    end,
    RegisterAddOnCategory = function(category)
      expect(type(category) == "table", "root category was not registered")
      registeredCategories = registeredCategories + 1
    end,
    OpenToCategory = function(categoryID)
      expect(type(categoryID) == "number", "category ID was not normalized")
      openCount = openCount + 1
    end,
  }
end

local loadCalls = 0
_G.C_AddOns = {
  LoadAddOn = function(addonName)
    expect(addonName == "Blizzard_Settings", "unexpected addon load")
    loadCalls = loadCalls + 1
    InstallSettingsMock()
    -- Simulate ADDON_LOADED firing before LoadAddOn returns. Register() must
    -- reject the reentrant callback and let the outer registration finish once.
    if settingsLoadCallback then settingsLoadCallback() end
    return true
  end,
  IsAddOnLoaded = function() return false end,
}

local values = {}
local ns = {
  safety = {
    TryCall = function(fn, ...)
      local ok, value = pcall(fn, ...)
      return ok, value
    end,
  },
  store = {
    GetConfigValue = function(path, fallback)
      local key = table.concat(path, ".")
      local value = values[key]
      return value == nil and fallback or value
    end,
    SetConfigValue = function(path, value)
      values[table.concat(path, ".")] = value
      return true
    end,
  },
  cfgDefaults = {},
}
_G.Roth_UI = ns

assert(loadfile("core/settings_main.lua"))("Roth_UI")
local ui = assert(ns.SettingsUI)
expect(type(settingsLoadCallback) == "function", "Blizzard Settings load callback was not registered")
expect(loadCalls == 0, "Blizzard_Settings was forced to load at Roth login")
expect(ui.registered == false, "settings registered before Blizzard_Settings loaded")
expect(#createdFrames == 0, "eager settings lifecycle created a frame")

local builderCalls = 0
expect(ui:RegisterBuilder("test", function()
  builderCalls = builderCalls + 1
end) == true, "test builder registration failed")

expect(ui:Open("root") == true, "explicit settings open failed")
expect(loadCalls == 1, "explicit open did not load Blizzard_Settings exactly once")
expect(ui.registered == true and ui.registering == false, "settings registration state is inconsistent")
expect(categoryCount == 8, "settings categories were duplicated or omitted")
expect(registeredCategories == 1, "addon category was registered more than once")
expect(builderCalls == 1, "settings builder did not run exactly once")
expect(openCount == 2, "existing double OpenToCategory compatibility call changed")

settingsLoadCallback()
expect(categoryCount == 8 and registeredCategories == 1 and builderCalls == 1,
  "late callback duplicated registered settings")

local deferredCalls = 0
inCombat = true
expect(ui:RunOutOfCombat("test", function() deferredCalls = deferredCalls + 1 end) == false,
  "combat callback was not deferred")
expect(#createdFrames == 1, "regen queue created an unexpected number of frames")
local regenFrame = createdFrames[1]
expect(regenFrame.events.PLAYER_REGEN_ENABLED == true, "regen event was not registered")

inCombat = false
regenFrame.scripts.OnEvent(regenFrame, "PLAYER_REGEN_ENABLED")
expect(deferredCalls == 1, "deferred callback did not run")
expect(regenFrame.events.PLAYER_REGEN_ENABLED == nil, "regen event remained permanently registered")

inCombat = true
ui:RunOutOfCombat("test2", function() deferredCalls = deferredCalls + 1 end)
expect(regenFrame.events.PLAYER_REGEN_ENABLED == true, "regen event did not re-register for new work")
inCombat = false
regenFrame.scripts.OnEvent(regenFrame, "PLAYER_REGEN_ENABLED")
expect(deferredCalls == 2, "second deferred callback did not run")
expect(regenFrame.events.PLAYER_REGEN_ENABLED == nil, "regen event remained registered after second drain")

print("settings lazy lifecycle test: OK")
