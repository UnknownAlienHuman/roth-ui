--get the addon namespace
local addon, ns = ...

--object container
local bars = CreateFrame("Frame")
ns.bars = bars

--get the functions
local func = ns.func
local cfg = ns.cfg
local barposition = ns.player
local mediapath = ns.mediapath or "Interface\\AddOns\\Roth_UI\\media\\"
local safety = assert(ns and ns.safety, "Roth_UI: ns.safety is required by bars.lua")
local IsSecretValue = (func and func.IsSecretValue) or
assert(safety.IsSecret, "Roth_UI: safety.IsSecret is required by bars.lua")
local function CoerceNumber(v)
  if IsSecretValue(v) then return nil end
  if type(v) == "number" then return v end
  if type(v) == "string" then
    local n = tonumber(v)
    if n then return n end
  end
  return nil
end
local function SafeNumber(v)
  if IsSecretValue(v) then return nil end
  if type(v) ~= "number" then return nil end
  return v
end

local function ResolveBarDimension(value, fallback)
  local n = tonumber(value)
  if type(n) ~= "number" or n <= 0 then
    return fallback
  end
  return n
end

local function ResolveExpRepHeight(primaryCfg, secondaryCfg, primaryDefaults, secondaryDefaults)
  local h = ResolveBarDimension(primaryCfg and primaryCfg.height, nil)
  if h then return h end
  h = ResolveBarDimension(secondaryCfg and secondaryCfg.height, nil)
  if h then return h end
  h = ResolveBarDimension(primaryDefaults and primaryDefaults.height, nil)
  if h then return h end
  h = ResolveBarDimension(secondaryDefaults and secondaryDefaults.height, nil)
  if h then return h end
  return 1
end

local function CallTooltipHook(name, frame)
  local t = ns and ns.Tooltip
  local fn = t and t[name]
  if type(fn) ~= "function" then return false end
  local handled = fn(t, frame)
  return handled and true or false
end

local function GetColorRGB(color)
  if not color then return nil end
  if type(color.GetRGB) == "function" then
    local r, g, b = color:GetRGB()
    if type(r) == "number" and type(g) == "number" and type(b) == "number" then
      return r, g, b
    end
  end
  local r = color.r or color[1]
  local g = color.g or color[2]
  local b = color.b or color[3]
  if type(r) == "number" and type(g) == "number" and type(b) == "number" then
    return r, g, b
  end
  return nil
end

local function ResolvePowerColorRGB(powerType, fallback)
  local color
  if powerType then
    if oUF and oUF.colors and oUF.colors.power then
      color = oUF.colors.power[powerType]
    end
    if not color and PowerBarColor then
      color = PowerBarColor[powerType]
    end
  end
  local r, g, b = GetColorRGB(color)
  if r then return r, g, b end
  return GetColorRGB(fallback)
end

local function AttachClassPower(self, bar, orbs)
  if not (self and bar and orbs) then return end
  local element = {}
  for i = 1, #orbs do
    local orb = orbs[i]
    local fill = orb and orb.fill
    if fill and fill.SetValue then
      element[i] = fill
      fill.__rothOrb = orb
    end
  end
  if #element < 1 then return end

  element.__bar = bar
  element.__orbs = orbs
  element.__fallbackColor = bar.color
  element.__fullColor = bar.fullColor
  element.__colorize = bar.colorize

  element.UpdateColor = function(elem, powerType)
    if not elem.__colorize then return end
    local r, g, b = ResolvePowerColorRGB(powerType, elem.__fallbackColor)
    if not r then return end
    for i = 1, #elem do
      local fill = elem[i]
      local tex = fill and fill.GetStatusBarTexture and fill:GetStatusBarTexture() or nil
      if tex then tex:SetVertexColor(r, g, b) end
      local orb = fill and fill.__rothOrb
      if orb and orb.glow then
        orb.glow:SetVertexColor(r, g, b)
      end
    end
  end

  element.PostVisibility = function(elem, isVisible)
    local b = elem.__bar
    if b and b.SetShown then
      b:SetShown(isVisible)
    end
  end

  element.PostUpdate = function(elem, cur, max, hasMaxChanged, powerType, ...)
    local b = elem.__bar
    if not b then return end
    local total = #elem
    if total < 1 then return end

    local maxNum = SafeNumber(max)
    if not maxNum or maxNum < 1 then
      maxNum = b.maxOrbs or total
    end
    if maxNum > total then maxNum = total end

    if b.orbSize and b.edgeOrbs then
      b:SetWidth(b.orbSize * (maxNum + b.edgeOrbs))
    end

    for i = 1, total do
      local orb = elem[i] and elem[i].__rothOrb
      if orb then
        if i > maxNum then
          orb:Hide()
        else
          orb:Show()
        end
      end
    end

    local curNum = SafeNumber(cur)
    local isFull = (curNum and maxNum and curNum >= maxNum) or false

    local baseR, baseG, baseB
    local fullR, fullG, fullB
    if elem.__colorize then
      baseR, baseG, baseB = ResolvePowerColorRGB(powerType, elem.__fallbackColor)
      if elem.__fullColor then
        fullR, fullG, fullB = GetColorRGB(elem.__fullColor)
      end
    end

    for i = 1, maxNum do
      local fill = elem[i]
      local orb = fill and fill.__rothOrb
      if orb then
        local value = (fill and fill.GetValue) and fill:GetValue() or 0
        local active = (not IsSecretValue(value)) and value > 0
        if active then
          fill:Show()
          if orb.glow then orb.glow:Show() end
          if orb.highlight then orb.highlight:Show() end
        else
          fill:Hide()
          if orb.glow then orb.glow:Hide() end
          if orb.highlight then orb.highlight:Hide() end
        end

        if elem.__colorize and baseR then
          local r, g, b = baseR, baseG, baseB
          if isFull and fullR then
            r, g, b = fullR, fullG, fullB
          end
          local tex = fill.GetStatusBarTexture and fill:GetStatusBarTexture() or nil
          if tex then tex:SetVertexColor(r, g, b) end
          if orb.glow then orb.glow:SetVertexColor(r, g, b) end
        end
      end
    end
  end

  self.ClassPower = element
end

local function AttachRunes(self, bar, orbs)
  if not (self and bar and orbs) then return end
  local element = {}
  for i = 1, #orbs do
    local orb = orbs[i]
    local fill = orb and orb.fill
    if fill and fill.SetValue then
      element[i] = fill
      fill.__rothOrb = orb
    end
  end
  if #element < 1 then return end

  element.__bar = bar
  element.__orbs = orbs
  element.colorSpec = true

  element.PostUpdateColor = function(elem, color)
    local r, g, b = GetColorRGB(color)
    if not r then
      return
    end

    for i = 1, #elem do
      local fill = elem[i]
      if fill then
        local tex = fill.GetStatusBarTexture and fill:GetStatusBarTexture() or nil
        if tex then
          tex:SetVertexColor(r, g, b)
        end
      end
      local orb = fill and fill.__rothOrb
      if orb and orb.glow then
        orb.glow:SetVertexColor(r, g, b)
      end
    end
  end

  element.PostUpdate = function(elem, runemap)
    local b = elem.__bar
    if b and b.SetShown then
      local show = true
      if UnitHasVehicleUI and UnitHasVehicleUI("player") then
        show = false
      end
      b:SetShown(show)
    end

    for i = 1, #elem do
      local fill = elem[i]
      local orb = fill and fill.__rothOrb
      if orb and orb.glow then
        local v = fill:GetValue()
        if not IsSecretValue(v) and v >= 1 then
          orb.glow:Show()
        else
          orb.glow:Hide()
        end
      end
    end
  end

  self.Runes = element
end

---------------------------------------------
-- FUNCTIONS
---------------------------------------------

--create the exp bar
bars.createExpBar = function(self)
  local cfg = self.cfg.expbar

  local w = ResolveBarDimension(cfg.width, 365)
  local repCfg = self.cfg.repbar or {}
  local playerDefaults = (ns and ns.cfgDefaults and ns.cfgDefaults.units and ns.cfgDefaults.units.player) or {}
  local defaultExpCfg = playerDefaults.expbar or {}
  local defaultRepCfg = playerDefaults.repbar or {}
  local h = ResolveExpRepHeight(cfg, repCfg, defaultExpCfg, defaultRepCfg)

  local f = CreateFrame("StatusBar", "Roth_UIExpBar", self)
  f:SetFrameStrata("BACKGROUND")
  f:SetFrameLevel(2)
  f:SetSize(w, h)
  f:SetPoint(cfg.pos.a1, cfg.pos.af, cfg.pos.a2, cfg.pos.x, cfg.pos.y)
  f:SetScale(cfg.scale)
  f:SetStatusBarTexture(cfg.texture)
  f:SetStatusBarColor(cfg.color.r, cfg.color.g, cfg.color.b)
  f.show = cfg.show

  local r = CreateFrame("StatusBar", nil, f)
  r:SetAllPoints(f)
  r:SetStatusBarTexture(cfg.texture)
  r:SetStatusBarColor(cfg.rested.color.r, cfg.rested.color.g, cfg.rested.color.b)
  r:SetMinMaxValues(0, 1)
  r:SetValue(0)
  r:EnableMouse(false)
  r:Hide()

  func.applyDragFunctionality(f)
  f:EnableMouse(true)
  if f.SetHitRectInsets then
    f:SetHitRectInsets(0, 0, -6, -6)
  end

  local t = r:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetAllPoints(r)
  t:SetTexture(cfg.texture)
  t:SetVertexColor(cfg.color.r, cfg.color.g, cfg.color.b, 0.3)
  f.bg = t
  f:Hide()

  f:SetScript("OnEnter", function(s)
    if CallTooltipHook("OnExpBarEnter", s) then
      s.__tooltipHandled = true
      return
    end
    if not GameTooltip then return end
    local curXP = (type(UnitXP) == "function") and CoerceNumber(UnitXP("player")) or nil
    local maxXP = (type(UnitXPMax) == "function") and CoerceNumber(UnitXPMax("player")) or nil
    local exhaustion = (type(GetXPExhaustion) == "function") and CoerceNumber(GetXPExhaustion()) or nil
    GameTooltip:SetOwner(s, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(EXPERIENCE or "Experience")
    if curXP and maxXP and maxXP > 0 then
      GameTooltip:AddLine(
      string.format("%s / %s", BreakUpLargeNumbers and BreakUpLargeNumbers(curXP) or tostring(curXP),
        BreakUpLargeNumbers and BreakUpLargeNumbers(maxXP) or tostring(maxXP)), 1, 1, 1)
    end
    if exhaustion and exhaustion > 0 then
      GameTooltip:AddLine(
      string.format("%s: %s", RESTED or "Rested",
        BreakUpLargeNumbers and BreakUpLargeNumbers(exhaustion) or tostring(exhaustion)), 0.2, 0.8, 1)
    end
    GameTooltip:Show()
    s.__tooltipHandled = true
  end)
  f:SetScript("OnLeave", function(s)
    if CallTooltipHook("OnExpBarLeave", s) then
      s.__tooltipHandled = nil
      return
    end
    if s.__tooltipHandled and GameTooltip then GameTooltip:Hide() end
    s.__tooltipHandled = nil
  end)

  f.PostUpdate = function(bar, unit, cur, maxv)
    local rested = bar and bar.Rested
    if not rested then return end

    local exhaustion = (type(GetXPExhaustion) == "function") and CoerceNumber(GetXPExhaustion()) or nil
    local maxXP = CoerceNumber(maxv)
    if not maxXP and type(UnitXPMax) == "function" then
      maxXP = CoerceNumber(UnitXPMax(unit or "player"))
    end

    if not exhaustion or exhaustion <= 0 or not maxXP or maxXP <= 0 then
      rested:SetMinMaxValues(0, 1)
      rested:SetValue(0)
      rested:Hide()
      return
    end

    local currentXP = CoerceNumber(cur)
    if not currentXP and type(UnitXP) == "function" then
      currentXP = CoerceNumber(UnitXP(unit or "player"))
    end
    if not currentXP then currentXP = 0 end

    local restedValue = currentXP + exhaustion
    if restedValue > maxXP then
      restedValue = maxXP
    end
    rested:SetMinMaxValues(0, maxXP)
    rested:SetValue(restedValue)
    rested:Show()
  end

  self.Experience = f
  self.Experience.Rested = r
  self.Experience.show = cfg.show
end

--create the reputation bar
bars.createRepBar = function(self)
  local cfg = self.cfg.repbar

  local w = ResolveBarDimension(cfg.width, 365)
  local expCfg = self.cfg.expbar or {}
  local playerDefaults = (ns and ns.cfgDefaults and ns.cfgDefaults.units and ns.cfgDefaults.units.player) or {}
  local defaultRepCfg = playerDefaults.repbar or {}
  local defaultExpCfg = playerDefaults.expbar or {}
  local h = ResolveExpRepHeight(cfg, expCfg, defaultRepCfg, defaultExpCfg)

  local f = CreateFrame("StatusBar", "Roth_UIRepBar", self)
  f:SetFrameStrata("BACKGROUND")
  f:SetFrameLevel(0)
  f:SetSize(w, h)
  f:SetPoint(cfg.pos.a1, cfg.pos.af, cfg.pos.a2, cfg.pos.x, cfg.pos.y)
  f:SetScale(cfg.scale)
  f:SetStatusBarTexture(cfg.texture)
  f:SetStatusBarColor(0, 0.7, 0)
  f.show = cfg.show
  f.colorStanding = true

  func.applyDragFunctionality(f)
  f:EnableMouse(true)
  if f.SetHitRectInsets then
    f:SetHitRectInsets(0, 0, -6, -6)
  end

  local t = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetAllPoints(f)
  t:SetTexture(cfg.texture)
  t:SetVertexColor(0, 0.7, 0)
  t:SetAlpha(0.3)
  f.bg = t
  f:Hide()

  f:SetScript("OnEnter", function(s)
    if CallTooltipHook("OnRepBarEnter", s) then
      s.__tooltipHandled = true
      return
    end
    if not GameTooltip then return end
    local watchedInfo = ns and ns.GetWatchedFactionProgressInfo and ns.GetWatchedFactionProgressInfo() or nil
    local watched = watchedInfo and watchedInfo.watchedFactionData or
    (C_Reputation and C_Reputation.GetWatchedFactionData and C_Reputation.GetWatchedFactionData() or nil)
    if not watched then return end
    GameTooltip:SetOwner(s, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(watched.name or (REPUTATION or "Reputation"))
    if watchedInfo and watchedInfo.maximum and watchedInfo.value then
      GameTooltip:AddLine(
        string.format(
          "%s / %s",
          BreakUpLargeNumbers and BreakUpLargeNumbers(watchedInfo.value) or tostring(watchedInfo.value),
          BreakUpLargeNumbers and BreakUpLargeNumbers(watchedInfo.maximum) or tostring(watchedInfo.maximum)
        ),
        1, 1, 1
      )
    elseif watched.currentReactionThreshold and watched.nextReactionThreshold and watched.currentStanding then
      local cur = (watched.currentStanding or 0) - (watched.currentReactionThreshold or 0)
      local max = (watched.nextReactionThreshold or 0) - (watched.currentReactionThreshold or 0)
      if max > 0 then
        GameTooltip:AddLine(
        string.format("%s / %s", BreakUpLargeNumbers and BreakUpLargeNumbers(cur) or tostring(cur),
          BreakUpLargeNumbers and BreakUpLargeNumbers(max) or tostring(max)), 1, 1, 1)
      end
    end
    GameTooltip:Show()
    s.__tooltipHandled = true
  end)
  f:SetScript("OnLeave", function(s)
    if CallTooltipHook("OnRepBarLeave", s) then
      s.__tooltipHandled = nil
      return
    end
    if s.__tooltipHandled and GameTooltip then GameTooltip:Hide() end
    s.__tooltipHandled = nil
  end)

  self.Reputation = f
  self.Reputation.show = cfg.show
end


--create harmony power bar
bars.createHarmonyPowerBar = function(self)
  self.Harmony = {}

  local t
  local bar = CreateFrame("Frame", "Roth_UIHarmonyPower", self)
  bar.maxOrbs = 6
  local w = 64 * (bar.maxOrbs + 2) --create the bar for
  local h = 64
  --bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  bar:SetPoint(self.cfg.harmony.pos.a1, self.cfg.harmony.pos.af, self.cfg.harmony.pos.a2, self.cfg.harmony.pos.x,
    self.cfg.harmony.pos.y)
  bar:SetWidth(w)
  bar:SetHeight(h)

  --color
  bar.color = self.cfg.harmony.color

  --left edge
  t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetSize(64, 64)
  t:SetPoint("LEFT", 0, 0)
  t:SetTexture(mediapath .. "combo_left")
  bar.leftEdge = t

  --right edge
  t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetSize(64, 64)
  t:SetPoint("RIGHT", 0, 0)
  t:SetTexture(mediapath .. "combo_right")
  bar.rightEdge = t

  for i = 1, bar.maxOrbs do
    local orb = CreateFrame("Frame", nil, bar)
    self.Harmony[i] = orb

    orb:SetSize(64, 64)
    orb:SetPoint("LEFT", i * 64, 0)

    local orbSizeMultiplier = 0.85

    --bar background
    orb.barBg = orb:CreateTexture(nil, "BACKGROUND", nil, -8)
    orb.barBg:SetSize(64, 64)
    orb.barBg:SetPoint("CENTER")
    orb.barBg:SetTexture(mediapath .. "combo_bar_bg")

    --orb background
    orb.bg = orb:CreateTexture(nil, "BACKGROUND", nil, -7)
    orb.bg:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.bg:SetPoint("CENTER")
    orb.bg:SetTexture(mediapath .. "combo_orb_bg")

    --orb filling
    orb.fill = CreateFrame("StatusBar", nil, orb)
    orb.fill:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.fill:SetPoint("CENTER")
    local fill = orb.fill:CreateTexture(nil, "BACKGROUND", nil, -6)
    fill:SetTexture(mediapath .. "combo_orb_fill1")
    orb.fill:SetStatusBarTexture(fill)
    orb.fill:SetMinMaxValues(0, 1)
    orb.fill:SetValue(0)
    orb.fill:SetStatusBarColor(self.cfg.harmony.color.r, self.cfg.harmony.color.g, self.cfg.harmony.color.b)
    --orb.fill:SetBlendMode("ADD")

    --orb border
    orb.border = orb:CreateTexture(nil, "BACKGROUND", nil, -5)
    orb.border:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.border:SetPoint("CENTER")
    orb.border:SetTexture(mediapath .. "combo_orb_border")

    --orb glow
    orb.glow = orb:CreateTexture(nil, "BACKGROUND", nil, -4)
    orb.glow:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.glow:SetPoint("CENTER")
    orb.glow:SetTexture(mediapath .. "combo_orb_glow")
    orb.glow:SetVertexColor(self.cfg.harmony.color.r, self.cfg.harmony.color.g, self.cfg.harmony.color.b)
    orb.glow:SetBlendMode("BLEND")

    --orb highlight
    orb.highlight = orb:CreateTexture(nil, "BACKGROUND", nil, -3)
    orb.highlight:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.highlight:SetPoint("CENTER")
    orb.highlight:SetTexture(mediapath .. "combo_orb_highlight")
  end

  bar:SetScale(self.cfg.harmony.scale)
  func.applyDragFunctionality(bar)
  --combat fading
  if self.cfg.harmony.combat.enable then
    rCombatFrameFader(bar, self.cfg.harmony.combat.fadeIn, self.cfg.harmony.combat.fadeOut)   --frame, buttonList, fadeIn, fadeOut
  end

  bar.orbSize = 64
  bar.edgeOrbs = 2
  bar.colorize = true
  bar.fullColor = { r = 1, g = 0, b = 0 }
  AttachClassPower(self, bar, self.Harmony)

  self.HarmonyPowerBar = bar
end

--create holy power bar
bars.createHolyPowerBar = function(self)
  self.HolyPower = {}

  local t
  local bar = CreateFrame("Frame", "Roth_UIHolyPower", self)
  bar.maxOrbs = 5
  local w = 64 * (bar.maxOrbs + 2) --create the bar for
  local h = 64
  --bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  bar:SetPoint(self.cfg.holypower.pos.a1, self.cfg.holypower.pos.af, self.cfg.holypower.pos.a2, self.cfg.holypower.pos.x,
    self.cfg.holypower.pos.y)
  bar:SetWidth(w)
  bar:SetHeight(h)
  bar:Hide()   -- show via oUF/fallback update

  --color
  bar.color = self.cfg.holypower.color

  --left edge
  t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetSize(64, 64)
  t:SetPoint("LEFT", 0, 0)
  t:SetTexture(mediapath .. "combo_left")
  bar.leftEdge = t

  --right edge
  t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetSize(64, 64)
  t:SetPoint("RIGHT", 0, 0)
  t:SetTexture(mediapath .. "combo_right")
  bar.rightEdge = t

  for i = 1, bar.maxOrbs do
    local orb = CreateFrame("Frame", nil, bar)
    self.HolyPower[i] = orb

    orb:SetSize(64, 64)
    orb:SetPoint("LEFT", i * 64, 0)

    local orbSizeMultiplier = 0.85

    --bar background
    orb.barBg = orb:CreateTexture(nil, "BACKGROUND", nil, -8)
    orb.barBg:SetSize(64, 64)
    orb.barBg:SetPoint("CENTER")
    orb.barBg:SetTexture(mediapath .. "combo_bar_bg")

    --orb background
    orb.bg = orb:CreateTexture(nil, "BACKGROUND", nil, -7)
    orb.bg:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.bg:SetPoint("CENTER")
    orb.bg:SetTexture(mediapath .. "combo_orb_bg")

    --orb filling
    orb.fill = CreateFrame("StatusBar", nil, orb)
    orb.fill:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.fill:SetPoint("CENTER")
    local fill = orb.fill:CreateTexture(nil, "BACKGROUND", nil, -6)
    fill:SetTexture(mediapath .. "combo_orb_fill1")
    orb.fill:SetStatusBarTexture(fill)
    orb.fill:SetMinMaxValues(0, 1)
    orb.fill:SetValue(0)
    orb.fill:SetStatusBarColor(self.cfg.holypower.color.r, self.cfg.holypower.color.g, self.cfg.holypower.color.b)
    --orb.fill:SetBlendMode("ADD")

    --orb border
    orb.border = orb:CreateTexture(nil, "BACKGROUND", nil, -5)
    orb.border:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.border:SetPoint("CENTER")
    orb.border:SetTexture(mediapath .. "combo_orb_border")

    --orb glow
    orb.glow = orb:CreateTexture(nil, "BACKGROUND", nil, -4)
    orb.glow:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.glow:SetPoint("CENTER")
    orb.glow:SetTexture(mediapath .. "combo_orb_glow")
    orb.glow:SetVertexColor(self.cfg.holypower.color.r, self.cfg.holypower.color.g, self.cfg.holypower.color.b)
    orb.glow:SetBlendMode("BLEND")

    --orb highlight
    orb.highlight = orb:CreateTexture(nil, "BACKGROUND", nil, -3)
    orb.highlight:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.highlight:SetPoint("CENTER")
    orb.highlight:SetTexture(mediapath .. "combo_orb_highlight")
  end

  bar:SetScale(self.cfg.holypower.scale)
  func.applyDragFunctionality(bar)
  --combat fading
  if self.cfg.holypower.combat.enable then
    rCombatFrameFader(bar, self.cfg.holypower.combat.fadeIn, self.cfg.holypower.combat.fadeOut)   --frame, buttonList, fadeIn, fadeOut
  end

  bar.orbSize = 64
  bar.edgeOrbs = 2
  bar.colorize = true
  bar.fullColor = { r = 1, g = 0, b = 0 }
  AttachClassPower(self, bar, self.HolyPower)

  self.HolyPowerBar = bar
end

--create soulshard power bar
bars.createSoulShardPowerBar = function(self)
  self.SoulShards = {}

  local t
  local bar = CreateFrame("Frame", "Roth_UISoulShardPower", self)
  bar.maxOrbs = 5
  local w = 64 * (bar.maxOrbs + 2) --create the bar for
  local h = 64
  --bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  bar:SetPoint(self.cfg.soulshards.pos.a1, self.cfg.soulshards.pos.af, self.cfg.soulshards.pos.a2,
    self.cfg.soulshards.pos.x, self.cfg.soulshards.pos.y)
  bar:SetWidth(w)
  bar:SetHeight(h)
  bar:Hide()   --hide bar (it will become available if the spec matches)

  --color
  bar.color = self.cfg.soulshards.color

  --left edge
  t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetSize(64, 64)
  t:SetPoint("LEFT", 0, 0)
  t:SetTexture(mediapath .. "combo_left")
  bar.leftEdge = t

  --right edge
  t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetSize(64, 64)
  t:SetPoint("RIGHT", 64, 0)
  t:SetTexture(mediapath .. "combo_right")
  bar.rightEdge = t

  for i = 1, bar.maxOrbs do
    local orb = CreateFrame("Frame", nil, bar)
    self.SoulShards[i] = orb
    orb:SetSize(64, 64)
    orb:SetPoint("LEFT", i * 64, 0)

    local orbSizeMultiplier = 0.95

    --bar background
    orb.barBg = orb:CreateTexture(nil, "BACKGROUND", nil, -8)
    orb.barBg:SetSize(64, 64)
    orb.barBg:SetPoint("CENTER")
    orb.barBg:SetTexture(mediapath .. "combo_bar_bg")

    --orb background
    orb.bg = orb:CreateTexture(nil, "BACKGROUND", nil, -7)
    orb.bg:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.bg:SetPoint("CENTER")
    orb.bg:SetTexture(mediapath .. "combo_gem_bg")

    --orb filling
    orb.fill = CreateFrame("StatusBar", nil, orb)
    orb.fill:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.fill:SetPoint("CENTER")
    local fill = orb.fill:CreateTexture(nil, "BACKGROUND", nil, -6)
    fill:SetTexture(mediapath .. "combo_gem_fill1")
    orb.fill:SetStatusBarTexture(fill)
    orb.fill:SetMinMaxValues(0, 1)
    orb.fill:SetValue(0)
    orb.fill:SetStatusBarColor(self.cfg.soulshards.color.r, self.cfg.soulshards.color.g, self.cfg.soulshards.color.b)
    --orb.fill:SetBlendMode("ADD")

    --orb border
    orb.border = orb:CreateTexture(nil, "BACKGROUND", nil, -5)
    orb.border:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.border:SetPoint("CENTER")
    orb.border:SetTexture(mediapath .. "combo_gem_border")

    --orb glow
    orb.glow = orb:CreateTexture(nil, "BACKGROUND", nil, -4)
    orb.glow:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.glow:SetPoint("CENTER")
    orb.glow:SetTexture(mediapath .. "combo_gem_glow")
    orb.glow:SetVertexColor(self.cfg.soulshards.color.r, self.cfg.soulshards.color.g, self.cfg.soulshards.color.b)
    orb.glow:SetBlendMode("BLEND")

    --orb highlight
    orb.highlight = orb:CreateTexture(nil, "BACKGROUND", nil, -3)
    orb.highlight:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.highlight:SetPoint("CENTER")
    orb.highlight:SetTexture(mediapath .. "combo_gem_highlight")
  end

  bar:SetScale(self.cfg.soulshards.scale)
  func.applyDragFunctionality(bar)
  --combat fading
  if self.cfg.soulshards.combat.enable then
    rCombatFrameFader(bar, self.cfg.soulshards.combat.fadeIn, self.cfg.soulshards.combat.fadeOut)   --frame, buttonList, fadeIn, fadeOut
  end

  bar.orbSize = 64
  bar.edgeOrbs = 1
  bar.colorize = true
  bar.fullColor = { r = 1, g = 0, b = 0 }
  AttachClassPower(self, bar, self.SoulShards)

  self.SoulShardPowerBar = bar
end


--create rune orbs bar
bars.createRuneBar = function(self)
  self.RuneOrbs = {}

  local t
  local bar = CreateFrame("Frame", "Roth_UIRuneBar", self)
  bar.maxOrbs = 6
  local w = 64 * (bar.maxOrbs + 2) --create the bar for
  local h = 64
  bar:SetPoint(self.cfg.runes.pos.a1, self.cfg.runes.pos.af, self.cfg.runes.pos.a2, self.cfg.runes.pos.x,
    self.cfg.runes.pos.y)
  bar:SetWidth(w)
  bar:SetHeight(h)
  bar:Hide()   --hide bar (it will become available if the spec matches)

  --left edge
  t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetSize(64, 64)
  t:SetPoint("LEFT", 0, 0)
  t:SetTexture(mediapath .. "combo_left")
  bar.leftEdge = t

  --right edge
  t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetSize(64, 64)
  t:SetPoint("RIGHT", 0, 0)
  t:SetTexture(mediapath .. "combo_right")
  bar.rightEdge = t

  for i = 1, bar.maxOrbs do
    local orb = CreateFrame("Frame", nil, bar)
    self.RuneOrbs[i] = orb
    orb:SetSize(64, 64)
    orb:SetPoint("LEFT", i * 64, 0)

    local orbSizeMultiplier = 0.85

    --bar background
    orb.barBg = orb:CreateTexture(nil, "BACKGROUND", nil, -8)
    orb.barBg:SetSize(64, 64)
    orb.barBg:SetPoint("CENTER")
    orb.barBg:SetTexture(mediapath .. "combo_bar_bg")

    --orb background
    orb.bg = orb:CreateTexture(nil, "BACKGROUND", nil, -7)
    orb.bg:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
    orb.bg:SetPoint("CENTER")
    orb.bg:SetTexture(mediapath .. "combo_orb_bg")

    --orb filling
    orb.fill = CreateFrame("StatusBar", nil, orb)
    orb.fill:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.fill:SetPoint("CENTER")
    local fill = orb.fill:CreateTexture(nil, "BACKGROUND", nil, -6)
    fill:SetTexture(mediapath .. "combo_orb_fill64_1")
    fill:SetAlpha(1)
    orb.fill:SetStatusBarTexture(fill)
    orb.fill:SetAlpha(1)
    orb.fill:SetOrientation("VERTICAL")
    orb.fill:SetMinMaxValues(0, 1)
    orb.fill:SetValue(0)

    --stack another frame to correct the texture stacking
    local helper = CreateFrame("Frame", nil, orb.fill)
    helper:SetAllPoints(orb)

    --orb border
    orb.border = helper:CreateTexture(nil, "BACKGROUND", nil, -5)
    orb.border:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
    orb.border:SetPoint("CENTER")
    orb.border:SetTexture(mediapath .. "combo_orb_border")

    --orb glow
    orb.glow = helper:CreateTexture(nil, "BACKGROUND", nil, -4)
    orb.glow:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
    orb.glow:SetPoint("CENTER")
    orb.glow:SetTexture(mediapath .. "combo_orb_glow")
    orb.glow:SetBlendMode("BLEND")
    orb.glow:Hide()

    --orb highlight
    orb.highlight = helper:CreateTexture(nil, "BACKGROUND", nil, -3)
    orb.highlight:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
    orb.highlight:SetPoint("CENTER")
    orb.highlight:SetTexture(mediapath .. "combo_orb_highlight")
  end

  bar:SetScale(self.cfg.runes.scale)
  func.applyDragFunctionality(bar)
  --combat fading
  if self.cfg.runes.combat.enable then
    rCombatFrameFader(bar, self.cfg.runes.combat.fadeIn, self.cfg.runes.combat.fadeOut)   --frame, buttonList, fadeIn, fadeOut
  end

  -- Let native oUF Runes own updates; Roth only reacts with visuals.
  AttachRunes(self, bar, self.RuneOrbs)

  self.RuneBar = bar
end

--create combo
bars.createComboBar = function(self)
  self.ComboPoints = {}
  local t
  local max = 10   -- Allocate 10 orbs safely; unused ones are hidden dynamically by AttachClassPower
  local bar = CreateFrame("Frame", "Roth_UIComboPoints", self)
  local h = 64
  bar.maxOrbs = max
  local w = 64 * (max + 2)
  --bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  bar:SetPoint(self.cfg.combobar.pos.a1, self.cfg.combobar.pos.af, self.cfg.combobar.pos.a2, self.cfg.combobar.pos.x,
    self.cfg.combobar.pos.y)
  bar:SetWidth(w)
  bar:SetHeight(h)
  bar:SetScale(self.cfg.combobar.scale)

  --color
  bar.color = self.cfg.combobar.color

  --left edge
  t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetSize(64, 64)
  t:SetPoint("LEFT", 0, 0)
  t:SetTexture(mediapath .. "combo_left")
  bar.leftEdge = t

  --right edge
  t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetSize(64, 64)
  t:SetPoint("RIGHT", 0, 0)
  t:SetTexture(mediapath .. "combo_right")
  bar.rightEdge = t

  for i = 1, max do
    local orb = CreateFrame("Frame", nil, bar)
    self.ComboPoints[i] = orb

    orb:SetSize(64, 64)
    orb:SetPoint("LEFT", i * 64, 0)

    local orbSizeMultiplier = 0.85

    --bar background
    orb.barBg = orb:CreateTexture(nil, "BACKGROUND", nil, -8)
    orb.barBg:SetSize(64, 64)
    orb.barBg:SetPoint("CENTER")
    orb.barBg:SetTexture(mediapath .. "combo_bar_bg")

    --orb background
    orb.bg = orb:CreateTexture(nil, "BACKGROUND", nil, -7)
    orb.bg:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.bg:SetPoint("CENTER")
    orb.bg:SetTexture(mediapath .. "combo_orb_bg")

    --orb filling
    orb.fill = CreateFrame("StatusBar", nil, orb)
    orb.fill:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.fill:SetPoint("CENTER")
    local fill = orb.fill:CreateTexture(nil, "BACKGROUND", nil, -6)
    fill:SetTexture(mediapath .. "combo_orb_fill1")
    orb.fill:SetStatusBarTexture(fill)
    orb.fill:SetMinMaxValues(0, 1)
    orb.fill:SetValue(0)
    orb.fill:SetStatusBarColor(self.cfg.combobar.color.r, self.cfg.combobar.color.g, self.cfg.combobar.color.b)
    --orb.fill:SetBlendMode("ADD")

    --orb border
    orb.border = orb:CreateTexture(nil, "BACKGROUND", nil, -5)
    orb.border:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.border:SetPoint("CENTER")
    orb.border:SetTexture(mediapath .. "combo_orb_border")

    --orb glow
    orb.glow = orb:CreateTexture(nil, "BACKGROUND", nil, -4)
    orb.glow:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.glow:SetPoint("CENTER")
    orb.glow:SetTexture(mediapath .. "combo_orb_glow")
    orb.glow:SetVertexColor(self.cfg.combobar.color.r, self.cfg.combobar.color.g, self.cfg.combobar.color.b)
    orb.glow:SetBlendMode("BLEND")

    --orb highlight
    orb.highlight = orb:CreateTexture(nil, "BACKGROUND", nil, -3)
    orb.highlight:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.highlight:SetPoint("CENTER")
    orb.highlight:SetTexture(mediapath .. "combo_orb_highlight")
  end



  func.applyDragFunctionality(bar)
  --combat fading
  if self.cfg.combobar.combat.enable then
    rCombatFrameFader(bar, self.cfg.combobar.combat.fadeIn, self.cfg.combobar.combat.fadeOut)   --frame, buttonList, fadeIn, fadeOut
  end
  bar.orbSize = 64
  bar.edgeOrbs = 2
  bar.colorize = true
  bar.fullColor = { r = 1, g = 0, b = 0 }
  AttachClassPower(self, bar, self.ComboPoints)
  self.ComboBar = bar
end


--Arcane Charges
bars.createArcBar = function(self)
  self.ACharges = {}

  local t
  local bar = CreateFrame("Frame", "Roth_UIArcanePower", self)
  bar.maxOrbs = 4
  local w = 64 * (bar.maxOrbs + 2) --create the bar for
  local h = 64
  --bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  bar:SetPoint(self.cfg.arcbar.pos.a1, self.cfg.arcbar.pos.af, self.cfg.arcbar.pos.a2, self.cfg.arcbar.pos.x,
    self.cfg.arcbar.pos.y)
  bar:SetWidth(w)
  bar:SetHeight(h)
  bar:Hide()   --hide bar (it will become available if the spec matches)

  --color
  bar.color = self.cfg.arcbar.color

  --left edge
  t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetSize(64, 64)
  t:SetPoint("LEFT", 0, 0)
  t:SetTexture(mediapath .. "combo_left")
  bar.leftEdge = t

  --right edge
  t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetSize(64, 64)
  t:SetPoint("RIGHT", 65, 0)
  t:SetTexture(mediapath .. "combo_right")
  bar.rightEdge = t

  for i = 1, bar.maxOrbs do
    local orb = CreateFrame("Frame", nil, bar)
    self.ACharges[i] = orb

    orb:SetSize(64, 64)
    orb:SetPoint("LEFT", i * 64, 0)

    local orbSizeMultiplier = 0.95

    --bar background
    orb.barBg = orb:CreateTexture(nil, "BACKGROUND", nil, -8)
    orb.barBg:SetSize(64, 64)
    orb.barBg:SetPoint("CENTER")
    orb.barBg:SetTexture(mediapath .. "combo_bar_bg")

    --orb background
    orb.bg = orb:CreateTexture(nil, "BACKGROUND", nil, -7)
    orb.bg:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.bg:SetPoint("CENTER")
    orb.bg:SetTexture(mediapath .. "combo_orb_bg")

    --orb filling
    orb.fill = CreateFrame("StatusBar", nil, orb)
    orb.fill:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.fill:SetPoint("CENTER")
    local fill = orb.fill:CreateTexture(nil, "BACKGROUND", nil, -6)
    fill:SetTexture [[Interface\PLAYERFRAME\MageArcaneCharges]]
    fill:SetTexCoord(0.25, 0.375, 0.5, 0.75)
    orb.fill:SetStatusBarTexture(fill)
    orb.fill:SetMinMaxValues(0, 1)
    orb.fill:SetValue(0)
    --orb.fill:SetBlendMode("ADD")

    --orb border
    orb.border = orb:CreateTexture(nil, "BACKGROUND", nil, -5)
    orb.border:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.border:SetPoint("CENTER")
    orb.border:SetTexture(mediapath .. "combo_orb_border")


    --orb highlight
    orb.highlight = orb:CreateTexture(nil, "BACKGROUND", nil, -3)
    orb.highlight:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
    orb.highlight:SetPoint("CENTER")
    orb.highlight:SetTexture(mediapath .. "combo_orb_highlight")
  end

  bar:SetScale(self.cfg.arcbar.scale)
  func.applyDragFunctionality(bar)
  --combat fading
  if self.cfg.arcbar.combat.enable then
    rCombatFrameFader(bar, self.cfg.arcbar.combat.fadeIn, self.cfg.arcbar.combat.fadeOut)   --frame, buttonList, fadeIn, fadeOut
  end

  bar.orbSize = 64
  bar.edgeOrbs = 1
  bar.colorize = false
  AttachClassPower(self, bar, self.ACharges)

  self.ArcBar = bar
end
