
  --get the addon namespace
  local addon, ns = ...

  --get oUF namespace (just in case needed)
  local oUF = ns.oUF or oUF

  --get the config
  local cfg = ns.cfg

  --get the functions
  local func = ns.func
  local safety = ns and ns.safety
  local groupVisibility = assert(ns and ns.GroupHeaderVisibility, "Roth_UI: GroupHeaderVisibility is required by units/raid.lua")
  local frameRegistry = assert(ns and ns.frameRegistry, "Roth_UI: frameRegistry is required by units/raid.lua")

  local mediapath = ns.mediapath or "Interface\\AddOns\\Roth_UI\\media\\"

  --get the unit container
  local unit = ns.unit
  local type = type
  local pairs = pairs
  local CreateFrame = CreateFrame
  local InCombatLockdown = InCombatLockdown
  local TryCall = safety and safety.TryCall
  local TryMethod = safety and safety.TryMethod
  assert(type(TryCall) == "function" and type(TryMethod) == "function", "Roth_UI: safety.TryCall/TryMethod are required by units/raid.lua")

  ---------------------------------------------
  -- UNIT SPECIFIC FUNCTIONS
  ---------------------------------------------
	-- Always load the module. We spawn the raid headers lazily so the raid frames can be
	-- enabled/disabled from the in-game options without needing ReloadUI.

  --init parameters
  local initUnitParameters = function(self)
    self:RegisterForClicks("AnyDown")
    self:SetScript("OnEnter", UnitFrame_OnEnter)
    self:SetScript("OnLeave", UnitFrame_OnLeave)
  end


  -- Aura filtering is expressed only through managed container specifications.

  -- Health/power presentation is shared with the other unit layouts. Keeping a
  -- single hot-path implementation avoids duplicate API calls and divergent
  -- secret-value handling across forty raid frames.
  local updateHealth = assert(func and func.updateHealth, "Roth_UI: shared health runtime is required by units/raid.lua")

--check threat
  local checkThreat = function(self,event,unit)
    self.Health:ForceUpdate()
  end

  --actionbar background
  local createArtwork = function(self)
    local t = self:CreateTexture(nil,"BACKGROUND",nil,-8)
    t:SetAllPoints(self)
    t:SetTexture("Interface\\AddOns\\Roth_UI\\media\\targettarget")

    if self.cfg.special.chains then
      local c1 = self:CreateTexture(nil,"BACKGROUND",nil,-7)
      c1:SetTexture("Interface\\AddOns\\Roth_UI\\media\\chain2")
      c1:SetSize(32,32)
      c1:SetPoint("CENTER",-32,28)
      c1:SetAlpha(0.9)
      local c2 = self:CreateTexture(nil,"BACKGROUND",nil,-7)
      c2:SetTexture("Interface\\AddOns\\Roth_UI\\media\\chain2")
      c2:SetSize(32,32)
      c2:SetPoint("CENTER",32,28)
      c2:SetAlpha(0.9)
    end
	self.Texture = t

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
	h:SetFrameStrata("BACKGROUND")

    h:SetStatusBarTexture(cfg.texture)
    h.bg = h:CreateTexture(nil,"BACKGROUND",nil,-6)
    h.bg:SetTexture(cfg.texture)
    h.bg:SetAllPoints(h)

    h.glow = h:CreateTexture(nil,"BACKGROUND",nil,-5)
    h.glow:SetTexture("Interface\\AddOns\\Roth_UI\\media\\targettarget_hpglow")
    h.glow:SetPoint("TOP",0,17)
    h.glow:SetPoint("LEFT",-24,0)
    h.glow:SetPoint("RIGHT",24,0)
    h.glow:SetPoint("BOTTOM",0,-20)
    h.glow:SetVertexColor(0,0,0,1)

    h.highlight = h:CreateTexture(nil,"BACKGROUND",nil,-4)
    h.highlight:SetTexture("Interface\\AddOns\\Roth_UI\\media\\targettarget_highlight")
    h.highlight:SetAllPoints(self)

    self.Health = h
    self.Health.smoothing = func.ResolveStatusBarSmoothing(self.cfg.health and self.cfg.health.smooth)
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

    h.glow = h:CreateTexture(nil,"ARTWORK",nil,-5)
    h.glow:SetTexture("Interface\\AddOns\\Roth_UI\\media\\targettarget_ppglow")
    h.glow:SetAllPoints(self)
    h.glow:SetVertexColor(0,0,0,1)

    self.Power = h
    self.Power.smoothing = func.ResolveStatusBarSmoothing(self.cfg.power and self.cfg.power.smooth)

  end

  --create health power strings
  local createHealthPowerStrings = function(self)

    local name = func.createFontString(self, cfg.font, 10, "THINOUTLINE", "OVERLAY")
    name:SetPoint("BOTTOM", self, "TOP", 0, -22)
    name:SetPoint("LEFT", self.Health, 0, 0)
    name:SetPoint("RIGHT", self.Health, 0, 0)
    self.Name = name

    local hpval = func.createFontString(self.Health, cfg.font, 8, "THINOUTLINE", "OVERLAY")
    hpval:SetPoint("RIGHT", self.Health, "RIGHT", -4, 0)
    hpval:SetJustifyH("RIGHT")

    local perphp = func.createFontString(self.Health, cfg.font, 8, "THINOUTLINE", "OVERLAY")
    perphp:SetPoint("CENTER", self.Health, "CENTER", 0, 0)
    perphp:SetJustifyH("CENTER")

    self:Tag(name, "[roth:namecolor][name<$|r]")
    -- WoW 12.x: drive HP value from PostUpdate (secret-safe); avoid tag engine caching/comparisons.
    self.Health.valueText = hpval
    self.Health.valueTextMode = func.ResolveHealthValueMode()
    self.Health.perText = perphp

  end


  ---------------------------------------------
  -- RAID STYLE FUNC
  ---------------------------------------------

  local function createStyle(self)
  self.colors = self.colors or (oUF and oUF.colors) or {}

    --apply config to self
    self.cfg = (ns.GetUnitConfig and ns.GetUnitConfig("raid")) or cfg.units.raid
    self.__style = "raid"

    --init
    initUnitParameters(self)

    --create the art
    createArtwork(self)

    --createhealthPower
    createHealthFrame(self)
    createPowerFrame(self)

    --health power strings
    createHealthPowerStrings(self)

    --health update
    self.Health.PostUpdate = updateHealth
    self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", checkThreat)
    self:HookScript("OnHide", function(s)
      s:UnregisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    end)
    self:HookScript("OnShow", function(s)
      s:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", checkThreat)
    end)
    self.Power.PostUpdate = func.updatePower

    --debuffglow
    func.createDebuffGlow(self)

	func.ConfigureGroupRange(self)

    -- Managed aura groups are registered lazily on first frame show.
    func.QueueRaidAuras(self)
    func.QueueHealerAuraWatch(self)

    --icons
    self.RaidTargetIndicator = func.createIcon(self,"OVERLAY",14,self.Health,"CENTER","CENTER",0,0,7)
	self.RaidTargetIndicator:SetTexture("Interface\\AddOns\\Roth_UI\\media\\raidicons")
    self.ReadyCheckIndicator = func.createIcon(self,"OVERLAY",24,self.Health,"CENTER","CENTER",0,0,7)
    self.GroupRoleIndicator = func.createIcon(self,"OVERLAY",14,self.Health,"CENTER","CENTER",0,0,7)
    self.GroupRoleIndicator:SetTexture("Interface\\AddOns\\Roth_UI\\media\\lfd_role")
    self.GroupRoleIndicator:SetDesaturated(1)
	self.LeaderIndicator = func.createIcon(self,"OVERLAY",14,self.Name,"TOPLEFT","TOPLEFT",-7,-10,7)
	self.LeaderIndicator:SetTexture("Interface\\AddOns\\Roth_UI\\media\\leader")

	func.healPrediction(self)
    
    --add total absorb
    func.totalAbsorb(self)

  end

  ---------------------------------------------
  -- SPAWN RAID UNIT
  ---------------------------------------------


  -- Spawn lazily (only when enabled).
  local raidAnchor
  local raidGroups
  local ApplyRaidLayoutRuntime

  local function SpawnRaid()
    if raidGroups then return end

    -- register style
    oUF:RegisterStyle("diablo:raid", createStyle)
    oUF:SetActiveStyle("diablo:raid")

    local attr = cfg.units.raid.attributes
    local pos = cfg.units.raid.pos
    local layout = cfg.units.raid.layout or {}
    local cols = tonumber(layout.columns) or 2
    local groupSpacingX = tonumber(layout.groupSpacingX or layout.xSpacing) or 128
    local groupSpacingY = tonumber(layout.groupSpacingY or layout.ySpacing) or 310

    if not raidAnchor then
      raidAnchor = CreateFrame("Frame", "Roth_UIRaidAnchor", UIParent)
      raidAnchor:SetSize(50,50)
      raidAnchor:SetPoint(pos.a1, pos.af, pos.a2, pos.x, pos.y)
      func.applyDragFunctionality(raidAnchor)
      raidAnchor:SetFrameStrata("DIALOG")
      raidAnchor:SetFrameLevel(10)
      raidAnchor.texture = raidAnchor:CreateTexture(nil, "BACKGROUND")
      raidAnchor.texture:SetAllPoints(raidAnchor)
      raidAnchor.texture:SetTexture(mediapath.."bar_d")
      raidAnchor.texture:SetVertexColor(0,1,0,0.2)
      frameRegistry.Register("units", raidAnchor)
    end

    raidGroups = {}
    for i = 1, NUM_RAID_GROUPS do
      local name = "Roth_UIRaidGroup"..i
      local group = oUF:SpawnHeader(
        name,
        nil,
        'showPlayer',         attr.showPlayer,
        'showSolo',           attr.showSolo,
        'showParty',          attr.showParty,
        'showRaid',           attr.showRaid,
        'point',              attr.point,
        'yOffset',            attr.yOffset,
        'xOffset',            attr.xoffset,
        'groupFilter',        tostring(i),
        'maxColumns',         attr.maxColumns,
        'unitsPerColumn',     attr.unitsPerColumn,
        'oUF-initialConfigFunction', ([[
          self:SetWidth(%d)
          self:SetHeight(%d)
        ]]):format(128, 64)
      )

      local col = (i-1) % cols
      local row = math.floor((i-1) / cols)
      group:SetPoint('TOPLEFT', raidAnchor, 'TOPLEFT', col*groupSpacingX, -row*groupSpacingY)

      group.__roth_vis = attr.visibility
      groupVisibility.Apply(group, attr.visibility)

      raidGroups[i] = group
    end

    local scale = cfg.units.raid.scale
    for _, group in pairs(raidGroups) do
      if group then group:SetScale(scale) end
    end

    ns.raidAnchor = raidAnchor
    ns.raidGroups = raidGroups

    if attr.showInArena and raidGroups[1] and attr.visibility then
      local f = CreateFrame("Frame")
      f:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
      f:RegisterEvent("PLAYER_ENTERING_WORLD")
      f:SetScript("OnEvent", function()
        if ns.cfg and ns.cfg.units and ns.cfg.units.raid and (ns.IsRothEnabled and not ns.IsRothEnabled(ns.cfg.units.raid.show)) then
          return
        end
        local isArena = IsActiveBattlefieldArena and select(1, IsActiveBattlefieldArena())
        if isArena then
          groupVisibility.Show(raidGroups[1])
        else
          groupVisibility.Apply(raidGroups[1], attr.visibility)
        end
      end)
    end
  end

  local function ApplyEnabled(enabled)
    if InCombatLockdown and InCombatLockdown() then
      -- Defer to after combat.
      if not ns.__rothRaidRegenHook then
        ns.__rothRaidRegenHook = CreateFrame("Frame")
        ns.__rothRaidRegenHook:RegisterEvent("PLAYER_REGEN_ENABLED")
        ns.__rothRaidRegenHook:SetScript("OnEvent", function()
          if ns.__rothRaidPendingEnabled ~= nil then
            local v = ns.__rothRaidPendingEnabled
            ns.__rothRaidPendingEnabled = nil
            ApplyEnabled(v)
          end
        end)
      end
      ns.__rothRaidPendingEnabled = enabled and true or false
      return
    end

    if enabled then
      SpawnRaid()
      if raidAnchor then raidAnchor:Show() end
      if raidGroups then
        for _, g in pairs(raidGroups) do
          if g and g.__roth_vis then
            groupVisibility.Apply(g, g.__roth_vis)
          end
        end
      end
    else
      if raidAnchor then raidAnchor:Hide() end
      if raidGroups then
        for _, g in pairs(raidGroups) do
          if g then
            groupVisibility.Hide(g)
          end
        end
      end
    end
  end

  local function RebuildRaidStructureRuntime()
    if not (cfg and cfg.units and cfg.units.raid) then
      return
    end
    if InCombatLockdown and InCombatLockdown() then
      ns.__rothRaidPendingEnabled = ((ns.IsRothEnabled and ns.IsRothEnabled(cfg.units.raid.show)) or (cfg.units.raid.show ~= false)) and true or false
      return
    end

    local wasEnabled = ((ns.IsRothEnabled and ns.IsRothEnabled(cfg.units.raid.show)) or (cfg.units.raid.show ~= false)) and true or false
    if raidGroups then
      for _, group in pairs(raidGroups) do
        if group then
          groupVisibility.Park(group, "raid")
        end
      end
    end
    raidGroups = nil
    ns.raidGroups = nil

    if wasEnabled then
      SpawnRaid()
    end
    ApplyRaidLayoutRuntime()
    ApplyEnabled(wasEnabled)
  end

  ns.ApplyRaidEnabled = ApplyEnabled

  ApplyRaidLayoutRuntime = function()
    if not (cfg and cfg.units and cfg.units.raid) then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local scale = tonumber(cfg.units.raid.scale) or 1
    if raidGroups then
      for _, g in pairs(raidGroups) do
        if g and g.SetScale then
          g:SetScale(scale)
        end
      end
    end
    local pos = cfg.units.raid.pos
    if raidAnchor and pos then
      raidAnchor:ClearAllPoints()
      raidAnchor:SetPoint(pos.a1, pos.af, pos.a2, pos.x, pos.y)
    end
  end

  ns.ApplyRaidLayoutRuntime = ApplyRaidLayoutRuntime
  ns.RebuildRaidStructureRuntime = RebuildRaidStructureRuntime

  -- Initial state.
  ApplyEnabled((ns.IsRothEnabled and ns.IsRothEnabled(cfg.units.raid.show)) or (cfg.units.raid.show ~= false))
