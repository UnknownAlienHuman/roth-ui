local addon, ns = ...

local cfg = assert(ns and ns.cfg, "Roth_UI: cfg is required by units/mini_target_scaffold.lua")
local func = assert(ns and ns.func, "Roth_UI: func is required by units/mini_target_scaffold.lua")

function func.buildMiniTargetScaffold(self, opts)
  opts = opts or {}

  local healthCfg = self.cfg.health
  local powerCfg = self.cfg.power

  local art = self:CreateTexture(nil, "BACKGROUND", nil, -8)
  art:SetAllPoints(self)
  art:SetTexture("Interface\\AddOns\\Roth_UI\\media\\targettarget")

  local health = CreateFrame("StatusBar", nil, self)
  health:SetPoint("TOP", 0, -27.9)
  health:SetPoint("LEFT", 24.5, 0)
  health:SetPoint("RIGHT", -24.5, 0)
  health:SetPoint("BOTTOM", 0, 28.7)
  health:SetFrameStrata("LOW")

  health:SetStatusBarTexture(healthCfg.texture)
  health.bg = health:CreateTexture(nil, "BACKGROUND", nil, -6)
  health.bg:SetTexture(healthCfg.texture)
  health.bg:SetAllPoints(health)

  health.glow = health:CreateTexture(nil, "OVERLAY", nil, -5)
  health.glow:SetTexture("Interface\\AddOns\\Roth_UI\\media\\targettarget_hpglow")
  health.glow:SetPoint("TOP", 0, 17)
  health.glow:SetPoint("LEFT", -24, 0)
  health.glow:SetPoint("RIGHT", 24, 0)
  health.glow:SetPoint("BOTTOM", 0, -20)
  health.glow:SetVertexColor(0, 0, 0, 1)

  health.highlight = health:CreateTexture(nil, "OVERLAY", nil, -4)
  health.highlight:SetTexture("Interface\\AddOns\\Roth_UI\\media\\targettarget_highlight")
  health.highlight:SetAllPoints(self)

  self.Health = health
  self.Health.Smooth = true

  local power = CreateFrame("StatusBar", nil, self.Health)
  power:SetPoint("TOP", 0, -13)
  power:SetPoint("LEFT", 5, 0)
  power:SetPoint("RIGHT", -5, 0)
  power:SetPoint("BOTTOM", 0, -10)
  if opts.powerFrameStrata then
    power:SetFrameStrata(opts.powerFrameStrata)
  end

  power:SetStatusBarTexture(powerCfg.texture)

  power.bg = power:CreateTexture(nil, "BACKGROUND", nil, -6)
  power.bg:SetTexture(powerCfg.texture)
  power.bg:SetAllPoints(power)

  power.glow = power:CreateTexture(nil, "OVERLAY", nil, -5)
  power.glow:SetTexture("Interface\\AddOns\\Roth_UI\\media\\targettarget_ppglow")
  power.glow:SetAllPoints(self)
  power.glow:SetVertexColor(0, 0, 0, 1)

  self.Power = power
  if opts.smoothPower then
    self.Power.Smooth = true
  end

  local name = func.createFontString(self, cfg.font, 14, "THINOUTLINE")
  name:SetPoint("BOTTOM", self, "TOP", 0, opts.nameYOffset or -13)
  name:SetPoint("LEFT", self.Health, 0, 0)
  name:SetPoint("RIGHT", self.Health, 0, 0)
  self.Name = name

  local hpval = func.createFontString(self.Health, cfg.font, 11, "THINOUTLINE")
  hpval:SetPoint("RIGHT", -2, 0)

  local perphp
  if opts.showHealthPercent then
    perphp = func.createFontString(self.Health, cfg.font, 11, "THINOUTLINE")
    perphp:SetPoint("CENTER", self.Health, "CENTER", 0, 0)
    perphp:SetJustifyH("CENTER")
  end

  self:Tag(name, "[diablo:name]")

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
