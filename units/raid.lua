
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


  --whitelist
  local whitelist = {}
  if cfg.units.raid.auras.whitelist then
    for _,spellid in pairs(cfg.units.raid.auras.whitelist) do
      local spell = C_Spell.GetSpellInfo(spellid)
      if spell then whitelist[spellid] = true end
    end
  end

  --blacklist
  local blacklist = {}
  if cfg.units.raid.auras.blacklist then
    for _,spellid in pairs(cfg.units.raid.auras.blacklist) do
      local spell = C_Spell.GetSpellInfo(spellid)
      if spell then blacklist[spellid] = true end
    end
  end

  --custom aura filter
  local customFilter = function(icons, unit, icon, name, texture, count, dtype, duration, timeLeft, caster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff)
    local ret = false
	if(spellID == 25771) then
		ret = true
    elseif isBossDebuff then
		ret = true
	elseif(dtype == 'Magic') then
		ret = true
	elseif(dtype == 'Poison') then
		ret = true
	elseif(dtype == 'Disease') then
		ret = true
	elseif(dtype == 'Curse') then
		ret = true
    elseif caster and caster:match("(boss)%d?$") == "boss" then
		ret = true
	elseif(spellID == 313255) then
		ret = true
	end
	if (whitelist[spellID]) then
		ret = true
	end
    return ret
  end

  local customFilterB = function(icons, unit, icon, name, texture, count, dtype, duration, timeLeft, caster, isStealable, shouldConsolidate, spellID)
    return whitelist[spellID] == true
  end

  --create buffs
  local createBuffs = function(self)
	local f = CreateFrame("Frame", nil, self)
	local cfg = self.cfg.auras
	f.size = cfg.size or 26
	f.num = cfg.num or 5
	f.spacing = cfg.spacing or 5
	f:SetAlpha(0.75)
	f.initialAnchor = cfg.initialAnchor or "TOPLEFT"
	f["growth-x"] = cfg.growthX or "RIGHT"
	f["growth-y"] = cfg.growthY or "DOWN"
	f.disableCooldown = cfg.disableCooldown or false
	--f.showDebuffType = cfg.showDebuffType or false
    f.showBuffType = cfg.showBuffType or false
    f.showStealableBuffs = cfg.showStealableBuffs or false
    if cfg.useCustomFilter and type(customFilterB) == "function" then
      f.CustomFilter = customFilterB
    end
    f.onlyShowPlayer = cfg.onlyShowPlayer
    f:SetHeight(f.size)
    f:SetWidth((f.size+f.spacing)*f.num)
    if cfg.buffPos then
      f:SetPoint(cfg.buffPos.a1 or "CENTER", self, cfg.buffPos.a2 or "CENTER", cfg.buffPos.x or 0, cfg.buffPos.y or 0)
    else
      f:SetPoint("CENTER",0,-5)
	end
	self.Buffs = (type(func.SetupNativeAuraFrame) == "function" and func.SetupNativeAuraFrame(f, false)) or f
  end

  --create aura func
  local createDebuffs = function(self)
    local f = CreateFrame("Frame", nil, self)
    local cfg = self.cfg.auras
    f.size = cfg.size or 26
    f.num = cfg.num or 5
    f.spacing = cfg.spacing or 5
    f.initialAnchor = cfg.initialAnchor or "TOPLEFT"
    f["growth-x"] = cfg.growthX or "RIGHT"
    f["growth-y"] = cfg.growthY or "DOWN"
    f.disableCooldown = cfg.disableCooldown or false
    f.showDebuffType = cfg.showDebuffType or false
    f.showBuffType = cfg.showBuffType or false
    if not cfg.doNotUseCustomFilter then
      f.CustomFilter = customFilter
    end
    f:SetHeight(f.size)
    f:SetWidth((f.size+f.spacing)*f.num)
    if cfg.debuffPos then
      f:SetPoint(cfg.debuffPos.a1 or "CENTER", self, cfg.debuffPos.a2 or "CENTER", cfg.debuffPos.x or 0, cfg.debuffPos.y or 0)
    else
      f:SetPoint("CENTER",0,-5)
    end
    f.onlyShowPlayer = cfg.onlyShowPlayer
    self.Debuffs = (type(func.SetupNativeAuraFrame) == "function" and func.SetupNativeAuraFrame(f, false)) or f
  end

  --update health func
  local COLOR_TAP_DENIED = { r = 0.65, g = 0.65, b = 0.65 }
  local COLOR_DEAD_OFFLINE = { r = 0.4, g = 0.4, b = 0.4 }
  local COLOR_THREAT = { r = 1, g = 0, b = 0 }
  local COLOR_NEUTRAL = { r = 0.5, g = 0.5, b = 0.5 }
  local IsSecretValue = (func and func.IsSecretValue) or (safety and safety.IsSecret) or function(v)
    local fn = _G.issecretvalue or _G.IsSecretValue
    return type(fn) == "function" and fn(v) or false
  end
  local SharedGetClassColorForUnit = func and func.GetClassColorForUnit
  local SafeUnitHealthPercent = func and func.SafeUnitHealthPercent
  local CoerceAccessibleNumber = func and func.CoerceAccessibleNumber
  local TryBlizzardAbbrev = func and func.TryBlizzardAbbrev
  local SetPercentText = func and func.SetPercentText
  local function GetClassColorForUnit(unit)
    if type(SharedGetClassColorForUnit) == "function" then
      return SharedGetClassColorForUnit(unit)
    end
    if not unit then return nil end
    local isPlayer = UnitIsPlayer(unit)
    if IsSecretValue(isPlayer) or not isPlayer then return nil end
    local guid = UnitGUID(unit)
    if guid and not IsSecretValue(guid) and _G.GetPlayerInfoByGUID then
      local _, class = _G.GetPlayerInfoByGUID(guid)
      if class and not IsSecretValue(class) then
        return RAID_CLASS_COLORS[class]
      end
    end
    local _, class = UnitClass(unit)
    if class and not IsSecretValue(class) then
      return RAID_CLASS_COLORS[class]
    end
    return nil
  end
  local updateHealth = function(bar, unit, min, max)
    -- WoW 12.x: values can be Secret Values. Prefer the shared safe-percent helper
    -- and only fall back to manual math when we have plain numbers.
    local value = min
    local maxv = max
    local minSecret = IsSecretValue(value)
    local maxSecret = IsSecretValue(maxv)

    if minSecret and type(CoerceAccessibleNumber) == "function" then
      local coerced = CoerceAccessibleNumber(value)
      if type(coerced) == "number" then
        value = coerced
        minSecret = false
      end
    end

    if maxSecret and type(CoerceAccessibleNumber) == "function" then
      local coerced = CoerceAccessibleNumber(maxv)
      if type(coerced) == "number" then
        maxv = coerced
        maxSecret = false
      end
    end

    local d = type(SafeUnitHealthPercent) == "function" and SafeUnitHealthPercent(unit) or nil
    local dIsNumber = type(d) == "number" and not IsSecretValue(d)
    if d == nil and (not minSecret) and (not maxSecret) and maxv and maxv > 0 and value then
      d = floor(value / maxv * 100)
      dIsNumber = true
    end

    local color
    local dead
	local offline

  local tap = unit and UnitIsTapDenied(unit)
  if not IsSecretValue(tap) and tap then
    color = COLOR_TAP_DENIED
  else
    local deadFlag = unit and UnitIsDeadOrGhost(unit)
    if not IsSecretValue(deadFlag) and deadFlag then
      color = COLOR_DEAD_OFFLINE
      dead = 1
    else
      local connected = unit and UnitIsConnected(unit)
      if not IsSecretValue(connected) and not connected then
        color = COLOR_DEAD_OFFLINE
        offline = 1
      elseif not cfg.colorswitcher.classcolored then
        color = cfg.colorswitcher.bright
      else
        if cfg.colorswitcher.threatColored and unit then
          local threat = UnitThreatSituation(unit)
          if not IsSecretValue(threat) and threat == 3 then
            color = COLOR_THREAT
          end
        end
        if not color then
          local isPlayer = unit and UnitIsPlayer(unit)
          if not IsSecretValue(isPlayer) and isPlayer then
            local classColor = GetClassColorForUnit(unit)
            if classColor then color = classColor end
          end
        end
        if not color then
          local reaction = unit and UnitReaction(unit, "player")
          if reaction and not IsSecretValue(reaction) then
            color = FACTION_BAR_COLORS[reaction]
          end
        end
      end
    end
  end
  
  if not color then color = COLOR_NEUTRAL end
    --dead
    if offline == 1 then
		bar:SetStatusBarColor(0.4, 0.4, 0.4, 0.4)
		bar.glow:SetVertexColor(0, 0, 0, 0)
    else
      --alive
      if cfg.colorswitcher.useBrightForeground then
        bar:SetStatusBarColor(color.r,color.g,color.b,color.a or 1)
        bar.bg:SetVertexColor(cfg.colorswitcher.dark.r,cfg.colorswitcher.dark.g,cfg.colorswitcher.dark.b,cfg.colorswitcher.dark.a)
      else
        bar:SetStatusBarColor(cfg.colorswitcher.dark.r,cfg.colorswitcher.dark.g,cfg.colorswitcher.dark.b,cfg.colorswitcher.dark.a)
        bar.bg:SetVertexColor(color.r,color.g,color.b,color.a or 1)
      end
    end
    --low hp
    if (dIsNumber and d <= 25) or dead == 1 then
      if cfg.colorswitcher.useBrightForeground then
        bar.glow:SetVertexColor(0.3,0,0,0.9)
        bar:SetStatusBarColor(1,0,0,1)
        bar.bg:SetVertexColor(0.15,0,0,0.7)
      else
        bar.glow:SetVertexColor(1,0,0,1)
      end
    else
      --inner shadow
      bar.glow:SetVertexColor(0,0,0,0.7)
    end
    if (not minSecret) and (not maxSecret) and maxv and maxv > 0 and value then
      bar.highlight:SetAlpha((value / maxv) * cfg.highlightMultiplier)
    else
      bar.highlight:SetAlpha(0)
    end

    -- numeric text (optional)
    if bar.valueText then
      if offline == 1 then
        bar.valueText:SetText(PLAYER_OFFLINE or "OFFLINE")
      elseif dead == 1 then
        bar.valueText:SetText(DEAD or "DEAD")
      elseif (not minSecret) and value ~= nil then
        local valueMode = bar.valueTextMode or "cur"
        if (not maxSecret) and maxv and maxv > 0 then
          if valueMode == "cur" then
            bar.valueText:SetText(func.numFormat(value))
          elseif valueMode == "percent" then
            if dIsNumber then
              bar.valueText:SetText(floor(d) .. "%")
            elseif d ~= nil and type(SetPercentText) == "function" then
              SetPercentText(bar.valueText, d)
            else
              bar.valueText:SetText(func.numFormat(value))
            end
          elseif valueMode == "curpercent" then
            if bar.perText then
              bar.valueText:SetText(func.numFormat(value))
            elseif dIsNumber then
              bar.valueText:SetText(func.numFormat(value) .. " / " .. floor(d) .. "%")
            else
              bar.valueText:SetText(func.numFormat(value))
            end
          elseif valueMode == "max" then
            bar.valueText:SetText(func.numFormat(maxv))
          else
            bar.valueText:SetText(func.numFormat(value).." / "..func.numFormat(maxv))
          end
        else
          bar.valueText:SetText(func.numFormat(value))
        end
      else
        if value == nil then
          bar.valueText:SetText("")
        elseif type(TryBlizzardAbbrev) == "function" and ns and ns.cfg and ns.cfg.shortNumbers == true then
          local abbrev = TryBlizzardAbbrev(value)
          if abbrev then
            bar.valueText:SetText(abbrev)
          else
            bar.valueText:SetText(value)
          end
        elseif IsSecretValue(value) then
          bar.valueText:SetText(value)
        elseif type(value) == "number" then
          bar.valueText:SetText(func.numFormat(value))
        else
          bar.valueText:SetText(tostring(value))
        end
      end
    end

    if bar.perText then
      local valueMode = bar.valueTextMode or "cur"
      if valueMode ~= "curpercent" or offline == 1 or dead == 1 then
        bar.perText:SetText("")
      elseif dIsNumber then
        bar.perText:SetText(floor(d) .. "%")
      elseif d ~= nil and type(SetPercentText) == "function" then
        SetPercentText(bar.perText, d)
      else
        bar.perText:SetText("")
      end
    end
  end

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

    h.glow = h:CreateTexture(nil,"ARTWORK",nil,-5)
    h.glow:SetTexture("Interface\\AddOns\\Roth_UI\\media\\targettarget_ppglow")
    h.glow:SetAllPoints(self)
    h.glow:SetVertexColor(0,0,0,1)

    self.Power = h
    self.Power.Smooth = true

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

    self:Tag(name, "[diablo:name]")
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
      func.QueueGroupAuraColorUpdate(s, "ROTH_FORCE_AURA_SYNC", s.unit)
    end)
    self:RegisterEvent("UNIT_AURA", func.QueueGroupAuraColorUpdate)
    self.Power.PostUpdate = func.updatePower

    --debuffglow
    func.createDebuffGlow(self)

	func.ConfigureGroupRange(self)

    -- Raid auras now use the native oUF/C_UnitAuras path.
    -- Safe AuraWatch lives in core/group_aura_watch.lua and stays separate.
    if self.cfg.auras.show then
      createDebuffs(self)
      if self.cfg.auras.showBuffs then
        createBuffs(self)
      end
    end

    if self.cfg.aurawatch and self.cfg.aurawatch.show and type(func.CreateSafeAuraWatch) == "function" then
      func.CreateSafeAuraWatch(self)
    end

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
