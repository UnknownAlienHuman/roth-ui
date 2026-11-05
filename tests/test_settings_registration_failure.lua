local function expect(value, message)
  if not value then error(message, 2) end
end
local noop = function() end

local function Scenario(failLoading)
  local callbacks = {}
  local categories, builders, published, loadCalls = 0, 0, 0, 0
  _G.Settings = nil
  _G.EventUtil = { ContinueOnAddOnLoaded = function(name, callback) callbacks[name] = callback end }
  _G.CreateFrame = function() error('unexpected fallback frame') end
  local function InstallSettings()
    local function Category()
      categories = categories + 1
      return { GetID = function() return 1 end }
    end
    _G.Settings = {
      RegisterVerticalLayoutCategory = Category,
      RegisterVerticalLayoutSubcategory = Category,
      RegisterAddOnCategory = function() published = published + 1 end,
      OpenToCategory = noop,
    }
  end
  _G.C_AddOns = { LoadAddOn = function()
    loadCalls = loadCalls + 1
    if failLoading and loadCalls == 1 then error('injected load failure') end
    InstallSettings()
    if callbacks.Blizzard_Settings then callbacks.Blizzard_Settings() end
    return true
  end }
  local ns = {
    framePolicy = { DeferUntilOutOfCombat = function() return false end },
    safety = { TryCall = pcall },
    store = { GetConfigValue = function(_, fallback) return fallback end,
      SetConfigValue = function() return true end },
  }
  assert(loadfile('core/settings_main.lua'))('Roth_UI', ns)
  local ui = ns.SettingsUI
  ui:RegisterBuilder('test', function()
    builders = builders + 1
    if not failLoading then error('injected partial builder failure') end
  end)
  if callbacks.Roth_UI then callbacks.Roth_UI() end
  local ok, opened = pcall(ui.Open, ui, 'root')
  expect(ok and opened == false, 'Settings failure escaped instead of returning unavailable')
  expect(ui.registering == false and not ui.registered, 'failed registration retained its active lock')
  if failLoading then
    expect(categories == 0 and builders == 0, 'failed load started native registration')
    expect(ui:Open('root') == true, 'failed load blocked a later valid load')
    expect(categories == 8 and builders == 1 and published == 1, 'valid retry duplicated registration')
  else
    expect(categories == 8 and builders == 1 and published == 0, 'partial tree was published')
    expect(ui.registrationFailed == true, 'partial native registration was not terminal')
    expect(ui:Open('root') == false, 'partial registration was retried')
    callbacks.Blizzard_Settings()
    expect(categories == 8 and builders == 1 and published == 0, 'native controls were registered twice after failure')
  end
end

local failures = {}
for _, failLoading in ipairs({ false, true }) do
  local ok, err = pcall(Scenario, failLoading)
  if not ok then failures[#failures + 1] = tostring(err) end
end
expect(#failures == 0, table.concat(failures, '\n'))
print('settings failed-load recovery and terminal registration tests: OK')
