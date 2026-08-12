-- Extracted from core/lib.lua to reduce monolithic hot-path runtime coupling.
-- Provides numeric/unit-value helpers and health/power PostUpdate handlers.

local addonName, ns = ...

local func = assert(ns and ns.func, "Roth_UI: ns.func is required by unit_value_runtime.lua")
local cfg = ns and ns.cfg
local safety = ns and ns.safety

local type = type
local tonumber = tonumber
local tostring = tostring
local floor = floor or math.floor

local UnitPowerType = UnitPowerType
local UnitIsTapDenied = UnitIsTapDenied
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsConnected = UnitIsConnected
local UnitClass = UnitClass
local UnitGUID = UnitGUID
local UnitIsPlayer = UnitIsPlayer
local UnitReaction = UnitReaction
local GetPlayerInfoByGUID = GetPlayerInfoByGUID

local IsSecretValue = assert(func.IsSecretValue, "Roth_UI: func.IsSecretValue is required by unit_value_runtime.lua")
local ReportGuardFailure = safety and safety.ReportGuardFailure
--update health func
--
-- WoW 12.x: Unit* APIs may return Secret Values in combat. Secret Values must never
-- be used in arithmetic/comparisons or in boolean contexts. For unitframe numeric
-- text we either:
--   * pass the raw Secret Value directly to FontString:SetText (allowed), or
--   * only do math/formatting when the values are NOT secret.
-- oUF 13 / Midnight: prefer percent APIs that do not require Unit*Max (often secret).
local function GetScaleTo100Curve()
  return (_G.CurveConstants and _G.CurveConstants.ScaleTo100) or nil
end
func.GetScaleTo100Curve = GetScaleTo100Curve

local function SafeUnitHealthPercent(unit)
  local fn = _G.UnitHealthPercent
  if not (unit and type(fn) == "function") then
    return nil
  end
  local curve = GetScaleTo100Curve()
  if curve then
    local ok, val = pcall(fn, unit, true, curve)
    if ok and val ~= nil then return val end
    if not ok and type(ReportGuardFailure) == "function" then
      ReportGuardFailure("UnitHealthPercent(curve)", val)
    end
  end
  -- Fallback: call without curve args (plain 0-100 percent).
  local ok, val = pcall(fn, unit)
  if ok then return val end
  if type(ReportGuardFailure) == "function" then
    ReportGuardFailure("UnitHealthPercent", val)
  end
  return nil
end

local function SafeUnitPowerPercent(unit)
  local fn = _G.UnitPowerPercent
  if not (unit and type(fn) == "function") then
    return nil
  end
  local curve = GetScaleTo100Curve()
  if curve then
    local ok, val = pcall(fn, unit, nil, true, curve)
    if ok and val ~= nil then return val end
    if not ok and type(ReportGuardFailure) == "function" then
      ReportGuardFailure("UnitPowerPercent(curve)", val)
    end
  end
  local ok, val = pcall(fn, unit)
  if ok then return val end
  if type(ReportGuardFailure) == "function" then
    ReportGuardFailure("UnitPowerPercent", val)
  end
  return nil
end

func.SafeUnitHealthPercent = SafeUnitHealthPercent
func.SafeUnitPowerPercent = SafeUnitPowerPercent

local CanAccessValue = _G.canaccessvalue
local function CoerceAccessibleNumber(v)
  if v == nil then
    return nil
  end
  if IsSecretValue(v) then
    if type(CanAccessValue) == "function" and CanAccessValue(v) then
      local n = tonumber(v)
      if type(n) == "number" then
        return n
      end
    end
    return nil
  end
  if type(v) == "number" then
    return v
  end
  if type(v) == "string" then
    local n = tonumber(v)
    if type(n) == "number" then
      return n
    end
  end
  return nil
end
func.CoerceAccessibleNumber = CoerceAccessibleNumber

-- Try Blizzard abbreviation functions for secret values (they may handle secrets internally).
local _cachedAbbrevFn = nil
local function TryBlizzardAbbrev(v)
  if v == nil then return nil end
  local function tryFn(fn)
    if type(fn) ~= "function" then return nil end
    local ok, res = pcall(fn, v)
    if not ok or res == nil then return nil end
    return res
  end
  if _cachedAbbrevFn then
    local res = tryFn(_cachedAbbrevFn)
    if res then return res end
    _cachedAbbrevFn = nil
  end
  local fns = { _G.AbbreviateNumbers, _G.AbbreviateLargeNumbers, _G.AbbreviateNumber, _G.AbbreviateLargeNumber }
  for i = 1, #fns do
    local res = tryFn(fns[i])
    if res then
      _cachedAbbrevFn = fns[i]
      return res
    end
  end
  return nil
end
func.TryBlizzardAbbrev = TryBlizzardAbbrev

local function SetTextCached(fs, v)
  if not fs then return end
  if v == nil then v = "" end
  if type(v) == "number" then
    v = tostring(v)
  end
  if fs._rothLastText == v then
    return
  end
  fs._rothLastText = v
  fs:SetText(v)
end

local function SetAlphaCached(region, a)
  if not region then return end
  if region._rothLastAlpha == a then
    return
  end
  region._rothLastAlpha = a
  region:SetAlpha(a)
end

local function SetVertexColorCached(region, r, g, b, a)
  if not region then return end
  if region._rothLastR == r
      and region._rothLastG == g
      and region._rothLastB == b
      and region._rothLastA == a then
    return
  end
  region._rothLastR = r
  region._rothLastG = g
  region._rothLastB = b
  region._rothLastA = a
  region:SetVertexColor(r, g, b, a)
end

local function SetStatusBarColorCached(bar, r, g, b, a)
  if not bar then return end
  if bar._rothLastR == r
      and bar._rothLastG == g
      and bar._rothLastB == b
      and bar._rothLastA == a then
    return
  end
  bar._rothLastR = r
  bar._rothLastG = g
  bar._rothLastB = b
  bar._rothLastA = a
  bar:SetStatusBarColor(r, g, b, a)
end

local function SafeSetText(fs, v)
  if not fs then return end
  if IsSecretValue(v) then
    fs._rothLastText = nil
    fs:SetText(v)
    return
  end
  if v == nil then
    SetTextCached(fs, "")
    return
  end
  SetTextCached(fs, v)
end

local _truncateWhenZero = _G.C_StringUtil and _G.C_StringUtil.TruncateWhenZero
local function TryTruncateWhenZero(v)
  if type(_truncateWhenZero) == "function" then
    return _truncateWhenZero(v)
  end
  return nil
end

local function SafeSetStackText(fs, v)
  if not fs then return end
  if IsSecretValue(v) then
    fs._rothLastText = nil
    local text = TryTruncateWhenZero(v)
    if text ~= nil then
      SetTextCached(fs, text or "")
      return
    end
    fs:SetText(v)
    return
  end
  if v == nil then
    SetTextCached(fs, "")
    return
  end
  -- Some game APIs (and some callers) may pass stack text as a string.
  -- Avoid comparing numbers with strings.
  if type(v) ~= "number" then
    local n = tonumber(v)
    if not n then
      SetTextCached(fs, "")
      return
    end
    v = n
  end
  if v > 1 then
    SetTextCached(fs, v)
  else
    SetTextCached(fs, "")
  end
end

local function SetPercentText(fs, d)
  if not fs then return end
  if d == nil then
    SetTextCached(fs, "")
    return
  end
  if IsSecretValue(d) then
    -- Formatting secret percentages using Lua triggers taint errors when fractions appear.
    -- Calling FontString:SetFormattedText natively rounds and appends the '%' safely in C!
    fs._rothLastText = nil
    fs:SetFormattedText("%.0f%%", d)
    return
  end
  local n = tonumber(d)
  if type(n) == "number" then
    SetTextCached(fs, floor(n) .. "%")
    return
  end
  SetTextCached(fs, d)
end

func.SafeSetText             = SafeSetText
func.SafeSetStackText        = SafeSetStackText
func.SetPercentText          = SetPercentText
func.SetVertexColorCached    = SetVertexColorCached

-----------------------------------------------------------------------------
-- PERF: avoid per-update table allocations in frequently-called PostUpdate
--       handlers (reduces GC churn on unitframe frequentUpdates).
-----------------------------------------------------------------------------

local COLOR_TAP_DENIED       = { r = 0.65, g = 0.65, b = 0.65, a = 1 }
local COLOR_DEAD_OFFLINE     = { r = 0.40, g = 0.40, b = 0.40, a = 1 }
local COLOR_NEUTRAL_FALLBACK = { r = 0.50, g = 0.50, b = 0.50, a = 1 }
local COLOR_POWER_DEFAULT    = { r = 1.00, g = 0.50, b = 0.25, a = 1 }
local DEFAULT_COLORSWITCHER  = {
  bright = { r = 1, g = 0, b = 0, a = 1 },
  dark = { r = 1, g = 0, b = 0, a = 0.1 },
  classcolored = true,
  useBrightForeground = true,
  threatColored = true,
}

local function GetEffectiveRuntimeConfig()
  local runtimeCfg = (ns and ns.cfg) or cfg or {}
  local defaults = (ns and ns.cfgDefaults) or {}
  local colorCfg = runtimeCfg.colorswitcher or defaults.colorswitcher or DEFAULT_COLORSWITCHER
  local powerColors = runtimeCfg.powercolors or defaults.powercolors or PowerBarColor or {}
  local highlightMultiplier = runtimeCfg.highlightMultiplier
  if type(highlightMultiplier) ~= "number" then
    highlightMultiplier = defaults.highlightMultiplier
  end
  if type(highlightMultiplier) ~= "number" then
    highlightMultiplier = 0
  end
  return runtimeCfg, colorCfg, powerColors, highlightMultiplier
end

local function GetClassColorForUnit(unit)
  if not unit then return nil end
  local isPlayer = UnitIsPlayer(unit)
  if IsSecretValue(isPlayer) or not isPlayer then return nil end

  local classToken
  local guid = UnitGUID(unit)
  if guid and not IsSecretValue(guid) then
    if GetPlayerInfoByGUID then
      local _, byGUID = GetPlayerInfoByGUID(guid)
      if byGUID and not IsSecretValue(byGUID) then
        classToken = byGUID
      end
    end
  end
  if not classToken then
    local _, byUnit = UnitClass(unit)
    if byUnit and not IsSecretValue(byUnit) then
      classToken = byUnit
    end
  end
  if not classToken then return nil end
  return (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]) or nil
end
func.GetClassColorForUnit = GetClassColorForUnit

func.updateHealth = function(bar, unit, cur, min, max)
  local _, colorCfg, _, highlightMultiplier = GetEffectiveRuntimeConfig()
  -- oUF PostUpdateHealth is typically (bar, unit, cur, max), but some forks call
  -- it like (bar, unit, cur, min, max). Normalize without touching secrets.
  local value = cur
  local maxv = max
  if (not IsSecretValue(maxv)) and maxv == nil then
    maxv = min
  end

  local dead, offline
  local color

  local tap = unit and UnitIsTapDenied(unit)
  if not IsSecretValue(tap) and tap then
    color = COLOR_TAP_DENIED
  else
    local deadFlag = unit and UnitIsDeadOrGhost(unit)
    if not IsSecretValue(deadFlag) and deadFlag then
      color = COLOR_DEAD_OFFLINE
      dead = 1
    else
      local connected = unit and UnitIsConnected(unit)
      if not IsSecretValue(connected) and not connected then
        color = COLOR_DEAD_OFFLINE
        offline = 1
      elseif not colorCfg.classcolored then
        color = colorCfg.bright
      else
        local classColor = GetClassColorForUnit(unit)
        if classColor then color = classColor end
        if not color then
          local reaction = unit and UnitReaction(unit, "player")
          if reaction and not IsSecretValue(reaction) then
            color = FACTION_BAR_COLORS[reaction]
          end
        end
      end
    end
  end
  if not color then color = COLOR_NEUTRAL_FALLBACK end

  local minSecret = IsSecretValue(value)
  local maxSecret = IsSecretValue(maxv)

  -- If the values are Secret Values, try to coerce them to plain numbers when allowed.
  -- This enables short-number formatting in combat without doing arithmetic on secrets.
  if minSecret then
    local n = CoerceAccessibleNumber(value)
    if type(n) == "number" then
      value = n
      minSecret = false
    end
  end
  if maxSecret then
    local n = CoerceAccessibleNumber(maxv)
    if type(n) == "number" then
      maxv = n
      maxSecret = false
    end
  end

  -- Prefer UnitHealthPercent so we can display % even when max is secret.
  local d = SafeUnitHealthPercent(unit)
  local dIsNumber = (type(d) == "number") and (not IsSecretValue(d))

  -- Fallback to manual ratio only if both inputs are not secret.
  if (d == nil) and (not minSecret) and (not maxSecret) and (maxv ~= nil) and (maxv > 0) and (value ~= nil) then
    d = floor(value / maxv * 100)
    dIsNumber = true
  end

  -- Numeric text (optional fields wired by unit layouts)
  if bar.valueText then
    if offline == 1 then
      SafeSetText(bar.valueText, PLAYER_OFFLINE or "OFFLINE")
    elseif dead == 1 then
      SafeSetText(bar.valueText, DEAD or "DEAD")
    elseif (not minSecret) and (value ~= nil) then
      local valueMode = bar.valueTextMode or "curmax"
      if (not maxSecret) and (maxv ~= nil) and (maxv > 0) then
        if valueMode == "cur" then
          SafeSetText(bar.valueText, func.numFormat(value))
        elseif valueMode == "percent" then
          if dIsNumber then
            SafeSetText(bar.valueText, floor(d) .. "%")
          elseif d ~= nil then
            SetPercentText(bar.valueText, d)
          else
            SafeSetText(bar.valueText, func.numFormat(value))
          end
        elseif valueMode == "curpercent" then
          if bar.perText then
            SafeSetText(bar.valueText, func.numFormat(value))
          elseif dIsNumber then
            SafeSetText(bar.valueText, func.numFormat(value) .. " / " .. floor(d) .. "%")
          else
            SafeSetText(bar.valueText, func.numFormat(value))
          end
        elseif valueMode == "max" then
          SafeSetText(bar.valueText, func.numFormat(maxv))
        else
          SafeSetText(bar.valueText, func.numFormat(value) .. " / " .. func.numFormat(maxv))
        end
      else
        -- When max is secret, still show current (abbreviated) value.
        SafeSetText(bar.valueText, func.numFormat(value))
      end
    else
      -- value is secret and could not be coerced; try Blizzard abbreviation
      local useShort = ns and ns.cfg and ns.cfg.shortNumbers == true
      local abbrev = useShort and TryBlizzardAbbrev(value) or nil
      if abbrev then
        SafeSetText(bar.valueText, abbrev)
      else
        SafeSetText(bar.valueText, value)
      end
    end
  end
  if bar.perText then
    local valueMode = bar.valueTextMode or "curmax"
    if valueMode ~= "curpercent" then
      SafeSetText(bar.perText, "")
    elseif offline == 1 or dead == 1 then
      SafeSetText(bar.perText, "")
    elseif dIsNumber then
      SafeSetText(bar.perText, floor(d) .. "%")
    elseif d ~= nil then
      SetPercentText(bar.perText, d)
    else
      SafeSetText(bar.perText, "")
    end
  end

  -- bar colors
  if offline == 1 then
    SetStatusBarColorCached(bar, 0.4, 0.4, 0.4, 0.4)
    if bar.glow then SetVertexColorCached(bar.glow, 0, 0, 0, 0) end
  else
    if colorCfg.useBrightForeground then
      SetStatusBarColorCached(bar, color.r, color.g, color.b, color.a or 1)
      if bar.bg then
        SetVertexColorCached(bar.bg, colorCfg.dark.r, colorCfg.dark.g, colorCfg.dark.b, colorCfg.dark.a)
      end
    else
      SetStatusBarColorCached(bar, colorCfg.dark.r, colorCfg.dark.g, colorCfg.dark.b, colorCfg.dark.a)
      if bar.bg then
        SetVertexColorCached(bar.bg, color.r, color.g, color.b, color.a or 1)
      end
    end
  end

  -- low HP cosmetics (only when we have a non-secret percent)
  if dead == 1 or (dIsNumber and d <= 25) then
    if bar.highlight then SetAlphaCached(bar.highlight, 0) end
    if colorCfg.useBrightForeground then
      if bar.glow then SetVertexColorCached(bar.glow, 1, 0, 0, 0.6) end
      SetStatusBarColorCached(bar, 1, 0, 0, 1)
      if bar.bg then SetVertexColorCached(bar.bg, 0.2, 0, 0, 0.9) end
    else
      if bar.glow then SetVertexColorCached(bar.glow, 1, 0, 0, 1) end
    end
  elseif (not bar.buffOverride) then
    if bar.glow then SetVertexColorCached(bar.glow, 0, 0, 0, 0.7) end
    if bar.highlight then SetAlphaCached(bar.highlight, highlightMultiplier) end
  end
end

--update power func
func.updatePower = function(bar, unit, cur, min, max)
  local _, _, powerColors = GetEffectiveRuntimeConfig()
  local token = unit and select(2, UnitPowerType(unit)) or nil
  if IsSecretValue(token) then token = nil end
  local color = token and powerColors[token] or nil
  if not color then
    color = COLOR_POWER_DEFAULT
  end
  SetStatusBarColorCached(bar, color.r, color.g, color.b, 1)
  if bar.bg then SetVertexColorCached(bar.bg, color.r, color.g, color.b, 0.2) end

  -- Normalize signature (bar, unit, cur, max) vs (bar, unit, cur, min, max)
  local value = cur
  local maxv = max
  if (not IsSecretValue(maxv)) and maxv == nil then
    maxv = min
  end

  local minSecret = IsSecretValue(value)
  local maxSecret = IsSecretValue(maxv)

  -- If the values are Secret Values, try to coerce them to plain numbers when allowed.
  -- This enables short-number formatting in combat without doing arithmetic on secrets.
  if minSecret then
    local n = CoerceAccessibleNumber(value)
    if type(n) == "number" then
      value = n
      minSecret = false
    end
  end
  if maxSecret then
    local n = CoerceAccessibleNumber(maxv)
    if type(n) == "number" then
      maxv = n
      maxSecret = false
    end
  end

  local d = SafeUnitPowerPercent(unit)
  local dIsNumber = (type(d) == "number") and (not IsSecretValue(d))
  if (d == nil) and (not minSecret) and (not maxSecret) and (maxv ~= nil) and (maxv > 0) and (value ~= nil) then
    d = floor(value / maxv * 100)
    dIsNumber = true
  end

  if bar.valueText then
    if (not minSecret) and (value ~= nil) then
      local valueMode = bar.valueTextMode or "curmax"
      if (not maxSecret) and (maxv ~= nil) and (maxv > 0) then
        if valueMode == "cur" then
          SafeSetText(bar.valueText, func.numFormat(value))
        elseif valueMode == "percent" then
          if dIsNumber then
            SafeSetText(bar.valueText, floor(d) .. "%")
          elseif d ~= nil then
            SetPercentText(bar.valueText, d)
          else
            SafeSetText(bar.valueText, func.numFormat(value))
          end
        elseif valueMode == "curpercent" then
          if bar.perText then
            SafeSetText(bar.valueText, func.numFormat(value))
          elseif dIsNumber then
            SafeSetText(bar.valueText, func.numFormat(value) .. " / " .. floor(d) .. "%")
          else
            SafeSetText(bar.valueText, func.numFormat(value))
          end
        elseif valueMode == "max" then
          SafeSetText(bar.valueText, func.numFormat(maxv))
        else
          SafeSetText(bar.valueText, func.numFormat(value) .. " / " .. func.numFormat(maxv))
        end
      else
        SafeSetText(bar.valueText, func.numFormat(value))
      end
    else
      local useShort = ns and ns.cfg and ns.cfg.shortNumbers == true
      local abbrev = useShort and TryBlizzardAbbrev(value) or nil
      if abbrev then
        SafeSetText(bar.valueText, abbrev)
      else
        SafeSetText(bar.valueText, value)
      end
    end
  end

  if bar.perText then
    if dIsNumber then
      SafeSetText(bar.perText, floor(d) .. "%")
    elseif d ~= nil then
      SetPercentText(bar.perText, d)
    else
      SafeSetText(bar.perText, "")
    end
  end
end
