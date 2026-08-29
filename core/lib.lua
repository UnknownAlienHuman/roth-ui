--get the addon namespace
local addon, ns = ...

--get oUF namespace (just in case needed)
local oUF = ns.oUF or _G["oUF"]
local LSM = LibStub("LibSharedMedia-3.0")
local frameRegistry = assert(ns and ns.frameRegistry, "Roth_UI: frameRegistry is required by lib.lua")

--get the config
local cfg = ns.cfg
local mediapath = ns.mediapath or "Interface\\AddOns\\Roth_UI\\media\\"
local type = type
local pairs = pairs
local ipairs = ipairs
local next = next
local select = select
local tostring = tostring
local tonumber = tonumber

local format = format
local floor = floor
local mod = mod
local wipe = wipe
local tinsert = table.insert or tinsert
local tremove = table.remove or tremove
local InCombatLockdown = InCombatLockdown
local CreateFrame = CreateFrame
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsConnected = UnitIsConnected
local UnitInRange = UnitInRange
local UnitClass = UnitClass
local UnitIsPlayer = UnitIsPlayer
local UnitReaction = UnitReaction

--object container
local func = CreateFrame("Frame")
ns.func = func

---------------------------------------------
-- MAINLINE HELPERS
---------------------------------------------

local safety = ns and ns.safety

-- Centralized Secret Value handling (WoW 12.x/Midnight).
-- Hot paths should call the native predicate directly; safety.IsSecret keeps
-- pcall guards for non-hot serialization/sanitization code.
local _nativeIsSecret = _G["issecretvalue"] or _G["IsSecretValue"]
local _issecretvalue = (type(_nativeIsSecret) == "function" and _nativeIsSecret) or (safety and safety.IsSecret)
func.IsSecretValue = function(v)
  return _issecretvalue and _issecretvalue(v) or false
end
local IsSecretValue = func.IsSecretValue

func.ResolveStatusBarSmoothing = function(enabled)
  local interpolation = Enum and Enum.StatusBarInterpolation
  if not interpolation then
    return nil
  end
  if enabled == false then
    return interpolation.Immediate
  end
  return interpolation.ExponentialEaseOut or interpolation.Immediate
end

func.SafeUnitHealth = function(unit)
  local v = UnitHealth(unit)
  if func.IsSecretValue(v) then return nil end
  return v
end

func.SafeUnitHealthMax = function(unit)
  local v = UnitHealthMax(unit)
  if func.IsSecretValue(v) then return nil end
  return v
end

func.SafeUnitPower = function(unit, powerType)
  local pType = powerType or UnitPowerType(unit)
  if func.IsSecretValue(pType) then return nil end
  local v = UnitPower(unit, pType)
  if func.IsSecretValue(v) then return nil end
  return v
end

func.SafeUnitPowerMax = function(unit, powerType)
  local pType = powerType or UnitPowerType(unit)
  if func.IsSecretValue(pType) then return nil end
  local v = UnitPowerMax(unit, pType)
  if func.IsSecretValue(v) then return nil end
  return v
end

---------------------------------------------
-- VARIABLES
---------------------------------------------

---------------------------------------------
-- FUNCTIONS
---------------------------------------------

-- Numeric formatting runtime moved to core/unit_misc_runtime.lua.

local VALID_HEALTH_VALUE_MODES = {
  cur = true,
  max = true,
  curmax = true,
  percent = true,
  curpercent = true,
}

local function ResolveUnitStyle(frame)
  if type(frame) ~= "table" then
    return nil
  end

  local style = frame.__style
  if type(style) == "string" and style ~= "" then
    return style
  end

  local unitCfg = frame.cfg
  style = unitCfg and unitCfg.style
  if type(style) == "string" and style ~= "" then
    return style
  end

  return nil
end

func.GetUnitStyle = ResolveUnitStyle

func.GetUnitRenderWidth = function(frame)
  local width = tonumber(frame and frame.__renderWidth)
  if width and width > 0 then
    return width
  end

  local unitCfg = frame and frame.cfg
  width = tonumber(unitCfg and unitCfg.width)
  if width and width > 0 then
    return width
  end

  return 0
end

func.GetUnitRenderHeight = function(frame)
  local height = tonumber(frame and frame.__renderHeight)
  if height and height > 0 then
    return height
  end

  local unitCfg = frame and frame.cfg
  height = tonumber(unitCfg and unitCfg.height)
  if height and height > 0 then
    return height
  end

  return 0
end

func.ShouldShowPortrait = function(frame)
  local style = ResolveUnitStyle(frame)
  if style == "party" then
    return true
  end

  local portrait = frame and frame.cfg and frame.cfg.portrait
  return type(portrait) == "table" and portrait.show == true
end

func.ResolveHealthValueMode = function()
  local mode = ns.cfg and ns.cfg.healthValueMode or nil
  if type(mode) == "string" and VALID_HEALTH_VALUE_MODES[mode] then
    return mode
  end
  return "cur"
end

local function RefreshUnitHealthBar(frame)
  if not (type(frame) == "table" and frame.Health) then
    return
  end

  frame.Health.valueTextMode = func.ResolveHealthValueMode()

  if type(frame.Health.ForceUpdate) == "function" then
    frame.Health:ForceUpdate()
    return
  end

  local unitId = frame.__unit
  local postUpdate = frame.Health.PostUpdate
  if type(unitId) ~= "string" or unitId == "" or type(postUpdate) ~= "function" then
    return
  end

  postUpdate(frame.Health, unitId, UnitHealth(unitId), UnitHealthMax(unitId))
end

function ns.RefreshUnitHealthValueText(unitKey)
  local unitFrames = ns and ns.unit
  if type(unitFrames) ~= "table" then
    return
  end

  if unitKey == "party" then
    local header = ns.partyHeader
    if not (header and header.GetChildren) then
      return
    end
    local children = { header:GetChildren() }
    for i = 1, #children do
      RefreshUnitHealthBar(children[i])
    end
    return
  end

  if unitKey == "boss" then
    local bosses = unitFrames.boss
    if type(bosses) ~= "table" then
      return
    end
    for i = 1, #bosses do
      RefreshUnitHealthBar(bosses[i])
    end
    return
  end

  if unitKey == "raid" then
    local raidGroups = ns.raidGroups
    if type(raidGroups) ~= "table" then
      return
    end
    for _, header in pairs(raidGroups) do
      if header and header.GetChildren then
        local children = { header:GetChildren() }
        for i = 1, #children do
          RefreshUnitHealthBar(children[i])
        end
      end
    end
    return
  end

  RefreshUnitHealthBar(unitFrames[unitKey])
end

-- Обновить health text mode на всех юнит-фреймах (глобальная настройка)
function ns.RefreshAllHealthValueText()
  local SMALL_UNITS = { "target", "focus", "pet", "targettarget", "pettarget", "focustarget" }
  for _, key in ipairs(SMALL_UNITS) do
    ns.RefreshUnitHealthValueText(key)
  end
  ns.RefreshUnitHealthValueText("party")
  ns.RefreshUnitHealthValueText("boss")
  ns.RefreshUnitHealthValueText("raid")
end

-- Aura rendering is owned by core/aura_runtime.lua and oUF managed
-- AuraContainer objects. No AuraData, duration polling, or legacy Buffs/Debuffs
-- element callbacks are kept in this general utility module.

--backdrop func
func.createBackdrop = function(f)
  if not f then return end
  if not f.SetBackdrop and BackdropTemplateMixin and Mixin then
    Mixin(f, BackdropTemplateMixin)
  end
  if not f.SetBackdrop then return end
  f:SetBackdrop(cfg.backdrop)
  f:SetBackdropColor(0, 0, 0, 0.7)
  f:SetBackdropBorderColor(0, 0, 0, 1)
end

--create AlternativePower
func.createAlternativePowerBar = function(self, name)
  local t, f
  local num = 4
  local w = 64 * num
  local h = 22

  local bar = CreateFrame("StatusBar", name, self)
  bar:SetPoint(self.cfg.altpower.pos.a1, self.cfg.altpower.pos.af, self.cfg.altpower.pos.a2, self.cfg.altpower.pos.x,
    self.cfg.altpower.pos.y)
  bar:SetSize(w, h)
  bar:SetStatusBarTexture(self.cfg.altpower.texture)
  bar:SetStatusBarColor(self.cfg.altpower.color.r, self.cfg.altpower.color.g, self.cfg.altpower.color.b)
  bar.colorTexture = true --color the altpower bar
  --bar:SetMinMaxValues(0,100)
  --bar:SetValue(70)

  t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetSize(64, 64)
  t:SetPoint("LEFT", -64, 0)
  t:SetTexture(mediapath .. "combo_left")
  bar.leftedge = t

  t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetSize(64, 64)
  t:SetPoint("RIGHT", 64, 0)
  t:SetTexture(mediapath .. "combo_right")
  bar.rightedge = t

  t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetSize(64 * num, 64)
  t:SetPoint("LEFT", 0, 0)
  t:SetTexture(mediapath .. "combo_back")
  bar.back = t

  local g = CreateFrame("Frame", nil, bar)
  g:SetAllPoints(bar)

  t = g:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetSize(64 * num, 64)
  t:SetPoint("LEFT", 0, 0)
  t:SetAlpha(0.7)
  t:SetBlendMode("BLEND")
  t:SetTexture(mediapath .. "combo_highlight2")

  f = func.createFontString(g, cfg.font, 24, "THINOUTLINE")
  f:SetPoint("CENTER", 0, 0)
  f:SetTextColor(0.8, 0.8, 0.8)
  bar.ValueText = f
  bar.PostUpdate = function(element, unit, current, minimum, maximum)
    local IsSecretValue = func.IsSecretValue
    if IsSecretValue(current) or IsSecretValue(maximum) then
      element.ValueText:SetFormattedText("%.0f / %.0f", current, maximum)
      return
    end
    if type(current) == "number" and type(maximum) == "number" and maximum > 0 then
      element.ValueText:SetFormattedText("%.0f / %.0f", current, maximum)
    else
      element.ValueText:SetText("")
    end
  end
  bar.smoothing = func.ResolveStatusBarSmoothing(self.cfg.altpower and self.cfg.altpower.smooth)

  bar:SetScale(self.cfg.altpower.scale)
  bar:Hide()
  func.simpleDragFunc(bar)
  self.AlternativePower = bar
end

-- Runtime hot-path helpers moved to core/unit_value_runtime.lua.
-- Standard unit auras are framework-owned through native oUF Buffs/Debuffs.

--debuffglow
func.createDebuffGlow = function(self)
  local style = ResolveUnitStyle(self)
  local t = self:CreateTexture(nil, "BACKGROUND", nil, -5)
  if style == "target" then
    t:SetTexture(mediapath .. "target_debuffglow")
  else
    t:SetTexture(mediapath .. "targettarget_debuffglow")
  end
  if style == "party" then
    if cfg.units.party.vertical == true then
      t:SetPoint("TOP", 0, 29)
      t:SetPoint("LEFT", 0, 0)
      t:SetPoint("RIGHT", 0, 0)
      t:SetPoint("BOTTOM", 0, -10)
    else
      t:SetPoint("TOP", 0, 19)
      t:SetPoint("LEFT", 0, 0)
      t:SetPoint("RIGHT", 0, 0)
      t:SetPoint("BOTTOM", 0, -15)
    end
  elseif style == "target" then
    t:SetPoint("TOP", 0, 25)
    t:SetPoint("LEFT", -60, 0)
    t:SetPoint("RIGHT", 60, 0)
    t:SetPoint("BOTTOM", 0, -15)
  else
    t:SetAllPoints()
  end
  t:SetBlendMode("BLEND")
  t:SetVertexColor(0, 1, 1, 0) -- set alpha to 0 to hide the texture
  self.DebuffHighlight = t
  self.DebuffHighlightAlpha = 1
  self.DebuffHighlightFilter = false
end

--check threat
func.checkThreat = function(self, event, unit)
  if unit then
    if self.__unit ~= unit then return end
    local threat = UnitThreatSituation(unit)
    if IsSecretValue(threat) then
      threat = nil
    end
    if (threat and threat > 0) then
      local r, g, b = GetThreatStatusColor(threat)
      if self.Border then
        self.Border:SetVertexColor(r, g, b)
        self.PortraitBack:SetVertexColor(r, g, b, 1)
      end
    else
      if self.Border then
        self.Border:SetVertexColor(0.6, 0.5, 0.5)
        self.PortraitBack:SetVertexColor(0.1, 0.1, 0.1, 0.9)
      end
    end
  end
end

-- Lazy 3D portrait lifecycle.
--
-- PlayerModel creation and oUF Portrait event registration are deferred until
-- the owning unit frame is actually visible. Static 2D portraits remain eager
-- because they are cheap and oUF can bind them during normal style setup.
local function EnsureLazyPortrait(frame)
  local factory = frame and frame.__rothPortraitFactory
  if type(factory) ~= "function" or frame.Portrait then return end

  if InCombatLockdown and InCombatLockdown() then
    if not frame.__rothPortraitDeferred then
      frame.__rothPortraitDeferred = true
      local policy = ns.framePolicy
      if policy and type(policy.DeferUntilOutOfCombat) == "function" then
        policy.DeferUntilOutOfCombat("portrait:" .. tostring(frame), function()
          frame.__rothPortraitDeferred = nil
          EnsureLazyPortrait(frame)
        end)
      else
        frame.__rothPortraitDeferred = nil
      end
    end
    return
  end

  local portrait = factory(frame)
  if not portrait then return end
  frame.__rothPortraitFactory = nil
  frame.Portrait = portrait
  if frame.__rothPortraitLifecycleReady
      and type(frame.EnableElement) == "function"
      and not frame:IsElementEnabled("Portrait") then
    frame:EnableElement("Portrait")
  end
end

local function AttachLazyPortraitLifecycle(frame)
  if type(frame.__rothPortraitFactory) ~= "function" then
    return
  end
  frame.__rothPortraitLifecycleReady = true
  frame:HookScript("OnShow", EnsureLazyPortrait)
  if frame:IsVisible() then
    EnsureLazyPortrait(frame)
  end
end

oUF:RegisterInitCallback(AttachLazyPortraitLifecycle)

local function CreatePortraitChrome(owner, back)
  local borderholder = CreateFrame("Frame", nil, back)
  borderholder:SetAllPoints(back)
  owner.BorderHolder = borderholder

  local border = borderholder:CreateTexture(nil, "BACKGROUND", nil, -6)
  border:SetAllPoints(borderholder)
  border:SetTexture(mediapath .. "portrait_border")
  border:SetVertexColor(0.6, 0.5, 0.5)
  owner.Border = border

  local gloss = borderholder:CreateTexture(nil, "BACKGROUND", nil, -5)
  gloss:SetAllPoints(borderholder)
  gloss:SetTexture(mediapath .. "portrait_gloss")
  gloss:SetVertexColor(0.9, 0.95, 1, 0.6)
end

--create portrait func
func.createPortrait = function(self)
  local back = CreateFrame("Frame", nil, self)
  local portraitWidth = func.GetUnitRenderWidth(self)
  back:SetSize(portraitWidth, portraitWidth)

  local style = ResolveUnitStyle(self)
  local isParty = style == "party"
  if isParty and cfg.units.party.vertical == true then
    back:SetPoint("BOTTOM", self, "LEFT", 10, -38)
  else
    back:SetPoint("BOTTOM", self, "TOP", 0, -35)
  end
  self.PortraitHolder = back

  local background = back:CreateTexture(nil, "BACKGROUND", nil, -8)
  background:SetAllPoints(back)
  background:SetTexture(mediapath .. "portrait_back")
  background:SetVertexColor(0.1, 0.1, 0.1, 0.9)
  self.PortraitBack = background

  if self.cfg.portrait.use3D == true then
    CreatePortraitChrome(self, back)
    self.__rothPortraitFactory = function()
      local portrait = CreateFrame("PlayerModel", nil, back)
      if isParty then
        portrait:SetPoint("TOPLEFT", back, "TOPLEFT", 22, -20)
        portrait:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -19, 21)
      else
        portrait:SetPoint("TOPLEFT", back, "TOPLEFT", 27, -27)
        portrait:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -27, 27)
      end
      return portrait
    end
  else
    local portrait = back:CreateTexture(nil, "BACKGROUND", nil, -7)
    if isParty then
      portrait:SetPoint("TOPLEFT", back, "TOPLEFT", 21, -21)
      portrait:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -21, 21)
    else
      portrait:SetPoint("TOPLEFT", back, "TOPLEFT", 27, -27)
      portrait:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -27, 27)
    end
    portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
    self.Portrait = portrait
    CreatePortraitChrome(self, back)
  end

  if self.cfg.vertical == true then
    self.Name:SetPoint("CENTER", 0, 0)
  else
    self.Name:SetPoint("BOTTOM", self, "TOP", 0, portraitWidth - 53)
  end
end

--create standalone portrait func
func.createStandAlonePortrait = function(self)
  local style = ResolveUnitStyle(self)
  local fname = style == "player" and "Roth_UIPlayerPortrait"
    or style == "target" and "Roth_UITargetPortrait"
    or nil
  local pcfg = self.cfg.portrait

  local back = CreateFrame("Frame", fname, self)
  back:SetSize(pcfg.size, pcfg.size)
  local anchorFrame = type(pcfg.pos.af) == "string" and _G[pcfg.pos.af] or pcfg.pos.af
  back:SetPoint(pcfg.pos.a1, anchorFrame or UIParent, pcfg.pos.a2, pcfg.pos.x, pcfg.pos.y)
  self.PortraitHolder = back
  func.applyDragFunctionality(back)

  local background = back:CreateTexture(nil, "BACKGROUND", nil, -8)
  background:SetAllPoints(back)
  background:SetTexture(mediapath .. "portrait_back")
  background:SetVertexColor(0.1, 0.1, 0.1, 0.9)
  self.PortraitBack = background

  local inset = pcfg.size * 27 / 128
  if pcfg.use3D == true then
    CreatePortraitChrome(self, back)
    self.__rothPortraitFactory = function()
      local portrait = CreateFrame("PlayerModel", nil, back)
      portrait:SetPoint("TOPLEFT", back, "TOPLEFT", inset, -inset)
      portrait:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -inset, inset)
      return portrait
    end
  else
    local portrait = back:CreateTexture(nil, "BACKGROUND", nil, -7)
    portrait:SetPoint("TOPLEFT", back, "TOPLEFT", inset, -inset)
    portrait:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -inset, inset)
    portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
    self.Portrait = portrait
    CreatePortraitChrome(self, back)
  end
end
--create castbar func
local function ResolveAnchorFrame(af, ownerFrame)
  if type(af) == "string" then
    if af == "$parent" or af == "$self" or af == "self" then
      return ownerFrame
    end
    return _G[af]
  end
  return af
end

func.createCastbar = function(f)
  local style = ResolveUnitStyle(f)
  local cb = f.cfg and f.cfg.castbar or nil
  if not cb then return end
  if type(cb) ~= "table" then
    if ns and ns.Log then
      ns.Log("Castbar: skip style=%s (castbar type=%s)", tostring(style), type(cb))
    end
    return
  end

  local af = ResolveAnchorFrame(cb.pos and cb.pos.af, f) or UIParent
  local x = (cb.pos and cb.pos.x) or 0
  local y = (cb.pos and cb.pos.y) or 0
  local a1 = (cb.pos and cb.pos.a1) or "CENTER"
  local a2 = (cb.pos and cb.pos.a2) or a1

  local barW = tonumber(cb.width) or 265
  local barH = tonumber(cb.height) or 15
  local isMini = (cb.mini == true)

  if ns and ns.Log then
    ns.Log(
      "Castbar: create style=%s mini=%s w=%s h=%s anchor=%s",
      tostring(style),
      tostring(isMini),
      tostring(barW),
      tostring(barH),
      tostring(cb.pos and cb.pos.af)
    )
  end

  local frame = CreateFrame("Frame", "$parentCastBarDragFrame", f)
  frame:SetPoint(a1, af, a2, x + 8, y)
  frame:SetSize(barW, barH)

  frameRegistry.Register("bars", frame)

  local c = CreateFrame("StatusBar", "$parentCastbar", frame)
  c:SetSize(barW, barH)
  c:SetStatusBarTexture(cb.texture)
  c:SetScale(cb.scale or 1)
  c:SetPoint("CENTER", frame, 0, 0)
  c:SetFrameStrata("HIGH")
  c.castbarCfg = cb
  c:SetStatusBarColor(cb.color.bar.r, cb.color.bar.g, cb.color.bar.b, cb.color.bar.a)
  c.timeToHold = cb.timeToHold or 0.8
  c._dragFrame = frame

  if isMini then
    -- Minimal background (no large castbar art) for small unitframes.
    c.bg = c:CreateTexture(nil, "BACKGROUND", nil, -6)
    c.bg:SetAllPoints(c)
    c.bg:SetColorTexture(cb.color.bg.r, cb.color.bg.g, cb.color.bg.b, cb.color.bg.a)

    c._miniShade = c:CreateTexture(nil, "OVERLAY", nil, -5)
    c._miniShade:SetAllPoints(c)
    c._miniShade:SetColorTexture(0, 0, 0, 0.35)
  else
    c.background = c:CreateTexture(nil, "BACKGROUND", nil, -8)
    c.background:SetTexture(mediapath .. "castbar")
    c.background:SetPoint("TOP", 0, 24.9)
    c.background:SetPoint("LEFT", -170, 0)
    c.background:SetPoint("RIGHT", 170, 0)
    c.background:SetPoint("BOTTOM", 0, -24.2)

    c.bg = c:CreateTexture(nil, "BACKGROUND", nil, -6)
    c.bg:SetTexture(cb.texture)
    c.bg:SetAllPoints(c)
    c.bg:SetVertexColor(cb.color.bg.r, cb.color.bg.g, cb.color.bg.b, cb.color.bg.a)

    c.glow = c:CreateTexture(nil, "OVERLAY", nil, -4)
    c.glow:SetTexture(mediapath .. "castbar_glow")
    c.glow:SetPoint("TOP", 0, 26.5)
    c.glow:SetPoint("LEFT", -35, 0)
    c.glow:SetPoint("RIGHT", 35, 0)
    c.glow:SetPoint("BOTTOM", 0, -24.2)
    c.glow:SetVertexColor(0, 0, 0, 1)

    c.highlight = c:CreateTexture(nil, "OVERLAY", nil, -3)
    c.highlight:SetTexture(mediapath .. "castbar_highlight")
    c.highlight:SetPoint("TOP", 0, 26.5)
    c.highlight:SetPoint("LEFT", -35, 0)
    c.highlight:SetPoint("RIGHT", 35, 0)
    c.highlight:SetPoint("BOTTOM", 0, -24.2)
  end

  c.Text = func.createFontString(c, cfg.font, cb.TextSize or 11, "THINOUTLINE")
  c.Text:SetPoint("LEFT", 5, 0)
  c.Text:SetJustifyH("LEFT")

  c.Time = func.createFontString(c, cfg.font, cb.TextSize or 11, "THINOUTLINE")
  c.Time:SetPoint("RIGHT", -2, 0)
  c.Text:SetPoint("RIGHT", -50, 0)

  c.Spark = c:CreateTexture(nil, "OVERLAY", nil, -7)
  c.Spark:SetBlendMode("ADD")
  c.Spark:SetVertexColor(0.8, 0.6, 0, 1)

  if style == "target" then
    -- Blizzard-style shield for non-interruptible casts.
    c.Shield = c:CreateTexture(nil, "OVERLAY", nil, 3)
    c.Shield:SetTexture("Interface\\CastingBar\\UI-CastingBar-Shield")
    c.Shield:SetSize(26, 26)
    c.Shield:SetPoint("LEFT", c, "LEFT", -10, 0)
    c.Shield:SetBlendMode("BLEND")
    c.Shield:SetVertexColor(0.9, 0.9, 0.9, 1)
    c.Shield:Hide()
  end

  if style ~= "player" and ns.TargetCastbarRuntime and type(ns.TargetCastbarRuntime.Bind) == "function" then
    ns.TargetCastbarRuntime.Bind(c, f.unit or style)
  end

  --safezone
  if style == "player" and cb.latency then
    c.SafeZone = c:CreateTexture(nil, "OVERLAY")
    c.SafeZone:SetTexture(cb.texture)
    c.SafeZone:SetVertexColor(0.6, 0, 0, 0.6)
    c.SafeZone:SetPoint("TOPRIGHT")
    c.SafeZone:SetPoint("BOTTOMRIGHT")
  end

  if style == "player" then
    c.PostUpdateStage = func.PostUpdateStage
    c.cfg = f.cfg
  end

  func.applyDragFunctionality(frame)

  f.Castbar = c
  c:Hide()
end

-- Eventless *target unit tokens do not receive an addon polling fallback.
-- Polling UnitCastingInfo/UnitChannelInfo would create a permanent hot path and
-- duplicate oUF cast state; targettarget castbars are therefore unsupported.

func.PostUpdateStage =
    function(self, stage)
      if (stage == 1) then
        self:SetStatusBarColor(1, 0, 0)
      elseif (stage == 2) then
        self:SetStatusBarColor(0, 0, 1)
      elseif (stage == 3) then
        self:SetStatusBarColor(self.cfg.castbar.color.bar.r, self.cfg.castbar.color.bar.g, self.cfg.castbar.color.bar.b,
          self.cfg.castbar.color.bar.a)
      end
    end

--fontstring func
local function ResolveFontPath(fontPath)
  if type(fontPath) ~= "string" or fontPath == "" then
    fontPath = (ns and ns.cfg and ns.cfg.font) or STANDARD_TEXT_FONT
  else
    -- If a LSM key (not a file path) is passed, try to resolve it
    if not fontPath:find("\\") and not fontPath:find("/") and not fontPath:lower():match("%.ttf$") and not fontPath:lower():match("%.otf$") then
      if LSM and type(LSM.Fetch) == "function" then
        local fetched = LSM:Fetch("font", fontPath)
        if type(fetched) == "string" and fetched ~= "" then
          fontPath = fetched
        end
      end
    end
  end
  return fontPath
end
func.ResolveFontPath = ResolveFontPath

local function RegisterFontString(fs, size, flags)
  if not fs then return end
  local reg = ns and ns._fontStrings
  if type(reg) ~= "table" then
    reg = setmetatable({}, { __mode = "k" })
    if ns then ns._fontStrings = reg end
  end
  reg[fs] = { size = size or 12, flags = flags or "" }
end

func.RegisterFontString = RegisterFontString

func.createFontString = function(f, font, size, outline, layer)
  local fs = f:CreateFontString(nil, layer or "OVERLAY")
  local fontPath = ResolveFontPath(font)
  fs:SetFont(fontPath, size or 12, outline)
  fs:SetShadowColor(0, 0, 0, 1)
  RegisterFontString(fs, size or 12, outline)
  return fs
end

-- Mover runtime moved to core/mover_runtime.lua.

--create icon func
func.createIcon = function(f, layer, size, anchorframe, anchorpoint1, anchorpoint2, posx, posy, sublevel)
  local icon = f:CreateTexture(nil, layer, nil, sublevel)
  icon:SetSize(size, size)
  icon:SetPoint(anchorpoint1, anchorframe, anchorpoint2, posx, posy)
  return icon
end

local function GetGroupRangeOutsideAlpha(frame)
  local alphaCfg = frame and frame.cfg and frame.cfg.alpha
  local outsideAlpha = type(alphaCfg) == "table" and tonumber(alphaCfg.notinrange) or nil
  return outsideAlpha or 0.55
end

-- oUF 14 owns range events and forwards potentially secret booleans directly to
-- Frame:SetAlphaFromBoolean. Roth UI only supplies the two ordinary alpha values.
func.ConfigureGroupRange = function(self)
  local style = ResolveUnitStyle(self)
  if style ~= "party" and style ~= "raid" then
    return
  end

  self.Range = {
    insideAlpha = 1,
    outsideAlpha = GetGroupRangeOutsideAlpha(self),
  }
end

func.RefreshGroupRangeFrame = function(frame)
  local range = frame and frame.Range
  if type(range) ~= "table" then return end
  range.insideAlpha = 1
  range.outsideAlpha = GetGroupRangeOutsideAlpha(frame)
  if type(frame.UpdateAllElements) == "function" then
    frame:UpdateAllElements("RothUIRangeSettings")
  end
end

function ns.RefreshGroupRangeRuntime()
  local seen = {}
  local function RefreshFrame(frame)
    if frame and not seen[frame] then
      seen[frame] = true
      func.RefreshGroupRangeFrame(frame)
    end
  end

  local partyHeader = ns and ns.partyHeader
  if partyHeader and partyHeader.GetChildren then
    for _, frame in ipairs({ partyHeader:GetChildren() }) do RefreshFrame(frame) end
  end

  local raidGroups = ns and ns.raidGroups
  if type(raidGroups) == "table" then
    for _, header in pairs(raidGroups) do
      if header and header.GetChildren then
        for _, frame in ipairs({ header:GetChildren() }) do RefreshFrame(frame) end
      end
    end
  end
end

-- Register incoming-heal bars on the Health element; oUF owns the calculator and updates.
func.healPrediction = function(self)
  if not self.cfg.healprediction or (self.cfg.healprediction and not self.cfg.healprediction.show) then return end
  local w = self.Health:GetWidth()
  if w == 0 then
    w = self:GetWidth() - 24.5 -
        24.5 --raids and party have no width on the health frame for whatever reason, thus use self and subtract the setpoint values
  end
  -- my heals
  local mhpb = CreateFrame("StatusBar", nil, self.Health)
  mhpb:SetFrameLevel(self.Health:GetFrameLevel())
  mhpb:SetPoint("TOPLEFT", self.Health, "TOPRIGHT", 0, 0)
  mhpb:SetPoint("BOTTOMLEFT", self.Health, "BOTTOMRIGHT", 0, 0)
  mhpb:SetWidth(w)
  mhpb:SetStatusBarTexture(self.cfg.healprediction.texture)
  mhpb:SetStatusBarColor(self.cfg.healprediction.color.myself.r, self.cfg.healprediction.color.myself.g,
    self.cfg.healprediction.color.myself.b, self.cfg.healprediction.color.myself.a)
  -- other heals
  local ohpb = CreateFrame("StatusBar", nil, self.Health)
  ohpb:SetFrameLevel(self.Health:GetFrameLevel())
  ohpb:SetPoint("TOPLEFT", mhpb:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
  ohpb:SetPoint("BOTTOMLEFT", mhpb:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
  ohpb:SetWidth(w)
  ohpb:SetStatusBarTexture(self.cfg.healprediction.texture)
  ohpb:SetStatusBarColor(self.cfg.healprediction.color.other.r, self.cfg.healprediction.color.other.g,
    self.cfg.healprediction.color.other.b, self.cfg.healprediction.color.other.a)
  -- Register on the Health element using the current oUF sub-widget contract.
  self.Health.HealingPlayer = mhpb
  self.Health.HealingOther = ohpb
  self.Health.incomingHealOverflow = self.cfg.healprediction.maxoverflow
end

--total absorb
func.totalAbsorb = function(self)
  if not self.cfg.totalabsorb or (self.cfg.totalabsorb and not self.cfg.totalabsorb.show) then return end

  local w = self.Health:GetWidth()

  if ResolveUnitStyle(self) == "party" then
    if cfg.units.party.vertical == false then
      if w == 0 then
        w = self:GetWidth() - 24.5 -
            24.5 --raids and party have no width on the health frame for whatever reason, thus use self and subtract the setpoint values
      end
    else
      if w == 0 then
        w = self:GetWidth() - 60 - 24.5
      end
    end
  else
    if w == 0 then
      w = self:GetWidth() - 24.5 -
          24.5 --raids and party have no width on the health frame for whatever reason, thus use self and subtract the setpoint values
    end
  end
  local absorbBar = CreateFrame("StatusBar", nil, self.Health)
  --new anchorpoint, absorb will now overlay the healthbar from right to left
  absorbBar:SetFrameLevel(self.Health:GetFrameLevel() + 1)
  absorbBar:SetPoint("TOPRIGHT", self.Health, 0, 0)
  absorbBar:SetPoint("BOTTOMRIGHT", self.Health, 0, 0)
  absorbBar:SetWidth(w)
  absorbBar:SetStatusBarTexture(self.cfg.totalabsorb.texture)
  absorbBar:SetStatusBarColor(self.cfg.totalabsorb.color.bar.r, self.cfg.totalabsorb.color.bar.g,
    self.cfg.totalabsorb.color.bar.b, self.cfg.totalabsorb.color.bar.a)
  absorbBar:SetReverseFill(true)
  -- Register on the Health element using the current oUF sub-widget contract.
  self.Health.DamageAbsorb = absorbBar
  -- Alias for smooth module and legacy call sites
  self.TotalAbsorb = absorbBar
end

--reset all settings
func.ResetAllSettings = function()
  local actions = ns and ns.settingsActions
  if type(actions) == "table" and type(actions.ResetAll) == "function" then
    return actions.ResetAll()
  end

  print("Roth_UI: settings reset is not available.")
  return false
end

--Register LSM media
LSM:Register("border", "RB border", "Interface\\AddOns\\Roth_UI\\media\\5.tga")
LSM:Register("statusbar", "Solid", "Interface\\AddOns\\Roth_UI\\media\\Solid.tga")
LSM:Register("statusbar", "Roth_Statusbar1", "Interface\\AddOns\\Roth_UI\\media\\statusbar")
LSM:Register("statusbar", "Roth_Statusbar2", "Interface\\AddOns\\Roth_UI\\media\\statusbar2")
LSM:Register("statusbar", "Roth_Statusbar3", "Interface\\AddOns\\Roth_UI\\media\\statusbar3")
LSM:Register("statusbar", "Roth_Statusbar4", "Interface\\AddOns\\Roth_UI\\media\\statusbar4")
LSM:Register("statusbar", "Roth_Statusbar5", "Interface\\AddOns\\Roth_UI\\media\\statusbar5")
LSM:Register("statusbar", "Roth_Statusbar6", "Interface\\AddOns\\Roth_UI\\media\\statusbar128")
LSM:Register("statusbar", "Roth_Statusbar7", "Interface\\AddOns\\Roth_UI\\media\\statusbar128_3")
LSM:Register("statusbar", "Roth_Statusbar8", "Interface\\AddOns\\Roth_UI\\media\\statusbar256")
LSM:Register("statusbar", "Roth_Statusbar9", "Interface\\AddOns\\Roth_UI\\media\\statusbar256_2")
LSM:Register("statusbar", "Roth_Statusbar10", "Interface\\AddOns\\Roth_UI\\media\\statusbar256_3")
LSM:Register("background", "Solid", "Interface\\AddOns\\Roth_UI\\media\\Solid.tga")
LSM:Register("font", "Cracked", "Interface\\AddOns\\Roth_UI\\media\\Cracked-Narrow.ttf")
LSM:Register("font", "Expressway", "Interface\\AddOns\\Roth_UI\\media\\Expressway.ttf")
LSM:Register("font", "Diablo Light", "Interface\\AddOns\\Roth_UI\\media\\Diablo-Light.ttf")
-- RothFont pack (integrated).
LSM:Register("font", "Roth Expressway", "Interface\\AddOns\\Roth_UI\\media\\Expressway.ttf")
LSM:Register("font", "Roth PT Sans Narrow", "Interface\\AddOns\\Roth_UI\\media\\PT_Sans_Narrow.ttf")
LSM:Register("font", "Roth Continuum", "Interface\\AddOns\\Roth_UI\\media\\Continuum_Medium.ttf")
LSM:Register("font", "Roth Cracked Narrow", "Interface\\AddOns\\Roth_UI\\media\\Cracked-Narrow.ttf")
LSM:Register("font", "Roth AssassinNation", "Interface\\AddOns\\Roth_UI\\media\\assassinnation.ttf")
LSM:Register("font", "Roth Devils Snare", "Interface\\AddOns\\Roth_UI\\media\\ufonts.com_devils-snare.ttf")
LSM:Register("font", "Roth Vielkalahizo", "Interface\\AddOns\\Roth_UI\\media\\vielkalahizo.ttf")
LSM:Register("font", "Roth Lycanthrope", "Interface\\AddOns\\Roth_UI\\media\\Lycanthrope.ttf")
LSM:Register("font", "Roth OldeEnglish", "Interface\\AddOns\\Roth_UI\\media\\OldeEnglish.ttf")
LSM:Register("font", "Roth Breakable", "Interface\\AddOns\\Roth_UI\\media\\Breakable_Regular.otf")
LSM:Register("font", "Roth Diablo Std", "Interface\\AddOns\\Roth_UI\\media\\Diablo Std Regular.otf")
LSM:Register("font", "Roth Enchanted Land", "Interface\\AddOns\\Roth_UI\\media\\Enchanted Land.otf")
