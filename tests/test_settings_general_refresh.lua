local function expect(condition, message)
  if not condition then error(message, 2) end
end

_G.InCombatLockdown = function() return false end

local builders = {}
local specs = {}
local nextFrame = {}
local refreshes = { health = 0, healthOrb = 0, powerOrb = 0, fontPolicy = 0 }

local ui = {
  RegisterBuilder = function(_, key, builder) builders[key] = builder end,
  GetConfigDefault = function(_, _, fallback) return fallback end,
  AddCheckbox = function(_, spec) specs[spec.variable] = spec end,
  AddDropdown = function(_, spec) specs[spec.variable] = spec end,
  AddSlider = function(_, spec) specs[spec.variable] = spec end,
  AddColorSwatch = function(_, spec) specs[spec.variable] = spec end,
  AddButton = function() end,
  RunOutOfCombat = function(_, _, callback) callback() return true end,
  SetConfigValue = function(_, _, value, opts)
    if opts and opts.apply then opts.apply(value) end
    return true
  end,
}

_G.Roth_UI = {
  SettingsUI = ui,
  settingsActions = { ResetAll = function() end, ReloadSession = function() end },
  cfgDefaults = {},
  cfg = { applyGlobalFonts = false, font = "font" },
  fontPolicy = {
    Refresh = function() refreshes.fontPolicy = refreshes.fontPolicy + 1 end,
  },
  defer = {
    RunNextFrame = function(key, callback)
      nextFrame[key] = callback
    end,
  },
  _fontStrings = {},
  RefreshAllHealthValueText = function() refreshes.health = refreshes.health + 1 end,
  ForceOrbValueRefresh = function(orb)
    local key = orb == "HEALTH" and "healthOrb" or "powerOrb"
    refreshes[key] = refreshes[key] + 1
  end,
  RefreshOrbsVisual = function() end,
  RefreshAllAuraFilters = function() end,
}

assert(loadfile("core/settings_general.lua"))("Roth_UI")
expect(type(builders.general) == "function", "general settings builder was not registered")
builders.general(ui)

local healthMode = assert(specs.ROTH_UI_HEALTH_VALUE_MODE, "health mode setting was not built")
for _ = 1, 25 do healthMode.apply() end
expect(refreshes.health == 0 and refreshes.healthOrb == 0 and refreshes.powerOrb == 0,
  "health mode repeated work before its coalesced refresh")
expect(type(nextFrame["settings_general:health_value_mode"]) == "function",
  "health mode did not queue a coalesced next-frame refresh")
nextFrame["settings_general:health_value_mode"]()
expect(refreshes.health == 1 and refreshes.healthOrb == 1 and refreshes.powerOrb == 1,
  "health mode next-frame refresh did not run exactly once")

local fontSetting = assert(specs.ROTH_UI_FONT_PATH, "font setting was not built")
_G.Roth_UI.cfg.applyGlobalFonts = true
fontSetting.apply()
expect(refreshes.fontPolicy == 0, "font policy refreshed before its scheduled next frame")
expect(type(nextFrame["settings_general:settings_font_policy"]) == "function",
  "font setting did not queue one coalesced next-frame refresh")
nextFrame["settings_general:settings_font_policy"]()
expect(refreshes.fontPolicy == 1, "font policy next-frame refresh did not run once")

local applyGlobalFonts = assert(specs.ROTH_UI_APPLY_GLOBAL_FONTS, "global font setting was not built")
applyGlobalFonts.set(true)
expect(refreshes.fontPolicy == 1, "global font toggle refreshed before its scheduled next frame")
expect(type(nextFrame["settings_general:settings_font_policy"]) == "function",
  "global font toggle did not queue one coalesced next-frame refresh")
nextFrame["settings_general:settings_font_policy"]()
expect(refreshes.fontPolicy == 2, "global font toggle did not refresh exactly once")

print("settings general refresh scheduling test: OK")
