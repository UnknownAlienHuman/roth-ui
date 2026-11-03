local addon, ns = ...

local cfg = assert(ns and ns.cfg, "Roth_UI: cfg is required by units/mini_target_scaffold.lua")
local func = assert(ns and ns.func, "Roth_UI: func is required by units/mini_target_scaffold.lua")

local DEFAULT_HEALTH_POINTS = {
  { "TOP", "TOP", 0, -27.9 },
  { "LEFT", "LEFT", 24.5, 0 },
  { "RIGHT", "RIGHT", -24.5, 0 },
  { "BOTTOM", "BOTTOM", 0, 28.7 },
}
local DEFAULT_POWER_POINTS = {
  { "TOP", "TOP", 0, -13 },
  { "LEFT", "LEFT", 5, 0 },
  { "RIGHT", "RIGHT", -5, 0 },
  { "BOTTOM", "BOTTOM", 0, -10 },
}
local DEFAULT_HEALTH_GLOW_POINTS = {
  { "TOP", "TOP", 0, 17 },
  { "LEFT", "LEFT", -24, 0 },
  { "RIGHT", "RIGHT", 24, 0 },
  { "BOTTOM", "BOTTOM", 0, -20 },
}

local function ApplyPoints(region, points, relativeTo)
  for i = 1, #points do
    local point = points[i]
    region:SetPoint(point[1], relativeTo, point[2], point[3], point[4])
  end
end

function func.buildMiniTargetScaffold(self, opts)
  opts = opts or {}

  local healthCfg = self.cfg.health
  local powerCfg = self.cfg.power

  local art = self:CreateTexture(nil, opts.artLayer or "BACKGROUND", nil, opts.artSublevel or -8)
  art:SetAllPoints(self)
  art:SetTexture(opts.artTexture or "Interface\\AddOns\\Roth_UI\\media\\targettarget")
  if opts.artPoints then
    art:ClearAllPoints()
    ApplyPoints(art, opts.artPoints, self)
  end

  local health = CreateFrame("StatusBar", nil, self)
  ApplyPoints(health, opts.healthPoints or DEFAULT_HEALTH_POINTS, self)
  health:SetFrameStrata(opts.healthStrata or "LOW")

  health:SetStatusBarTexture(healthCfg.texture)
  health.bg = health:CreateTexture(nil, opts.healthBgLayer or "BACKGROUND", nil, opts.healthBgSublevel or -6)
  health.bg:SetTexture(healthCfg.texture)
  health.bg:SetAllPoints(health)

  health.glow = health:CreateTexture(nil, opts.healthGlowLayer or "OVERLAY", nil, opts.healthGlowSublevel or -5)
  health.glow:SetTexture(opts.healthGlowTexture or "Interface\\AddOns\\Roth_UI\\media\\targettarget_hpglow")
  if opts.healthGlowRelativeTo == "health" then
    health.glow:SetAllPoints(health)
  else
    ApplyPoints(health.glow, opts.healthGlowPoints or DEFAULT_HEALTH_GLOW_POINTS, self)
  end
  health.glow:SetVertexColor(0, 0, 0, 1)

  health.highlight = health:CreateTexture(nil, opts.healthHighlightLayer or "OVERLAY", nil, opts.healthHighlightSublevel or -4)
  health.highlight:SetTexture(opts.healthHighlightTexture or "Interface\\AddOns\\Roth_UI\\media\\targettarget_highlight")
  local highlightRelativeTo = self
  if opts.healthHighlightRelativeTo == "glow" then
    highlightRelativeTo = health.glow
  elseif opts.healthHighlightRelativeTo == "health" then
    highlightRelativeTo = health
  end
  health.highlight:SetAllPoints(highlightRelativeTo)

  self.Health = health
  self.Health.smoothing = func.ResolveStatusBarSmoothing(healthCfg and healthCfg.smooth)

  local powerParent = opts.powerParent == "self" and self or self.Health
  local power = CreateFrame("StatusBar", nil, powerParent)
  ApplyPoints(power, opts.powerPoints or DEFAULT_POWER_POINTS, powerParent)
  if opts.powerFrameStrata then
    power:SetFrameStrata(opts.powerFrameStrata)
  end

  power:SetStatusBarTexture(powerCfg.texture)

  power.bg = power:CreateTexture(nil, opts.powerBgLayer or "BACKGROUND", nil, opts.powerBgSublevel or -6)
  power.bg:SetTexture(powerCfg.texture)
  power.bg:SetAllPoints(power)

  power.glow = power:CreateTexture(nil, opts.powerGlowLayer or "OVERLAY", nil, opts.powerGlowSublevel or -5)
  power.glow:SetTexture(opts.powerGlowTexture or "Interface\\AddOns\\Roth_UI\\media\\targettarget_ppglow")
  power.glow:SetAllPoints(opts.powerGlowRelativeTo == "health" and health or self)
  power.glow:SetVertexColor(0, 0, 0, 1)

  self.Power = power
  if opts.smoothPower then
    self.Power.smoothing = func.ResolveStatusBarSmoothing(powerCfg and powerCfg.smooth)
  end

  local name = func.createFontString(self, cfg.font, opts.nameSize or 14, "THINOUTLINE")
  name:SetPoint("BOTTOM", self, "TOP", 0, opts.nameYOffset or -13)
  name:SetPoint("LEFT", self.Health, 0, 0)
  name:SetPoint("RIGHT", self.Health, 0, 0)
  self.Name = name

  local hpval = func.createFontString(self.Health, cfg.font, opts.healthValueSize or 11, "THINOUTLINE")
  local healthValuePoint = opts.healthValuePoint
  if healthValuePoint then
    local relativeTo = healthValuePoint[2] == "health" and health or healthValuePoint[2]
    hpval:SetPoint(healthValuePoint[1], relativeTo, healthValuePoint[3], healthValuePoint[4],
      healthValuePoint[5])
  else
    hpval:SetPoint("RIGHT", -2, 0)
  end
  if opts.healthValueJustify then
    hpval:SetJustifyH(opts.healthValueJustify)
  end

  local perphp
  if opts.showHealthPercent then
    perphp = func.createFontString(self.Health, cfg.font, opts.healthPercentSize or 11, "THINOUTLINE")
    local healthPercentPoint = opts.healthPercentPoint
    if healthPercentPoint then
      perphp:SetPoint(healthPercentPoint[1], healthPercentPoint[2], healthPercentPoint[3],
        healthPercentPoint[4], healthPercentPoint[5])
    else
      perphp:SetPoint("CENTER", health, "CENTER", 0, 0)
    end
    perphp:SetJustifyH(opts.healthPercentJustify or "CENTER")
  end

  self:Tag(name, "[roth:namecolor][name<$|r]")

  self.Health.valueText = hpval
  self.Health.valueTextMode = func.ResolveHealthValueMode()
  self.Health.perText = perphp

  if type(opts.configurePowerText) == "function" then
    opts.configurePowerText(self)
  end

  if type(opts.beforeCastbar) == "function" then
    opts.beforeCastbar(self)
  end

  if type(opts.castbarPredicate) == "function" and opts.castbarPredicate(self) then
    func.createCastbar(self)
    if self.Castbar and type(opts.onCastbarCreated) == "function" then
      opts.onCastbarCreated(self, self.Castbar)
    end
  end
end
