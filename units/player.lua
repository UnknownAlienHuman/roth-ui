--get the addon namespace
local addon, ns = ...

--get oUF namespace (just in case needed)
local oUF = ns.oUF or oUF

--get the config
local cfg = ns.cfg
--get the database
local db = ns.db
local storeApi = ns and ns.store
local orbPersistence = ns and ns.orbPersistence
local orbText = assert(ns and ns.OrbTextController, "Roth_UI: ns.OrbTextController is required by units/player.lua")

--get the functions
local func = ns.func
local safety = assert(ns and ns.safety, "Roth_UI: safety helpers are required by units/player.lua")

local mediapath = ns.mediapath or "Interface\\AddOns\\Roth_UI\\media\\"

--get the unit container
local unit = ns.unit

--get the bars container
local bars = ns.bars

local type = type
local pairs = pairs
local format = format
local floor = floor
local max = math.max
local min = math.min
local abs, sin, pi = math.abs, math.sin, math.pi
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsConnected = UnitIsConnected
local tinsert = tinsert
local INTERRUPTED_TEXT = _G.INTERRUPTED or "Interrupted"
local CASTBAR_INTERRUPT_HOLD = 0.8

local function ResolveOrbConfig(orbType)
  if type(storeApi) == "table" and type(storeApi.GetOrbConfig) == "function" then
    local config = storeApi.GetOrbConfig(orbType)
    if type(config) == "table" then
      return config
    end
  end
  return nil
end

---------------------------------------------
-- UNIT SPECIFIC FUNCTIONS
---------------------------------------------

--init parameters
local initUnitParameters = function(self)
  self:SetFrameStrata("LOW")
  self:SetFrameLevel(1)
  self:SetSize(self.cfg.size, self.cfg.size)
  self:SetScale(self.cfg.scale)
  self:SetPoint(self.cfg.pos.a1, self.cfg.pos.af, self.cfg.pos.a2, self.cfg.pos.x, self.cfg.pos.y)
  self:RegisterForClicks("AnyDown")
  self:SetScript("OnEnter", UnitFrame_OnEnter)
  self:SetScript("OnLeave", UnitFrame_OnLeave)
  func.applyDragFunctionality(self, "orb")
end

--create the angel
local createAngelFrame = function(self)
  if not self.cfg.art.angel.show then return end
  local f = CreateFrame("Frame", "Roth_UIAngelFrame", self)
  f:SetSize(320, 160)
  f:SetFrameStrata("MEDIUM")
  f:SetFrameLevel(0)
  f:SetPoint(self.cfg.art.angel.pos.a1, self.cfg.art.angel.pos.af, self.cfg.art.angel.pos.a2, self.cfg.art.angel.pos.x,
    self.cfg.art.angel.pos.y)
  f:SetScale(self.cfg.art.angel.scale)
  func.applyDragFunctionality(f)
  local t = f:CreateTexture(nil, "BACKGROUND", nil, 2)
  t:SetAllPoints(f)
  t:SetTexture("Interface\\AddOns\\Roth_UI\\media\\d3_angel2")
end

--create the demon
local createDemonFrame = function(self)
  if not self.cfg.art.demon.show then return end
  local f = CreateFrame("Frame", "Roth_UIDemonFrame", self)
  f:SetSize(320, 160)
  f:SetFrameStrata("MEDIUM")
  f:SetFrameLevel(0)
  f:SetPoint(self.cfg.art.demon.pos.a1, self.cfg.art.demon.pos.af, self.cfg.art.demon.pos.a2, self.cfg.art.demon.pos.x,
    self.cfg.art.demon.pos.y)
  f:SetScale(self.cfg.art.demon.scale)
  func.applyDragFunctionality(f)
  local t = f:CreateTexture(nil, "BACKGROUND", nil, 2)
  t:SetAllPoints(f)
  t:SetTexture("Interface\\AddOns\\Roth_UI\\media\\d3_demon2")
end

--create the bottomline
local createBottomLine = function(self)
  local cfg = self.cfg.art.bottomline
  if not cfg.show then return end
  local f = CreateFrame("Frame", "Roth_UIBottomLine", self)
  f:SetFrameStrata("MEDIUM")
  f:SetFrameLevel(0)
  f:SetSize(600, 112)
  f:SetPoint(cfg.pos.a1, cfg.pos.af, cfg.pos.a2, cfg.pos.x, cfg.pos.y)
  f:SetScale(cfg.scale)
  func.applyDragFunctionality(f, "bottomline")
  local t = f:CreateTexture(nil, "BACKGROUND", nil, 3)
  t:SetAllPoints(f)
  t:SetTexture("Interface\\AddOns\\Roth_UI\\media\\d3_bottom")
end
--post update orb func
--
-- WoW 12.x: cur/max may become Secret Values in combat. Do not do arithmetic,
-- comparisons, or boolean tests on Secret Values. We only compute percent/lowHP
-- when both numbers are NOT secret; otherwise we pass the raw Secret Value to
-- FontString:SetText.
assert(
  func and func.IsSecretValue and func.GetScaleTo100Curve and func.SafeUnitHealthPercent and func.SafeUnitPowerPercent,
  "Roth_UI: units/player.lua requires core/lib helpers")
local IsSecretValue = func.IsSecretValue
local SafeUnitHealthPercent = func.SafeUnitHealthPercent
local SafeUnitPowerPercent = func.SafeUnitPowerPercent
local CoerceVisibleNumber = func.CoerceAccessibleNumber
if type(CoerceVisibleNumber) ~= "function" then
  local CanAccessValue = _G.canaccessvalue
  CoerceVisibleNumber = function(v)
    if IsSecretValue(v) then
      if type(CanAccessValue) == "function" and CanAccessValue(v) then
        local n = tonumber(v)
        if type(n) == "number" then
          return n
        end
      end
      return nil
    end
    if v == nil then return nil end
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
end

local SafeSetText = func.SafeSetText or function(fs, v)
  if not fs then return end
  if IsSecretValue(v) then
    fs:SetText(v)
    return
  end
  if v == nil then
    fs:SetText("")
    return
  end
  fs:SetText(v)
end
local SafeSetPercentText = func.SetPercentText or function(fs, v)
  if not fs then return end
  if IsSecretValue(v) then
    fs:SetFormattedText("%.0f%%", v)
    return
  end
  if v == nil then
    SafeSetText(fs, "")
    return
  end
  local n = tonumber(v)
  if type(n) == "number" then
    SafeSetText(fs, floor(n) .. "%")
    return
  end
  SafeSetText(fs, v)
end

local function FormatRawNumber(v)
  if type(v) ~= "number" then
    return tostring(v)
  end
  local rounded = floor(v + 0.5)
  if abs(v - rounded) < 0.01 then
    return tostring(rounded)
  end
  local s = string.format("%.1f", v)
  if s:sub(-2) == ".0" then
    s = s:sub(1, -3)
  end
  return s
end

local defaultOrbModes = {
  top = orbText.GetDefaultMode("top"),
  bottom = orbText.GetDefaultMode("bottom"),
}

local function GetDefaultOrbMode(orbType, which)
  if db and db.GetOrbDefaults then
    local defs = db:GetOrbDefaults()
    local orbDefaults = type(defs) == "table" and defs[orbType]
    local valueCfg = type(orbDefaults) == "table" and orbDefaults.value or nil
    return orbText.GetValueMode(valueCfg, which, defaultOrbModes[which])
  end
  return defaultOrbModes[which]
end

local function ResolveOrbValueMode(orbType, valueCfg, which)
  return orbText.GetValueMode(valueCfg, which, GetDefaultOrbMode(orbType, which))
end

-- Helper: coerce a potentially-secret value to a plain number for formatting.
-- Returns the number on success, nil on failure (value stays secret/unusable).
local function CoerceNum(v)
  if IsSecretValue(v) then
    return CoerceVisibleNumber(v)
  end
  if v == nil then return nil end
  if type(v) == "number" then return v end
  return tonumber(v)
end

-- Format percent: always returns a string or nil.
local function FmtPercent(d, withSign)
  local n = CoerceNum(d)
  if type(n) == "number" then
    local s = tostring(floor(n + 0.5))
    if withSign then s = s .. "%" end
    return s
  end
  return nil
end

local function FormatAccessibleNumber(v)
  if IsSecretValue(v) then
    return v
  end
  if v == nil then return "" end
  local n = CoerceNum(v)
  if type(n) == "number" then
    return func.numFormat(n)
  end
  return v
end

local function ResolveNumericOrbText(rawValue)
  local useShort = ns and ns.cfg and ns.cfg.shortNumbers == true
  if useShort then
    return FormatAccessibleNumber(rawValue), true
  end

  local n = CoerceNum(rawValue)
  if type(n) == "number" then
    return FormatRawNumber(n), true
  end
  if IsSecretValue(rawValue) then
    return rawValue, true, "%.0f"
  end
  return nil, false
end

local function EvalOrbMode(mode, d, value, maxv)
  if mode == "percent" then
    if IsSecretValue(d) then
      return d, true, "%.0f%%"
    end
    if d ~= nil then
      local s = FmtPercent(d, true)
      if s then return s, true end
    end
    return nil, false
  end
  if mode == "max" then
    return ResolveNumericOrbText(maxv)
  end
  return ResolveNumericOrbText(value)
end

local updateValue = function(bar, unit, cur, min, max)
  local orb = bar:GetParent()
  local orbcfg = ResolveOrbConfig(orb.type)
  local valueCfg = orbcfg and orbcfg.value
  -- Normalize signature (bar, unit, cur, max) vs (bar, unit, cur, min, max)
  local value = cur
  local maxv = max
  if (not IsSecretValue(maxv)) and maxv == nil then
    maxv = min
  end
  local coercedValue = CoerceVisibleNumber(value)
  if type(coercedValue) == "number" then
    value = coercedValue
  end
  local coercedMax = CoerceVisibleNumber(maxv)
  if type(coercedMax) == "number" then
    maxv = coercedMax
  end

  -- Player orbs: consume PostUpdate arguments from oUF directly.
  -- Secret/unavailable values are handled via CoerceVisibleNumber and guards below.
  local isPlayerUnit = unit and UnitIsUnit and UnitIsUnit(unit, 'player')
  local valueNum = CoerceVisibleNumber(value)
  local maxNum = CoerceVisibleNumber(maxv)
  if type(valueNum) == "number" then value = valueNum end
  if type(maxNum) == "number" then maxv = maxNum end

  local dead = unit and UnitIsDeadOrGhost(unit)
  if IsSecretValue(dead) then dead = false end
  local connected = unit and UnitIsConnected(unit)
  if IsSecretValue(connected) then connected = true end

  local powerToken
  if orb.type == "POWER" and unit then
    powerToken = select(2, UnitPowerType(unit))
    if IsSecretValue(powerToken) then powerToken = nil end
  end

  -- keep power color in sync even if oUF stops updating it dynamically
  if orb.type == "POWER" and bar.colorPower and unit then
    local token = powerToken
    local c = token and cfg.powercolors and cfg.powercolors[token] or nil
    if c then
      if bar._rothLastR ~= c.r or bar._rothLastG ~= c.g or bar._rothLastB ~= c.b or bar._rothLastA ~= 1 then
        bar._rothLastR, bar._rothLastG, bar._rothLastB, bar._rothLastA = c.r, c.g, c.b, 1
        bar:SetStatusBarColor(c.r, c.g, c.b, 1)
      end
    end
  end

  -- Percent: prefer Unit*Percent (Midnight-safe) because max values can be secret.
  local d
  if unit then
    if orb.type == "HEALTH" then
      d = SafeUnitHealthPercent(unit)
    else
      d = SafeUnitPowerPercent(unit)
    end
  end
  local dIsNumber = (not IsSecretValue(d)) and type(d) == "number"

  -- For player unit, compute percent from the non-secret values above.
  if (not dIsNumber) and isPlayerUnit and type(valueNum) == "number" and type(maxNum) == "number" and maxNum > 0 then
    d = math.floor(valueNum / maxNum * 100)
    dIsNumber = true
  end

  -- Fallback only if both inputs are not secret.
  if (d == nil) and type(valueNum) == "number" and type(maxNum) == "number" and maxNum > 0 then
    d = floor(valueNum / maxNum * 100)
    dIsNumber = true
  end

  local topMode = ResolveOrbValueMode(orb.type, valueCfg, "top")
  local bottomMode = ResolveOrbValueMode(orb.type, valueCfg, "bottom")
  local hideOnEmpty = valueCfg and valueCfg.hideOnEmpty and true or false
  local hideOnFull = valueCfg and valueCfg.hideOnFull and true or false
  local dedupeEligible = type(valueNum) == "number" and type(maxNum) == "number" and type(dead) == "boolean" and
      type(connected) == "boolean" and dIsNumber
  if dedupeEligible then
    local prev = bar._rothValueCache
    if prev
        and prev.value == valueNum
        and prev.maxv == maxNum
        and prev.dead == dead
        and prev.connected == connected
        and prev.percent == d
        and prev.powerToken == powerToken
        and prev.topMode == topMode
        and prev.bottomMode == bottomMode
        and prev.hideOnEmpty == hideOnEmpty
        and prev.hideOnFull == hideOnFull then
      return
    end
    if not prev then
      prev = {}
      bar._rothValueCache = prev
    end
    prev.value = valueNum
    prev.maxv = maxNum
    prev.dead = dead
    prev.connected = connected
    prev.percent = d
    prev.powerToken = powerToken
    prev.topMode = topMode
    prev.bottomMode = bottomMode
    prev.hideOnEmpty = hideOnEmpty
    prev.hideOnFull = hideOnFull
  else
    bar._rothValueCache = nil
  end

  -- spark visibility (cosmetic)
  if orb.spark then
    local hideSpark = false

    -- Spark is cosmetic; if alpha is 0, keep it disabled.
    if orb.spark.GetAlpha and orb.spark:GetAlpha() <= 0 then
      hideSpark = true
    elseif dead then
      hideSpark = true
    elseif dIsNumber and (d >= 99 or d <= 0) then
      hideSpark = true
    else
      -- When percent is unavailable (secret/unavailable), disable spark to avoid
      -- secret-value comparisons and cosmetic glitches.
      hideSpark = true
    end

    if hideSpark then
      orb.spark:Hide()
    else
      orb.spark:Show()
    end
  end

  -- skull/lowHP cosmetics (only when we have a non-secret percent)
  if orb.type == "HEALTH" then
    if orb.skull then
      if dead then orb.skull:Show() else orb.skull:Hide() end
    end
    if orb.lowHP then
      if (not dead) and dIsNumber and d <= 25 then
        orb.lowHP:Show()
      else
        orb.lowHP:Hide()
      end
    end
  end

  -- Numeric text for player orbs is now driven by semantic modes:
  -- current, max, or percent. Short formatting comes only from the global setting.
  local hideText = false
  if valueCfg and dIsNumber then
    if valueCfg.hideOnEmpty and d <= 0 then hideText = true end
    if valueCfg.hideOnFull and d >= 99 then hideText = true end
  end

  if bar.valueText then
    if hideText then
      bar.valueText:SetText("")
    else
      local topText, topResolved, topFormat = EvalOrbMode(topMode, d, value, maxv)
      if topResolved then
        if topFormat and IsSecretValue(topText) then
          bar.valueText._rothLastText = nil
          bar.valueText:SetFormattedText(topFormat, topText)
        else
          SafeSetText(bar.valueText, topText)
        end
      else
        if dead then
          SafeSetText(bar.valueText, DEAD or "DEAD")
        elseif type(valueNum) == "number" then
          SafeSetText(bar.valueText, func.numFormat(valueNum))
        else
          SafeSetText(bar.valueText, "")
        end
      end
    end
  end
  if bar.perText then
    if hideText then
      bar.perText:SetText("")
    else
      local bottomText, bottomResolved, bottomFormat = EvalOrbMode(bottomMode, d, value, maxv)
      if bottomResolved then
        if bottomFormat and IsSecretValue(bottomText) then
          bar.perText._rothLastText = nil
          bar.perText:SetFormattedText(bottomFormat, bottomText)
        else
          SafeSetText(bar.perText, bottomText)
        end
      else
        if dead then
          SafeSetText(bar.perText, "")
        elseif d ~= nil then
          SafeSetPercentText(bar.perText, d)
        else
          SafeSetText(bar.perText, "")
        end
      end
    end
  end

end

-- oUF 14 owns cast failure/interruption hold state through Castbar.timeToHold.
-- Roth UI does not mutate the framework's private cast state.

--update statusbar color hook

local updateStatusBarColor = function(bar, r, g, b)
  local orb = bar:GetParent()
  if orb.spark then orb.spark:SetVertexColor(r, g, b) end
  if orb.galaxies then
    for i = 1, #orb.galaxies do
      local galaxy = orb.galaxies[i]
      if galaxy then
        galaxy:SetVertexColor(r, g, b)
      end
    end
  end
  if orb.bubbles then
    for i = 1, #orb.bubbles do
      local bubble = orb.bubbles[i]
      if bubble then
        bubble:SetVertexColor(r, g, b)
      end
    end
  end
end

--create galaxy func
local createGalaxy = function(frame, orbType, x, y, size, duration, texture, sublevel, degree)
  local t = frame:CreateTexture(nil, "OVERLAY", nil, sublevel)
  t:SetSize(size, size)
  t:SetPoint("CENTER", x, y)
  t:SetTexture("Interface\\AddOns\\Roth_UI\\media\\" .. texture)
  t:SetBlendMode("ADD")
  t.ag = t:CreateAnimationGroup()
  t.ag.anim = t.ag:CreateAnimation("Rotation")
  t.ag.anim:SetDegrees(degree)
  t.ag.anim:SetDuration(duration)
  t.ag:Play()
  t.ag:SetLooping("REPEAT")
  return t
end

local function CreateOrbGalaxies(orb, alpha)
  if type(orb) ~= "table" or type(orb.fillClip) ~= "table" then
    return nil
  end
  if type(orb.galaxies) == "table" then
    return orb.galaxies
  end

  local a = type(alpha) == "number" and alpha or 0
  local size = orb.size or 0
  local fillClip = orb.fillClip

  orb.galaxies = {}
  local g1 = createGalaxy(fillClip, orb.type, 0, 0, size - 0, 120, "galaxy2", -8, 360)
  g1:SetAlpha(a)
  local g2 = createGalaxy(fillClip, orb.type, 0, -2, size - 20, 90, "galaxy", -7, 360)
  g2:SetAlpha(a)
  local g3 = createGalaxy(fillClip, orb.type, 0, -4, size - 5, 60, "galaxy4", -6, 360)
  g3:SetAlpha(a)
  orb.galaxies[1], orb.galaxies[2], orb.galaxies[3] = g1, g2, g3
  return orb.galaxies
end

local function CreateOrbBubbles(orb, alpha)
  if type(orb) ~= "table" or type(orb.fillClip) ~= "table" then
    return nil
  end
  if type(orb.bubbles) == "table" then
    return orb.bubbles
  end

  local a = type(alpha) == "number" and alpha or 0
  local size = orb.size or 0
  local fillClip = orb.fillClip

  orb.bubbles = {}
  local b1 = createGalaxy(fillClip, orb.type, -8, -3, size / 2, 10, "bubble", -5, 360)
  b1:SetAlpha(a)
  local b2 = createGalaxy(fillClip, orb.type, 0, 0, size - 20, 20, "bubble2", -4, -360)
  b2:SetAlpha(a)
  local b3 = createGalaxy(fillClip, orb.type, 12, 4, size - 40, 15, "bubble3", -3, 360)
  b3:SetAlpha(a)
  local b4 = createGalaxy(fillClip, orb.type, 0, 0, size - 5, 20, "bubble4", -2, 360)
  b4:SetAlpha(a)
  orb.bubbles[1], orb.bubbles[2], orb.bubbles[3], orb.bubbles[4] = b1, b2, b3, b4
  return orb.bubbles
end

--create orb func
local createOrb = function(self, orbType)
  --get the orb config
  if type(orbPersistence) == "table" and type(orbPersistence.RunPipeline) == "function" then
    orbPersistence.RunPipeline()
  elseif type(orbPersistence) == "table" and type(orbPersistence.EnsureStores) == "function" then
    orbPersistence.EnsureStores()
  end
  local orbcfg = ResolveOrbConfig(orbType)
  local name
  if orbType == "HEALTH" then
    name = "Roth_UIHealthOrb"
  else
    name = "Roth_UIPowerOrb"
  end
  --create the orb baseframe
  local orb = CreateFrame("Frame", name, self)
  --orb data
  orb.self = self
  orb.type = orbType
  orb.size = self.cfg.size
  orb:SetSize(orb.size, orb.size)
  --position the orb
  if orb.type == "POWER" then
    --reset the power to be on the opposite side of the health orb
    orb:SetPoint(self.cfg.pos.a1, self.cfg.pos.af, self.cfg.pos.a2, self.cfg.pos.x * (-1), self.cfg.pos.y)
    --make the power orb dragable
    func.applyDragFunctionality(orb, "orb")
  else
    --position the health orb ontop of the self object
    orb:SetPoint("CENTER")
  end

  if orb.type == "HEALTH" then
    --debuff glow
    local glow = orb:CreateTexture("$parentGlow", "BACKGROUND", nil, -7)
    glow:SetPoint("CENTER", 0, 0)
    glow:SetSize(self.cfg.size + 5, self.cfg.size + 5)
    glow:SetBlendMode("BLEND")
    glow:SetVertexColor(0, 1, 1, 0) -- set alpha to 0 to hide the texture
    glow:SetTexture("Interface\\AddOns\\Roth_UI\\media\\orb_debuff_glow")
    orb.glow = glow
    self.DebuffHighlight = orb.glow
    self.DebuffHighlightAlpha = 1
    self.DebuffHighlightFilter = false
  end


  --background
  local bg = orb:CreateTexture("$parentBG", "BACKGROUND", nil, -6)
  bg:SetAllPoints()
  bg:SetTexture("Interface\\AddOns\\Roth_UI\\media\\orb_back2")
  orb.bg = bg

  --filling statusbar
  local fill = CreateFrame("StatusBar", "$parentFill", orb)
  fill:SetAllPoints()
  fill:SetMinMaxValues(0, 100)
  fill:SetStatusBarTexture(orbcfg.filling.texture)
  fill:SetStatusBarColor(orbcfg.filling.color.r, orbcfg.filling.color.g, orbcfg.filling.color.b)
  fill:SetOrientation("VERTICAL")
  orb.fill = fill


  -- WoW 12.x: clip decorative layers to the StatusBarTexture height without any
  -- manual math (no comparisons/arithmetic on secret values required).
  fill.orbType = orb.type
  local sbtexClip = fill:GetStatusBarTexture()
  local fillClip = CreateFrame("Frame", nil, fill)
  fillClip:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT", 0, 0)
  fillClip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
  if sbtexClip then
    fillClip:SetPoint("TOPLEFT", sbtexClip, "TOPLEFT", 0, 0)
    fillClip:SetPoint("TOPRIGHT", sbtexClip, "TOPRIGHT", 0, 0)
  else
    fillClip:SetAllPoints(fill)
  end
  fillClip:SetClipsChildren(true)
  orb.fillClip = fillClip

  local staticVisuals = CreateFrame("Frame", nil, orb)
  staticVisuals:SetAllPoints(orb)
  staticVisuals:SetFrameStrata(fill:GetFrameStrata())
  staticVisuals:SetFrameLevel(fill:GetFrameLevel() + 1)
  orb.staticVisuals = staticVisuals

  function orb:EnsureGalaxies(alpha)
    return CreateOrbGalaxies(self, alpha)
  end

  function orb:EnsureBubbles(alpha)
    return CreateOrbBubbles(self, alpha)
  end

  -- Optional player model (purely visual). Always allocate the region so the
  -- active Settings UI can toggle and retune it without requiring a respawn.
  if orbcfg.model then
    local model = CreateFrame("PlayerModel", "$parentModel", staticVisuals)
    model:SetAllPoints()
    model:SetFrameLevel(staticVisuals:GetFrameLevel())
    model.type = orb.type

    function model:Update()
      local orbConfig = ResolveOrbConfig(self.type)
      local cfgm = (type(orbConfig) == "table" and type(orbConfig.model) == "table")
        and orbConfig.model
        or orbcfg.model
        or {}
      local enabled = cfgm.enable ~= false
      if not enabled then
        self._rothModelHidden = true
        self:Hide()
        return
      end

      self:Show()
      self:SetAlpha(cfgm.alpha or 1)
      if type(cfgm.camDistanceScale) == "number" then
        self:SetCamDistanceScale(cfgm.camDistanceScale)
      end
      self:SetPosition(0, tonumber(cfgm.pos_x) or 0, tonumber(cfgm.pos_y) or 0.1)
      if type(cfgm.rotation) == "number" then
        self:SetRotation(cfgm.rotation)
      end
      if type(cfgm.portraitZoom) == "number" then
        self:SetPortraitZoom(cfgm.portraitZoom)
      end

      local displayInfo = tonumber(cfgm.displayInfo)
      if type(displayInfo) == "number" and (self._rothDisplayInfo ~= displayInfo or self._rothModelHidden == true) then
        self:ClearModel()
        self:SetDisplayInfo(displayInfo)
        self._rothDisplayInfo = displayInfo
      end

      self._rothModelHidden = false
    end

    model:RegisterEvent("PLAYER_ENTERING_WORLD")
    model:SetScript("OnEvent", function(self)
      self:Update()
    end)
    model:SetScript("OnShow", function(self)
      self:Update()
    end)
    model:Update()
    orb.model = model
  end


  -- Decorative galaxies (clipped by fillClip). Defaults: power=on, health=off.
  if orbcfg.galaxies and (orbcfg.galaxies.alpha or 0) > 0 then
    orb:EnsureGalaxies(orbcfg.galaxies.alpha or 1)
  end

  -- Decorative bubbles (clipped by fillClip). Defaults: health=on, power=low.
  if orbcfg.bubbles and (orbcfg.bubbles.alpha or 0) > 0 then
    orb:EnsureBubbles(orbcfg.bubbles.alpha or 1)
  end

  --overlay frame
  local overlay = CreateFrame("Frame", "$parentOverlay", orb)
  --overlay:SetFrameLevel(model:GetFrameLevel()+1)
  overlay:SetAllPoints(orb)
  orb.overlay = overlay

  --spark frame
  local spark = overlay:CreateTexture(nil, "BACKGROUND", nil, -3)
  spark:SetTexture("Interface\\AddOns\\Roth_UI\\media\\orb_spark")
  --the spark should fit the filling color otherwise it will stand out too much
  spark:SetVertexColor(orbcfg.filling.color.r, orbcfg.filling.color.g, orbcfg.filling.color.b)
  spark:SetWidth(256 * orb.size / 256)
  spark:SetHeight(32 * orb.size / 256)
  local sbtex = fill:GetStatusBarTexture()
  if sbtex then
    spark:SetPoint("TOP", sbtex, "TOP", 0, 0)
  else
    spark:SetPoint("TOP", orb, 0, -16 * orb.size / 256)
  end
  --texture will be blended by blendmode, http://wowprogramming.com/docs/widgets/Texture/SetBlendMode
  spark:SetAlpha(orbcfg.spark.alpha or 0)
  spark:SetBlendMode("ADD")
  spark:Hide()
  orb.spark = spark

  --skull+lowhp
  if orb.type == "HEALTH" then
    local skull = overlay:CreateTexture(nil, "BACKGROUND", nil, 1)
    skull:SetPoint("CENTER", 0, 0)
    skull:SetSize(self.cfg.size - 40, self.cfg.size - 40)
    skull:SetTexture("Interface\\AddOns\\Roth_UI\\media\\d2_skull")
    skull:SetBlendMode("ADD")
    skull:SetAlpha(0.6)
    skull:Hide()
    orb.skull = skull

    local lowHP = overlay:CreateTexture(nil, "BACKGROUND", nil, 2)
    lowHP:SetPoint("CENTER", 0, 0)
    lowHP:SetSize(self.cfg.size - 15, self.cfg.size - 15)
    lowHP:SetTexture("Interface\\AddOns\\Roth_UI\\media\\orb_lowhp_glow")
    lowHP:SetBlendMode("ADD")
    lowHP:SetVertexColor(1, 0, 0, 1)
    lowHP:Hide()
    orb.lowHP = lowHP
  end

  --highlight
  local highlight = overlay:CreateTexture("$parentHighlight", "BACKGROUND", nil, 3)
  highlight:SetAllPoints()
  highlight:SetTexture("Interface\\AddOns\\Roth_UI\\media\\orb_gloss")
  highlight:SetAlpha(orbcfg.highlight.alpha or 1)
  orb.highlight = highlight

  --orb values
  local values = CreateFrame("Frame", "$parentValues", overlay)
  values:SetAllPoints(orb)
  --top value
  values.top = func.createFontString(values, cfg.font, 28, "THINOUTLINE")
  values.top:SetPoint("CENTER", 0, 10)
  values.top:SetTextColor(orbcfg.value.top.color.r, orbcfg.value.top.color.g, orbcfg.value.top.color.b)
  --bottom value
  values.bottom = func.createFontString(values, cfg.font, 16, "THINOUTLINE")
  values.bottom:SetPoint("CENTER", 0, -10)
  local bottomColor = orbcfg.value.bottom or orbcfg.value.bot or orbcfg.value.top
  values.bottom:SetTextColor(bottomColor.color.r, bottomColor.color.g, bottomColor.color.b)
  orb.values = values

  -- WoW 12.x: drive orb numeric text from PostUpdate (secret-safe).
  fill.valueText = values.top
  fill.perText = values.bottom

  -- Absorb display directly on the orb.
  -- WoW 12.x: do NOT derive ratios from Unit* values (secret). Let the StatusBar
  -- render the fill level itself through the Health element sub-widget contract.
  if self.cfg.absorb.show and orb.type == "HEALTH" then
    local absorbBar = CreateFrame("StatusBar", nil, values)
    absorbBar:SetPoint("CENTER")
    absorbBar:SetSize(self.cfg.size - 5, self.cfg.size - 5)
    absorbBar:SetOrientation("VERTICAL")
    absorbBar:SetMinMaxValues(0, 1)
    absorbBar:SetValue(0)
    absorbBar:SetStatusBarTexture("Interface\\AddOns\\Roth_UI\\media\\orb_absorb_glow")
    absorbBar:SetStatusBarColor(1, 1, 1, 1)

    -- Very subtle backdrop so an empty absorb does not look like "full".
    local bg = absorbBar:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetTexture("Interface\\AddOns\\Roth_UI\\media\\orb_absorb_glow")
    bg:SetAlpha(0.05)
    absorbBar.bg = bg

    fill.DamageAbsorb = absorbBar
    self.TotalAbsorb = absorbBar
    self.TotalAbsorb.smoothing = func.ResolveStatusBarSmoothing(self.cfg.absorb and self.cfg.absorb.smooth)
  end

  if orb.type == "POWER" then
    self.Power = orb.fill
    ns.PowerOrb = orb --save the orb in the namespace
    hooksecurefunc(self.Power, "SetStatusBarColor", updateStatusBarColor)
    self.Power.smoothing = func.ResolveStatusBarSmoothing(self.cfg.power and self.cfg.power.smooth)
    self.Power.colorPower = orbcfg.filling.colorAuto or false
    self.Power.PostUpdate = updateValue
  else
    self.Health = orb.fill
    ns.HealthOrb = orb --save the orb in the namespace
    hooksecurefunc(self.Health, "SetStatusBarColor", updateStatusBarColor)
    self.Health.smoothing = func.ResolveStatusBarSmoothing(self.cfg.health and self.cfg.health.smooth)
    self.Health.colorClass = orbcfg.filling.colorAuto or false
    self.Health.colorHealth = orbcfg.filling.colorAuto or
        false --when player switches into a vehicle it will recolor the orb
    --we need to display the lowhp on a certain threshold without smoothing, so we use the postUpdate for that
    self.Health.PostUpdate = updateValue
  end
  --print(addon..": orb created "..orb.type)
end

local CreateAdditionalPowerBar = function(self)
  -- Let current oUF handle secondary-power visibility/update via Blizzard pair rules.
  local DM = CreateFrame("StatusBar", "Roth_DruidMana", Roth_UIPowerOrb)
  DM:SetSize(140, 20)
  DM:SetPoint("TOP", 0, 15)
  DM:SetPoint("LEFT")
  DM:SetPoint("RIGHT")
  DM:SetFrameStrata("LOW")
  DM:SetStatusBarTexture("Interface\\AddOns\\Roth_UI\\media\\statusbar2")
  DM:Hide()

  func.applyDragFunctionality(DM)

  --Add Artwork
  local b = CreateFrame("Frame", nil, DM)
  b:SetSize(20, 20)
  b:SetPoint("TOP")
  b:SetPoint("LEFT")
  b:SetPoint("RIGHT")
  b:SetFrameStrata("LOW")

  local br = b:CreateTexture(nil, "BORDER")
  br:SetPoint("TOP", 0, 8)
  br:SetPoint("LEFT", -50, 0)
  br:SetPoint("RIGHT", 50, 0)
  br:SetPoint("BOTTOM", 0, -8)
  br:SetTexture("Interface\\AddOns\\Roth_UI\\media\\d3_altpower_border")

  --Register with oUF
  self.AdditionalPower = DM
  self.AdditionalPower.colorPower = true
  self.AdditionalPower.bg = nil
end




---------------------------------------------
-- PLAYER STYLE FUNC
---------------------------------------------

local createStyle = function(self)
  self.colors = self.colors or (oUF and oUF.colors) or {}

  --apply config to self
  self.cfg = (ns.GetUnitConfig and ns.GetUnitConfig("player")) or cfg.units.player
  self.__style = "player"

  --init
  initUnitParameters(self)

  --create the health orb
  createOrb(self, "HEALTH")
  --create the power orb
  createOrb(self, "POWER")

  --additional power
  CreateAdditionalPowerBar(self)

  --create art textures do this now for correct frame stacking
  createAngelFrame(self)
  createDemonFrame(self)

  --experience bar
  bars.createExpBar(self)

  --reputation bar
  bars.createRepBar(self)

  --bottomline
  createBottomLine(self)

  --icons
  if self.cfg.icons.resting.show then
    local pos = self.cfg.icons.resting.pos
    self.RestingIndicator = func.createIcon(self, "OVERLAY", 32, self, pos.a1, pos.a2, pos.x, pos.y, -1)
  end
  if self.cfg.icons.pvp.show then
    local pos = self.cfg.icons.pvp.pos
    self.PvPIndicator = func.createIcon(self, "OVERLAY", 44, self, pos.a1, pos.a2, pos.x, pos.y, -1)
  end
  if self.cfg.icons.combat.show then
    local pos = self.cfg.icons.combat.pos
    self.CombatIndicator = func.createIcon(self, "OVERLAY", 32, self, pos.a1, pos.a2, pos.x, pos.y, -1)
  end

  --castbar
  if self.cfg.castbar.show then
    --load castingbar
    func.createCastbar(self)
    if self.Castbar then
      self.Castbar.timeToHold = self.cfg.castbar.timeToHold or CASTBAR_INTERRUPT_HOLD
    end
  end

  --warlock bars
  if cfg.playerclass == "WARLOCK" and self.cfg.soulshards.show then
    bars.createSoulShardPowerBar(self)
  end

  --mage bars
  if cfg.playerclass == "MAGE" and self.cfg.arcbar.show then
    bars.createArcBar(self)
  end

  --holypower
  if cfg.playerclass == "PALADIN" and self.cfg.holypower.show then
    bars.createHolyPowerBar(self)
  end

  --harmony
  if cfg.playerclass == "MONK" and self.cfg.harmony.show then
    bars.createHarmonyPowerBar(self)
  end

  --runes
  if cfg.playerclass == "DEATHKNIGHT" and self.cfg.runes.show then
    --position deathknight runes
    bars.createRuneBar(self)
  end

  --combobar
  if (cfg.playerclass == "ROGUE" or cfg.playerclass == "DRUID") and self.cfg.combobar.show then
    bars.createComboBar(self)
  end

  --create portrait
  if self.cfg.portrait.show then
    func.createStandAlonePortrait(self)
  end

  --make alternative power bar movable
  if self.cfg.altpower.show then
    func.createAlternativePowerBar(self, "oUF_AltPowerPlayer")
  end

  --add self to unit container (maybe access to that unit is needed in another style)
  unit.player = self
end

---------------------------------------------
-- SPAWN PLAYER UNIT
---------------------------------------------
if ns.IsRothEnabled and ns.IsRothEnabled(cfg.units.player.show) then
  oUF:RegisterStyle("diablo:player", createStyle)
  oUF:SetActiveStyle("diablo:player")
  oUF:Spawn("player", "Roth_UIPlayerFrame")
end
