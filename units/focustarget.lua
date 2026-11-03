
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
    "Roth_UI: buildMiniTargetScaffold is required by units/focustarget.lua"
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
  -- FOCUSTARGET STYLE FUNC
  ---------------------------------------------

  local function createStyle(self)
  self.colors = self.colors or (oUF and oUF.colors) or {}

    --apply config to self
    self.cfg = (ns.GetUnitConfig and ns.GetUnitConfig("focustarget")) or cfg.units.focustarget
    self.__style = "focustarget"

    --init
    initUnitParameters(self)

    buildMiniTargetScaffold(self, {
      powerParent = "self",
      powerPoints = {
        { "TOP", "TOP", 0, -38.5 },
        { "LEFT", "LEFT", 24.5, 0 },
        { "RIGHT", "RIGHT", -24.5, 0 },
        { "BOTTOM", "BOTTOM", 0, 21.9 },
      },
      smoothPower = true,
    })

    --health power update
    self.Health.PostUpdate = func.updateHealth
    self.Power.PostUpdate = func.updatePower

    --create portrait
    if func.ShouldShowPortrait(self) then
      func.createPortrait(self)
      self:SetHitRectInsets(0, 0, -100, 0);
    end

    -- Managed aura groups are registered lazily on first frame show.
    func.QueueStandardAuras(self)

    --debuffglow
    func.createDebuffGlow(self)

    --icons
    self.RaidTargetIndicator = func.createIcon(self,"BACKGROUND",18,self.Name,"BOTTOM","TOP",0,0,-1)
    self.RaidTargetIndicator:SetTexture("Interface\\AddOns\\Roth_UI\\media\\raidicons")

    func.healPrediction(self)

    --add self to unit container (maybe access to that unit is needed in another style)
    unit.focustarget = self

  end

  ---------------------------------------------
  -- SPAWN FOCUSTARGET UNIT
  ---------------------------------------------

  if ns.IsRothEnabled and ns.IsRothEnabled(cfg.units.focustarget.show) then
    oUF:RegisterStyle("diablo:focustarget", createStyle)
    oUF:SetActiveStyle("diablo:focustarget")
    oUF:Spawn("focustarget", "Roth_UIFocusTargetFrame")
  end
