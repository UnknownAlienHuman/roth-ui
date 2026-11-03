local function expect(ok, message)
  if not ok then error(message, 2) end
end

local function ReadPath(root, path)
  local value = root
  for index = 1, #path do
    if type(value) ~= "table" then return nil end
    value = value[path[index]]
  end
  return value
end

local saved = {
  HEALTH = {
    filling = { colorAuto = true, color = { r = 0.8, g = 0.2, b = 0.1, a = 1 } },
    model = { alpha = 0.85 },
    value = { top = { mode = "percent" }, bottom = { mode = "current" } },
  },
  POWER = { filling = {}, model = {}, value = { top = {}, bottom = {} } },
}
local defaults = {
  HEALTH = {
    filling = { colorAuto = false, color = { r = 0.2, g = 0.4, b = 0.6, a = 1 } },
    model = { alpha = 0.3 },
    value = { top = { mode = "current" }, bottom = { mode = "current" } },
  },
  POWER = { filling = {}, model = {}, value = { top = {}, bottom = {} } },
}
local selection = { HEALTH = "existing", POWER = "" }
local popup
local deleteResult = false
local saveResult = false
local deleteCalls, saveCalls, resetLibraryCalls, resetOrbCalls = 0, 0, 0, 0
local specs = {}
local builder

local ui = {
  RegisterBuilder = function(_, _, callback) builder = callback end,
  AddCheckbox = function(_, spec) specs[spec.variable] = spec end,
  AddDropdown = function(_, spec) specs[spec.variable] = spec end,
  AddSlider = function(_, spec) specs[spec.variable] = spec end,
  AddColorSwatch = function(_, spec) specs[spec.variable] = spec end,
  AddButton = function(_, spec) specs[spec.category .. ":" .. spec.buttonText] = spec end,
  ColorToHex = function(_, color)
    if type(color) ~= "table" then return "#FFFFFF" end
    return string.format("#%02X%02X%02X", color.r * 255, color.g * 255, color.b * 255)
  end,
  HexToColor = function(_, hex, current) return current end,
}

local ns = {
  SettingsUI = ui,
  OrbTextController = {
    GetDefaultMode = function(_, which) return which == "top" and "current" or "current" end,
    GetValueModeOptions = function() return {} end,
  },
  store = {
    GetOrbGlobalValue = function(path, fallback)
      if path[1] == "__selection" then return selection[path[2]] end
      return fallback
    end,
    SetOrbGlobalValue = function(path, value)
      if path[1] == "__selection" then selection[path[2]] = value end
      return true
    end,
    GetOrbConfigValue = function(orbType, path, fallback)
      local value = ReadPath(saved[orbType], path)
      if value == nil then return fallback end
      return value
    end,
    SetOrbConfigValue = function(orbType, path, value)
      local tableAtPath = saved[orbType]
      for index = 1, #path - 1 do
        local key = path[index]
        tableAtPath[key] = tableAtPath[key] or {}
        tableAtPath = tableAtPath[key]
      end
      tableAtPath[path[#path]] = value
      return true
    end,
    GetOrbDefaults = function(orbType) return defaults[orbType] end,
    ReadPath = function(root, path) return ReadPath(root, path) end,
  },
  db = {
    getListModel = function() return {} end,
    getListFillingTexture = function() return {} end,
  },
  orbPersistence = {
    GetTemplateList = function() return { { value = "existing" } } end,
    SaveTemplate = function(name, orbType)
      saveCalls = saveCalls + 1
      if saveResult then return true, "normalized" end
      return false
    end,
    DeleteTemplate = function()
      deleteCalls = deleteCalls + 1
      return deleteResult
    end,
    LoadTemplate = function() return true end,
    ResetOrbToDefaults = function() resetOrbCalls = resetOrbCalls + 1 end,
  },
  settingsActions = {
    ResetTemplateLibrary = function() resetLibraryCalls = resetLibraryCalls + 1 end,
  },
}
_G.Roth_UI = ns
_G.Settings = { VarType = { String = "string" } }
_G.YES, _G.CANCEL, _G.SAVE = "Yes", "Cancel", "Save"
_G.StaticPopup_Show = nil

assert(loadfile("core/settings_orbs.lua"))("Roth_UI")
expect(type(builder) == "function", "orb settings builder was not registered")
builder()

local autoColor = assert(specs.ROTH_UI_ORB_HEALTH_FILL_COLOR_AUTO, "boolean control missing")
local modelAlpha = assert(specs.ROTH_UI_ORB_HEALTH_MODEL_ALPHA, "numeric control missing")
local fillColor = assert(specs.ROTH_UI_ORB_HEALTH_FILL_COLOR, "color control missing")
local topMode = assert(specs.ROTH_UI_ORB_HEALTH_TOP_MODE, "text mode control missing")
expect(autoColor.defaultValue == false and autoColor.get() == true,
  "boolean default must come from defaults while get returns the saved false/true distinction")
expect(modelAlpha.defaultValue == 0.3 and modelAlpha.get() == 0.85,
  "numeric default must come from defaults while get returns the saved value")
local defaultFillColorHex = ui:ColorToHex(ReadPath(defaults.HEALTH, { "filling", "color" }))
local savedFillColorHex = ui:ColorToHex(ReadPath(saved.HEALTH, { "filling", "color" }))
expect(fillColor.defaultValue == defaultFillColorHex and fillColor.get() == savedFillColorHex,
  "color default must come from defaults while get returns the saved color")
expect(topMode.defaultValue == "current" and topMode.get() == "percent",
  "text mode default must come from defaults while get returns the saved mode")

specs["orb_health:Delete Selected"].onClick()
specs["orb_health:Reset Template Library"].onClick()
specs["orb_health:Reset Orb To Defaults"].onClick()
expect(deleteCalls == 0 and resetLibraryCalls == 0 and resetOrbCalls == 0,
  "destructive template actions ran when confirmation UI was unavailable")
expect(selection.HEALTH == "existing", "missing confirmation UI changed the selected template")

_G.StaticPopup_Show = function(kind, _, _, data)
  popup = { kind = kind, data = data }
  if kind == "GENERIC_INPUT_BOX" then
    local editBox = { SetText = function(self, value) self.value = value end, HighlightText = function() end }
    return { GetEditBox = function() return editBox end }
  end
end

specs["orb_health:Delete Selected"].onClick()
expect(popup and popup.kind == "GENERIC_CONFIRMATION", "delete did not use a confirmation dialog")
popup.data.callback()
expect(deleteCalls == 1 and selection.HEALTH == "existing",
  "failed delete cleared the selected template")
deleteResult = true
specs["orb_health:Delete Selected"].onClick()
popup.data.callback()
expect(deleteCalls == 2 and selection.HEALTH == "",
  "successful delete did not clear the selected template")

selection.HEALTH = "existing"
specs["orb_health:Save Current As..."].onClick()
expect(popup and popup.kind == "GENERIC_INPUT_BOX", "save did not open its input dialog")
popup.data.callback("  candidate  ")
expect(saveCalls == 1 and selection.HEALTH == "existing",
  "failed template save changed the selected template")
saveResult = true
specs["orb_health:Save Current As..."].onClick()
popup.data.callback("  candidate  ")
expect(saveCalls == 2 and selection.HEALTH == "normalized",
  "successful template save did not select the owner-returned normalized name")

print("orb settings defaults and confirmation behavior test: OK")
