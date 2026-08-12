local addonName, ns = ...

local func = assert(ns and ns.func, "Roth_UI: ns.func is required by group_aura_watch.lua")
local IsSecretValue = assert(func.IsSecretValue, "Roth_UI: func.IsSecretValue is required by group_aura_watch.lua")

local CreateFilterString = AuraUtil and AuraUtil.CreateFilterString
local ForEachAura = AuraUtil and AuraUtil.ForEachAura
local HelpfulFilter = CreateFilterString and CreateFilterString(AuraUtil.AuraFilters.Helpful, AuraUtil.AuraFilters.Player) or "HELPFUL|PLAYER"
local GetAuraDataByAuraInstanceID = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
local UnitGUID = UnitGUID

local SPELL_IDS_BY_CLASS = {
  PRIEST = { 139, 17, 77489, 41635 },
  PALADIN = { 223306, 53563, 6940, 287280, 156910, 200025 },
  DRUID = { 33763, 774, 8936, 102342, 102351, 48438, 155777 },
  SHAMAN = { 61295 },
  MONK = { 119611, 124682 },
}

local ICON_ORDER = { 0, 1, -1, 2, -2, 3, -3 }

local function GetPlayerClassToken()
  local classToken = ns and ns.cfg and ns.cfg.playerclass
  if type(classToken) == "string" and classToken ~= "" and not IsSecretValue(classToken) then
    return classToken
  end
  local _, fallback = UnitClass("player")
  if type(fallback) == "string" and fallback ~= "" and not IsSecretValue(fallback) then
    return fallback
  end
  return nil
end

local function GetSpellIDs()
  local classToken = GetPlayerClassToken()
  return SPELL_IDS_BY_CLASS[classToken] or {}
end

local function GetAuraWatchConfig(frame)
  local cfg = frame and frame.cfg and frame.cfg.aurawatch
  if type(cfg) ~= "table" then
    return nil
  end
  return cfg
end

local function ClearTable(target)
  if type(target) ~= "table" then
    return {}
  end

  for key in pairs(target) do
    target[key] = nil
  end
  return target
end

local function ResolveUnitIdentity(unit)
  if type(unit) ~= "string" or unit == "" then
    return nil, nil
  end
  local guid = type(UnitGUID) == "function" and UnitGUID(unit) or nil
  return unit, guid
end

local function EnsureAuraWatchIdentity(root, unitToken, unitGUID)
  if type(root) ~= "table" or type(unitToken) ~= "string" then
    return false
  end

  local currentToken = root.__rothWatchUnitToken
  local currentGUID = root.__rothWatchUnitGUID
  if currentToken == unitToken and currentGUID == unitGUID then
    return false
  end

  root.__rothWatchUnitToken = unitToken
  root.__rothWatchUnitGUID = unitGUID
  root.activeBySpellID = ClearTable(root.activeBySpellID)
  root.instanceToSpellID = ClearTable(root.instanceToSpellID)
  root.__rothWatchInitialized = false
  return true
end

local function AcquireScratchSet(owner, key)
  if type(owner) ~= "table" or type(key) ~= "string" or key == "" then
    return nil
  end

  local scratch = owner[key]
  if type(scratch) ~= "table" then
    scratch = {}
    owner[key] = scratch
    return scratch
  end

  for value in pairs(scratch) do
    scratch[value] = nil
  end
  return scratch
end

local function CreateWatchIcon(parent, size)
  local button = CreateFrame("Frame", nil, parent)
  button:SetSize(size, size)
  button:SetFrameStrata("HIGH")

  local back = button:CreateTexture(nil, "BACKGROUND", nil, -1)
  back:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
  back:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
  back:SetTexture("Interface\\AddOns\\Roth_UI\\media\\simplesquare_glow")
  back:SetVertexColor(0, 0, 0, 1)
  button.back = back

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
  icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button.icon = icon

  local border = button:CreateTexture(nil, "OVERLAY", nil, 1)
  border:SetAllPoints(button)
  border:SetTexture("Interface\\AddOns\\Roth_UI\\media\\icon_border")
  border:SetVertexColor(0.15, 0.15, 0.15, 0.9)
  button.border = border

  local count = button:CreateFontString(nil, "OVERLAY")
  count:SetPoint("TOPRIGHT", button, "TOPRIGHT", 3, 3)
  count:SetTextColor(0.95, 0.95, 0.95)
  count:SetFont((ns and ns.cfg and ns.cfg.font) or _G.STANDARD_TEXT_FONT, math.max(8, math.floor(size * 0.55)), "THINOUTLINE")
  if func.RegisterFontString then
    func.RegisterFontString(count, math.max(8, math.floor(size * 0.55)), "THINOUTLINE")
  end
  button.count = count

  button:Hide()
  return button
end

local function EnsureAuraWatch(frame)
  if not frame then
    return nil
  end

  local watchCfg = GetAuraWatchConfig(frame)
  if not (watchCfg and watchCfg.show == true) then
    if frame.__rothAuraWatch then
      frame.__rothAuraWatch:Hide()
    end
    return nil
  end

  local spellIDs = GetSpellIDs()
  if #spellIDs == 0 then
    return nil
  end

  local size = tonumber(watchCfg.size) or 15
  local root = frame.__rothAuraWatch
  if not root then
    root = CreateFrame("Frame", nil, frame)
    root:SetAllPoints(frame)
    root.iconsBySpellID = {}
    root.order = {}
    root.activeBySpellID = {}
    root.instanceToSpellID = {}
    root.__rothWatchInitialized = false
    frame.__rothAuraWatch = root
    root.__rothWatchUnitToken = nil
    root.__rothWatchUnitGUID = nil
  end

  if root.__rothSize == size then
    root:Show()
    return root
  end

  root.__rothSize = size
  root.__rothWatchCount = #spellIDs
  root:Show()
  local step = size
  local y = math.floor(size * 0.83 + 0.5)

  for i = 1, #spellIDs do
    local spellID = spellIDs[i]
    local icon = root.iconsBySpellID[spellID]
    if not icon then
      icon = CreateWatchIcon(root, size)
      root.iconsBySpellID[spellID] = icon
      root.order[#root.order + 1] = spellID
    else
      icon:SetSize(size, size)
      if icon.count then
        icon.count:SetFont((ns and ns.cfg and ns.cfg.font) or _G.STANDARD_TEXT_FONT, math.max(8, math.floor(size * 0.55)), "THINOUTLINE")
      end
    end

    icon:ClearAllPoints()
    icon:SetPoint("CENTER", frame, "CENTER", ICON_ORDER[i] * step, y)
  end

  return root
end

local function ApplyAuraWatchDisplay(root)
  if type(root) ~= "table" then
    return
  end

  local activeBySpellID = type(root.activeBySpellID) == "table" and root.activeBySpellID or {}
  for i = 1, #root.order do
    local spellID = root.order[i]
    local button = root.iconsBySpellID[spellID]
    local auraData = activeBySpellID[spellID]
    if button then
      if auraData then
        local iconTexture = auraData.icon
        if not IsSecretValue(iconTexture) and iconTexture then
          button.icon:SetTexture(iconTexture)
        end

        local applications = auraData.applications
        if type(applications) == "number" and applications > 1 and not IsSecretValue(applications) then
          button.count:SetText(applications)
        else
          button.count:SetText("")
        end

        button:Show()
      else
        button.count:SetText("")
        button:Hide()
      end
    end
  end
end

local function ResolveWatchedSpellID(root, auraData)
  if type(root) ~= "table" or type(auraData) ~= "table" then
    return nil
  end

  local spellID = auraData.spellId or auraData.spellID
  if type(spellID) ~= "number" or IsSecretValue(spellID) then
    return nil
  end

  if not root.iconsBySpellID or not root.iconsBySpellID[spellID] then
    return nil
  end

  return spellID
end

local function ResolveAuraInstanceID(auraData)
  if type(auraData) ~= "table" then
    return nil
  end

  local auraInstanceID = auraData.auraInstanceID
  if type(auraInstanceID) ~= "number" or IsSecretValue(auraInstanceID) then
    return nil
  end

  return auraInstanceID
end

local function NormalizeWatchApplications(auraData)
  local applications = type(auraData) == "table" and auraData.applications or nil
  if type(applications) ~= "number" or IsSecretValue(applications) then
    return 0
  end
  return applications
end

local function DidWatchAuraChange(previousAuraData, auraData)
  if type(previousAuraData) ~= "table" then
    return true
  end

  local previousInstanceID = ResolveAuraInstanceID(previousAuraData)
  local auraInstanceID = ResolveAuraInstanceID(auraData)
  if previousInstanceID ~= auraInstanceID then
    return true
  end

  local previousIcon = previousAuraData.icon
  local nextIcon = type(auraData) == "table" and auraData.icon or nil
  if not IsSecretValue(previousIcon) and not IsSecretValue(nextIcon) and previousIcon ~= nextIcon then
    return true
  end

  return NormalizeWatchApplications(previousAuraData) ~= NormalizeWatchApplications(auraData)
end

local function TrackWatchAura(root, auraData)
  if type(root) ~= "table" or type(auraData) ~= "table" then
    return false
  end

  local spellID = ResolveWatchedSpellID(root, auraData)
  if not spellID then
    return false
  end

  root.activeBySpellID = root.activeBySpellID or {}
  root.instanceToSpellID = root.instanceToSpellID or {}

  local changed = DidWatchAuraChange(root.activeBySpellID[spellID], auraData)
  root.activeBySpellID[spellID] = auraData

  local auraInstanceID = ResolveAuraInstanceID(auraData)
  if auraInstanceID then
    local previousSpellID = root.instanceToSpellID[auraInstanceID]
    if previousSpellID and previousSpellID ~= spellID and root.activeBySpellID[previousSpellID] and ResolveAuraInstanceID(root.activeBySpellID[previousSpellID]) == auraInstanceID then
      root.activeBySpellID[previousSpellID] = nil
      changed = true
    end
    if root.instanceToSpellID[auraInstanceID] ~= spellID then
      root.instanceToSpellID[auraInstanceID] = spellID
      changed = true
    end
  end

  return changed
end

local function RemoveWatchAura(root, auraInstanceID)
  if type(root) ~= "table" or type(auraInstanceID) ~= "number" or IsSecretValue(auraInstanceID) then
    return false
  end

  local instanceToSpellID = type(root.instanceToSpellID) == "table" and root.instanceToSpellID or nil
  if type(instanceToSpellID) ~= "table" then
    return false
  end

  local spellID = instanceToSpellID[auraInstanceID]
  if spellID == nil then
    return false
  end

  instanceToSpellID[auraInstanceID] = nil
  local activeBySpellID = type(root.activeBySpellID) == "table" and root.activeBySpellID or nil
  if type(activeBySpellID) == "table" then
    local auraData = activeBySpellID[spellID]
    if auraData == nil or ResolveAuraInstanceID(auraData) == auraInstanceID then
      activeBySpellID[spellID] = nil
    end
  end

  return true
end

local function FullRefreshSafeAuraWatch(root, auraUnit)
  if not (type(root) == "table" and type(ForEachAura) == "function") then
    return
  end

  root.activeBySpellID = ClearTable(root.activeBySpellID)
  root.instanceToSpellID = ClearTable(root.instanceToSpellID)

  local remainingWatched = tonumber(root.__rothWatchCount) or #root.order
  ForEachAura(auraUnit, HelpfulFilter, nil, function(auraData)
    local spellID = ResolveWatchedSpellID(root, auraData)
    if spellID then
      local wasMissing = root.activeBySpellID[spellID] == nil
      TrackWatchAura(root, auraData)
      if wasMissing then
        remainingWatched = remainingWatched - 1
        if remainingWatched <= 0 then
          return true
        end
      end
    end
    return false
  end, true)

  root.__rothWatchInitialized = true
  ApplyAuraWatchDisplay(root)
end

local function ApplyIncrementalAuraWatch(root, auraUnit, updateInfo)
  if type(root) ~= "table" then
    return false, "init"
  end

  local unitToken, unitGUID = ResolveUnitIdentity(auraUnit)
  if not unitToken then
    return false, "nilUnit"
  end
  if EnsureAuraWatchIdentity(root, unitToken, unitGUID) then
    return false, "unitSwitch"
  end

  if root.__rothWatchInitialized ~= true then
    return false, "init"
  end

  if type(updateInfo) ~= "table" then
    return false, "nilPayload"
  end

  if updateInfo.isFullUpdate then
    return false, "isFullUpdate"
  end

  local addedAuras = updateInfo.addedAuras
  local updatedAuraInstanceIDs = updateInfo.updatedAuraInstanceIDs
  local removedAuraInstanceIDs = updateInfo.removedAuraInstanceIDs
  local hasPayload = false
  local touched = false
  local updatedSeen = nil
  local removedSeen = nil
  local updatedDeduped = 0
  local removedDeduped = 0

  if type(addedAuras) == "table" and #addedAuras > 0 then
    hasPayload = true
    for i = 1, #addedAuras do
      if TrackWatchAura(root, addedAuras[i]) then
        touched = true
      end
    end
  end

  if type(updatedAuraInstanceIDs) == "table" and #updatedAuraInstanceIDs > 0 then
    hasPayload = true
    if type(GetAuraDataByAuraInstanceID) ~= "function" then
      return false, "missingAuraInstanceResolver"
    end

    updatedSeen = AcquireScratchSet(root, "__rothWatchUpdatedAuraInstanceSeen")
    for i = 1, #updatedAuraInstanceIDs do
      local auraInstanceID = updatedAuraInstanceIDs[i]
      if type(auraInstanceID) == "number" and not IsSecretValue(auraInstanceID) then
        if updatedSeen and updatedSeen[auraInstanceID] then
          updatedDeduped = updatedDeduped + 1
        else
          if updatedSeen then
            updatedSeen[auraInstanceID] = true
          end
          local auraData = GetAuraDataByAuraInstanceID(auraUnit, auraInstanceID)
          if auraData then
            if TrackWatchAura(root, auraData) then
              touched = true
            end
          elseif RemoveWatchAura(root, auraInstanceID) then
            touched = true
          end
        end
      end
    end
  end

  if type(removedAuraInstanceIDs) == "table" and #removedAuraInstanceIDs > 0 then
    hasPayload = true
    removedSeen = AcquireScratchSet(root, "__rothWatchRemovedAuraInstanceSeen")
    for i = 1, #removedAuraInstanceIDs do
      local auraInstanceID = removedAuraInstanceIDs[i]
      if type(auraInstanceID) == "number" then
        if removedSeen and removedSeen[auraInstanceID] then
          removedDeduped = removedDeduped + 1
        else
          if removedSeen then
            removedSeen[auraInstanceID] = true
          end
          if RemoveWatchAura(root, auraInstanceID) then
            touched = true
          end
        end
      end
    end
  end

  if updatedDeduped > 0 and type(ns.NoteSimpleAuraWatchUpdatedIDDeduped) == "function" then
    ns.NoteSimpleAuraWatchUpdatedIDDeduped(updatedDeduped)
  end
  if removedDeduped > 0 and type(ns.NoteSimpleAuraWatchRemovedIDDeduped) == "function" then
    ns.NoteSimpleAuraWatchRemovedIDDeduped(removedDeduped)
  end

  if not hasPayload then
    if type(ns.NoteSimpleAuraWatchNoopPayload) == "function" then
      ns.NoteSimpleAuraWatchNoopPayload()
    end
    return true, false
  end

  return true, touched
end

function func.RefreshSafeAuraWatch(frame, unit, updateInfo)
  local root = EnsureAuraWatch(frame)
  if not root or not (type(ForEachAura) == "function") then
    return
  end

  local auraUnit = unit or frame.unit or frame.displayedUnit
  if type(auraUnit) ~= "string" or auraUnit == "" then
    return
  end

  local appliedIncremental, touchedOrReason = ApplyIncrementalAuraWatch(root, auraUnit, updateInfo)
  if appliedIncremental then
    if type(ns.NoteSimpleAuraWatchIncrementalApply) == "function" then
      ns.NoteSimpleAuraWatchIncrementalApply()
    end
    if touchedOrReason == true then
      ApplyAuraWatchDisplay(root)
    elseif type(ns.NoteSimpleAuraWatchSkip) == "function" then
      ns.NoteSimpleAuraWatchSkip()
    end
    return
  end

  if type(ns.NoteSimpleAuraWatchFullScan) == "function" then
    ns.NoteSimpleAuraWatchFullScan(touchedOrReason)
  end
  FullRefreshSafeAuraWatch(root, auraUnit)
end

function func.CreateSafeAuraWatch(frame)
  local root = EnsureAuraWatch(frame)
  if root then
    func.RefreshSafeAuraWatch(frame, frame and frame.unit)
  end
  return root
end
