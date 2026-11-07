local _, private = ...
local ns = assert(private or _G.Roth_UI, "Roth_UI: main namespace is required")

local ui = assert(ns and ns.SettingsUI, "Roth_UI: SettingsUI is required by settings_target.lua")
local type = type
local targetCastbarRuntime = assert(ns and ns.TargetCastbarRuntime,
  "Roth_UI: TargetCastbarRuntime is required by settings_target.lua")
local ScheduleTargetCastbarRefresh = assert(targetCastbarRuntime.ScheduleActiveRefresh,
  "Roth_UI: TargetCastbarRuntime.ScheduleActiveRefresh is required by settings_target.lua")

local function SemanticPath(key)
  return { "units", "target", "castbar", "color", "semantic", key }
end

local function GetDefaultColor(key)
  return ui:GetConfigDefault(SemanticPath(key))
end

local function GetCurrentColor(key)
  return ui:GetConfigValue(SemanticPath(key), GetDefaultColor(key))
end

local function ApplyTargetCastbarContract()
  ScheduleTargetCastbarRefresh()
end

local function SetSemanticColor(key, hexColor)
  local path = SemanticPath(key)
  local current = GetCurrentColor(key)
  local color = ui:HexToColor(hexColor, current)
  if ui:SetConfigValue(path, color, { reloadRequired = false }) ~= true then
    return false
  end
  ApplyTargetCastbarContract()
  return true
end

local function AddTargetColor(variable, label, key, tooltip)
  local path = SemanticPath(key)
  local defaultColor = GetDefaultColor(key)

  ui:AddColorSwatch({
    category = "target",
    variable = variable,
    label = label,
    tooltip = tooltip,
    path = path,
    varType = Settings.VarType.String,
    defaultValue = ui:ColorToHex(defaultColor),
    get = function()
      return ui:ColorToHex(GetCurrentColor(key), defaultColor)
    end,
    set = function(hexColor)
      SetSemanticColor(key, hexColor)
    end,
  })
end

ui:RegisterBuilder("target", function()
  AddTargetColor(
    "ROTH_UI_TARGET_CASTBAR_INTERRUPTIBLE_CAST",
    "Interruptible Cast Color",
    "interruptibleCast",
    "Controls the target castbar tint for normal interruptible casts."
  )

  AddTargetColor(
    "ROTH_UI_TARGET_CASTBAR_NON_INTERRUPTIBLE",
    "Non-Interruptible Color",
    "nonInterruptible",
    "Controls the target castbar tint when the spell cannot be interrupted."
  )

  AddTargetColor(
    "ROTH_UI_TARGET_CASTBAR_FAILED",
    "Failed / Interrupted Color",
    "failedOrInterrupted",
    "Controls the short hold tint after the target cast fails or is interrupted."
  )
end)
