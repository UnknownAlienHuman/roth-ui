local function expect(value, message)
  if not value then error(message, 2) end
end
local noop = function() end
local callbacks, settings, queued, writes = {}, {}, {}, {}
local filters, fonts, orbs = 0, 0, 0
_G.Settings = nil
_G.LibStub = nil
_G.STANDARD_TEXT_FONT = 'old.ttf'
_G.EventUtil = { ContinueOnAddOnLoaded = function(name, callback) callbacks[name] = callback end }
_G.CreateSettingsButtonInitializer = function() return {} end
_G.C_AddOns = { LoadAddOn = function() error('unexpected eager load') end }
local cfg = {
  font = 'old.ttf', applyGlobalFonts = true,
  simpleAuras = { durationText = false, cooldownSwipe = true },
}
local function Read(path, fallback)
  local node = cfg
  for i = 1, #path do
    if type(node) ~= 'table' then return fallback end
    node = node[path[i]]
  end
  if node == nil then return fallback end
  return node
end
local ns = {
  cfgDefaults = cfg,
  framePolicy = { DeferUntilOutOfCombat = function() return false end },
  safety = { TryCall = pcall },
  store = {
    GetConfigValue = Read,
    SetConfigValue = function(path, value, opts)
      writes[#writes + 1] = { path = table.concat(path, '.'), value = value, reload = opts.markPendingReload }
      local node = cfg
      for i = 1, #path - 1 do node = node[path[i]] end
      node[path[#path]] = value
      return true
    end,
  },
  defer = { RunNextFrame = function(key, callback) queued[key] = callback end },
  settingsActions = {},
  fontPolicy = { Refresh = function() fonts = fonts + 1 end },
  RefreshOrbsVisual = function() orbs = orbs + 1 end,
  RefreshAllAuraFilters = function() filters = filters + 1 end,
}
assert(loadfile('core/settings_main.lua'))('Roth_UI', ns)
assert(loadfile('core/settings_general.lua'))('Roth_UI', ns)
if callbacks.Roth_UI then callbacks.Roth_UI() end
_G.Settings = {
  VarType = { Boolean = 1, Number = 2, String = 3 },
  RegisterVerticalLayoutCategory = function() return {} end,
  RegisterVerticalLayoutSubcategory = function() return {} end,
  RegisterAddOnCategory = noop,
  RegisterInitializer = noop,
  RegisterProxySetting = function(_, variable, _, _, _, getter, setter)
    local setting = { get = getter, set = setter }
    settings[variable] = setting
    return setting
  end,
  CreateCheckbox = noop, CreateDropdown = noop,
}
assert(callbacks.Blizzard_Settings)()
expect(ns.SettingsUI.registered, 'settings did not register')

settings.ROTH_UI_AURA_DURATION_TEXT.set(true)
expect(writes[#writes].reload == true and Read({'simpleAuras', 'durationText'}) == true,
  'duration display changed construction settings without marking reload')
expect(filters == 0, 'duration display queued an unrelated candidate-filter scan')
settings.ROTH_UI_AURA_COOLDOWN_SWIPE.set(false)
expect(writes[#writes].reload == true and Read({'simpleAuras', 'cooldownSwipe'}) == false,
  'cooldown display changed construction settings without marking reload')
expect(filters == 0, 'cooldown display queued an unrelated candidate-filter scan')
settings.ROTH_UI_FONT_PATH.set('new.ttf')
expect(writes[#writes].reload == true, 'font change hid the managed-aura reload requirement')
for _, callback in pairs(queued) do callback() end
expect(fonts == 1 and orbs == 1, 'ordinary fonts/orbs lost their immediate refresh')
expect(filters == 0, 'font-only change scanned aura candidate filters')

-- Truly live candidate settings retain their immediate application path.
local target = { auras = { onlyShowPlayerBuffs = false } }
cfg.units = { target = target }
settings.ROTH_UI_TARGET_ONLY_PLAYER_BUFFS.set(true)
expect(writes[#writes].reload == false and filters == 1,
  'live candidate filter was incorrectly made structural')
print('settings managed-aura appearance and live-filter contract: OK')
