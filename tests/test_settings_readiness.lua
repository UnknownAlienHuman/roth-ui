local function expect(value, message)
  if not value then error(message, 2) end
end

local function Scenario(useEventUtil, settingsPreloaded, tableEarly)
  local callbacks, frames, ready = {}, {}, {}
  local categories, roots, builders, opens, loads = 0, 0, 0, 0, 0
  local namespace
  _G.Roth_UI = nil
  _G.Settings = nil
  _G.CreateFrame = function()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(script, callback) self.scripts[script] = callback end
    frames[#frames + 1] = frame
    return frame
  end
  local function InstallSettings()
    local function Category()
      categories = categories + 1
      return { GetID = function() return categories end }
    end
    _G.Settings = {
      RegisterVerticalLayoutCategory = Category,
      RegisterVerticalLayoutSubcategory = Category,
      RegisterAddOnCategory = function()
        expect(builders == 1, 'published empty Settings before builder files finished')
        roots = roots + 1
      end,
      OpenToCategory = function() opens = opens + 1 end,
    }
  end
  local function Complete(name)
    ready[name] = true
    local callback = callbacks[name]
    callbacks[name] = nil
    if callback then callback() end
    -- Detach this batch: callbacks created during delivery see the next event.
    local count = #frames
    for i = 1, count do
      local frame = frames[i]
      if frame.events.ADDON_LOADED and frame.scripts.OnEvent then
        frame.scripts.OnEvent(frame, 'ADDON_LOADED', name)
      end
    end
  end
  _G.C_AddOns = {
    IsAddOnLoaded = function(name)
      -- The first return includes LOADING, not just load completion.
      return true, ready[name] == true
    end,
    LoadAddOn = function(name)
      expect(name == 'Blizzard_Settings', 'unexpected addon load')
      loads = loads + 1
      InstallSettings()
      Complete(name)
      return true
    end,
  }
  _G.EventUtil = useEventUtil and {
    ContinueOnAddOnLoaded = function(name, callback)
      if ready[name] then callback() else callbacks[name] = callback end
    end,
  } or nil
  if settingsPreloaded then
    ready.Blizzard_Settings = true
    InstallSettings()
  end
  if tableEarly then InstallSettings() end
  namespace = {
    framePolicy = { DeferUntilOutOfCombat = function() return false end },
    safety = { TryCall = pcall },
    store = { GetConfigValue = function(_, fallback) return fallback end,
      SetConfigValue = function() return true end },
  }
  assert(loadfile('core/settings_main.lua'))('Roth_UI', namespace)
  local ui = namespace.SettingsUI
  expect(not ui.registered and categories == 0,
    'preloaded or loading Settings registered before Roth files finished')
  expect(loads == 0, 'Settings was forced to load at file scope')
  expect(ui:Open('root') == false and categories == 0 and loads == 0,
    'an early Open bypassed the addon-completion gate')
  ui:RegisterBuilder('test', function() builders = builders + 1 end)
  -- Ignore unrelated addon events without consuming the readiness listener.
  Complete('UnrelatedAddon')
  expect(builders == 0, 'unrelated addon event released the readiness gate')
  Complete('Roth_UI')
  if not settingsPreloaded then
    expect(categories == 0 and loads == 0, 'Roth completion eagerly loaded Settings')
  end
  expect(ui:Open('root') == true, 'ready Settings could not be opened')
  expect(builders == 1 and roots == 1 and categories == 8 and opens == 1,
    'Settings did not register one complete category tree')
  expect(loads == (settingsPreloaded and 0 or 1), 'incorrect lazy load count')
  Complete('Roth_UI')
  Complete('Blizzard_Settings')
  expect(builders == 1 and roots == 1 and categories == 8, 'duplicate lifecycle built controls twice')
  for i = 1, #frames do
    expect(not frames[i].events.ADDON_LOADED and frames[i].scripts.OnEvent == nil,
      'one-shot fallback retained its event or callback')
  end
end

Scenario(true, true)
Scenario(true, false)
Scenario(false, true)
Scenario(false, false)
Scenario(true, false, true)
Scenario(false, false, true)
print('settings own-addon readiness and load-order tests: OK')
