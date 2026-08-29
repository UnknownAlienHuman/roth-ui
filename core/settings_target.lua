local addonName = ...
local ns = assert(_G.Roth_UI, "Roth_UI_Options: main Roth_UI namespace is required")

local ui = assert(ns and ns.SettingsUI, "Roth_UI: SettingsUI is required by settings_target.lua")
local type = type

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
  local runtime = ns and ns.TargetCastbarRuntime
  if runtime and type(runtime.ScheduleActiveRefresh) == "function" then
    runtime.ScheduleActiveRefresh()
    return
  end

  if ns and type(ns.RefreshTargetCastbarColorContract) == "function" then
    ns.RefreshTargetCastbarColorContract()
  end
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
