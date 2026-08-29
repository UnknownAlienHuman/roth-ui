-- Target/focus/boss castbar presentation for oUF 14.
--
-- oUF owns cast discovery, timing, identity and interruptibility events. Roth UI
-- only maps oUF callback values into native widget sinks. In particular, the
-- potentially secret notInterruptible boolean is never compared, formatted,
-- cached or used as Lua application state.

local addonName, ns = ...

local runtime = ns.TargetCastbarRuntime or {}
ns.TargetCastbarRuntime = runtime

local type = type
local pairs = pairs
local CreateColor = assert(_G.CreateColor, "Roth_UI: CreateColor is required by target_castbar.lua")

local DEFAULTS = {
  interruptibleCast = { r = 1.0, g = 0.7, b = 0.0, a = 1.0 },
  nonInterruptible = { r = 0.9, g = 0.9, b = 0.9, a = 1.0 },
  failedOrInterrupted = { r = 1.0, g = 0.15, b = 0.15, a = 1.0 },
}

local TRANSPARENT = CreateColor(0, 0, 0, 0)
local boundBars = setmetatable({}, { __mode = "k" })

local function ResolveColorTable(bar, key)
  local castbarCfg = bar and (bar.castbarCfg or bar.cfg)
  local colors = type(castbarCfg) == "table" and castbarCfg.color or nil
  local semantic = type(colors) == "table" and colors.semantic or nil
  local value = type(semantic) == "table" and semantic[key] or nil

  if type(value) ~= "table" and type(colors) == "table" then
    if key == "interruptibleCast" then
      value = colors.bar
    elseif key == "nonInterruptible" then
      value = colors.shieldbar
    end
  end

  return type(value) == "table" and value or DEFAULTS[key]
end

local function ResolveRGBA(bar, key)
  local value = ResolveColorTable(bar, key)
  local r = tonumber(value and (value.r or value[1])) or 1
  local g = tonumber(value and (value.g or value[2])) or 1
  local b = tonumber(value and (value.b or value[3])) or 1
  local a = tonumber(value and (value.a or value[4])) or 1
  return r, g, b, a
end

local function ResolveColorObject(bar, key)
  bar.__rothCastColors = bar.__rothCastColors or {}
  local cache = bar.__rothCastColors
  local r, g, b, a = ResolveRGBA(bar, key)
  local fingerprint = table.concat({ r, g, b, a }, ":")
  local record = cache[key]
  if record and record.fingerprint == fingerprint then
    return record.color
  end

  local color = CreateColor(r, g, b, a)
  cache[key] = { fingerprint = fingerprint, color = color }
  return color
end

local function SetKnownBarColor(bar, key)
  if not (bar and bar.SetStatusBarColor) then
    return
  end
  local r, g, b, a = ResolveRGBA(bar, key)
  bar:SetStatusBarColor(r, g, b, a)
end

local function EnsureNativeSinks(bar)
  if not bar or bar.__rothInterruptOverlay then
    return
  end

  local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture() or nil
  local overlay = bar:CreateTexture(nil, "OVERLAY", nil, 4)
  if fill then
    overlay:SetAllPoints(fill)
  else
    overlay:SetAllPoints(bar)
  end
  overlay:SetTexture((bar.castbarCfg and bar.castbarCfg.texture) or "Interface\\TargetingFrame\\UI-StatusBar")
  overlay:SetAlpha(0)
  bar.__rothInterruptOverlay = overlay

  local shield = bar.Shield
  if not shield then
    shield = bar:CreateTexture(nil, "OVERLAY", nil, 5)
    shield:SetTexture("Interface\\CastingBar\\UI-CastingBar-Shield")
    shield:SetSize(26, 26)
    shield:SetPoint("LEFT", bar, "LEFT", -10, 0)
    shield:SetBlendMode("BLEND")
    shield:SetAlpha(0)
    bar.Shield = shield
  end
end

local function ClearConditionalSinks(bar)
  if not bar then
    return
  end
  if bar.__rothInterruptOverlay then
    bar.__rothInterruptOverlay:SetAlpha(0)
  end
  if bar.Shield then
    bar.Shield:SetAlpha(0)
  end
end

local function ApplyInterruptibility(bar, notInterruptible)
  EnsureNativeSinks(bar)
  SetKnownBarColor(bar, "interruptibleCast")

  local overlay = bar and bar.__rothInterruptOverlay
  if overlay and type(overlay.SetVertexColorFromBoolean) == "function" then
    overlay:SetAlpha(1)
    overlay:SetVertexColorFromBoolean(
      notInterruptible,
      ResolveColorObject(bar, "nonInterruptible"),
      TRANSPARENT
    )
    overlay:Show()
  end

  local shield = bar and bar.Shield
  if shield and type(shield.SetAlphaFromBoolean) == "function" then
    shield:SetAlphaFromBoolean(notInterruptible, 1, 0)
    shield:Show()
  end
end

local function ApplyFailure(bar)
  ClearConditionalSinks(bar)
  SetKnownBarColor(bar, "failedOrInterrupted")
end

-- Exact oUF 14.0.2 callback signature.
function runtime.PostCastStart(bar, unit, spellID, notInterruptible)
  ApplyInterruptibility(bar, notInterruptible)
end

-- Exact oUF 14.0.2 callback signature.
function runtime.PostCastInterruptible(bar, unit, spellID, notInterruptible)
  ApplyInterruptibility(bar, notInterruptible)
end

function runtime.PostCastFail(bar)
  ApplyFailure(bar)
end

function runtime.PostCastInterrupted(bar)
  ApplyFailure(bar)
end

function runtime.PostCastStop(bar)
  ClearConditionalSinks(bar)
end

function runtime.ApplyInitialVisual(bar)
  if not bar then
    return
  end
  EnsureNativeSinks(bar)
  ClearConditionalSinks(bar)
  SetKnownBarColor(bar, "interruptibleCast")
end

function runtime.Bind(bar, unitToken)
  if not bar then
    return false
  end

  runtime.ApplyInitialVisual(bar)
  bar.__rothCastUnit = unitToken
  bar.PostCastStart = runtime.PostCastStart
  bar.PostCastInterruptible = runtime.PostCastInterruptible
  bar.PostCastFail = runtime.PostCastFail
  bar.PostCastInterrupted = runtime.PostCastInterrupted
  bar.PostCastStop = runtime.PostCastStop
  boundBars[bar] = true
  return true
end

function runtime.RefreshActive()
  for bar in pairs(boundBars) do
    bar.__rothCastColors = nil
    if bar.IsShown and bar:IsShown() and type(bar.ForceUpdate) == "function" then
      bar:ForceUpdate()
    else
      runtime.ApplyInitialVisual(bar)
    end
  end
end

function runtime.ScheduleActiveRefresh()
  local defer = ns and ns.defer
  if defer and type(defer.RunNextFrame) == "function" then
    defer.RunNextFrame("target_castbar:refresh", runtime.RefreshActive, false)
  else
    runtime.RefreshActive()
  end
end
