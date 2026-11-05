local _, private = ...
local ns = assert(private or _G.Roth_UI, "Roth_UI: main namespace is required")

local ui = assert(ns and ns.SettingsUI, "Roth_UI: SettingsUI is required by settings_general.lua")
local type = type
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local InCombatLockdown = InCombatLockdown
local defer = ns and ns.defer
local settingsActions = assert(ns and ns.settingsActions, "Roth_UI: settings actions are required by settings_general.lua")

local LSM = (LibStub and LibStub("LibSharedMedia-3.0", true)) or nil

local function GetMoverRuntime()
  local moverRuntime = ns and ns.moverRuntime
  if type(moverRuntime) ~= "table" then
    return nil
  end
  return moverRuntime
end

local function RefreshAuraFilters()
  if ns and type(ns.RefreshAllAuraFilters) == "function" then
    ns.RefreshAllAuraFilters()
  end
end

local function QueueFontPolicyRefresh(key, afterRefresh)
  ui:RunOutOfCombat(key, function()
    local function Refresh()
      local fontPolicy = ns and ns.fontPolicy
      assert(type(fontPolicy) == "table" and type(fontPolicy.Refresh) == "function",
        "Roth_UI: fontPolicy.Refresh is required by settings_general.lua")
      fontPolicy.Refresh()
      if type(afterRefresh) == "function" then
        afterRefresh()
      end
    end

    if defer and type(defer.RunNextFrame) == "function" then
      defer.RunNextFrame("settings_general:" .. key, Refresh)
    else
      Refresh()
    end
  end)
end

local function BuildFontOptions()
  local options = {
    { label = "Diablo Light (Roth)", value = "Interface\\AddOns\\Roth_UI\\media\\Diablo-Light.ttf" },
  }

  if type(_G.STANDARD_TEXT_FONT) == "string" and _G.STANDARD_TEXT_FONT ~= "" then
    options[#options + 1] = { label = "Game Default", value = _G.STANDARD_TEXT_FONT }
  end

  if LSM and LSM.List and LSM.Fetch then
    local seen = {}
    local fonts = LSM:List("font") or {}
    table.sort(fonts)
    for i = 1, #fonts do
      local key = fonts[i]
      if type(key) == "string" and key ~= "" and not seen[key] then
        local path = LSM:Fetch("font", key)
        if type(path) == "string" and path ~= "" then
          seen[key] = true
          options[#options + 1] = {
            label = key,
            value = path,
          }
        end
      end
    end
  end

  return options
end

local function ApplyFramesLocked(value)
  if InCombatLockdown and InCombatLockdown() then
    return
  end

  local moverRuntime = GetMoverRuntime()
  local forEachMoverFrame = moverRuntime and moverRuntime.ForEachFrame or nil
  local setMoverUnlocked = moverRuntime and moverRuntime.SetUnlocked or nil
  local getDragHandle = moverRuntime and moverRuntime.GetDragHandle or nil
  if type(forEachMoverFrame) ~= "function" or type(setMoverUnlocked) ~= "function" or type(getDragHandle) ~= "function" then
    return
  end

  local anyUnlocked = false
  forEachMoverFrame("all", function(frame)
    if getDragHandle(frame) then
      setMoverUnlocked(frame, value ~= true)
      if value ~= true then
        anyUnlocked = true
      end
    end
  end)

  if anyUnlocked then
    if ns and type(ns.ShowMoveGrid) == "function" then
      ns.ShowMoveGrid()
    end
  elseif ns and type(ns.HideMoveGrid) == "function" then
    ns.HideMoveGrid()
  end
end

local function RefreshDataBarLayout()
  local function Refresh()
    local playerFrame = ns and ns.unit and ns.unit.player
    local experience = playerFrame and playerFrame.Experience
    if experience and type(experience.ForceUpdate) == "function" then
      experience:ForceUpdate()
    end
    local reputation = playerFrame and playerFrame.Reputation
    if reputation and type(reputation.ForceUpdate) == "function" then
      reputation:ForceUpdate()
    end
    if ns and type(ns.RefreshActionBarArtwork) == "function" then
      ns.RefreshActionBarArtwork()
      return
    end
    local artwork = playerFrame and playerFrame.ActionBarBackground
    if artwork and type(artwork.RefreshActionBarArtwork) == "function" then
      artwork.RefreshActionBarArtwork()
    end
  end

  ui:RunOutOfCombat("settings_data_bars_refresh", Refresh)
end

local function SetDataBarEnabled(path, frameName, value)
  local requiresReload = (value == true and _G[frameName] == nil)
  ui:SetConfigValue(path, value, {
    reloadRequired = requiresReload,
    apply = RefreshDataBarLayout,
  })
end

local function ResetAllSettings()
  if type(settingsActions.ResetAll) ~= "function" then
    print("Roth_UI: settings reset is not available.")
    return
  end
  settingsActions.ResetAll()
end

local function ReloadUIFromSettings()
  if type(settingsActions.ReloadSession) ~= "function" then
    print("Roth_UI: reload is not available.")
    return
  end
  settingsActions.ReloadSession()
end

local function BuildHealthValueModeOptions()
  return {
    { label = "Current Value", value = "cur" },
    { label = "Percent", value = "percent" },
    { label = "Current + Percent", value = "curpercent" },
  }
end

local function ApplyGlobalHealthValueMode()
  if not (ns and type(ns.RefreshAllHealthValueText) == "function") then
    return
  end

  local function Refresh()
    ns.RefreshAllHealthValueText()
    if ns and type(ns.ForceOrbValueRefresh) == "function" then
      ns.ForceOrbValueRefresh("HEALTH")
      ns.ForceOrbValueRefresh("POWER")
    end
  end

  ui:RunOutOfCombat("settings_health_value_mode_global", function()
    if defer and type(defer.RunNextFrame) == "function" then
      defer.RunNextFrame("settings_general:health_value_mode", Refresh)
    else
      Refresh()
    end
  end)
end

ui:RegisterBuilder("general", function()
  ui:AddCheckbox({
    category = "root",
    variable = "ROTH_UI_FRAMES_LOCKED",
    label = "Frames Locked",
    tooltip = "Locks or unlocks Roth UI movers without leaving Settings.",
    path = { "framesLocked" },
    defaultValue = ui:GetConfigDefault({ "framesLocked" }, true),
    reloadRequired = false,
    apply = function(value)
      ui:RunOutOfCombat("settings_frames_locked", function()
        ApplyFramesLocked(value)
      end)
    end,
  })

  ui:AddDropdown({
    category = "root",
    variable = "ROTH_UI_FONT_PATH",
    label = "UI Font",
    tooltip =
    "Applies the font to ordinary Roth UI text immediately. Managed aura text requires /reload. Global Blizzard fonts use the separate checkbox.",
    path = { "font" },
    defaultValue = ui:GetConfigDefault({ "font" }, STANDARD_TEXT_FONT),
    reloadRequired = true,
    options = BuildFontOptions,
    apply = function()
      QueueFontPolicyRefresh("settings_font_policy", function()
        if ns and type(ns.RefreshOrbsVisual) == "function" then
          ns.RefreshOrbsVisual()
        end
      end)
    end,
  })

  ui:AddCheckbox({
    category = "root",
    variable = "ROTH_UI_APPLY_GLOBAL_FONTS",
    label = "Apply Font Globally",
    tooltip =
    "When enabled, the selected font is applied to supported Blizzard FontObjects. When disabled, their previous fonts are restored.",
    path = { "applyGlobalFonts" },
    defaultValue = ui:GetConfigDefault({ "applyGlobalFonts" }, true),
    reloadRequired = false,
    set = function(value)
      ui:SetConfigValue({ "applyGlobalFonts" }, value, {
        reloadRequired = false,
        apply = function()
          QueueFontPolicyRefresh("settings_font_policy", function()
            if ns and type(ns.RefreshOrbsVisual) == "function" then
              ns.RefreshOrbsVisual()
            end
          end)
        end,
      })
    end,
  })

  ui:AddCheckbox({
    category = "root",
    variable = "ROTH_UI_AURA_DURATION_TEXT",
    label = "Aura Duration Text",
    tooltip = "Shows or hides duration text on managed aura icons after /reload.",
    path = { "simpleAuras", "durationText" },
    defaultValue = ui:GetConfigDefault({ "simpleAuras", "durationText" }, false),
    reloadRequired = true,
  })

  ui:AddCheckbox({
    category = "root",
    variable = "ROTH_UI_AURA_COOLDOWN_SWIPE",
    label = "Aura Cooldown Swipe",
    tooltip = "Shows or hides the cooldown spiral on managed aura icons after /reload.",
    path = { "simpleAuras", "cooldownSwipe" },
    defaultValue = ui:GetConfigDefault({ "simpleAuras", "cooldownSwipe" }, true),
    reloadRequired = true,
  })

  ui:AddCheckbox({
    category = "root",
    variable = "ROTH_UI_TARGET_ONLY_PLAYER_BUFFS",
    label = "Target: Only My Buffs",
    tooltip = "Filters target buffs to player-owned auras only and refreshes the current target aura set immediately.",
    path = { "units", "target", "auras", "onlyShowPlayerBuffs" },
    defaultValue = ui:GetConfigDefault({ "units", "target", "auras", "onlyShowPlayerBuffs" }, false),
    reloadRequired = false,
    apply = RefreshAuraFilters,
  })

  ui:AddCheckbox({
    category = "root",
    variable = "ROTH_UI_TARGET_ONLY_PLAYER_DEBUFFS",
    label = "Target: Only My Debuffs",
    tooltip = "Filters target debuffs to player-owned auras only and refreshes the current target aura set immediately.",
    path = { "units", "target", "auras", "onlyShowPlayerDebuffs" },
    defaultValue = ui:GetConfigDefault({ "units", "target", "auras", "onlyShowPlayerDebuffs" }, true),
    reloadRequired = false,
    apply = RefreshAuraFilters,
  })

  ui:AddDropdown({
    category = "root",
    variable = "ROTH_UI_HEALTH_VALUE_MODE",
    label = "Health Text Mode",
    tooltip = "Controls what all unit frames show in the health text slot: current value, percent, or both.",
    path = { "healthValueMode" },
    defaultValue = ui:GetConfigDefault({ "healthValueMode" }, "cur"),
    reloadRequired = false,
    options = BuildHealthValueModeOptions,
    apply = ApplyGlobalHealthValueMode,
  })

  ui:AddCheckbox({
    category = "root",
    variable = "ROTH_UI_SHORT_NUMBERS",
    label = "Short Numbers",
    tooltip = "Abbreviates large numbers (1k, 1m, 1b). When disabled, full values are shown.",
    path = { "shortNumbers" },
    defaultValue = ui:GetConfigDefault({ "shortNumbers" }, true),
    reloadRequired = false,
    apply = ApplyGlobalHealthValueMode,
  })



  ui:AddCheckbox({
    category = "data_bars",
    variable = "ROTH_UI_EXPBAR_ENABLED",
    label = "Experience Bar Enabled",
    tooltip =
    "Hides or shows the XP bar policy. Enabling after a session where the bar was never created can still require /reload; existing bars refresh immediately.",
    path = { "units", "player", "expbar", "show" },
    defaultValue = ui:GetConfigDefault({ "units", "player", "expbar", "show" }, true),
    reloadRequired = false,
    set = function(value)
      SetDataBarEnabled({ "units", "player", "expbar", "show" }, "Roth_UIExpBar", value)
    end,
  })

  ui:AddCheckbox({
    category = "data_bars",
    variable = "ROTH_UI_REPBAR_ENABLED",
    label = "Reputation Bar Enabled",
    tooltip =
    "Hides or shows the watched-faction bar policy. Existing bars refresh immediately through the actionbar artwork layout pass.",
    path = { "units", "player", "repbar", "show" },
    defaultValue = ui:GetConfigDefault({ "units", "player", "repbar", "show" }, true),
    reloadRequired = false,
    set = function(value)
      SetDataBarEnabled({ "units", "player", "repbar", "show" }, "Roth_UIRepBar", value)
    end,
  })

  ui:AddButton({
    category = "root",
    label = "Saved Variables",
    buttonText = "Reset Settings",
    tooltip = "Wipes Roth_UI_DB and Roth_UI_DB_Char, then reloads the UI.",
    onClick = ResetAllSettings,
  })

  ui:AddButton({
    category = "root",
    label = "Session",
    buttonText = "Reload UI",
    tooltip = "Reloads the UI so settings marked as pendingReload can fully apply.",
    onClick = ReloadUIFromSettings,
  })
end)
