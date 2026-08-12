
  --get the addon namespace
  local addon, ns = ...

  --get oUF namespace (just in case needed)
  local oUF = ns.oUF or oUF
  local mediapath = ns.mediapath or "Interface\\AddOns\\Roth_UI\\media\\"

  --get the config
  local cfg = ns.cfg

  --get the functions
  local func = ns.func
  local safety = assert(ns and ns.safety, "Roth_UI: safety helpers are required by units/party.lua")
  local groupVisibility = assert(ns and ns.GroupHeaderVisibility, "Roth_UI: GroupHeaderVisibility is required by units/party.lua")
  local frameRegistry = assert(ns and ns.frameRegistry, "Roth_UI: frameRegistry is required by units/party.lua")

  --get the unit container
  local unit = ns.unit
  local type = type
  local pairs = pairs
  local format = format
  local floor = floor
  local max = math.max
  local min = math.min
  local CreateFrame = CreateFrame
  local InCombatLockdown = InCombatLockdown
  local UnitHealth = UnitHealth
  local UnitHealthMax = UnitHealthMax
  local UnitPower = UnitPower
  local UnitPowerMax = UnitPowerMax
  local UnitIsDeadOrGhost = UnitIsDeadOrGhost
  local UnitIsConnected = UnitIsConnected
  local TryCall = safety.TryCall
  local TryMethod = safety.TryMethod
  ---------------------------------------------
  -- UNIT SPECIFIC FUNCTIONS
  ---------------------------------------------
  
  --init parameters
  local initUnitParameters = function(self)
    self:RegisterForClicks("AnyDown")
    self:SetScript("OnEnter", UnitFrame_OnEnter)
    self:SetScript("OnLeave", UnitFrame_OnLeave)
  end

  --actionbar background
  local createArtwork = function(self)
    local t = self:CreateTexture(nil,"BACKGROUND",nil,-8)
	if self.cfg.vertical == true then
		t:SetPoint("TOP",0,40)
		t:SetPoint("LEFT",-0,0)
		t:SetPoint("RIGHT",0,0)
		t:SetPoint("BOTTOM",0,-20)
	else
		t:SetPoint("TOP",0,20)
		t:SetPoint("LEFT",-10,0)
		t:SetPoint("RIGHT",10,0)
		t:SetPoint("BOTTOM",0,-20)
	end
    t:SetTexture("Interface\\AddOns\\Roth_UI\\media\\targettarget")
  end

  --create health frames
  local createHealthFrame = function(self)
    local cfg = self.cfg.health

    --health
    local h = CreateFrame("StatusBar", nil, self)
	if self.cfg.vertical == true then
	 h:SetPoint("TOP",0,-15)
	 h:SetPoint("LEFT",47,0)
	 h:SetPoint("RIGHT",-47,0)
	 h:SetPoint("BOTTOM",0,35)
	 h:SetFrameStrata("BACKGROUND")
	else
     h:SetPoint("TOP",0,-25)
     h:SetPoint("LEFT",10,0)
     h:SetPoint("RIGHT",-10,0)
     h:SetPoint("BOTTOM",0,25)
	 h:SetFrameStrata("BACKGROUND")
	end
    h:SetStatusBarTexture(cfg.texture)
    h.bg = h:CreateTexture(nil,"BORDER",nil,-6)
    h.bg:SetTexture(cfg.texture)
    h.bg:SetAllPoints(h)

    h.glow = h:CreateTexture(nil,"OVERLAY",nil,-5)
    h.glow:SetTexture(mediapath.."targettarget_hpglow")
	if self.cfg.vertical == true then
		h.glow:SetPoint("TOP",0,15)
		h.glow:SetPoint("LEFT",-40,0)
		h.glow:SetPoint("RIGHT",40,0)
		h.glow:SetPoint("BOTTOM",0,-35)
	else
		h.glow:SetPoint("TOP", 0, 20)
        h.glow:SetPoint("LEFT",-20,0)
        h.glow:SetPoint("RIGHT",20,0)
        h.glow:SetPoint("BOTTOM",0,-20)
	end
		
    h.highlight = h:CreateTexture(nil,"OVERLAY",nil,-4)
    h.highlight:SetTexture("Interface\\AddOns\\Roth_UI\\media\\targettarget_highlight")
    h.highlight:SetAllPoints(h.glow)

    self.Health = h
    self.Health.Smooth = true
    self.Health.frequentUpdates = self.cfg.health.frequentUpdates or false
  end

  --create power frames
  local createPowerFrame = function(self)
    local cfg = self.cfg.power

    --power
    local h = CreateFrame("StatusBar", nil, self.Health)
	if self.cfg.vertical == true then
     h:SetPoint("TOP",0,-20)
     h:SetPoint("LEFT",6,0)
     h:SetPoint("RIGHT",-6,0)
     h:SetPoint("BOTTOM",0,-20)
	 h:SetFrameStrata("BACKGROUND")
	else
     h:SetPoint("TOP",0,-20)
     h:SetPoint("LEFT",5,0)
     h:SetPoint("RIGHT",-5,0)
     h:SetPoint("BOTTOM",0,-15)
	 h:SetFrameStrata("BACKGROUND")
	end
    h:SetStatusBarTexture(cfg.texture)

    h.bg = h:CreateTexture(nil,"BORDER",nil,-6)
    h.bg:SetTexture(cfg.texture)
    h.bg:SetAllPoints(h)

    self.Power = h
    self.Power.Smooth = true
    self.Power.frequentUpdates = self.cfg.power.frequentUpdates or false

  end

  --create health power strings
  local createHealthPowerStrings = function(self)

    local nameSize = math.min(11, tonumber(self.cfg.misc and self.cfg.misc.NameFontSize) or 11)
    local valueSize = math.min(9, tonumber(self.cfg.health and self.cfg.health.fontSize) or 9)

    local name = func.createFontString(self.Health, cfg.font, nameSize, "THINOUTLINE")
	if self.cfg.vertical == true then
		name:SetPoint("BOTTOM", self, "TOP", 0, -6)
		name:SetPoint("LEFT", self.Health, 0, 0)
		name:SetPoint("RIGHT", self.Health, 0, 0)
	else
		name:SetPoint("TOP", self, "TOP", 0, 56)
		name:SetPoint("LEFT", self.Health, 0, 0)
		name:SetPoint("RIGHT", self.Health, 0, 0)
	end
	self.Name = name

    local hpval = func.createFontString(self.Health, cfg.font, valueSize, "THINOUTLINE")
    hpval:SetPoint("RIGHT", self.Health, "RIGHT", -4, 0)
    hpval:SetJustifyH("RIGHT")

    local perphp = func.createFontString(self.Health, cfg.font, valueSize, "THINOUTLINE")
    perphp:SetPoint("CENTER", self.Health, "CENTER", 0, 0)
    perphp:SetJustifyH("CENTER")

    self:Tag(name, "[diablo:name]")

    self.Health.valueText = hpval
    self.Health.valueTextMode = func.ResolveHealthValueMode()
    self.Health.perText = perphp

  end

  ---------------------------------------------
  -- PARTY STYLE FUNC
  ---------------------------------------------

  local function createStyle(self)
  self.colors = self.colors or (oUF and oUF.colors) or {}
    --apply config to self
    self.cfg = (ns.GetUnitConfig and ns.GetUnitConfig("party")) or cfg.units.party
    self.__style = "party"
    self.__renderWidth = self.cfg.portrait and self.cfg.portrait.width or self.cfg.width
    self.__renderHeight = 64

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
      if self.PortraitHolder then
        if(InCombatLockdown()) then
          self.PortraitHolder:RegisterEvent("PLAYER_REGEN_ENABLED")
        else
			if self.cfg.vertical then
				self:SetHitRectInsets(0,0,0,0)
			else 
				self:SetHitRectInsets(0,0,-100,0)
			end
        end      
        self.PortraitHolder:SetScript("OnEvent", function(...)
          self.PortraitHolder:UnregisterEvent("PLAYER_REGEN_ENABLED")
          self:SetHitRectInsets(0, 0, 0, 0)
        end)
      end      
    end

    -- Auras (WoW 12.x): simple icons + Duration objects (no manual duration math)
    if self.cfg.auras.show then
      func.createDebuffs(self)
      if self.cfg.auras.showBuffs then
        func.createBuffs(self)
      end
    end

    if self.cfg.aurawatch and self.cfg.aurawatch.show and type(func.CreateSafeAuraWatch) == "function" then
      func.CreateSafeAuraWatch(self)
    end

    --debuffglow
    func.createDebuffGlow(self)

    func.ConfigureGroupRange(self)

    --icons
    self.RaidTargetIndicator = func.createIcon(self,"OVERLAY",18,self.Name,"RIGHT","LEFT",25,0,-1)
	self.RaidTargetIndicator:SetTexture("Interface\\AddOns\\Roth_UI\\media\\raidicons")
    self.ReadyCheckIndicator = func.createIcon(self,"OVERLAY",24,self.Health,"CENTER","CENTER",0,0,-1)
    if self.Border then
      self.LeaderIndicator = func.createIcon(self,"OVERLAY",13,self.Border,"BOTTOMRIGHT","TOPRIGHT",-5,-27,-1)
      if self.cfg.portrait.use3D then
        self.GroupRoleIndicator = func.createIcon(self.BorderHolder,"OVERLAY",12,self.Health,"CENTER","CENTER",0,0,5)
      else
        self.GroupRoleIndicator = func.createIcon(self.PortraitHolder,"OVERLAY",12,self.Name,"CENTER","CENTER",0,0,5)
      end
    else
      self.LeaderIndicator = func.createIcon(self,"OVERLAY",13,self,"RIGHT","LEFT",70,30,-1)
      self.GroupRoleIndicator = func.createIcon(self,"OVERLAY",12,self,"CENTER","CENTER",0,10,-1)
    end
	self.LeaderIndicator:SetTexture("Interface\\AddOns\\Roth_UI\\media\\leader")
    self.GroupRoleIndicator:SetTexture("Interface\\AddOns\\Roth_UI\\media\\lfd_role")
    --self.LFDRole:SetDesaturated(1)

    func.healPrediction(self)
    
    --add total absorb
    func.totalAbsorb(self)

    --threat
    self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", func.checkThreat)
    self:HookScript("OnHide", function(s)
      s:UnregisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    end)
    self:HookScript("OnShow", function(s)
      s:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", func.checkThreat)
      func.QueueGroupAuraColorUpdate(s, "ROTH_FORCE_AURA_SYNC", s.unit)
    end)

    self:RegisterEvent("UNIT_AURA", func.QueueGroupAuraColorUpdate)

  end
  

  ---------------------------------------------
  -- SPAWN PARTY UNIT
  ---------------------------------------------

  local styleRegistered = false
  local partyHeaderGeneration = 0
  local partyHeader
  local partyRegenHook

  local partyDragFrame = CreateFrame("Frame", "Roth_UIPartyDragFrame", UIParent)
  partyDragFrame:SetSize(50,50)
  partyDragFrame:SetPoint(cfg.units.party.pos.a1,cfg.units.party.pos.af,cfg.units.party.pos.a2,cfg.units.party.pos.x,cfg.units.party.pos.y)
  func.applyDragFunctionality(partyDragFrame)
  frameRegistry.Register("units", partyDragFrame)

  local function GetPartyConfig()
    return cfg and cfg.units and cfg.units.party
  end

  local function IsPartyEnabled()
    local partyCfg = GetPartyConfig()
    if type(partyCfg) ~= "table" then
      return false
    end
    return (ns.IsRothEnabled and ns.IsRothEnabled(partyCfg.show)) or (partyCfg.show ~= false)
  end

  local function EnsureStyle()
    if styleRegistered then
      return
    end
    oUF:RegisterStyle("diablo:party", createStyle)
    styleRegistered = true
  end

  local function ParkPartyHeader(header)
    if header then
      groupVisibility.Park(header, "party")
    end
  end

  local function SpawnPartyHeader()
    local partyCfg = GetPartyConfig()
    if type(partyCfg) ~= "table" then
      return nil
    end

    EnsureStyle()
    oUF:SetActiveStyle("diablo:party")

    local attr = partyCfg.attributes or {}
    partyHeaderGeneration = partyHeaderGeneration + 1
    local headerName = "Roth_UIPartyHeader" .. partyHeaderGeneration
    local header

    if partyCfg.vertical == true then
      header = oUF:SpawnHeader(
        headerName,
        nil,
        "showPlayer",         attr.showPlayer,
        "showSolo",           attr.showSolo,
        "showParty",          true,
        "showRaid",           attr.showRaid,
        "point",              attr.VerticalPoint,
        "yOffset",            attr.yOffset,
        "oUF-initialConfigFunction", ([[
          self:SetWidth(%d)
          self:SetHeight(%d)
          self:SetScale(%f)
        ]]):format(partyCfg.vertwidth, partyCfg.vertheight, partyCfg.scale)
      )
    else
      header = oUF:SpawnHeader(
        headerName,
        nil,
        "showPlayer",         attr.showPlayer,
        "showSolo",           attr.showSolo,
        "showParty",          true,
        "showRaid",           attr.showRaid,
        "point",              attr.HorizontalPoint,
        "oUF-initialConfigFunction", ([[
          self:SetWidth(%d)
          self:SetHeight(%d)
          self:SetScale(%f)
        ]]):format(partyCfg.width, partyCfg.height, partyCfg.scale)
      )
    end

    if not header then
      return nil
    end

    header:ClearAllPoints()
    header:SetParent(UIParent)
    header:SetPoint("TOPLEFT", partyDragFrame, 0, 0)
    header.__roth_vis = attr.visibility
    return header
  end

  local function SetActivePartyHeader(header)
    partyHeader = header
    ns.partyHeader = header
  end

  local function QueuePartyEnabled(enabled)
    if not partyRegenHook then
      partyRegenHook = CreateFrame("Frame")
      partyRegenHook:RegisterEvent("PLAYER_REGEN_ENABLED")
      partyRegenHook:SetScript("OnEvent", function()
        if ns.__rothPartyPendingEnabled ~= nil then
          local nextEnabled = ns.__rothPartyPendingEnabled
          ns.__rothPartyPendingEnabled = nil
          ns.ApplyPartyEnabled(nextEnabled)
        end
      end)
    end
    ns.__rothPartyPendingEnabled = enabled and true or false
  end

  local function ApplyEnabled(enabled)
    if InCombatLockdown and InCombatLockdown() then
      QueuePartyEnabled(enabled)
      return
    end

    if enabled then
      if not partyHeader then
        SetActivePartyHeader(SpawnPartyHeader())
      end
      partyDragFrame:Show()
      if partyHeader then
        if partyHeader.__roth_vis then
          groupVisibility.Apply(partyHeader, partyHeader.__roth_vis)
        else
          groupVisibility.Apply(partyHeader, "show")
        end
        TryMethod(partyHeader, "Show")
      end
    else
      partyDragFrame:Hide()
      if partyHeader then
        groupVisibility.Hide(partyHeader)
      end
    end
  end

  local function ApplyPartyLayoutRuntime()
    local partyCfg = GetPartyConfig()
    if type(partyCfg) ~= "table" then return end
    if InCombatLockdown and InCombatLockdown() then return end

    local scale = tonumber(partyCfg.scale) or 1
    if partyHeader and partyHeader.SetScale then
      partyHeader:SetScale(scale)
    end

    local pos = partyCfg.pos
    if partyDragFrame and pos then
      partyDragFrame:ClearAllPoints()
      partyDragFrame:SetPoint(pos.a1, pos.af, pos.a2, pos.x, pos.y)
    end
  end

  local function RebuildPartyStructureRuntime()
    local partyCfg = GetPartyConfig()
    if type(partyCfg) ~= "table" then
      return
    end
    if InCombatLockdown and InCombatLockdown() then
      QueuePartyEnabled(IsPartyEnabled())
      return
    end

    local wasEnabled = IsPartyEnabled()
    local previousHeader = partyHeader
    SetActivePartyHeader(nil)
    if previousHeader then
      ParkPartyHeader(previousHeader)
    end

    if wasEnabled then
      SetActivePartyHeader(SpawnPartyHeader())
    end

    ApplyPartyLayoutRuntime()
    ApplyEnabled(wasEnabled)

    if wasEnabled and ns and type(ns.RefreshUnitHealthValueText) == "function" then
      ns.RefreshUnitHealthValueText("party")
    end
  end

  ns.partyDragFrame = partyDragFrame
  ns.ApplyPartyEnabled = ApplyEnabled
  ns.ApplyPartyLayoutRuntime = ApplyPartyLayoutRuntime
  ns.RebuildPartyStructureRuntime = RebuildPartyStructureRuntime

  -- Optional: hide party frames in arena.
  do
    local f = CreateFrame("Frame")
    f:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function()
      local partyCfg = GetPartyConfig()
      local attr = partyCfg and partyCfg.attributes or nil
      if not (attr and attr.hideInArena) then
        return
      end
      if not IsPartyEnabled() then
        ApplyEnabled(false)
        return
      end
      local isArena = IsActiveBattlefieldArena and select(1, IsActiveBattlefieldArena())
      if isArena then
        if partyHeader then
          groupVisibility.Hide(partyHeader)
        end
      else
        ApplyEnabled(true)
      end
    end)
  end

  -- Initial state from the profile.
  ApplyEnabled(IsPartyEnabled())
