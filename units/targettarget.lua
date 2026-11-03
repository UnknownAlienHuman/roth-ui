
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
    "Roth_UI: buildMiniTargetScaffold is required by units/targettarget.lua"
  )

  --get the unit container
  local unit = ns.unit

  ---------------------------------------------
  -- UNIT SPECIFIC FUNCTIONS
  ---------------------------------------------

  --init parameters
  local initUnitParameters = function(self)
    self:SetFrameStrata("LOW")
    self:SetFrameLevel(1)
    self:SetSize(self.cfg.width, self.cfg.height)
    self:SetScale(self.cfg.scale)
    self:SetPoint(self.cfg.pos.a1,self.cfg.pos.af,self.cfg.pos.a2,self.cfg.pos.x,self.cfg.pos.y)
    self:RegisterForClicks("AnyDown")
    self:SetScript("OnEnter", UnitFrame_OnEnter)
    self:SetScript("OnLeave", UnitFrame_OnLeave)
    func.applyDragFunctionality(self)
    self:SetHitRectInsets(10,10,10,10)
  end

  ---------------------------------------------
  -- TARGETTARGET STYLE FUNC
  ---------------------------------------------

  local function createStyle(self)
  self.colors = self.colors or (oUF and oUF.colors) or {}

    --apply config to self
    self.cfg = (ns.GetUnitConfig and ns.GetUnitConfig("targettarget")) or cfg.units.targettarget
    self.__style = "targettarget"

    --init
    initUnitParameters(self)

    buildMiniTargetScaffold(self, {
      artLayer = "BORDER",
      healthPoints = {
        { "TOP", "TOP", 0, -29 },
        { "LEFT", "LEFT", 30.5, 0 },
        { "RIGHT", "RIGHT", -30.5, 0 },
        { "BOTTOM", "BOTTOM", 0, 25.7 },
      },
      healthStrata = "BACKGROUND",
      healthGlowPoints = {
        { "TOP", "TOP", 0, -33 },
        { "LEFT", "LEFT", -27.5, 0 },
        { "RIGHT", "RIGHT", 27.5, 0 },
        { "BOTTOM", "BOTTOM", 0, 27 },
      },
      healthHighlightRelativeTo = "glow",
      powerPoints = {
        { "TOP", "TOP", 0, -12 },
        { "LEFT", "LEFT", 4, 0 },
        { "RIGHT", "RIGHT", -4, 0 },
        { "BOTTOM", "BOTTOM", 0, -10 },
      },
      smoothPower = true,
      nameSize = 11,
      nameYOffset = -16,
      healthValueSize = 8,
      healthValuePoint = { "RIGHT", "health", "RIGHT", -4, 0 },
      healthValueJustify = "RIGHT",
      healthPercentSize = 8,
    })

    --health power update
    self.Health.PostUpdate = func.updateHealth
    self.Power.PostUpdate = func.updatePower

    -- oUF treats *target units as eventless. Roth UI deliberately does not
    -- install a permanent UnitCastingInfo polling loop for targettarget.

    -- Managed debuffs are registered lazily on first frame show.
    func.QueueStandardAuras(self)

    --debuffglow
    func.createDebuffGlow(self)

    --icons
    self.RaidTargetIndicator = func.createIcon(self,"BACKGROUND",20,self.Name,"BOTTOM","TOP",0,0,-1)
	self.RaidTargetIndicator:SetTexture("Interface\\AddOns\\Roth_UI\\media\\raidicons")

    func.healPrediction(self)

    --add self to unit container (maybe access to that unit is needed in another style)
    unit.targettarget = self

  end

  ---------------------------------------------
  -- SPAWN TARGETTARGET UNIT
  ---------------------------------------------

  if ns.IsRothEnabled and ns.IsRothEnabled(cfg.units.targettarget.show) then
    oUF:RegisterStyle("diablo:targettarget", createStyle)
    oUF:SetActiveStyle("diablo:targettarget")
    oUF:Spawn("targettarget", "Roth_UITargetTargetFrame")
  end
