--get the addon namespace
local addon, ns = ...

-- Constructor namespace; it has no visual or event behavior of its own.
local bars = {}
ns.bars = bars

--get the functions
local func = ns.func
local cfg = ns.cfg
local mediapath = ns.mediapath or "Interface\\AddOns\\Roth_UI\\media\\"
local safety = assert(ns and ns.safety, "Roth_UI: ns.safety is required by bars.lua")
local IsSecret = assert(safety.IsSecret, "Roth_UI: safety.IsSecret is required by bars.lua")
assert(safety.CanAccess, "Roth_UI: safety.CanAccess is required by bars.lua")
local function CoerceNumber(v)
  if not safety.CanAccess(v) then return nil end
  if IsSecret(v) then return nil end
  if type(v) == "number" then return v end
  if type(v) == "string" then
    local n = tonumber(v)
    if n then return n end
  end
  return nil
end
local function PlayerHasVehicleUI()
  if type(UnitHasVehicleUI) ~= "function" then return false end
  local value = UnitHasVehicleUI("player")
  if not safety.CanAccess(value) then return false end
  if IsSecret(value) then return false end
  return value == true
end

local function SafeNumber(v)
  if not safety.CanAccess(v) then return nil end
  if IsSecret(v) then return nil end
  if type(v) ~= "number" then return nil end
  return v
end

local function ResolveBarDimension(value, fallback)
  if not safety.CanAccess(value) then return fallback end
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

local function AttachClassPower(self, bar, orbs)
  if not (self and bar and orbs) then return end
  local element = {}
  for i = 1, #orbs do
    local orb = orbs[i]
    local fill = orb and orb.fill
    if fill and fill.SetValue then
      element[i] = fill
      fill.__rothOrb = orb
      -- The StatusBar fill is the only active-state renderer. Avoid a second
      -- Lua state machine that reads StatusBar:GetValue on every power update.
      if orb.glow then orb.glow:Hide() end
      if orb.highlight then orb.highlight:Hide() end
    end
  end
  if #element < 1 then return end

  element.__bar = bar
  local displayedMax

  element.PostVisibility = function(elem, isVisible)
    local owner = elem.__bar
    if owner and owner.SetShown then owner:SetShown(isVisible) end
  end

  -- oUF 14 signature: (cur, max, hasCurChanged, hasMaxChanged, powerType, ...).
  -- The framework owns values and colors; Roth only adjusts bounded layout when
  -- the maximum number of pips changes.
  element.PostUpdate = function(elem, cur, maxValue, hasCurChanged, hasMaxChanged, powerType, ...)
    local owner = elem.__bar
    if not owner then return end
    local total = #elem
    if total < 1 then return end

    local maxNum = SafeNumber(maxValue)
    if not maxNum or maxNum < 1 then maxNum = owner.maxOrbs or total end
    if maxNum > total then maxNum = total end

    if displayedMax ~= maxNum then
      local maxChanged = safety.CanAccess(hasMaxChanged) and hasMaxChanged == true
      if owner.orbSize and owner.edgeOrbs and maxChanged then
        owner:SetWidth(owner.orbSize * (maxNum + owner.edgeOrbs))
      end

      for i = 1, total do
        local orb = elem[i] and elem[i].__rothOrb
        if orb then orb:SetShown(i <= maxNum) end
      end
      displayedMax = maxNum
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
      if orb.glow then orb.glow:Hide() end
      if orb.highlight then orb.highlight:Hide() end
    end
  end
  if #element < 1 then return end

  element.__bar = bar
  element.colorSpec = true
  element.PostUpdate = function(elem)
    local owner = elem.__bar
    if not (owner and owner.SetShown) then return end
    local shouldShow = not PlayerHasVehicleUI()
    if elem.__rothVisible ~= shouldShow then
      elem.__rothVisible = shouldShow
      owner:SetShown(shouldShow)
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


-- Resource bars share the same frame and pip construction. Each spec below
-- records only the visual differences, while the oUF attachment remains
-- explicit at the end of the constructor.
local COMMON_RESOURCE_TEXTURES

local function CreatePipTexture(parent, layer, sublevel, size, texturePath)
  local texture = parent:CreateTexture(nil, layer, nil, sublevel)
  texture:SetSize(size, size)
  texture:SetPoint("CENTER")
  texture:SetTexture(texturePath)
  return texture
end

local function CreatePipFill(orb, spec, color)
  local size = 64 * spec.pipScale
  local fill = CreateFrame("StatusBar", nil, orb)
  fill:SetSize(size, size)
  fill:SetPoint("CENTER")
  local texture = fill:CreateTexture(nil, "BACKGROUND", nil, -6)
  texture:SetTexture(spec.fillTexture or COMMON_RESOURCE_TEXTURES.fillTexture)
  if spec.fillAlpha then texture:SetAlpha(spec.fillAlpha) end
  if spec.fillTexCoord then texture:SetTexCoord(unpack(spec.fillTexCoord)) end
  fill:SetStatusBarTexture(texture)
  if spec.fillAlpha then fill:SetAlpha(spec.fillAlpha) end
  if spec.orientation then fill:SetOrientation(spec.orientation) end
  fill:SetMinMaxValues(0, 1)
  fill:SetValue(0)
  if spec.fillUsesColor ~= false then fill:SetStatusBarColor(color.r, color.g, color.b) end
  orb.fill = fill
end

local function CreatePipDecorations(orb, spec, color)
  local parent = orb
  if spec.decorationOnFill then
    parent = CreateFrame("Frame", nil, orb.fill)
    parent:SetAllPoints(orb)
  end
  local size = (spec.decorationSize or 64) * spec.pipScale
  orb.border = CreatePipTexture(parent, "BACKGROUND", -5, size,
    spec.borderTexture or COMMON_RESOURCE_TEXTURES.borderTexture)
  local glowTexture = spec.glowTexture
  if glowTexture == nil then glowTexture = COMMON_RESOURCE_TEXTURES.glowTexture end
  if glowTexture then
    orb.glow = CreatePipTexture(parent, "BACKGROUND", -4, size, glowTexture)
    if spec.glowUsesColor ~= false then orb.glow:SetVertexColor(color.r, color.g, color.b) end
    orb.glow:SetBlendMode("BLEND")
  end
  local highlightTexture = spec.highlightTexture or COMMON_RESOURCE_TEXTURES.highlightTexture
  if highlightTexture then
    orb.highlight = CreatePipTexture(parent, "BACKGROUND", -3, size, highlightTexture)
  end
end

local function CreateResourcePip(bar, index, orbs, spec, color)
  local orb = CreateFrame("Frame", nil, bar)
  orbs[index] = orb
  orb:SetSize(64, 64)
  orb:SetPoint("LEFT", index * 64, 0)

  orb.barBg = CreatePipTexture(orb, "BACKGROUND", -8, 64,
    spec.barBgTexture or COMMON_RESOURCE_TEXTURES.barBgTexture)
  orb.bg = CreatePipTexture(orb, "BACKGROUND", -7,
    (spec.backgroundSize or 64) * spec.pipScale,
    spec.backgroundTexture or (mediapath .. "combo_orb_bg"))
  CreatePipFill(orb, spec, color)
  CreatePipDecorations(orb, spec, color)
end

local function CreateResourceEdges(bar, spec)
  bar.leftEdge = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  bar.leftEdge:SetSize(64, 64)
  bar.leftEdge:SetPoint("LEFT", 0, 0)
  bar.leftEdge:SetTexture(mediapath .. "combo_left")

  bar.rightEdge = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  bar.rightEdge:SetSize(64, 64)
  bar.rightEdge:SetPoint("RIGHT", spec.rightEdgeX or 0, 0)
  bar.rightEdge:SetTexture(mediapath .. "combo_right")
end

COMMON_RESOURCE_TEXTURES = {
  barBgTexture = mediapath .. "combo_bar_bg",
  borderTexture = mediapath .. "combo_orb_border",
  glowTexture = mediapath .. "combo_orb_glow",
  highlightTexture = mediapath .. "combo_orb_highlight",
  fillTexture = mediapath .. "combo_orb_fill1",
}

local RESOURCE_BAR_SPECS = {
  harmony = {
    frameName = "Roth_UIHarmonyPower", orbsField = "Harmony", barField = "HarmonyPowerBar",
    maxOrbs = 6, pipScale = 0.85, classPower = true,
  },
  holypower = {
    frameName = "Roth_UIHolyPower", orbsField = "HolyPower", barField = "HolyPowerBar",
    maxOrbs = 5, pipScale = 0.85, hide = true, classPower = true,
  },
  soulshards = {
    frameName = "Roth_UISoulShardPower", orbsField = "SoulShards", barField = "SoulShardPowerBar",
    maxOrbs = 5, pipScale = 0.95, hide = true, rightEdgeX = 64, edgeOrbs = 1,
    backgroundTexture = mediapath .. "combo_gem_bg", fillTexture = mediapath .. "combo_gem_fill1",
    borderTexture = mediapath .. "combo_gem_border", glowTexture = mediapath .. "combo_gem_glow",
    highlightTexture = mediapath .. "combo_gem_highlight", classPower = true,
  },
  runes = {
    frameName = "Roth_UIRuneBar", orbsField = "RuneOrbs", barField = "RuneBar",
    maxOrbs = 6, pipScale = 0.85, hide = true, backgroundSize = 128, decorationSize = 128,
    fillTexture = mediapath .. "combo_orb_fill64_1", fillAlpha = 1, orientation = "VERTICAL",
    decorationOnFill = true, runes = true, noBarColor = true,
  },
  combobar = {
    frameName = "Roth_UIComboPoints", orbsField = "ComboPoints", barField = "ComboBar",
    maxOrbs = 10, pipScale = 0.85, classPower = true, scaleBeforePips = true,
  },
  arcbar = {
    frameName = "Roth_UIArcanePower", orbsField = "ACharges", barField = "ArcBar",
    maxOrbs = 4, pipScale = 0.95, hide = true, rightEdgeX = 65, edgeOrbs = 1,
    fillTexture = [[Interface\PLAYERFRAME\MageArcaneCharges]],
    fillTexCoord = { 0.25, 0.375, 0.5, 0.75 },
    glowTexture = false, fillUsesColor = false, classPower = true, colorize = false,
  },
}

local function CreateResourceBar(self, key)
  local spec = RESOURCE_BAR_SPECS[key]
  local config = self.cfg[key]
  local orbs = {}
  self[spec.orbsField] = orbs

  local bar = CreateFrame("Frame", spec.frameName, self)
  bar.maxOrbs = spec.maxOrbs
  bar:SetPoint(config.pos.a1, config.pos.af, config.pos.a2, config.pos.x, config.pos.y)
  bar:SetWidth(64 * (bar.maxOrbs + 2))
  bar:SetHeight(64)
  if spec.hide then bar:Hide() end
  if not spec.noBarColor then bar.color = config.color end
  if spec.scaleBeforePips then bar:SetScale(config.scale) end
  CreateResourceEdges(bar, spec)

  for index = 1, bar.maxOrbs do
    CreateResourcePip(bar, index, orbs, spec, config.color or {})
  end

  if not spec.scaleBeforePips then bar:SetScale(config.scale) end
  func.applyDragFunctionality(bar)
  if config.combat.enable then
    rCombatFrameFader(bar, config.combat.fadeIn, config.combat.fadeOut)
  end

  if spec.classPower then
    bar.orbSize = 64
    bar.edgeOrbs = spec.edgeOrbs or 2
    bar.colorize = spec.colorize ~= false
    if bar.colorize then bar.fullColor = { r = 1, g = 0, b = 0 } end
    AttachClassPower(self, bar, orbs)
  elseif spec.runes then
    AttachRunes(self, bar, orbs)
  end
  self[spec.barField] = bar
end

bars.createHarmonyPowerBar = function(self) CreateResourceBar(self, "harmony") end
bars.createHolyPowerBar = function(self) CreateResourceBar(self, "holypower") end
bars.createSoulShardPowerBar = function(self) CreateResourceBar(self, "soulshards") end
bars.createRuneBar = function(self) CreateResourceBar(self, "runes") end
bars.createComboBar = function(self) CreateResourceBar(self, "combobar") end
bars.createArcBar = function(self) CreateResourceBar(self, "arcbar") end
