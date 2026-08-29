--get the addon namespace
local addon, ns = ...

--get oUF namespace (just in case needed)
local oUF = ns.oUF or oUF

--get the config
local cfg = ns.cfg

--get the functions
local func = ns.func
local safety = ns and ns.safety

--get the unit container
local unit = ns.unit
local type = type
local pairs = pairs
local format = format
local floor = floor
local max = math.max
local min = math.min
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsConnected = UnitIsConnected
local IsSecretValue = (func and func.IsSecretValue) or (safety and safety.IsSecret) or function(v)
  local fn = _G.issecretvalue or _G.IsSecretValue
  return type(fn) == "function" and fn(v) or false
end
local function AppendClassText(parts, value)
  if value == nil then return end
  if IsSecretValue(value) then return end
  local v = value
  if type(v) ~= "string" then
    v = tostring(v)
  end
  if v == "" then return end
  parts[#parts + 1] = v
end

local classTextParts = {}
local targetCastbarRuntime = ns.TargetCastbarRuntime
local function ResetClassTextParts(parts)
  for i = #parts, 1, -1 do
    parts[i] = nil
  end
end

---------------------------------------------
-- UNIT SPECIFIC FUNCTIONS
---------------------------------------------

--init parameters
local initUnitParameters = function(self)
  self:SetFrameStrata("LOW")
  self:SetFrameLevel(1)
  self:SetSize(self.cfg.width, self.cfg.height)
  self:SetScale(self.cfg.scale)
  self:SetPoint(self.cfg.pos.a1, self.cfg.pos.af, self.cfg.pos.a2, self.cfg.pos.x, self.cfg.pos.y)
  self:RegisterForClicks("AnyDown")
  self:SetScript("OnEnter", UnitFrame_OnEnter)
  self:SetScript("OnLeave", UnitFrame_OnLeave)
  func.applyDragFunctionality(self)
  self:SetHitRectInsets(10, 10, 10, 10)
  if ZoneTextFrame then ZoneTextFrame:SetFrameStrata("HIGH") end
  if SubZoneTextFrame then SubZoneTextFrame:SetFrameStrata("HIGH") end
end

--Target Frame
local createArtwork = function(self)
  local t = self:CreateTexture(nil, "BORDER", nil, -8)
  t:SetPoint("TOP", 0, 25)
  t:SetPoint("LEFT", -62, 0)
  t:SetPoint("RIGHT", 60, 0)
  t:SetPoint("BOTTOM", 0, -15)

  self.RareIcon = t
end


--make a sound when target gets selected
local playTargetSound = function(self, event)
  if event ~= "PLAYER_TARGET_CHANGED" then return end
  local unitToken = self.__unit or "target"
  local exists = UnitExists(unitToken)
  if IsSecretValue(exists) then return end
  if exists ~= true then
    PlaySound(684)
    return
  end

  local enemy = UnitIsEnemy(unitToken, "player")
  if not IsSecretValue(enemy) and enemy == true then
    PlaySound(873)
    return
  end
  local friendly = UnitIsFriend("player", unitToken)
  if not IsSecretValue(friendly) and friendly == true then
    PlaySound(867)
  elseif not IsSecretValue(enemy) and not IsSecretValue(friendly) then
    PlaySound(871)
  end
end

--create health frames
local createHealthFrame = function(self)
  local cfg = self.cfg.health

  --health
  local h = CreateFrame("StatusBar", nil, self)
  h:SetPoint("TOP", 0, -21.9)
  h:SetPoint("LEFT", 24.5, 0)
  h:SetPoint("RIGHT", -24.5, 0)
  h:SetPoint("BOTTOM", 0, 29.7)
  h:SetFrameStrata("BACKGROUND")


  h:SetStatusBarTexture(cfg.texture)
  h.bg = h:CreateTexture(nil, "BACKGROUND", nil, -6)
  h.bg:SetTexture()
  h.bg:SetAllPoints(h)

  h.glow = h:CreateTexture(nil, "OVERLAY", nil, -5)
  h.glow:SetTexture("Interface\\AddOns\\Roth_UI\\media\\target_hpglow")
  h.glow:SetVertexColor(0, 0, 0, 1)

  h.highlight = h:CreateTexture(nil, "OVERLAY", nil, -4)
  h.highlight:SetTexture("Interface\\AddOns\\Roth_UI\\media\\target_highlight")
  h.highlight:SetAllPoints(h)

  self.Health = h
  self.Health.smoothing = func.ResolveStatusBarSmoothing(self.cfg.health and self.cfg.health.smooth)
end


--create power frames
local createPowerFrame = function(self)
  local cfg = self.cfg.power

  --power
  local h = CreateFrame("StatusBar", nil, self.Health)
  h:SetPoint("TOP", 0, -20)
  h:SetPoint("LEFT", 11, 0)
  h:SetPoint("RIGHT", -12, 0)
  h:SetPoint("BOTTOM", 0, -14)

  h:SetStatusBarTexture(cfg.texture)

  h.bg = h:CreateTexture(nil, "BACKGROUND", nil, -6)
  h.bg:SetTexture(cfg.texture)
  h.bg:SetAllPoints(h)

  h.glow = h:CreateTexture(nil, "OVERLAY", nil, -5)
  h.glow:SetTexture("Interface\\AddOns\\Roth_UI\\media\\target_ppglow")
  h.glow:SetAllPoints(self)
  h.glow:SetVertexColor(0, 0, 0, 1)

  self.Power = h
  self.Power.smoothing = func.ResolveStatusBarSmoothing(self.cfg.power and self.cfg.power.smooth)
end

--create health power strings
local createHealthPowerStrings = function(self)
  local name = func.createFontString(self, cfg.font, self.cfg.misc.NameFontSize, "THINOUTLINE")
  name:SetPoint("BOTTOM", self, "TOP", 0, 0)
  name:SetPoint("LEFT", self.Health, 0, 0)
  name:SetPoint("RIGHT", self.Health, 0, 0)
  self.Name = name

  local hpval = func.createFontString(self.Health, cfg.font, self.cfg.health.fontSize, "THINOUTLINE")
  hpval:SetPoint(self.cfg.health.point, self.cfg.health.x, self.cfg.health.y)

  local perphp = func.createFontString(self.Health, cfg.font, self.cfg.healper.fontSize, "THINOUTLINE")
  perphp:SetPoint(self.cfg.healper.point, self.cfg.healper.x, self.cfg.healper.y)

  local perpp = func.createFontString(self.Power, cfg.font, self.cfg.powper.fontSize, "THINOUTLINE")
  perpp:SetPoint(self.cfg.powper.point, self.cfg.powper.x, self.cfg.powper.y)

  -- Power numeric value should be anchored to the Power bar, not the Health bar.
  local ppval = func.createFontString(self.Power, cfg.font, self.cfg.power.fontSize, "THINOUTLINE")
  ppval:SetPoint(self.cfg.power.point, self.cfg.power.x, self.cfg.power.y)

  local classtext = func.createFontString(self, cfg.font, self.cfg.misc.classFontSize, "THINOUTLINE")
  classtext:SetPoint("BOTTOM", self, "TOP", 0, -15)

  self:Tag(name, "[roth:namecolor][name<$|r]")

  self.Health.valueText = hpval
  self.Health.valueTextMode = func.ResolveHealthValueMode()
  self.Health.perText = perphp
  self.Power.valueText = ppval
  self.Power.valueTextMode = "cur"
  self.Power.perText = perpp
  self:Tag(classtext, "[diablo:classtext]")
end


-- Target castbar runtime lives in core/target_castbar.lua.

-- Aura specifications are queued here and materialized on first show.

---------------------------------------------
-- UNIT SPECIFIC TAG
---------------------------------------------

oUF.Tags.Methods["diablo:classtext"] = function(unit)
  local parts = classTextParts
  ResetClassTextParts(parts)
  local level = UnitLevel(unit)
  if IsSecretValue(level) then
    level = nil
    AppendClassText(parts, "??")
  elseif level == 0 or level == -1 then
    AppendClassText(parts, "??")
  elseif level then
    AppendClassText(parts, level)
  end

  local unitrace = UnitRace(unit)
  local creatureType = UnitCreatureType(unit)
  local isPlayer = UnitIsPlayer(unit)
  if IsSecretValue(isPlayer) then isPlayer = nil end
  if isPlayer == true then
    AppendClassText(parts, unitrace)
  end
  if isPlayer ~= true then
    AppendClassText(parts, creatureType)
  end
  local unit_classification = UnitClassification(unit)
  if IsSecretValue(unit_classification) then unit_classification = nil end
  local isBossLevel = (level == -1)
  local tmpstring
  if unit_classification == "worldboss" or isBossLevel then
    tmpstring = "Boss"
  elseif unit_classification == "rare" or unit_classification == "rareelite" then
    tmpstring = (unit_classification == "rareelite") and "Rare Elite" or "Rare"
  elseif unit_classification == "elite" then
    tmpstring = "Elite"
  end
  AppendClassText(parts, tmpstring)
  if isPlayer == true then
    local localizedClass = UnitClass(unit)
    AppendClassText(parts, localizedClass)
  end
  return table.concat(parts, " ")
end


---------------------------------------------
-- TARGET STYLE FUNC
---------------------------------------------

local function createStyle(self)
  self.colors = self.colors or (oUF and oUF.colors) or {}

  --apply config to self
  self.cfg = (ns.GetUnitConfig and ns.GetUnitConfig("target")) or cfg.units.target
  self.__style = "target"



  --init
  initUnitParameters(self)

  --create the art
  createArtwork(self)

  --createhealthPower
  createHealthFrame(self)
  createPowerFrame(self)

  --sound
  self:RegisterEvent("PLAYER_TARGET_CHANGED", playTargetSound)
  self.Health:SetScript("OnShow", function(s)
    playTargetSound(self, "PLAYER_TARGET_CHANGED")
  end)

  --health power strings
  createHealthPowerStrings(self)

  --health power update
  self.Health.PostUpdate = func.updateHealth
  self.Power.PostUpdate = func.updatePower

  -- Managed aura groups are registered lazily on first frame show.
  func.QueueTargetAuras(self)

  --castbar
  if self.cfg.castbar.show then
    func.createCastbar(self)
    if targetCastbarRuntime and type(targetCastbarRuntime.Bind) == "function" then
      targetCastbarRuntime.Bind(self.Castbar, "target")
    end
  end

  --debuffglow
  func.createDebuffGlow(self)

  --icons
  self.RaidTargetIndicator = func.createIcon(self, "BACKGROUND", 24, self.Name, "BOTTOM", "TOP", 0, 0, -1)
  self.RaidTargetIndicator:SetTexture("Interface\\AddOns\\Roth_UI\\media\\raidicons")

  --create portrait
  if self.cfg.portrait.show then
    func.createStandAlonePortrait(self)
  end

  func.healPrediction(self)

  --add total absorb
  func.totalAbsorb(self)

  --add self to unit container (maybe access to that unit is needed in another style)
  unit.target = self
end

---------------------------------------------
-- SPAWN TARGET UNIT
---------------------------------------------

if ns.IsRothEnabled and ns.IsRothEnabled(cfg.units.target.show) then
  oUF:RegisterStyle("diablo:target", createStyle)
  oUF:SetActiveStyle("diablo:target")
  oUF:Spawn("target", "Roth_UITargetFrame")
end
