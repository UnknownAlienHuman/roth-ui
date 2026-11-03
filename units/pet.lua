
  --get the addon namespace
  local addon, ns = ...

  --get oUF namespace (just in case needed)
  local oUF = ns.oUF or oUF

  --get the config
  local cfg = ns.cfg

  --get the functions
  local func = ns.func
  local buildMiniTargetScaffold = assert(
    func.buildMiniTargetScaffold,
    "Roth_UI: buildMiniTargetScaffold is required by units/pet.lua"
  )

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

    buildMiniTargetScaffold(self, {
      healthStrata = "LOW",
      smoothPower = true,
      beforeCastbar = function(frame)
        if func.ShouldShowPortrait(frame) then
          func.createPortrait(frame)
          frame:SetHitRectInsets(0, 0, -100, 0)
        end
      end,
      castbarPredicate = function(frame)
        return frame.cfg.castbar.show
      end,
    })

    --health power update
    self.Health.PostUpdate = func.updateHealth
    self.Power.PostUpdate = func.updatePower

    -- Preserve Blizzard's default pet castbar toggle when Roth's castbar is disabled.
    if not self.cfg.castbar.show and self.cfg.castbar.hideDefault then
      if PetCastingBarFrame and type(PetCastingBarFrame.SetAndUpdateShowCastbar) == "function" then
        PetCastingBarFrame:SetAndUpdateShowCastbar(false)
      elseif PetCastingBarFrame then
        PetCastingBarFrame:Hide()
      end
    end

    -- Managed aura groups are registered lazily on first frame show.
    func.QueueStandardAuras(self, { buffs = self.cfg.auras.showBuffs == true })

    --debuffglow
    func.createDebuffGlow(self)

    --make alternative power bar movable (vehicle)
    if self.cfg.altpower.show then
      func.createAlternativePowerBar(self,"oUF_AltPowerPet")
    end

    --threat
    self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", func.checkThreat)

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
