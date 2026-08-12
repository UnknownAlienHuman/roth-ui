local addonName, ns = ...

local type = type
local select = select
local format = string.format
local GetTime = GetTime
local UnitGUID = UnitGUID
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local defer = ns and ns.defer
local INTERRUPTED_TEXT = _G.INTERRUPTED or "Interrupted"
local FAILED_TEXT = _G.FAILED or "Failed"

local runtime = ns.TargetCastbarRuntime or {}
ns.TargetCastbarRuntime = runtime

local CASTBAR_INTERRUPT_HOLD = 0.8
local CAST_FALLBACK_CAST = { 1.0, 0.7, 0.0 }
local CAST_FALLBACK_CHAN = { 0.0, 1.0, 0.0 }
local CAST_FALLBACK_FAIL = { 1.0, 0.15, 0.15 }
local NON_INTERRUPT_TINT = 0.9
local OVERLAY_ALPHA = 1.0

local DEFAULT_TARGET_CAST_COLORS = {
  interruptibleCast = { r = CAST_FALLBACK_CAST[1], g = CAST_FALLBACK_CAST[2], b = CAST_FALLBACK_CAST[3], a = 1 },
  interruptibleChannel = { r = CAST_FALLBACK_CHAN[1], g = CAST_FALLBACK_CHAN[2], b = CAST_FALLBACK_CHAN[3], a = 1 },
  nonInterruptible = { r = NON_INTERRUPT_TINT, g = NON_INTERRUPT_TINT, b = NON_INTERRUPT_TINT, a = 1 },
  failedOrInterrupted = { r = CAST_FALLBACK_FAIL[1], g = CAST_FALLBACK_FAIL[2], b = CAST_FALLBACK_FAIL[3], a = 1 },
}

local ResolveTrackedUnit
local UsesChannelState

local function GetFunc()
  return ns and ns.func or nil
end

local function IsSecretValue(value)
  local func = GetFunc()
  if func and type(func.IsSecretValue) == "function" then
    return func.IsSecretValue(value)
  end

  local safety = ns and ns.safety
  local predicate = _G.issecretvalue or _G.IsSecretValue or (safety and safety.IsSecret)
  return type(predicate) == "function" and predicate(value) or false
end

local function ResolveCastbarConfig(bar)
  if not bar then
    return nil
  end
  return bar.castbarCfg or bar.cfg
end

local function ApplyBarTint(bar, r, g, b, a)
  if not bar then
    return
  end

  if bar.SetStatusBarColor then
    bar:SetStatusBarColor(r, g, b, a)
  end

  local texture = bar.GetStatusBarTexture and bar:GetStatusBarTexture() or nil
  if texture and texture.SetVertexColor then
    texture:SetVertexColor(r, g, b, a)
  end

  if bar.bar and bar.bar.SetVertexColor then
    bar.bar:SetVertexColor(r, g, b, a)
  end
end

local function ResolveColor(bar, stateKey)
  local castbarCfg = ResolveCastbarConfig(bar)
  local colors = castbarCfg and castbarCfg.color or nil
  local semantic = type(colors) == "table" and type(colors.semantic) == "table" and colors.semantic or nil
  local color = semantic and semantic[stateKey] or nil

  if type(color) ~= "table" and type(colors) == "table" then
    if stateKey == "interruptibleCast" then
      color = colors.bar
    elseif stateKey == "nonInterruptible" then
      color = colors.shieldbar or colors.bar
    end
  end

  if type(color) ~= "table" then
    color = DEFAULT_TARGET_CAST_COLORS[stateKey]
  end

  local r = color and (color.r or color[1]) or 1
  local g = color and (color.g or color[2]) or 1
  local b = color and (color.b or color[3]) or 1
  local a = color and color.a
  return r, g, b, (type(a) == "number" and a) or 1
end

local function ApplyColorState(bar, stateKey)
  local r, g, b, a = ResolveColor(bar, stateKey)
  ApplyBarTint(bar, r, g, b, a)
  if bar then
    bar._rothLastColorState = stateKey
  end
end

local function HideOverlayTexture(texture)
  if not texture then
    return
  end
  if texture.SetAlpha then
    texture:SetAlpha(0)
  end
  if texture.Hide then
    texture:Hide()
  end
end

local function EnsureNonInterruptOverlay(bar)
  if not bar or bar._rothNIOverlay then
    return
  end

  local fillTexture = bar.GetStatusBarTexture and bar:GetStatusBarTexture() or nil

  local base = bar:CreateTexture(nil, "OVERLAY", nil, 5)
  if fillTexture then
    base:SetAllPoints(fillTexture)
  else
    base:SetAllPoints(bar)
  end
  base:SetTexture("Interface\\AddOns\\Roth_UI\\media\\statusbar3.tga")
  base:SetVertexColor(NON_INTERRUPT_TINT, NON_INTERRUPT_TINT, NON_INTERRUPT_TINT, 1)
  HideOverlayTexture(base)
  bar._rothNIOverlayBase = base

  local overlay = bar:CreateTexture(nil, "OVERLAY", nil, 6)
  if fillTexture then
    overlay:SetAllPoints(fillTexture)
  else
    overlay:SetAllPoints(bar)
  end
  overlay:SetTexture("Interface\\AddOns\\Roth_UI\\media\\statusbar3.tga")
  overlay:SetVertexColor(NON_INTERRUPT_TINT, NON_INTERRUPT_TINT, NON_INTERRUPT_TINT, 1)
  HideOverlayTexture(overlay)
  bar._rothNIOverlay = overlay
end

local function OverlaySetFromBoolean(texture, secretBool, fallbackBool)
  if not texture then
    return
  end

  if texture.SetAlphaFromBoolean then
    texture:SetAlphaFromBoolean(secretBool, OVERLAY_ALPHA, 0)
    if texture.Show then
      texture:Show()
    end
    return
  end

  local secret = IsSecretValue(secretBool)
  if texture.SetShown and not secret and type(secretBool) == "boolean" then
    if texture.SetAlpha then
      texture:SetAlpha(OVERLAY_ALPHA)
    end
    texture:SetShown(secretBool)
    return
  end

  local enabled = fallbackBool == true
  if texture.SetAlpha then
    texture:SetAlpha(enabled and OVERLAY_ALPHA or 0)
  end
  if enabled then
    if texture.Show then
      texture:Show()
    end
  elseif texture.Hide then
    texture:Hide()
  end
end

local function GetNotInterruptibleFromAPI(unitToken, isChannel)
  if isChannel then
    return select(7, UnitChannelInfo(unitToken))
  end
  return select(8, UnitCastingInfo(unitToken))
end

local function NormalizeInterruptibilityFlag(value)
  if IsSecretValue(value) then
    return nil
  end
  if type(value) == "boolean" then
    return value
  end
  return nil
end

local function NormalizeTrackedValue(value)
  if value == nil or IsSecretValue(value) then
    return nil
  end

  local valueType = type(value)
  if valueType == "number" or valueType == "string" then
    return value
  end

  return nil
end

local function ResolveUnitIdentity(unitToken)
  if type(unitToken) ~= "string" or unitToken == "" then
    return nil
  end

  return NormalizeTrackedValue(UnitGUID(unitToken))
end

local function ClearCastIdentity(bar)
  if not bar then
    return
  end

  bar._rothCastUnitGUID = nil
  bar._rothCastKind = nil
  bar._rothCastGUID = nil
  bar._rothCastBarID = nil
  bar._rothCastSpellID = nil
  bar._rothCastStartMS = nil
  bar._rothCastEndMS = nil
end

local function HasStoredCastIdentity(bar)
  return bar and (
    bar._rothCastUnitGUID ~= nil or
    bar._rothCastGUID ~= nil or
    bar._rothCastBarID ~= nil or
    bar._rothCastSpellID ~= nil or
    bar._rothCastStartMS ~= nil or
    bar._rothCastEndMS ~= nil
  ) or false
end

local function RememberCastIdentity(bar, unitGuid, kind, castGUID, castBarID, spellID, startMS, endMS)
  if not bar then
    return
  end

  bar._rothCastUnitGUID = unitGuid
  bar._rothCastKind = kind
  bar._rothCastGUID = castGUID
  bar._rothCastBarID = castBarID
  bar._rothCastSpellID = spellID
  bar._rothCastStartMS = startMS
  bar._rothCastEndMS = endMS
end

local function QueryCastIdentity(unitToken, preferChannelState)
  unitToken = unitToken or "target"
  local unitGuid = ResolveUnitIdentity(unitToken)

  local function QueryCast()
    local name, _, _, startTimeMS, endTimeMS, _, castGUID, notInterruptible, spellID, castBarID = UnitCastingInfo(unitToken)
    if not name then
      return nil
    end

    return unitGuid, "cast", NormalizeTrackedValue(castGUID), NormalizeTrackedValue(castBarID),
      NormalizeTrackedValue(spellID), NormalizeTrackedValue(startTimeMS), NormalizeTrackedValue(endTimeMS),
      NormalizeInterruptibilityFlag(notInterruptible)
  end

  local function QueryChannel()
    local name, _, _, startTimeMS, endTimeMS, _, notInterruptible, spellID, isEmpowered, _, castBarID = UnitChannelInfo(unitToken)
    if not name then
      return nil
    end

    local kind = NormalizeTrackedValue(isEmpowered) == true and "empower" or "channel"
    return unitGuid, kind, nil, NormalizeTrackedValue(castBarID), NormalizeTrackedValue(spellID),
      NormalizeTrackedValue(startTimeMS), NormalizeTrackedValue(endTimeMS), NormalizeInterruptibilityFlag(notInterruptible)
  end

  if preferChannelState then
    local unitGuidValue, kind, castGUID, castBarID, spellID, startMS, endMS, notInterruptible = QueryChannel()
    if kind then
      return unitGuidValue, kind, castGUID, castBarID, spellID, startMS, endMS, notInterruptible
    end
    return QueryCast()
  end

  local unitGuidValue, kind, castGUID, castBarID, spellID, startMS, endMS, notInterruptible = QueryCast()
  if kind then
    return unitGuidValue, kind, castGUID, castBarID, spellID, startMS, endMS, notInterruptible
  end

  return QueryChannel()
end

local function CurrentUnitMatchesStored(bar, unitToken)
  if not HasStoredCastIdentity(bar) then
    return true
  end

  local storedGuid = bar._rothCastUnitGUID
  if storedGuid == nil then
    return true
  end

  local currentGuid = ResolveUnitIdentity(unitToken)
  if currentGuid == nil then
    return true
  end

  return currentGuid == storedGuid
end

local function VisibleBarMatchesStoredIdentity(bar)
  if not HasStoredCastIdentity(bar) then
    return true
  end

  local castBarID = NormalizeTrackedValue(bar and bar.castID)
  if bar._rothCastBarID ~= nil and castBarID ~= nil then
    return bar._rothCastBarID == castBarID
  end

  local spellID = NormalizeTrackedValue(bar and bar.spellID)
  if bar._rothCastSpellID ~= nil and spellID ~= nil then
    return bar._rothCastSpellID == spellID
  end

  return true
end

local function SyncCastIdentity(bar, unitToken)
  if not bar then
    return false, nil
  end

  local trackedUnit = ResolveTrackedUnit(bar, unitToken)
  local unitGuid, kind, castGUID, castBarID, spellID, startMS, endMS, notInterruptible = QueryCastIdentity(
    trackedUnit,
    UsesChannelState(bar)
  )

  if not kind then
    return false, nil
  end

  RememberCastIdentity(bar, unitGuid, kind, castGUID, castBarID, spellID, startMS, endMS)
  return true, notInterruptible
end

local function HideNonInterruptOverlay(bar)
  if not bar then
    return
  end
  HideOverlayTexture(bar._rothNIOverlayBase)
  HideOverlayTexture(bar._rothNIOverlay)
end

local function HasActiveCast(bar)
  return bar and (bar.casting or bar.channeling or bar.empowering)
end

UsesChannelState = function(bar)
  return bar and (bar.channeling == true or bar.empowering == true)
end

local function UsesChannelVisual(bar)
  return bar and bar.channeling == true and not bar.empowering
end

ResolveTrackedUnit = function(bar, unitToken)
  if not bar then
    return "target"
  end

  if unitToken and unitToken ~= "" then
    bar._rothUnit = unitToken
  elseif not bar._rothUnit or bar._rothUnit == "" then
    bar._rothUnit = "target"
  end

  return bar._rothUnit
end

local function HideShield(bar)
  if bar and bar.Shield and bar.Shield.Hide then
    bar.Shield:Hide()
  end
end

local function ClearTransientVisuals(bar, clearLastColorState)
  if not bar then
    return
  end

  bar._rothNotInterruptible = nil
  ClearCastIdentity(bar)
  if clearLastColorState then
    bar._rothLastColorState = nil
  end

  HideNonInterruptOverlay(bar)
  HideShield(bar)
end

local function ResolveInterruptibility(bar, passedNotInterruptible)
  if not bar then
    return nil
  end

  local unitToken = ResolveTrackedUnit(bar)
  local apiValue = GetNotInterruptibleFromAPI(unitToken, UsesChannelState(bar))
  local normalized = NormalizeInterruptibilityFlag(apiValue)
  if normalized ~= nil then
    return normalized
  end

  normalized = NormalizeInterruptibilityFlag(passedNotInterruptible)
  if normalized ~= nil then
    return normalized
  end

  return NormalizeInterruptibilityFlag(bar.notInterruptible)
end

local function SyncNonInterruptOverlay(bar)
  if not bar then
    return
  end

  EnsureNonInterruptOverlay(bar)
  local overlay = bar._rothNIOverlay
  local base = bar._rothNIOverlayBase
  if not (overlay and base) then
    return
  end

  if not HasActiveCast(bar) then
    HideNonInterruptOverlay(bar)
    return
  end

  local now = GetTime and GetTime() or 0
  local nextSync = bar._rothNINextSync or 0
  if now < nextSync then
    return
  end
  bar._rothNINextSync = now + 0.1

  local unitToken = ResolveTrackedUnit(bar)
  local isChannel = UsesChannelState(bar)
  local notInterruptible = GetNotInterruptibleFromAPI(unitToken, isChannel)

  if base.Show then
    base:Show()
  end
  if overlay.Show then
    overlay:Show()
  end

  OverlaySetFromBoolean(base, notInterruptible, bar._rothNotInterruptible)
  OverlaySetFromBoolean(overlay, notInterruptible, bar._rothNotInterruptible)
end

local function ApplyInterruptVisual(bar, isChannel)
  if not bar then
    return
  end

  local stateKey
  if bar._rothNotInterruptible == true then
    stateKey = "nonInterruptible"
  elseif isChannel then
    stateKey = "interruptibleChannel"
  else
    stateKey = "interruptibleCast"
  end

  ApplyColorState(bar, stateKey)

  if bar.Shield then
    if bar._rothNotInterruptible == true then
      if bar.Shield.Show then
        bar.Shield:Show()
      end
    else
      HideShield(bar)
    end
  end

  SyncNonInterruptOverlay(bar)
end

local function ApplyCurrentCastVisual(bar, unitToken, passedNotInterruptible)
  if not HasActiveCast(bar) then
    return
  end

  local trackedUnit = ResolveTrackedUnit(bar, unitToken)
  local hasCurrentCast, currentNotInterruptible = SyncCastIdentity(bar, trackedUnit)
  if not hasCurrentCast and not CurrentUnitMatchesStored(bar, trackedUnit) then
    runtime.ApplyInitialVisual(bar)
    return
  end
  if not hasCurrentCast and not VisibleBarMatchesStoredIdentity(bar) then
    runtime.ApplyInitialVisual(bar)
    return
  end

  if currentNotInterruptible ~= nil then
    bar._rothNotInterruptible = currentNotInterruptible
  else
    bar._rothNotInterruptible = ResolveInterruptibility(bar, passedNotInterruptible)
  end
  ApplyInterruptVisual(bar, UsesChannelVisual(bar))
end

local function ResolveInterruptSource(unit, interruptedBy)
  local func = GetFunc()
  local src = func and func.ResolveInterruptSourceName and func.ResolveInterruptSourceName(interruptedBy) or nil
  if not src and func and func.GetCachedInterruptSource then
    src = func.GetCachedInterruptSource(unit)
  end
  return src
end

local function PostCastInterrupted(bar, unit, interruptedBy)
  if not (bar and bar.Text) then
    return
  end

  local trackedUnit = ResolveTrackedUnit(bar, unit)
  local hasCurrentCast = SyncCastIdentity(bar, trackedUnit)
  if hasCurrentCast then
    ApplyCurrentCastVisual(bar, trackedUnit)
    return
  end
  if not CurrentUnitMatchesStored(bar, trackedUnit) or not VisibleBarMatchesStoredIdentity(bar) then
    runtime.ApplyInitialVisual(bar)
    return
  end

  local text = INTERRUPTED_TEXT
  local src = ResolveInterruptSource(unit, interruptedBy)
  if src and src ~= "" then
    text = format("%s: %s", INTERRUPTED_TEXT, src)
  end

  ClearTransientVisuals(bar, false)
  bar.Text:SetText(text)
  ApplyColorState(bar, "failedOrInterrupted")
end

local function PostCastFailed(bar)
  if not bar then
    return
  end

  local trackedUnit = ResolveTrackedUnit(bar)
  local hasCurrentCast = SyncCastIdentity(bar, trackedUnit)
  if hasCurrentCast then
    ApplyCurrentCastVisual(bar, trackedUnit)
    return
  end
  if not CurrentUnitMatchesStored(bar, trackedUnit) or not VisibleBarMatchesStoredIdentity(bar) then
    runtime.ApplyInitialVisual(bar)
    return
  end

  ClearTransientVisuals(bar, false)
  if bar.Spark and bar.Spark.Hide then
    bar.Spark:Hide()
  end
  if bar.Text then
    bar.Text:SetText(FAILED_TEXT)
  end
  ApplyColorState(bar, "failedOrInterrupted")
end

function runtime.ApplyInitialVisual(bar)
  if not bar then
    return
  end
  ClearTransientVisuals(bar, true)
  EnsureNonInterruptOverlay(bar)
  ApplyColorState(bar, "interruptibleCast")
end

function runtime.Bind(bar, unitToken)
  if not bar then
    return
  end

  bar._rothUnit = unitToken or bar._rothUnit or "target"
  bar.timeToHold = bar.timeToHold or CASTBAR_INTERRUPT_HOLD
  EnsureNonInterruptOverlay(bar)
  HideNonInterruptOverlay(bar)

  bar.PostCastStart = runtime.PostCastStart
  bar.PostCastFail = runtime.PostCastFail
  bar.PostChannelStart = runtime.PostChannelStart
  bar.PostCastInterruptible = runtime.PostCastInterruptible
  bar.PostChannelInterruptible = runtime.PostChannelInterruptible
  bar.PostCastStop = runtime.PostCastStop
  bar.PostChannelStop = runtime.PostCastStop
  bar.PostCastInterrupted = runtime.PostCastInterrupted
  bar.PostUpdate = runtime.PostUpdate

  runtime.ApplyInitialVisual(bar)
end

function runtime.PostCastStart(bar, unitToken)
  ApplyCurrentCastVisual(bar, unitToken)
end

function runtime.PostChannelStart(bar, unitToken)
  ApplyCurrentCastVisual(bar, unitToken)
end

function runtime.PostCastInterruptible(bar, unitToken, passedNotInterruptible)
  ApplyCurrentCastVisual(bar, unitToken, passedNotInterruptible)
end

function runtime.PostChannelInterruptible(bar, unitToken, passedNotInterruptible)
  ApplyCurrentCastVisual(bar, unitToken, passedNotInterruptible)
end

function runtime.PostCastStop(bar)
  if not bar then
    return
  end
  local trackedUnit = ResolveTrackedUnit(bar)
  local hasCurrentCast = SyncCastIdentity(bar, trackedUnit)
  if hasCurrentCast then
    ApplyCurrentCastVisual(bar, trackedUnit)
    return
  end
  if not CurrentUnitMatchesStored(bar, trackedUnit) or not VisibleBarMatchesStoredIdentity(bar) then
    runtime.ApplyInitialVisual(bar)
    return
  end
  ClearTransientVisuals(bar, true)
  ApplyColorState(bar, "interruptibleCast")
end

function runtime.PostCastFail(bar)
  PostCastFailed(bar)
end

function runtime.PostCastInterrupted(bar, unitToken, interruptedBy)
  PostCastInterrupted(bar, unitToken, interruptedBy)
end

function runtime.PostUpdate(bar)
  ApplyCurrentCastVisual(bar)
end

function runtime.RefreshBar(bar)
  if not bar then
    return
  end

  if HasActiveCast(bar) then
    ApplyCurrentCastVisual(bar)
    return
  end

  if bar._rothLastColorState == "failedOrInterrupted" then
    ApplyColorState(bar, "failedOrInterrupted")
    return
  end

  runtime.ApplyInitialVisual(bar)
end

function runtime.RefreshActive()
  local targetFrame = ns and ns.unit and ns.unit.target
  local bar = targetFrame and targetFrame.Castbar
  runtime.RefreshBar(bar)
end

function runtime.ScheduleActiveRefresh()
  local function RefreshIfCurrent()
    runtime.RefreshActive()
  end

  if defer and type(defer.RunWithRetry) == "function" then
    defer.RunWithRetry("target_castbar:active_refresh", RefreshIfCurrent)
    return
  end

  RefreshIfCurrent()
end

ns.RefreshTargetCastbarColorContract = runtime.ScheduleActiveRefresh
