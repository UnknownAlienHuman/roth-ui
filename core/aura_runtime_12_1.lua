-- Retail 12.1 aura compatibility layer.
--
-- oUF 14 replaces the legacy self.Buffs/self.Debuffs element contract with
-- managed AuraContainer objects created through frame:CreateAuras().  This
-- adapter keeps Roth_UI's layout-facing helpers stable while moving aura
-- ownership, filtering, counts, cooldowns and durations to Blizzard/oUF sinks.
-- It deliberately does not inspect AuraData or UNIT_AURA payload values.

local addonName, ns = ...

local func = assert(ns and ns.func, "Roth_UI: ns.func is required by aura_runtime_12_1.lua")
local oUF = ns.oUF or _G.oUF
local cfg = ns.cfg

local type = type
local tonumber = tonumber
local next = next
local floor = math.floor
local max = math.max
local CreateFrame = CreateFrame
local UnitClass = UnitClass
local GetBuildInfo = GetBuildInfo

local mediapath = ns.mediapath or "Interface\\AddOns\\Roth_UI\\media\\"
local IsSecretValue = func.IsSecretValue or function()
  return false
end

local _, _, _, interfaceVersion = GetBuildInfo()
interfaceVersion = tonumber(interfaceVersion) or 0
if interfaceVersion < 120100 then
  return
end

local HORIZONTAL_AXIS = AnchorUtil and AnchorUtil.FlowLayoutAxis and AnchorUtil.FlowLayoutAxis.Horizontal
local VERTICAL_AXIS = AnchorUtil and AnchorUtil.FlowLayoutAxis and AnchorUtil.FlowLayoutAxis.Vertical
local SORT_METHODS = _G.AuraContainerSortMethod
local SORT_DIRECTIONS = _G.AuraContainerSortDirection

local SPELL_IDS_BY_CLASS = {
  PRIEST = { 139, 17, 77489, 41635 },
  PALADIN = { 223306, 53563, 6940, 287280, 156910, 200025 },
  DRUID = { 33763, 774, 8936, 102342, 102351, 48438, 155777 },
  SHAMAN = { 61295 },
  MONK = { 119611, 124682 },
}

local function WarnOnce(key, message)
  ns.__rothAuraWarnings = ns.__rothAuraWarnings or {}
  if ns.__rothAuraWarnings[key] then
    return
  end
  ns.__rothAuraWarnings[key] = true
  print("|cffff8000Roth_UI:|r " .. message)
end

local function ResolveUnitStyle(frame)
  if not frame then
    return nil
  end

  local style = frame.__style
  if type(style) == "string" and style ~= "" then
    return style
  end

  local frameCfg = frame.cfg
  style = frameCfg and frameCfg.style
  if type(style) == "string" and style ~= "" then
    return style
  end

  return nil
end

local function BuildSpellIDMap(list)
  if type(list) ~= "table" then
    return nil
  end

  local result = {}
  for i = 1, #list do
    local spellID = tonumber(list[i])
    if spellID and spellID > 0 then
      result[spellID] = true
    end
  end

  if next(result) == nil then
    return nil
  end
  return result
end

local function CopyMap(source)
  if type(source) ~= "table" then
    return nil
  end

  local result = {}
  for key, value in pairs(source) do
    if type(value) == "table" then
      local child = {}
      for childKey, childValue in pairs(value) do
        child[childKey] = childValue
      end
      result[key] = child
    else
      result[key] = value
    end
  end
  return result
end

local function ResolveAuraFilter(legacyFrame)
  local explicit = legacyFrame and legacyFrame.__rothAuraFilter
  if explicit == "HELPFUL" or explicit == "HARMFUL" then
    return explicit
  end

  -- Raid debuff placeholders historically carry both showDebuffType and
  -- showBuffType.  Harmful therefore has precedence when both are present.
  if legacyFrame and legacyFrame.showDebuffType ~= nil then
    return "HARMFUL"
  end
  if legacyFrame and (legacyFrame.showStealableBuffs ~= nil or legacyFrame.showBuffType ~= nil) then
    return "HELPFUL"
  end

  return "HARMFUL"
end

local function ResolveCandidateFilters(legacyFrame, owner, filter)
  local explicit = legacyFrame and legacyFrame.__rothCandidateFilters
  local result = CopyMap(explicit) or {}
  local style = ResolveUnitStyle(owner)
  local hasLegacyCustomFilter = legacyFrame and type(legacyFrame.CustomFilter) == "function"

  -- The old raid helpful CustomFilter was a spell-ID whitelist.  Translate it
  -- into a managed candidate filter instead of calling the Lua predicate.
  if filter == "HELPFUL" and style == "raid" and hasLegacyCustomFilter then
    local raidAuras = owner and owner.cfg and owner.cfg.auras
    local includeSpellIDs = BuildSpellIDMap(raidAuras and raidAuras.whitelist)
    if includeSpellIDs then
      result.includeSpellIDs = includeSpellIDs
    end
  end

  -- The old raid harmful predicate was an OR-chain over boss/dispel/spell
  -- properties.  A single candidate-filter table is conjunctive, so applying
  -- onlyShowPlayer here would silently remove boss and dispellable debuffs.
  local ignorePlayerRestriction = filter == "HARMFUL" and style == "raid" and hasLegacyCustomFilter
  if legacyFrame and legacyFrame.onlyShowPlayer == true and not ignorePlayerRestriction then
    result.isFromPlayerOrPlayerPet = true
  end

  if next(result) == nil then
    return nil
  end
  return result
end

local function NormalizeCount(value, fallback)
  local count = floor(tonumber(value) or fallback or 1)
  if count < 0 then
    return 0
  end
  return count
end

local function ResolveLegacyGeometry(legacyFrame)
  local size = max(1, tonumber(legacyFrame and legacyFrame.size) or 16)
  local spacing = max(0, tonumber(legacyFrame and legacyFrame.spacing) or 0)
  local width = legacyFrame and legacyFrame.GetWidth and tonumber(legacyFrame:GetWidth()) or nil
  local height = legacyFrame and legacyFrame.GetHeight and tonumber(legacyFrame:GetHeight()) or nil

  width = width and width > 0 and width or size
  height = height and height > 0 and height or size

  local growthX = legacyFrame and (legacyFrame.growthX or legacyFrame["growth-x"]) or "RIGHT"
  local growthY = legacyFrame and (legacyFrame.growthY or legacyFrame["growth-y"]) or "DOWN"
  if growthX ~= "LEFT" then growthX = "RIGHT" end
  if growthY ~= "UP" then growthY = "DOWN" end

  local initialAnchor = legacyFrame and legacyFrame.initialAnchor or "TOPLEFT"
  if type(initialAnchor) ~= "string" or initialAnchor == "" then
    initialAnchor = "TOPLEFT"
  end

  local axis = HORIZONTAL_AXIS
  local layoutLimit = width
  if VERTICAL_AXIS and height > width * 1.25 then
    axis = VERTICAL_AXIS
    layoutLimit = height
  end

  return {
    size = size,
    spacing = spacing,
    width = width,
    height = height,
    growthX = growthX,
    growthY = growthY,
    initialAnchor = initialAnchor,
    axis = axis,
    layoutLimit = max(1, layoutLimit),
  }
end

local function CopyAnchor(source, target)
  if not (source and source.GetPoint and target and target.SetPoint) then
    return
  end

  target:ClearAllPoints()
  local point, relativeTo, relativePoint, x, y = source:GetPoint(1)
  if not point then
    local parent = source.GetParent and source:GetParent()
    if parent then
      target:SetAllPoints(parent)
    end
    return
  end

  x = tonumber(x) or 0
  y = tonumber(y) or 0
  if relativeTo then
    target:SetPoint(point, relativeTo, relativePoint or point, x, y)
  else
    target:SetPoint(point, x, y)
  end
end

local function ApplyFont(fontString, size)
  if not (fontString and fontString.SetFont) then
    return
  end

  local fontPath = (cfg and cfg.font) or STANDARD_TEXT_FONT
  if type(func.ResolveFontPath) == "function" then
    fontPath = func.ResolveFontPath(fontPath)
  end
  if type(fontPath) ~= "string" or fontPath == "" then
    fontPath = STANDARD_TEXT_FONT
  end

  fontString:SetFont(fontPath, size, "THINOUTLINE")
end

local function StyleManagedAuraButton(element, button)
  if not button then
    return
  end

  local size = max(1, tonumber(element and element.size) or (button.GetWidth and button:GetWidth()) or 16)

  if button.Icon then
    button.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
  end

  if button.Cooldown then
    button.Cooldown:ClearAllPoints()
    button.Cooldown:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.Cooldown:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    if button.Cooldown.SetReverse then
      button.Cooldown:SetReverse(true)
    end
    if button.Cooldown.SetDrawEdge then
      button.Cooldown:SetDrawEdge(false)
    end
    if button.Cooldown.SetHideCountdownNumbers then
      button.Cooldown:SetHideCountdownNumbers(true)
    end
  end

  if button.Count then
    button.Count:ClearAllPoints()
    button.Count:SetPoint("TOPRIGHT", button, "TOPRIGHT", 4, 4)
    button.Count:SetTextColor(0.9, 0.9, 0.9)
    ApplyFont(button.Count, max(8, floor(size / 1.8)))
  end

  if button.Time then
    button.Time:ClearAllPoints()
    button.Time:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -1, 1)
    button.Time:SetJustifyH("LEFT")
    button.Time:SetJustifyV("BOTTOM")
    ApplyFont(button.Time, max(7, floor(size * 0.28)))
  end

  local back = button:CreateTexture(nil, "BACKGROUND", nil, 0)
  back:SetPoint("TOPLEFT", button, "TOPLEFT", -0.18 * size, 0.18 * size)
  back:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0.18 * size, -0.18 * size)
  back:SetTexture(mediapath .. "simplesquare_glow")
  back:SetVertexColor(0, 0, 0, 1)
  button.RothBackdropGlow = back

  local gloss = button:CreateTexture(nil, "ARTWORK", nil, 0)
  gloss:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
  gloss:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
  gloss:SetTexture(mediapath .. "gloss2")
  gloss:SetVertexColor(0.4, 0.35, 0.35, 1)
  button.RothGloss = gloss

  -- Keep this separate from button.Border.  oUF owns button.Border as the
  -- native dispel-type sink and updates it without exposing aura values.
  local border = button:CreateTexture(nil, "ARTWORK", nil, 1)
  border:SetAllPoints(button)
  border:SetTexture(mediapath .. "icon_border")
  border:SetVertexColor(0.08, 0.08, 0.08, 0.9)
  button.RothBorder = border
end

local function ResolveSortMethod(filter)
  if type(SORT_METHODS) ~= "table" then
    return nil
  end
  if filter == "HARMFUL" then
    return SORT_METHODS.UnitFrameDebuff or SORT_METHODS.Default
  end
  return SORT_METHODS.ExpirationOnly or SORT_METHODS.Default
end

local function CreateManagedAuraElement(legacyFrame, showTimers)
  if not (legacyFrame and legacyFrame.GetParent) then
    return legacyFrame
  end

  local owner = legacyFrame:GetParent()
  if not owner or type(owner.CreateAuras) ~= "function" then
    if legacyFrame.Hide then legacyFrame:Hide() end
    WarnOnce(
      "missingCreateAuras",
      "oUF 14.0.2 or newer is required for Retail 12.1 aura containers; aura display was disabled."
    )
    return legacyFrame
  end

  -- oUF's native dispel-border initializer reads owner.colors.dispel.  Most
  -- Roth styles set this themselves, but the adapter guarantees the invariant
  -- for every mini/unit style before managed buttons are batch-created.
  if type(owner.colors) ~= "table" then
    owner.colors = (oUF and oUF.colors) or {}
  end
  if type(owner.colors.dispel) ~= "table" then
    owner.colors.dispel = (oUF and oUF.colors and oUF.colors.dispel) or {}
  end

  local geometry = ResolveLegacyGeometry(legacyFrame)
  local filter = ResolveAuraFilter(legacyFrame)
  local candidateFilters = ResolveCandidateFilters(legacyFrame, owner, filter)

  local createOptions = {
    initialAnchor = geometry.initialAnchor,
    growthX = geometry.growthX,
    growthY = geometry.growthY,
    layoutLimit = geometry.layoutLimit,
  }
  if geometry.axis ~= nil then
    createOptions.layout = geometry.axis
  end

  local element = owner:CreateAuras(createOptions)
  if not element then
    if legacyFrame.Hide then legacyFrame:Hide() end
    WarnOnce("createAurasFailed", "oUF failed to create a managed aura container.")
    return legacyFrame
  end

  element:SetSize(geometry.width, geometry.height)
  CopyAnchor(legacyFrame, element)
  if legacyFrame.GetAlpha and element.SetAlpha then
    element:SetAlpha(legacyFrame:GetAlpha())
  end

  element.size = geometry.size
  element.maxFrameCount = NormalizeCount(legacyFrame.num, 40)
  element.elementSpacing = geometry.spacing
  element.lineSpacing = geometry.spacing
  element.showCount = true
  element.showDuration = showTimers == true
  element.disableCooldown = legacyFrame.disableCooldown == true
  element.showDebuffBorder = filter == "HARMFUL" and legacyFrame.showDebuffType ~= false
  element.showBuffBorder = filter == "HELPFUL" and legacyFrame.showBuffType == true
  element.showStealableBorder = filter == "HELPFUL" and legacyFrame.showStealableBuffs == true
  element.PostCreateButton = StyleManagedAuraButton

  local groupOptions = {
    maxFrameCount = element.maxFrameCount,
    candidateFilters = candidateFilters,
    layout = {
      elementSpacing = geometry.spacing,
      lineSpacing = geometry.spacing,
      elementWidth = geometry.size,
      elementHeight = geometry.size,
    },
  }

  local sortMethod = ResolveSortMethod(filter)
  if sortMethod ~= nil then
    groupOptions.sortMethod = sortMethod
  end
  if type(SORT_DIRECTIONS) == "table" and SORT_DIRECTIONS.Normal ~= nil then
    groupOptions.sortDirection = SORT_DIRECTIONS.Normal
  end

  element.__rothAuraGroupKey = element:AddGroup(filter, groupOptions)
  element.__rothLegacyAuraSource = legacyFrame
  element.__rothAuraFilter = filter

  if legacyFrame.Hide then
    legacyFrame:Hide()
  end
  legacyFrame.__rothManagedAuraElement = element
  return element
end

-- Target and raid layouts call this facade directly.
func.SetupNativeAuraFrame = CreateManagedAuraElement

-- Party and mini-frame layouts call these helpers, whose original closures
-- captured the legacy SetupNativeAuraFrame local.  Replace the helpers so all
-- paths reach the managed adapter.
func.createDebuffs = function(self)
  local style = ResolveUnitStyle(self)
  local auraCfg = self and self.cfg and self.cfg.auras
  if type(auraCfg) ~= "table" then
    return nil
  end

  local legacyFrame = CreateFrame("Frame", nil, self)
  legacyFrame.__rothAuraFilter = "HARMFUL"
  legacyFrame.size = tonumber(auraCfg.size) or 16
  legacyFrame.num = style == "targettarget" and 8
    or (cfg and cfg.units and cfg.units.party and cfg.units.party.auras and cfg.units.party.auras.number)
    or auraCfg.number
    or auraCfg.num
    or 5
  legacyFrame.spacing = tonumber(auraCfg.spacing) or 5

  if self.cfg.vertical then
    legacyFrame:SetHeight((legacyFrame.size + legacyFrame.spacing) * (legacyFrame.num / 4))
    legacyFrame:SetWidth((legacyFrame.size + legacyFrame.spacing) * 4)
    if style == "targettarget" then
      legacyFrame:SetPoint("BOTTOM", self, "RIGHT", 0, 0)
    elseif style == "party" then
      legacyFrame:SetPoint("BOTTOM", self.Health, "RIGHT", 22, -19)
    else
      legacyFrame:SetPoint("TOP", self, "RIGHT", 50, -5)
    end
  else
    legacyFrame:SetHeight((legacyFrame.size + legacyFrame.spacing) * (legacyFrame.num / 9))
    legacyFrame:SetWidth((legacyFrame.size + legacyFrame.spacing) * 4)
    if style == "targettarget" then
      legacyFrame:SetPoint("BOTTOM", self, "RIGHT", -90, -40)
    else
      legacyFrame:SetPoint("TOP", self, "RIGHT", -60, -67)
    end
  end

  legacyFrame.initialAnchor = "TOPLEFT"
  legacyFrame["growth-x"] = "RIGHT"
  legacyFrame["growth-y"] = "DOWN"
  legacyFrame.showDebuffType = auraCfg.showDebuffType
  legacyFrame.onlyShowPlayer = auraCfg.onlyShowPlayerDebuffs

  self.Debuffs = CreateManagedAuraElement(legacyFrame, style == "focus" or style == "targettarget")
  return self.Debuffs
end

func.createBuffs = function(self)
  local style = ResolveUnitStyle(self)
  local auraCfg = self and self.cfg and self.cfg.auras
  if type(auraCfg) ~= "table" or auraCfg.hideBuffs == true then
    return nil
  end

  local legacyFrame = CreateFrame("Frame", nil, self)
  legacyFrame.__rothAuraFilter = "HELPFUL"
  legacyFrame.size = tonumber(auraCfg.size) or 16
  legacyFrame.num = style == "targettarget" and 8
    or (cfg and cfg.units and cfg.units.party and cfg.units.party.auras and cfg.units.party.auras.number)
    or auraCfg.number
    or auraCfg.num
    or 5
  legacyFrame.spacing = tonumber(auraCfg.spacing) or 5

  legacyFrame:SetHeight((legacyFrame.size + legacyFrame.spacing) * (legacyFrame.num / 9))
  if self.cfg.vertical == false then
    legacyFrame:SetWidth((legacyFrame.size + legacyFrame.spacing) * 4)
    legacyFrame:SetPoint("TOP", self, "RIGHT", -60, -27)
    legacyFrame["growth-y"] = "DOWN"
  else
    legacyFrame:SetWidth((legacyFrame.size + legacyFrame.spacing) * 9)
    legacyFrame:SetPoint("TOP", self, "RIGHT", 117.5, 30)
    legacyFrame["growth-y"] = "UP"
  end

  legacyFrame.initialAnchor = "TOPLEFT"
  legacyFrame["growth-x"] = "RIGHT"
  legacyFrame.showBuffType = auraCfg.showBuffType
  legacyFrame.showStealableBuffs = auraCfg.showStealableBuffs
  legacyFrame.onlyShowPlayer = auraCfg.onlyShowPlayerBuffs

  self.Buffs = CreateManagedAuraElement(legacyFrame, style == "focus" or style == "targettarget")
  return self.Buffs
end

local function ResolvePlayerClassToken()
  local classToken = cfg and cfg.playerclass
  if type(classToken) == "string" and classToken ~= "" and not IsSecretValue(classToken) then
    return classToken
  end

  local _, fallback = UnitClass("player")
  if type(fallback) == "string" and fallback ~= "" and not IsSecretValue(fallback) then
    return fallback
  end
  return nil
end

local function CreateManagedAuraWatch(frame)
  if not frame then
    return nil
  end

  local existing = frame.__rothManagedAuraWatch
  local watchCfg = frame.cfg and frame.cfg.aurawatch
  if type(watchCfg) ~= "table" or watchCfg.show ~= true then
    if existing and existing.Hide then
      existing:Hide()
    end
    return nil
  end

  if existing then
    if existing.Show then existing:Show() end
    return existing
  end

  if type(frame.CreateAuras) ~= "function" then
    WarnOnce(
      "missingAuraWatchAPI",
      "oUF 14.0.2 or newer is required for managed party aura-watch indicators."
    )
    return nil
  end

  local classToken = ResolvePlayerClassToken()
  local spellIDs = SPELL_IDS_BY_CLASS[classToken]
  local includeSpellIDs = BuildSpellIDMap(spellIDs)
  if not includeSpellIDs then
    return nil
  end

  local size = max(1, tonumber(watchCfg.size) or 15)
  local spacing = 0
  local count = #spellIDs
  local width = max(size, count * size + max(0, count - 1) * spacing)
  local y = floor(size * 0.83 + 0.5)

  local createOptions = {
    initialAnchor = "LEFT",
    growthX = "RIGHT",
    growthY = "UP",
    layoutLimit = width,
  }
  if HORIZONTAL_AXIS ~= nil then
    createOptions.layout = HORIZONTAL_AXIS
  end

  local element = frame:CreateAuras(createOptions)
  if not element then
    return nil
  end

  element:SetSize(width, size)
  element:SetPoint("CENTER", frame, "CENTER", 0, y)
  element.size = size
  element.maxFrameCount = count
  element.showCount = true
  element.disableCooldown = true
  element.disableMouse = true
  element.PostCreateButton = StyleManagedAuraButton

  local options = {
    maxFrameCount = count,
    candidateFilters = {
      includeSpellIDs = includeSpellIDs,
    },
    layout = {
      elementSpacing = spacing,
      lineSpacing = spacing,
      elementWidth = size,
      elementHeight = size,
    },
  }
  if type(SORT_METHODS) == "table" then
    options.sortMethod = SORT_METHODS.ExpirationOnly or SORT_METHODS.Default
  end
  if type(SORT_DIRECTIONS) == "table" and SORT_DIRECTIONS.Normal ~= nil then
    options.sortDirection = SORT_DIRECTIONS.Normal
  end

  element.__rothAuraWatchGroupKey = element:AddGroup("HELPFUL", options)
  frame.__rothManagedAuraWatch = element
  frame.__rothAuraWatch = element
  frame.AuraWatch = element
  return element
end

-- Replace the raw AuraUtil/C_UnitAuras watcher with a managed includeSpellIDs
-- group.  The refresh facade ignores UNIT_AURA data and only asks the native
-- container to refresh when explicitly requested.
func.CreateSafeAuraWatch = CreateManagedAuraWatch
func.RefreshSafeAuraWatch = function(frame)
  local element = CreateManagedAuraWatch(frame)
  if element and type(element.ForceUpdate) == "function" then
    element:ForceUpdate()
  end
  return element
end

-- Health-glow dispel inference used to scan raw harmful AuraData.  Retail 12.1
-- intentionally protects that state.  Native managed dispel borders now carry
-- the actionable signal; these legacy event hooks remain inert for compatibility.
func.checkColors = function(self)
  if self and self.Health then
    self.Health.buffOverride = nil
  end
end

func.QueueGroupAuraColorUpdate = function(self, event)
  if event ~= "UNIT_AURA" then
    func.RefreshSafeAuraWatch(self)
  end
end

ns.auraRuntime12_1 = {
  interfaceVersion = interfaceVersion,
  requiredOUFVersion = "14.0.2",
  usesManagedContainers = true,
  rawAuraScanning = false,
}
