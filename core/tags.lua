-- Minimal Roth-specific oUF tags for Retail 12.1 / oUF 14.
-- Numeric health/power text is rendered by element PostUpdate callbacks and
-- native widget sinks; the tag engine is reserved for unit names only.

local addonName, ns = ...

local oUF = assert(ns and ns.oUF, "Roth_UI: oUF is required by tags.lua")
local func = assert(ns and ns.func, "Roth_UI: ns.func is required by tags.lua")

local IsSecretValue = assert(func.IsSecretValue, "Roth_UI: func.IsSecretValue is required by tags.lua")
local GetClassColorForUnit = func.GetClassColorForUnit

local COLOR_WHITE = "|cffffffff"
local COLOR_UNAVAILABLE = "|cff808080"

local function GenerateColorMarkup(color)
  if color and type(color.GenerateHexColorMarkup) == "function" then
    return color:GenerateHexColorMarkup()
  end
  if color and type(color.r) == "number" and type(color.g) == "number" and type(color.b) == "number" then
    return string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
  end
  return COLOR_WHITE
end

-- Return only an ordinary color prefix. The unit name itself comes from oUF's
-- built-in [name] tag so a secret name remains inside the framework/native
-- SetFormattedText path instead of being concatenated in addon Lua.
oUF.Tags.Methods["roth:namecolor"] = function(unit)
  local connected = UnitIsConnected(unit)
  if not IsSecretValue(connected) and connected == false then
    return COLOR_UNAVAILABLE
  end

  local dead = UnitIsDeadOrGhost(unit)
  if not IsSecretValue(dead) and dead == true then
    return COLOR_UNAVAILABLE
  end

  local tapped = UnitIsTapDenied(unit)
  if not IsSecretValue(tapped) and tapped == true then
    return COLOR_UNAVAILABLE
  end

  if type(GetClassColorForUnit) == "function" then
    local classColor = GetClassColorForUnit(unit)
    if classColor then
      return GenerateColorMarkup(classColor)
    end
  end

  local reaction = UnitReaction(unit, "player")
  if not IsSecretValue(reaction) and type(reaction) == "number" then
    return GenerateColorMarkup(FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction])
  end

  return COLOR_WHITE
end

oUF.Tags.Events["roth:namecolor"] = "UNIT_FLAGS UNIT_CONNECTION UNIT_FACTION UNIT_NAME_UPDATE PLAYER_TARGET_CHANGED"
