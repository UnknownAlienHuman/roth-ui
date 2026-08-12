
  --get the addon namespace
  local addon, ns = ...

  --get oUF namespace (just in case needed)
  local oUF = ns.oUF or oUF

  --get the config
  local cfg = ns.cfg

  --get the functions
  local func = ns.func
  local frameRegistry = assert(ns and ns.frameRegistry, "Roth_UI: frameRegistry is required by units/boss.lua")
  local targetCastbarRuntime = ns.TargetCastbarRuntime

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
    self:RegisterForClicks("AnyDown")
    self:SetScript("OnEnter", UnitFrame_OnEnter)
    self:SetScript("OnLeave", UnitFrame_OnLeave)
    self:SetHitRectInsets(10,10,10,10)
  end

  local buildMiniTargetScaffold = assert(
    func.buildMiniTargetScaffold,
    "Roth_UI: buildMiniTargetScaffold is required by units/boss.lua"
  )

  local function configureBossPowerText(self)
    local ppval = func.createFontString(self.Health, cfg.font, 10, "THINOUTLINE")
    ppval:SetPoint("TOP",self.Health,"BOTTOM", 0,0)
    ppval:SetVertexColor(0.6,0.6,0.6,1)

    self.Power.valueText = ppval
    self.Power.valueTextMode = "cur"
    self.Power.perText = nil
  end

  local function bossCastbarPredicate(frame)
    return frame.cfg.castbar and frame.cfg.castbar.show
  end


  ---------------------------------------------
  -- BOSS STYLE FUNC
  ---------------------------------------------

  local bossid = 1
  unit.boss = {}

  local function createStyle(self)
  self.colors = self.colors or (oUF and oUF.colors) or {}

    --apply config to self
    self.cfg = (ns.GetUnitConfig and ns.GetUnitConfig("boss")) or cfg.units.boss
    self.__style = "boss"

    --init
    initUnitParameters(self)

    buildMiniTargetScaffold(self, {
      nameYOffset = -14,
      powerFrameStrata = "LOW",
      configurePowerText = configureBossPowerText,
      castbarPredicate = bossCastbarPredicate,
    })

    --health power update
    self.Health.PostUpdate = func.updateHealth
    self.Power.PostUpdate = func.updatePower

    --icons
    self.RaidTargetIndicator = func.createIcon(self,"BACKGROUND",16,self.Name,"BOTTOM","TOP",0,0,-1)
    self.RaidTargetIndicator:SetTexture("Interface\\AddOns\\Roth_UI\\media\\raidicons")

    --add self to unit container (maybe access to that unit is needed in another style)
    unit.boss[bossid] = self

    bossid = bossid+1

  end

  ---------------------------------------------
  -- SPAWN BOSS UNIT
  ---------------------------------------------

  if ns.IsRothEnabled and ns.IsRothEnabled(cfg.units.boss.show) then
    oUF:RegisterStyle("diablo:boss", createStyle)
    oUF:SetActiveStyle("diablo:boss")
    local boss = {}
    for i = 1, MAX_BOSS_FRAMES do
      local name = "Roth_UIBossFrame"..i
      local unit = oUF:Spawn("boss"..i, name)
      if i==1 then
        unit:SetPoint(cfg.units.boss.pos.a1,cfg.units.boss.pos.af,cfg.units.boss.pos.a2,cfg.units.boss.pos.x,cfg.units.boss.pos.y)
      else
        unit:SetPoint("TOP", boss[i-1], "BOTTOM", 0, -5)
      end
      frameRegistry.Register("units", unit)
      if unit.Castbar and targetCastbarRuntime and type(targetCastbarRuntime.Bind) == "function" then
        targetCastbarRuntime.Bind(unit.Castbar, "boss"..i)
      end
      func.applyDragFunctionality(unit)
      boss[i] = unit
    end
  end
