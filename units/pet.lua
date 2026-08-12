
  --get the addon namespace
  local addon, ns = ...

  --get oUF namespace (just in case needed)
  local oUF = ns.oUF or oUF

  --get the config
  local cfg = ns.cfg

  --get the functions
  local func = ns.func

  --get the unit container
  local unit = ns.unit

  ---------------------------------------------
  -- UNIT SPECIFIC FUNCTIONS
  ---------------------------------------------

  --init parameters
  local initUnitParameters = function(self)
    self:SetFrameStrata("BACKGROUND")
    self:SetFrameLevel(1)
    self:SetSize(self.cfg.width, self.cfg.height)
    self:SetScale(self.cfg.scale)
    self:SetPoint(self.cfg.pos.a1,self.cfg.pos.af,self.cfg.pos.a2,self.cfg.pos.x,self.cfg.pos.y)
    self:RegisterForClicks("AnyDown")
    self:SetScript("OnEnter", UnitFrame_OnEnter)
    self:SetScript("OnLeave", UnitFrame_OnLeave)
    func.applyDragFunctionality(self)
  end

  --actionbar background
  local createArtwork = function(self)
    local t = self:CreateTexture(nil,"BACKGROUND",nil,-8)
    t:SetAllPoints(self)
    t:SetTexture("Interface\\AddOns\\Roth_UI\\media\\targettarget")
  end

  --create health frames
  local createHealthFrame = function(self)

    local cfg = self.cfg.health

    --health
    local h = CreateFrame("StatusBar", nil, self)
    h:SetPoint("TOP",0,-27.9)
    h:SetPoint("LEFT",24.5,0)
    h:SetPoint("RIGHT",-24.5,0)
    h:SetPoint("BOTTOM",0,28.7)
	h:SetFrameStrata("LOW")

    h:SetStatusBarTexture(cfg.texture)
    h.bg = h:CreateTexture(nil,"BACKGROUND",nil,-6)
    h.bg:SetTexture(cfg.texture)
    h.bg:SetAllPoints(h)

    h.glow = h:CreateTexture(nil,"OVERLAY",nil,-5)
    h.glow:SetTexture("Interface\\AddOns\\Roth_UI\\media\\targettarget_hpglow")
    h.glow:SetPoint("TOP",0,17)
    h.glow:SetPoint("LEFT",-24,0)
    h.glow:SetPoint("RIGHT",24,0)
    h.glow:SetPoint("BOTTOM",0,-20)
    h.glow:SetVertexColor(0,0,0,1)

    h.highlight = h:CreateTexture(nil,"OVERLAY",nil,-4)
    h.highlight:SetTexture("Interface\\AddOns\\Roth_UI\\media\\targettarget_highlight")
    h.highlight:SetAllPoints(self)

    self.Health = h
    self.Health.Smooth = true
  end

  --create power frames
  local createPowerFrame = function(self)
    local cfg = self.cfg.power

    --power
    local h = CreateFrame("StatusBar", nil, self.Health)
     h:SetPoint("TOP",0,-13)
     h:SetPoint("LEFT",5,0)
     h:SetPoint("RIGHT",-5,0)
     h:SetPoint("BOTTOM",0,-10)

    h:SetStatusBarTexture(cfg.texture)

    h.bg = h:CreateTexture(nil,"BACKGROUND",nil,-6)
    h.bg:SetTexture(cfg.texture)
    h.bg:SetAllPoints(h)

    h.glow = h:CreateTexture(nil,"OVERLAY",nil,-5)
    h.glow:SetTexture("Interface\\AddOns\\Roth_UI\\media\\targettarget_ppglow")
    h.glow:SetAllPoints(self)
    h.glow:SetVertexColor(0,0,0,1)

    self.Power = h
    self.Power.Smooth = true

  end

  --create health power strings
  local createHealthPowerStrings = function(self)

    local name = func.createFontString(self, cfg.font, 14, "THINOUTLINE")
    name:SetPoint("BOTTOM", self, "TOP", 0, -13)
    name:SetPoint("LEFT", self.Health, 0, 0)
    name:SetPoint("RIGHT", self.Health, 0, 0)
    self.Name = name

    local hpval = func.createFontString(self.Health, cfg.font, 11, "THINOUTLINE")
    hpval:SetPoint("RIGHT", -2,0)

    local perphp = func.createFontString(self.Health, cfg.font, 11, "THINOUTLINE")
    perphp:SetPoint("CENTER", self.Health, "CENTER", 0, 0)
    perphp:SetJustifyH("CENTER")

    self:Tag(name, "[diablo:name]")

    self.Health.valueText = hpval
    self.Health.valueTextMode = func.ResolveHealthValueMode()
    self.Health.perText = perphp
  end

  ---------------------------------------------
  -- PET STYLE FUNC
  ---------------------------------------------

  local function createStyle(self)
  self.colors = self.colors or (oUF and oUF.colors) or {}

    --apply config to self
    self.cfg = (ns.GetUnitConfig and ns.GetUnitConfig("pet")) or cfg.units.pet
    self.__style = "pet"

    --init
    initUnitParameters(self)

    --create the art
    createArtwork(self)

    --createhealthPower
    createHealthFrame(self)
    createPowerFrame(self)

    --health power strings
    createHealthPowerStrings(self)

    --health power update
    self.Health.PostUpdate = func.updateHealth
    self.Power.PostUpdate = func.updatePower

    --create portrait
    if func.ShouldShowPortrait(self) then
      func.createPortrait(self)
      self:SetHitRectInsets(0, 0, -100, 0);
    end

    --castbar
    if self.cfg.castbar.show then
      func.createCastbar(self)
    elseif self.cfg.castbar.hideDefault then
      --do not show the default castbar
      if PetCastingBarFrame and type(PetCastingBarFrame.SetAndUpdateShowCastbar) == "function" then
        PetCastingBarFrame:SetAndUpdateShowCastbar(false)
      elseif PetCastingBarFrame then
        PetCastingBarFrame:Hide()
      end
    end

    -- Auras (WoW 12.x): native oUF Buffs/Debuffs with Roth skinning callbacks.
    if self.cfg.auras.show then
      func.createDebuffs(self)
      if self.cfg.auras.showBuffs then
        func.createBuffs(self)
      end
	end

    --debuffglow
    func.createDebuffGlow(self)

    --make alternative power bar movable (vehicle)
    if self.cfg.altpower.show then
      func.createAlternativePowerBar(self,"oUF_AltPowerPet")
    end

    --threat
    self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", func.checkThreat)
    self:HookScript("OnHide", function(s)
      s:UnregisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    end)
    self:HookScript("OnShow", function(s)
      s:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", func.checkThreat)
    end)

    --icons
    self.RaidTargetIndicator = func.createIcon(self,"BACKGROUND",18,self.Name,"BOTTOM","TOP",0,0,-1)
    self.RaidTargetIndicator:SetTexture("Interface\\AddOns\\Roth_UI\\media\\raidicons")

    func.healPrediction(self)
    
    --add total absorb
    func.totalAbsorb(self)

    --add self to unit container (maybe access to that unit is needed in another style)
    unit.pet = self

  end

  ---------------------------------------------
  -- SPAWN PET UNIT
  ---------------------------------------------

  if ns.IsRothEnabled and ns.IsRothEnabled(cfg.units.pet.show) then
    oUF:RegisterStyle("diablo:pet", createStyle)
    oUF:SetActiveStyle("diablo:pet")
    oUF:Spawn("pet", "Roth_UIPetFrame")
  end
