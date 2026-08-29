-- Small unit formatting helpers kept outside the monolithic layout module.
-- Aura scanning and dispel-state inference are intentionally absent: Retail
-- 12.1 managed AuraContainers own that state.

local addonName, ns = ...

local func = assert(ns and ns.func, "Roth_UI: ns.func is required by unit_misc_runtime.lua")
local floor = math.floor
local abs = math.abs
local tonumber = tonumber
local tostring = tostring
local type = type
local canaccessvalue = _G.canaccessvalue

local function Accessible(value)
  if func.IsSecretValue(value) then
    return false
  end
  if type(canaccessvalue) == "function" and not canaccessvalue(value) then
    return false
  end
  return true
end

local function FormatOneDecimal(value)
  local text = string.format("%.1f", value)
  if text:sub(-2) == ".0" then
    return text:sub(1, -3)
  end
  return text
end

func.numFormat = function(value)
  if not Accessible(value) then
    return ""
  end

  local valueType = type(value)
  local number
  if valueType == "number" then
    number = value
  elseif valueType == "string" then
    number = tonumber(value)
  else
    return ""
  end

  if type(number) ~= "number" then
    return ""
  end

  local rounded = floor(number + 0.5)
  if abs(number - rounded) < 0.01 then
    number = rounded
  end

  local magnitude = abs(number)
  local short = ns.cfg and ns.cfg.shortNumbers == true
  if short and magnitude >= 1000000000 then
    return FormatOneDecimal(number / 1000000000) .. "b"
  elseif short and magnitude >= 1000000 then
    return FormatOneDecimal(number / 1000000) .. "m"
  elseif short and magnitude >= 1000 then
    return FormatOneDecimal(number / 1000) .. "k"
  end

  if number % 1 == 0 then
    return tostring(number)
  end
  return FormatOneDecimal(number)
end

func.round = function(value)
  if not Accessible(value) or type(value) ~= "number" then
    return nil
  end
  return floor(value * 1000) / 1000
end
