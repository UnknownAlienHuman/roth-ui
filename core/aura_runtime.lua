-- Retail 12.1 managed aura runtime.
--
-- Roth UI does not enumerate AuraData or own UNIT_AURA state. Unit layouts
-- register lightweight immutable specifications; managed AuraContainer groups
-- are created only when the owning unit frame is first shown. This defers
-- Blizzard's mandatory AuraButton batch allocation for frames that never become
-- visible while leaving filtering, sorting, durations and cooldowns native.

local addonName, ns = ...

local func = assert(ns and ns.func, "Roth_UI: ns.func is required by aura_runtime.lua")
local oUF = assert(ns.oUF or _G.oUF, "Roth_UI: oUF is required by aura_runtime.lua")
local cfg = assert(ns.cfg, "Roth_UI: cfg is required by aura_runtime.lua")

local type = type
local pairs = pairs
local tonumber = tonumber
local floor = math.floor
local max = math.max
local next = next
local UnitClass = UnitClass
local DoesSpellExist = C_Spell and C_Spell.DoesSpellExist

local HORIZONTAL_AXIS = assert(AnchorUtil and AnchorUtil.FlowLayoutAxis and AnchorUtil.FlowLayoutAxis.Horizontal,
  "Roth_UI: AnchorUtil.FlowLayoutAxis.Horizontal is required")
local VERTICAL_AXIS = AnchorUtil.FlowLayoutAxis.Vertical
local SORT_METHODS = assert(AuraContainerSortMethod, "Roth_UI: AuraContainerSortMethod is required")
local SORT_DIRECTIONS = assert(AuraContainerSortDirection, "Roth_UI: AuraContainerSortDirection is required")
local mediapath = ns.mediapath or "Interface\\AddOns\\Roth_UI\\media\\"

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

local function ResolveFontPath()
  local fontPath = cfg.font or STANDARD_TEXT_FONT
  if type(func.ResolveFontPath) == "function" then
    fontPath = func.ResolveFontPath(fontPath)
  end
  if type(fontPath) ~= "string" or fontPath == "" then
    return STANDARD_TEXT_FONT
  end
  return fontPath
end

local function ApplyFont(fontString, size)
  if not (fontString and fontString.SetFont) then
    return
  end
  fontString:SetFont(ResolveFontPath(), size, "THINOUTLINE")
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
    button.Cooldown:SetReverse(true)
    button.Cooldown:SetDrawEdge(false)
    button.Cooldown:SetHideCountdownNumbers(true)
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

  -- One static skin layer per button. Native oUF regions remain the state sinks.
  local border = button:CreateTexture(nil, "ARTWORK", nil, 1)
  border:SetAllPoints(button)
  border:SetTexture(mediapath .. "icon_border")
  border:SetVertexColor(0.08, 0.08, 0.08, 0.9)
  button.RothBorder = border
end

local function CopySpellIDMap(list)
  if type(list) ~= "table" then
    return nil, "none"
  end

  local result = {}
  local fingerprint = {}
  local count = 0
  for i = 1, #list do
    local spellID = tonumber(list[i])
    local exists = spellID and spellID > 0 and type(DoesSpellExist) == "function" and DoesSpellExist(spellID)
    if exists and not func.IsSecretValue(exists) and exists == true and not result[spellID] then
      result[spellID] = true
      count = count + 1
      fingerprint[count] = tostring(spellID)
    end
  end

  if count == 0 then
    return nil, "none"
  end
  table.sort(fingerprint)
  return result, table.concat(fingerprint, ",")
end

local function CopySpellIDList(list)
  local map, fingerprint = CopySpellIDMap(list)
  if not map then return nil, fingerprint end
  local result = {}
  for spellID in pairs(map) do result[#result + 1] = spellID end
  table.sort(result)
  return result, fingerprint
end

local function ResolvePlayerClassToken()
  local configured = cfg.playerclass
  if not func.IsSecretValue(configured) and type(configured) == "string" and configured ~= "" then
    return configured
  end

  local _, classToken = UnitClass("player")
  if not func.IsSecretValue(classToken) and type(classToken) == "string" and classToken ~= "" then
    return classToken
  end
  return nil
end

local function BuildCandidateFilters(frame, spec)
  if type(spec.candidateFilters) == "function" then
    return spec.candidateFilters(frame, spec)
  end
  return spec.candidateFilters, spec.candidateFingerprint or "static:none"
end

local function NormalizePoint(frame, spec)
  local point = spec.point
  if type(point) ~= "table" then
    return "CENTER", frame, "CENTER", 0, 0
  end

  local relativeTo = point.relativeTo
  if type(relativeTo) == "function" then
    relativeTo = relativeTo(frame)
  end
  relativeTo = relativeTo or frame

  return point.point or "CENTER", relativeTo, point.relativePoint or point.point or "CENTER",
    tonumber(point.x) or 0, tonumber(point.y) or 0
end

local function CreateAuraRegion(frame, spec)
  if spec.element then
    return spec.element
  end
  if type(frame.CreateAuras) ~= "function" then
    WarnOnce("missingCreateAuras", "oUF 14.0.2 or newer is required; managed unit auras were disabled.")
    return nil
  end

  if type(frame.colors) ~= "table" then
    frame.colors = oUF.colors
  end
  if type(frame.colors.dispel) ~= "table" then
    frame.colors.dispel = oUF.colors and oUF.colors.dispel or {}
  end

  local size = max(1, tonumber(spec.size) or 16)
  local spacing = max(0, tonumber(spec.spacing) or 0)
  local width = max(size, tonumber(spec.width) or size)
  local height = max(size, tonumber(spec.height) or size)
  local layout = spec.layout or HORIZONTAL_AXIS
  local layoutLimit = tonumber(spec.layoutLimit)
  if not layoutLimit or layoutLimit <= 0 then
    layoutLimit = layout == VERTICAL_AXIS and height or width
  end

  local element = frame:CreateAuras({
    layout = layout,
    layoutLimit = layoutLimit,
    initialAnchor = spec.initialAnchor or "TOPLEFT",
    growthX = spec.growthX or "RIGHT",
    growthY = spec.growthY or "DOWN",
  })
  if not element then
    WarnOnce("createAurasFailed", "oUF failed to create a managed aura container.")
    return nil
  end

  element:SetSize(width, height)
  element:SetPoint(NormalizePoint(frame, spec))
  if spec.alpha then
    element:SetAlpha(spec.alpha)
  end

  local simpleAuras = cfg.simpleAuras or {}
  element.size = size
  element.maxFrameCount = max(0, floor(tonumber(spec.maxFrameCount) or 1))
  element.showCount = spec.showCount ~= false
  element.showDuration = spec.allowDuration == true and simpleAuras.durationText == true
  element.disableCooldown = spec.disableCooldown == true or simpleAuras.cooldownSwipe == false
  element.disableMouse = spec.disableMouse == true
  element.showDebuffBorder = spec.showDebuffBorder == true
  element.showBuffBorder = spec.showBuffBorder == true
  element.showStealableBorder = spec.showStealableBorder == true
  element.PostCreateButton = StyleManagedAuraButton

  local sortMethod = spec.sortMethod
    or (spec.filter == "HARMFUL" and SORT_METHODS.UnitFrameDebuff)
    or SORT_METHODS.ExpirationOnly
  local sortDirection = spec.sortDirection or SORT_DIRECTIONS.Normal

  if type(spec.spellSlots) == "table" then
    spec.slotKeys = {}
    for i = 1, #spec.spellSlots do
      local spellID = spec.spellSlots[i]
      spec.slotKeys[i] = element:AddSlot(spec.filter, {
        candidateFilters = {
          includeSpellIDs = { [spellID] = true },
          isFromPlayerOrPlayerPet = spec.slotsFromPlayer == true or nil,
        },
        sortMethod = sortMethod,
        sortDirection = sortDirection,
      })
    end
    spec.candidateFingerprint = spec.candidateFingerprint or "slots"
  else
    local candidateFilters, fingerprint = BuildCandidateFilters(frame, spec)
    spec.groupKey = element:AddGroup(spec.filter, {
      maxFrameCount = element.maxFrameCount,
      candidateFilters = candidateFilters,
      sortMethod = sortMethod,
      sortDirection = sortDirection,
      layout = {
        elementSpacing = spacing,
        lineSpacing = spacing,
        elementWidth = size,
        elementHeight = size,
      },
    })
    spec.candidateFingerprint = fingerprint
  end
  spec.element = element

  if type(spec.exportField) == "string" and spec.exportField ~= "" then
    frame[spec.exportField] = element
  end
  return element
end

function func.EnsureAuraRegions(frame)
  if InCombatLockdown and InCombatLockdown() then
    if frame and not frame.__rothAuraDeferred then
      frame.__rothAuraDeferred = true
      local policy = ns.framePolicy
      if policy and type(policy.DeferUntilOutOfCombat) == "function" then
        policy.DeferUntilOutOfCombat("auras:" .. tostring(frame), function()
          frame.__rothAuraDeferred = nil
          func.EnsureAuraRegions(frame)
        end)
      else
        frame.__rothAuraDeferred = nil
      end
    end
    return false
  end
  local specs = frame and frame.__rothAuraSpecs
  if type(specs) ~= "table" or frame.__rothAuraRegionsCreated or frame.__rothAuraRegionsCreating then
    return false
  end

  frame.__rothAuraRegionsCreating = true
  local created = false
  local complete = true
  for i = 1, #specs do
    if CreateAuraRegion(frame, specs[i]) then
      created = true
    else
      complete = false
    end
  end
  frame.__rothAuraRegionsCreating = nil
  frame.__rothAuraRegionsCreated = created and complete

  if created and type(frame.EnableElement) == "function" and not frame:IsElementEnabled("Auras") then
    frame:EnableElement("Auras")
  end
  return created
end

local function EnsureAuraRegionsOnShow(frame)
  func.EnsureAuraRegions(frame)
end

function func.QueueAuraRegion(frame, spec)
  if not frame or type(spec) ~= "table" or type(spec.id) ~= "string" or spec.id == "" then
    return false
  end
  if spec.filter ~= "HELPFUL" and spec.filter ~= "HARMFUL" then
    return false
  end

  frame.__rothAuraSpecs = frame.__rothAuraSpecs or {}
  for i = 1, #frame.__rothAuraSpecs do
    if frame.__rothAuraSpecs[i].id == spec.id then
      return false
    end
  end
  frame.__rothAuraSpecs[#frame.__rothAuraSpecs + 1] = spec

  if frame.__rothAuraLifecycleReady and frame:IsVisible() then
    func.EnsureAuraRegions(frame)
  end
  return true
end

function func.RefreshAuraFilters(frame)
  local specs = frame and frame.__rothAuraSpecs
  if type(specs) ~= "table" then
    return false
  end

  local changed = false
  for i = 1, #specs do
    local spec = specs[i]
    local element = spec.element
    if element and spec.groupKey then
      local filters, fingerprint = BuildCandidateFilters(frame, spec)
      if fingerprint ~= spec.candidateFingerprint then
        element:SetAuraGroupCandidateFilters(spec.groupKey, filters)
        spec.candidateFingerprint = fingerprint
        changed = true
      end
    end
  end
  return changed
end

function ns.RefreshAllAuraFilters()
  local objects = oUF.objects
  if type(objects) ~= "table" then
    return
  end
  for i = 1, #objects do
    func.RefreshAuraFilters(objects[i])
  end
end

local function OwnAuraFilter(configKey)
  return function(frame)
    local auraCfg = frame and frame.cfg and frame.cfg.auras
    local enabled = auraCfg and auraCfg[configKey] == true
    if enabled then
      return { isFromPlayerOrPlayerPet = true }, "own:true"
    end
    return nil, "own:false"
  end
end

function func.QueueStandardAuras(frame, options)
  options = options or {}
  local auraCfg = frame and frame.cfg and frame.cfg.auras
  if type(auraCfg) ~= "table" or auraCfg.show ~= true then
    return
  end

  local style = frame.cfg.style
  local vertical = frame.cfg.vertical ~= false
  local size = max(1, tonumber(auraCfg.size) or 16)
  local spacing = max(0, tonumber(auraCfg.spacing) or 5)
  local count = style == "targettarget" and 8 or tonumber(auraCfg.number) or tonumber(auraCfg.num) or 5
  local allowDuration = style == "focus" or style == "targettarget"

  if options.debuffs ~= false then
    local width = (size + spacing) * 4
    local height
    local point
    if vertical then
      height = (size + spacing) * (count / 4)
      if style == "targettarget" then
        point = { point = "BOTTOM", relativeTo = frame, relativePoint = "RIGHT", x = 0, y = 0 }
      elseif style == "party" then
        point = { point = "BOTTOM", relativeTo = function(owner) return owner.Health end, relativePoint = "RIGHT", x = 22, y = -19 }
      else
        point = { point = "TOP", relativeTo = frame, relativePoint = "RIGHT", x = 50, y = -5 }
      end
    else
      height = (size + spacing) * (count / 9)
      if style == "targettarget" then
        point = { point = "BOTTOM", relativeTo = frame, relativePoint = "RIGHT", x = -90, y = -40 }
      else
        point = { point = "TOP", relativeTo = frame, relativePoint = "RIGHT", x = -60, y = -67 }
      end
    end

    func.QueueAuraRegion(frame, {
      id = "debuffs",
      exportField = "Debuffs",
      filter = "HARMFUL",
      size = size,
      spacing = spacing,
      maxFrameCount = count,
      width = width,
      height = height,
      layout = HORIZONTAL_AXIS,
      layoutLimit = width,
      initialAnchor = "TOPLEFT",
      growthX = "RIGHT",
      growthY = "DOWN",
      point = point,
      allowDuration = allowDuration,
      showDebuffBorder = auraCfg.showDebuffType ~= false,
      candidateFilters = OwnAuraFilter("onlyShowPlayerDebuffs"),
    })
  end

  if options.buffs == true and auraCfg.hideBuffs ~= true then
    local height = (size + spacing) * (count / 9)
    local width
    local point
    local growthY
    if vertical then
      width = (size + spacing) * 9
      point = { point = "TOP", relativeTo = frame, relativePoint = "RIGHT", x = 117.5, y = 30 }
      growthY = "UP"
    else
      width = (size + spacing) * 4
      point = { point = "TOP", relativeTo = frame, relativePoint = "RIGHT", x = -60, y = -27 }
      growthY = "DOWN"
    end

    func.QueueAuraRegion(frame, {
      id = "buffs",
      exportField = "Buffs",
      filter = "HELPFUL",
      size = size,
      spacing = spacing,
      maxFrameCount = count,
      width = width,
      height = height,
      layout = HORIZONTAL_AXIS,
      layoutLimit = width,
      initialAnchor = "TOPLEFT",
      growthX = "RIGHT",
      growthY = growthY,
      point = point,
      allowDuration = allowDuration,
      showBuffBorder = auraCfg.showBuffType == true,
      showStealableBorder = auraCfg.showStealableBuffs == true,
      candidateFilters = OwnAuraFilter("onlyShowPlayerBuffs"),
    })
  end
end

function func.QueueTargetAuras(frame)
  local auraCfg = frame and frame.cfg and frame.cfg.auras
  if type(auraCfg) ~= "table" or auraCfg.show ~= true then
    return
  end

  local size = max(1, tonumber(auraCfg.size) or 20)
  local spacing = max(0, tonumber(auraCfg.spacing) or 2)
  local width = (size + spacing) * 10
  local height = (size + spacing) * 4

  local function Add(id, filter, position, ownKey)
    func.QueueAuraRegion(frame, {
      id = id,
      exportField = id == "buffs" and "Buffs" or "Debuffs",
      filter = filter,
      size = size,
      spacing = spacing,
      maxFrameCount = 40,
      width = width,
      height = height,
      layout = HORIZONTAL_AXIS,
      layoutLimit = width,
      initialAnchor = position.initialAnchor or "TOPLEFT",
      growthX = position.growthx or "RIGHT",
      growthY = position.growthy or "DOWN",
      point = {
        point = position.pos.a1,
        relativeTo = frame,
        relativePoint = position.pos.a2,
        x = position.pos.x,
        y = position.pos.y,
      },
      allowDuration = true,
      showDebuffBorder = filter == "HARMFUL" and auraCfg.showDebuffType ~= false,
      showStealableBorder = filter == "HELPFUL" and auraCfg.showStealableBuffs == true,
      candidateFilters = OwnAuraFilter(ownKey),
    })
  end

  Add("buffs", "HELPFUL", auraCfg.buffs, "onlyShowPlayerBuffs")
  Add("debuffs", "HARMFUL", auraCfg.debuffs, "onlyShowPlayerDebuffs")
end

function func.QueueRaidAuras(frame)
  local auraCfg = frame and frame.cfg and frame.cfg.auras
  if type(auraCfg) ~= "table" or auraCfg.show ~= true then
    return
  end

  local size = max(1, tonumber(auraCfg.size) or 13)
  local spacing = max(0, tonumber(auraCfg.spacing) or 3)
  local count = max(0, floor(tonumber(auraCfg.num) or 5))
  local width = max(size, (size + spacing) * count)

  func.QueueAuraRegion(frame, {
    id = "debuffs",
    exportField = "Debuffs",
    filter = "HARMFUL",
    size = size,
    spacing = spacing,
    maxFrameCount = count,
    width = width,
    height = size,
    layout = HORIZONTAL_AXIS,
    layoutLimit = width,
    initialAnchor = auraCfg.initialAnchor or "TOPLEFT",
    growthX = auraCfg.growthX or "RIGHT",
    growthY = auraCfg.growthY or "DOWN",
    point = {
      point = auraCfg.debuffPos and auraCfg.debuffPos.a1 or "CENTER",
      relativeTo = frame,
      relativePoint = auraCfg.debuffPos and auraCfg.debuffPos.a2 or auraCfg.debuffPos and auraCfg.debuffPos.a1 or "CENTER",
      x = auraCfg.debuffPos and auraCfg.debuffPos.x or 0,
      y = auraCfg.debuffPos and auraCfg.debuffPos.y or -5,
    },
    disableCooldown = auraCfg.disableCooldown == true,
    showDebuffBorder = auraCfg.showDebuffType ~= false,
  })

  if auraCfg.showBuffs == true then
    func.QueueAuraRegion(frame, {
      id = "buffs",
      exportField = "Buffs",
      filter = "HELPFUL",
      size = size,
      spacing = spacing,
      maxFrameCount = count,
      width = width,
      height = size,
      layout = HORIZONTAL_AXIS,
      layoutLimit = width,
      initialAnchor = auraCfg.initialAnchor or "TOPLEFT",
      growthX = auraCfg.growthX or "RIGHT",
      growthY = auraCfg.growthY or "DOWN",
      point = {
        point = auraCfg.buffPos and auraCfg.buffPos.a1 or "CENTER",
        relativeTo = frame,
        relativePoint = auraCfg.buffPos and auraCfg.buffPos.a2 or auraCfg.buffPos and auraCfg.buffPos.a1 or "CENTER",
        x = auraCfg.buffPos and auraCfg.buffPos.x or 0,
        y = auraCfg.buffPos and auraCfg.buffPos.y or -5,
      },
      alpha = 0.75,
      disableCooldown = auraCfg.disableCooldown == true,
      showBuffBorder = auraCfg.showBuffType == true,
      candidateFilters = function(owner)
        local current = owner and owner.cfg and owner.cfg.auras or auraCfg
        local spellMap, spellFingerprint = CopySpellIDMap(current.whitelist)
        local own = current.onlyShowPlayer == true
        local filters = spellMap and { includeSpellIDs = spellMap } or {}
        if own then
          filters.isFromPlayerOrPlayerPet = true
        end
        if next(filters) == nil then
          filters = nil
        end
        return filters, "raid:" .. spellFingerprint .. ":own=" .. tostring(own)
      end,
    })
  end
end

function func.QueueHealerAuraWatch(frame)
  local watchCfg = frame and frame.cfg and frame.cfg.aurawatch
  if type(watchCfg) ~= "table" or watchCfg.show ~= true then
    return
  end

  local spellIDs, spellFingerprint = CopySpellIDList(SPELL_IDS_BY_CLASS[ResolvePlayerClassToken()])
  if not spellIDs then return end

  local size = max(1, tonumber(watchCfg.size) or 15)
  local count = #spellIDs
  local width = max(size, count * size)
  local y = floor(size * 0.83 + 0.5)

  func.QueueAuraRegion(frame, {
    id = "healer_watch",
    exportField = "AuraWatch",
    filter = "HELPFUL",
    size = size,
    spacing = 0,
    maxFrameCount = count,
    width = width,
    height = size,
    layout = HORIZONTAL_AXIS,
    layoutLimit = width,
    initialAnchor = "LEFT",
    growthX = "RIGHT",
    growthY = "UP",
    point = { point = "CENTER", relativeTo = frame, relativePoint = "CENTER", x = 0, y = y },
    disableCooldown = true,
    disableMouse = true,
    spellSlots = spellIDs,
    slotsFromPlayer = true,
    candidateFingerprint = "watch-slots:" .. spellFingerprint,
  })
end

local function AttachAuraLifecycle(frame)
  if type(frame.__rothAuraSpecs) ~= "table" or #frame.__rothAuraSpecs == 0 then
    return
  end

  frame.__rothAuraLifecycleReady = true
  frame:HookScript("OnShow", EnsureAuraRegionsOnShow)
  if frame:IsVisible() then
    func.EnsureAuraRegions(frame)
  end
end

oUF:RegisterInitCallback(AttachAuraLifecycle)

ns.auraRuntime = {
  requiredOUFVersion = "14.0.2",
  usesManagedContainers = true,
  lazyGroupRegistration = true,
  rawAuraScanning = false,
}
