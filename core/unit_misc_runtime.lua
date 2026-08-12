-- Extracted from core/lib.lua to reduce monolithic runtime coupling.
-- Provides numeric formatting and dispel-color runtime for aura checks.

local addonName, ns = ...

local func = assert(ns and ns.func, "Roth_UI: ns.func is required by unit_misc_runtime.lua")
local RothUI = _G.RothUI or {}
_G.RothUI = RothUI

local type = type
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local setmetatable = setmetatable
local floor = floor or math.floor
local mod = mod or math.fmod
local format = format or string.format

local UnitClass = UnitClass
local UnitGUID = UnitGUID
local CreateFrame = CreateFrame
local GetTime = GetTime
local AuraUtil = AuraUtil
local ForEachAura = AuraUtil and AuraUtil.ForEachAura
local GetAuraDataByAuraInstanceID = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
local defer = ns and ns.defer

local IsSecretValue = assert(func.IsSecretValue, "Roth_UI: func.IsSecretValue is required by unit_misc_runtime.lua")

local function fmt1(x)
  local s = string.format("%.1f", x)
  if s:sub(-2) == ".0" then
    s = s:sub(1, -3)
  end
  return s
end

local CanAccessSecret = _G.canaccessvalue

func.numFormat = function(v)
  if v == nil then return "" end

  local n
  local vt = type(v)
  if vt == "number" then
    if IsSecretValue(v) then
      if type(CanAccessSecret) == "function" and CanAccessSecret(v) then
        n = tonumber(v)
      else
        return ""
      end
    else
      n = v
    end
  elseif vt == "string" then
    n = tonumber(v)
  else
    n = tonumber(v)
  end

  if type(n) ~= "number" then
    return ""
  end

  local rounded = floor(n + 0.5)
  if math.abs(n - rounded) < 0.01 then
    n = rounded
  end

  local absn = n < 0 and -n or n

  local short = ns.cfg and ns.cfg.shortNumbers
  if short == nil then short = false end

  if short and absn >= 1000000000 then
    return fmt1(n / 1000000000) .. "b"
  elseif short and absn >= 1000000 then
    return fmt1(n / 1000000) .. "m"
  elseif short and absn >= 1000 then
    return fmt1(n / 1000) .. "k"
  end

  if n % 1 == 0 then
    return tostring(n)
  end
  return fmt1(n)
end

func.round = function(val)
  return floor(val * 1000) / 1000
end

local _, playerClassFile = UnitClass("player")
local playerRoleToken = nil

local function ResolvePlayerRoleToken()
  local specIndex = C_SpecializationInfo.GetSpecialization()
  if specIndex and GetSpecializationRole then
    local role = GetSpecializationRole(specIndex)
    if role and not IsSecretValue(role) then
      return role
    end
  end
  return nil
end

local function RefreshDispelContext()
  local _, classFile = UnitClass("player")
  if classFile and not IsSecretValue(classFile) then
    playerClassFile = classFile
  end
  playerRoleToken = ResolvePlayerRoleToken()
end
RefreshDispelContext()

if type(CreateFrame) == "function" then
  local dispelContextFrame = CreateFrame("Frame")
  dispelContextFrame:RegisterEvent("PLAYER_LOGIN")
  dispelContextFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  dispelContextFrame:SetScript("OnEvent", function(_, _, changedUnit)
    if changedUnit and changedUnit ~= "player" then return end
    RefreshDispelContext()
  end)
end

local function ResolveCanActivePlayerDispel(auraData)
  if type(auraData) ~= "table" then
    return nil
  end
  local canDispel = auraData.canActivePlayerDispel
  if canDispel == nil or IsSecretValue(canDispel) then
    return nil
  end
  if type(canDispel) == "boolean" then
    return canDispel
  end
  return nil
end

local function ResolveAccessibleBoolean(value)
  if value == nil or IsSecretValue(value) then
    return nil
  end
  if type(value) == "boolean" then
    return value
  end
  return nil
end

local function ResolveAuraIsHarmful(auraData)
  if type(auraData) ~= "table" then
    return nil
  end
  return ResolveAccessibleBoolean(auraData.isHarmful)
end

local simpleAuraStats = {}
local FULL_SCAN_REASON_SUFFIX = {
  init = "Init",
  nilPayload = "NilPayload",
  isFullUpdate = "IsFullUpdate",
  missingAuraInstanceResolver = "MissingAuraInstanceResolver",
}
local DISPELLABLE_HARMFUL_FILTER = "HARMFUL|RAID_PLAYER_DISPELLABLE"

local function IncrementAuraCounter(key)
  if type(key) ~= "string" or key == "" then
    return
  end
  simpleAuraStats[key] = (simpleAuraStats[key] or 0) + 1
end

local function NoteFullScan(prefix, reason)
  if type(prefix) ~= "string" or prefix == "" then
    return
  end

  IncrementAuraCounter(prefix .. "FullScans")
  local suffix = FULL_SCAN_REASON_SUFFIX[reason]
  if suffix then
    IncrementAuraCounter(prefix .. "FullScan" .. suffix)
  end
end

local function NoteIncrementalApply(prefix)
  if type(prefix) ~= "string" or prefix == "" then
    return
  end

  IncrementAuraCounter(prefix .. "IncrementalApplies")
end

local function ResetAuraStatsCounters()
  simpleAuraStats.ingressEvents = 0
  simpleAuraStats.queuedEvents = 0
  simpleAuraStats.queueFlushes = 0
  simpleAuraStats.appliedPasses = 0
  simpleAuraStats.fullPayloads = 0
  simpleAuraStats.incrementalPayloads = 0
  simpleAuraStats.addedAuras = 0
  simpleAuraStats.updatedAuras = 0
  simpleAuraStats.removedAuras = 0
  simpleAuraStats.containerRuns = 0
  simpleAuraStats.containerSkips = 0
  simpleAuraStats.iterationFailures = 0
  simpleAuraStats.groupIncrementalApplies = 0
  simpleAuraStats.groupFullScans = 0
  simpleAuraStats.groupFullScanInit = 0
  simpleAuraStats.groupFullScanNilPayload = 0
  simpleAuraStats.groupFullScanIsFullUpdate = 0
  simpleAuraStats.groupFullScanMissingAuraInstanceResolver = 0
  simpleAuraStats.groupUpdatedAuraIDDeduped = 0
  simpleAuraStats.groupRemovedAuraIDDeduped = 0
  simpleAuraStats.watchIncrementalApplies = 0
  simpleAuraStats.watchFullScans = 0
  simpleAuraStats.watchFullScanInit = 0
  simpleAuraStats.watchFullScanNilPayload = 0
  simpleAuraStats.watchFullScanIsFullUpdate = 0
  simpleAuraStats.watchFullScanMissingAuraInstanceResolver = 0
  simpleAuraStats.watchUpdatedAuraIDDeduped = 0
  simpleAuraStats.watchRemovedAuraIDDeduped = 0
  simpleAuraStats.watchNoopPayloads = 0
  simpleAuraStats.watchSkips = 0
end

local function SnapshotAuraStats()
  local sessionSeconds = 0
  if type(GetTime) == "function" then
    local now = GetTime()
    local startedAt = tonumber(simpleAuraStats.startedAt) or now
    sessionSeconds = now - startedAt
    if sessionSeconds < 0 then
      sessionSeconds = 0
    end
  end

  local containerRuns = tonumber(simpleAuraStats.containerRuns) or 0
  local containerSkips = tonumber(simpleAuraStats.containerSkips) or 0

  return {
    ingressEvents = tonumber(simpleAuraStats.ingressEvents) or 0,
    queuedEvents = tonumber(simpleAuraStats.queuedEvents) or 0,
    queueFlushes = tonumber(simpleAuraStats.queueFlushes) or 0,
    appliedPasses = tonumber(simpleAuraStats.appliedPasses) or 0,
    fullPayloads = tonumber(simpleAuraStats.fullPayloads) or 0,
    incrementalPayloads = tonumber(simpleAuraStats.incrementalPayloads) or 0,
    addedAuras = tonumber(simpleAuraStats.addedAuras) or 0,
    updatedAuras = tonumber(simpleAuraStats.updatedAuras) or 0,
    removedAuras = tonumber(simpleAuraStats.removedAuras) or 0,
    containerRuns = containerRuns,
    containerSkips = containerSkips,
    iterationFailures = tonumber(simpleAuraStats.iterationFailures) or 0,
    groupIncrementalApplies = tonumber(simpleAuraStats.groupIncrementalApplies) or 0,
    groupFullScans = tonumber(simpleAuraStats.groupFullScans) or 0,
    groupFullScanInit = tonumber(simpleAuraStats.groupFullScanInit) or 0,
    groupFullScanNilPayload = tonumber(simpleAuraStats.groupFullScanNilPayload) or 0,
    groupFullScanIsFullUpdate = tonumber(simpleAuraStats.groupFullScanIsFullUpdate) or 0,
    groupFullScanMissingAuraInstanceResolver = tonumber(simpleAuraStats.groupFullScanMissingAuraInstanceResolver) or 0,
    groupUpdatedAuraIDDeduped = tonumber(simpleAuraStats.groupUpdatedAuraIDDeduped) or 0,
    groupRemovedAuraIDDeduped = tonumber(simpleAuraStats.groupRemovedAuraIDDeduped) or 0,
    watchIncrementalApplies = tonumber(simpleAuraStats.watchIncrementalApplies) or 0,
    watchFullScans = tonumber(simpleAuraStats.watchFullScans) or 0,
    watchFullScanInit = tonumber(simpleAuraStats.watchFullScanInit) or 0,
    watchFullScanNilPayload = tonumber(simpleAuraStats.watchFullScanNilPayload) or 0,
    watchFullScanIsFullUpdate = tonumber(simpleAuraStats.watchFullScanIsFullUpdate) or 0,
    watchFullScanMissingAuraInstanceResolver = tonumber(simpleAuraStats.watchFullScanMissingAuraInstanceResolver) or 0,
    watchUpdatedAuraIDDeduped = tonumber(simpleAuraStats.watchUpdatedAuraIDDeduped) or 0,
    watchRemovedAuraIDDeduped = tonumber(simpleAuraStats.watchRemovedAuraIDDeduped) or 0,
    watchNoopPayloads = tonumber(simpleAuraStats.watchNoopPayloads) or 0,
    watchSkips = tonumber(simpleAuraStats.watchSkips) or 0,
    skipRate = containerRuns > 0 and (containerSkips / containerRuns) or 0,
    sessionSeconds = sessionSeconds,
  }
end

simpleAuraStats.startedAt = type(GetTime) == "function" and GetTime() or 0
ResetAuraStatsCounters()

function ns.GetSimpleAuraStats()
  return SnapshotAuraStats()
end

function ns.ResetSimpleAuraStats()
  simpleAuraStats.startedAt = type(GetTime) == "function" and GetTime() or 0
  ResetAuraStatsCounters()
  return SnapshotAuraStats()
end

function ns.NoteSimpleAuraGroupIncrementalApply()
  NoteIncrementalApply("group")
end

function ns.NoteSimpleAuraGroupFullScan(reason)
  NoteFullScan("group", reason)
end

function ns.NoteSimpleAuraWatchIncrementalApply()
  NoteIncrementalApply("watch")
end

function ns.NoteSimpleAuraWatchFullScan(reason)
  NoteFullScan("watch", reason)
end

function ns.NoteSimpleAuraWatchSkip()
  IncrementAuraCounter("watchSkips")
end

function ns.NoteSimpleAuraWatchNoopPayload()
  IncrementAuraCounter("watchNoopPayloads")
end

function ns.NoteSimpleAuraWatchUpdatedIDDeduped(count)
  local amount = tonumber(count) or 0
  if amount > 0 then
    simpleAuraStats.watchUpdatedAuraIDDeduped = (simpleAuraStats.watchUpdatedAuraIDDeduped or 0) + amount
  end
end

function ns.NoteSimpleAuraWatchRemovedIDDeduped(count)
  local amount = tonumber(count) or 0
  if amount > 0 then
    simpleAuraStats.watchRemovedAuraIDDeduped = (simpleAuraStats.watchRemovedAuraIDDeduped or 0) + amount
  end
end

local harmfulAuraScanState = {
  self = nil,
  state = nil,
  color = nil,
}

local pendingGroupColorUpdates = setmetatable({}, { __mode = "k" })

local function GetGroupAuraState(self)
  if type(self) ~= "table" then
    return nil
  end

  local state = self.__rothGroupAuraColorState
  if type(state) ~= "table" then
    state = {
      tracked = {},
      nextSerial = 1,
      initialized = false,
      unitToken = nil,
      unitGUID = nil,
    }
    self.__rothGroupAuraColorState = state
    return state
  end

  if type(state.tracked) ~= "table" then
    state.tracked = {}
  end
  if type(state.nextSerial) ~= "number" or state.nextSerial < 1 then
    state.nextSerial = 1
  end
  if state.initialized ~= true then
    state.initialized = false
  end

  return state
end

local function ResetTrackedDispels(state)
  if type(state) ~= "table" or type(state.tracked) ~= "table" then
    return
  end

  for auraInstanceID in pairs(state.tracked) do
    state.tracked[auraInstanceID] = nil
  end
  state.nextSerial = 1
end

local function AllocateAuraSerial(state)
  local nextSerial = tonumber(state and state.nextSerial) or 1
  state.nextSerial = nextSerial + 1
  return nextSerial
end

local function CountPayloadEntries(list)
  return type(list) == "table" and #list or 0
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

local function NoteAuraPayload(updateInfo)
  if type(updateInfo) ~= "table" then
    simpleAuraStats.fullPayloads = (simpleAuraStats.fullPayloads or 0) + 1
    return
  end

  if updateInfo.isFullUpdate then
    simpleAuraStats.fullPayloads = (simpleAuraStats.fullPayloads or 0) + 1
  else
    simpleAuraStats.incrementalPayloads = (simpleAuraStats.incrementalPayloads or 0) + 1
  end

  simpleAuraStats.addedAuras = (simpleAuraStats.addedAuras or 0) + CountPayloadEntries(updateInfo.addedAuras)
  simpleAuraStats.updatedAuras = (simpleAuraStats.updatedAuras or 0) + CountPayloadEntries(updateInfo.updatedAuraInstanceIDs)
  simpleAuraStats.removedAuras = (simpleAuraStats.removedAuras or 0) + CountPayloadEntries(updateInfo.removedAuraInstanceIDs)
end

local function AppendPayloadEntries(target, source)
  if type(source) ~= "table" or #source == 0 then
    return target
  end

  if type(target) ~= "table" then
    target = {}
  end

  for i = 1, #source do
    target[#target + 1] = source[i]
  end

  return target
end

local function MergeAuraUpdateInfo(current, incoming)
  if type(incoming) ~= "table" then
    return current
  end

  if type(current) ~= "table" then
    current = {}
  end

  if incoming.isFullUpdate then
    current.isFullUpdate = true
  end
  current.addedAuras = AppendPayloadEntries(current.addedAuras, incoming.addedAuras)
  current.updatedAuraInstanceIDs = AppendPayloadEntries(current.updatedAuraInstanceIDs, incoming.updatedAuraInstanceIDs)
  current.removedAuraInstanceIDs = AppendPayloadEntries(current.removedAuraInstanceIDs, incoming.removedAuraInstanceIDs)
  return current
end

local function ResolveAuraUnit(self, unit)
  if type(self) ~= "table" then
    return nil
  end

  local frameUnit = self.unit or self.displayedUnit or self.__unit
  if type(unit) == "string" and type(frameUnit) == "string" and unit ~= frameUnit then
    return nil
  end
  if type(frameUnit) == "string" then
    return frameUnit
  end
  if type(unit) == "string" then
    return unit
  end
  return nil
end

local function ResolveUnitIdentity(unit)
  if type(unit) ~= "string" or unit == "" then
    return nil, nil
  end
  local guid = type(UnitGUID) == "function" and UnitGUID(unit) or nil
  return unit, guid
end

local function EnsureGroupStateIdentity(state, unitToken, unitGUID)
  if type(state) ~= "table" then
    return false
  end

  local currentToken = state.unitToken
  local currentGUID = state.unitGUID
  if currentToken == unitToken and currentGUID == unitGUID then
    return false
  end

  ResetTrackedDispels(state)
  state.initialized = false
  state.unitToken = unitToken
  state.unitGUID = unitGUID
  return true
end

local function ResolveDispelAuraType(auraData, defaultDebuffType)
  local auraType = defaultDebuffType
  local canDispel = nil

  if type(auraData) == "table" then
    if ResolveAuraIsHarmful(auraData) == false then
      return nil
    end
    auraType = auraData.dispelName
    canDispel = ResolveCanActivePlayerDispel(auraData)
  end

  if type(auraType) ~= "string" or auraType == "" or IsSecretValue(auraType) then
    return nil
  end

  if canDispel == nil then
    canDispel = RothUI:canDispelDebuff(auraType)
  end
  if not canDispel then
    return nil
  end

  return auraType
end

local function TrackDispellableAura(state, auraData, defaultDebuffType, preserveSerial)
  if type(state) ~= "table" or type(state.tracked) ~= "table" or type(auraData) ~= "table" then
    return false
  end

  local auraType = ResolveDispelAuraType(auraData, defaultDebuffType)
  local auraInstanceID = auraData.auraInstanceID
  if type(auraInstanceID) ~= "number" or IsSecretValue(auraInstanceID) then
    if auraType ~= nil then
      simpleAuraStats.iterationFailures = (simpleAuraStats.iterationFailures or 0) + 1
    end
    return false
  end

  local tracked = state.tracked
  if not auraType then
    if tracked[auraInstanceID] ~= nil then
      tracked[auraInstanceID] = nil
      return true
    end
    return false
  end

  local entry = tracked[auraInstanceID]
  local changed = false
  if type(entry) ~= "table" then
    entry = { serial = AllocateAuraSerial(state) }
    tracked[auraInstanceID] = entry
    changed = true
  elseif not preserveSerial or type(entry.serial) ~= "number" then
    entry.serial = AllocateAuraSerial(state)
  end

  if entry.auraType ~= auraType then
    changed = true
  end
  entry.auraType = auraType
  return changed
end

local function ResolveTrackedDispelColor(state)
  if type(state) ~= "table" or type(state.tracked) ~= "table" then
    return nil
  end

  local selectedEntry = nil
  local selectedSerial = nil

  for _, entry in pairs(state.tracked) do
    if type(entry) == "table" and type(entry.auraType) == "string" and not IsSecretValue(entry.auraType) then
      local serial = tonumber(entry.serial) or 0
      if selectedSerial == nil or serial > selectedSerial then
        selectedSerial = serial
        selectedEntry = entry
      end
    end
  end

  if not selectedEntry then
    return nil
  end

  return DebuffTypeColor[selectedEntry.auraType] or DebuffTypeColor.none
end

local function ApplyGroupAuraColor(self, color)
  if not self or not self.Health then
    return
  end

  self.Health.buffOverride = true
  if self.Health.glow then
    if type(color) == "table" and color ~= DebuffTypeColor.none then
      self.Health.glow:SetVertexColor(color.r, color.g, color.b)
    else
      self.Health.glow:SetVertexColor(0, 0, 0)
    end
  end
end

local function HandleHarmfulAura(auraData, _, _, debuffType)
  local state = harmfulAuraScanState.state
  local auraType = ResolveDispelAuraType(auraData, debuffType)
  if not auraType then
    return
  end

  local color = DebuffTypeColor[auraType] or DebuffTypeColor.none
  if color ~= DebuffTypeColor.none then
    harmfulAuraScanState.color = color
  end

  if state and type(auraData) == "table" then
    TrackDispellableAura(state, auraData, auraType, false)
  end
end

local function ApplyIncrementalAuraUpdate(state, unit, updateInfo)
  simpleAuraStats.containerRuns = (simpleAuraStats.containerRuns or 0) + 1

  if type(state) ~= "table" or state.initialized ~= true or type(updateInfo) ~= "table" or updateInfo.isFullUpdate then
    return false
  end

  local addedAuras = updateInfo.addedAuras
  local updatedAuraInstanceIDs = updateInfo.updatedAuraInstanceIDs
  local removedAuraInstanceIDs = updateInfo.removedAuraInstanceIDs
  local tracked = state.tracked
  local touched = false
  local hasPayload = false
  local updatedSeen = nil
  local removedSeen = nil

  if type(addedAuras) == "table" and #addedAuras > 0 then
    hasPayload = true
    for i = 1, #addedAuras do
      local auraData = addedAuras[i]
      if type(auraData) == "table" and TrackDispellableAura(state, auraData, nil, false) then
        touched = true
      end
    end
  end

  if type(updatedAuraInstanceIDs) == "table" and #updatedAuraInstanceIDs > 0 then
    hasPayload = true
    if type(GetAuraDataByAuraInstanceID) ~= "function" then
      return false
    end

    updatedSeen = AcquireScratchSet(state, "__rothUpdatedAuraInstanceSeen")
    for i = 1, #updatedAuraInstanceIDs do
      local auraInstanceID = updatedAuraInstanceIDs[i]
      if type(auraInstanceID) == "number" and not IsSecretValue(auraInstanceID) then
        if updatedSeen and updatedSeen[auraInstanceID] then
          simpleAuraStats.groupUpdatedAuraIDDeduped = (simpleAuraStats.groupUpdatedAuraIDDeduped or 0) + 1
        else
          if updatedSeen then
            updatedSeen[auraInstanceID] = true
          end
          local auraData = GetAuraDataByAuraInstanceID(unit, auraInstanceID)
          if auraData then
            if TrackDispellableAura(state, auraData, nil, true) then
              touched = true
            end
          elseif tracked[auraInstanceID] ~= nil then
            tracked[auraInstanceID] = nil
            touched = true
          end
        end
      end
    end
  end

  if type(removedAuraInstanceIDs) == "table" and #removedAuraInstanceIDs > 0 then
    hasPayload = true
    removedSeen = AcquireScratchSet(state, "__rothRemovedAuraInstanceSeen")
    for i = 1, #removedAuraInstanceIDs do
      local auraInstanceID = removedAuraInstanceIDs[i]
      if type(auraInstanceID) == "number" then
        if removedSeen and removedSeen[auraInstanceID] then
          simpleAuraStats.groupRemovedAuraIDDeduped = (simpleAuraStats.groupRemovedAuraIDDeduped or 0) + 1
        else
          if removedSeen then
            removedSeen[auraInstanceID] = true
          end
          if tracked[auraInstanceID] ~= nil then
            tracked[auraInstanceID] = nil
            touched = true
          end
        end
      end
    end
  end

  if not hasPayload or not touched then
    simpleAuraStats.containerSkips = (simpleAuraStats.containerSkips or 0) + 1
  end

  return true
end

local function ResolveIncrementalFallbackReason(state, updateInfo)
  if type(state) ~= "table" or state.initialized ~= true then
    return "init"
  end

  if type(updateInfo) ~= "table" then
    return "nilPayload"
  end

  if updateInfo.isFullUpdate then
    return "isFullUpdate"
  end

  local updatedAuraInstanceIDs = updateInfo.updatedAuraInstanceIDs
  if type(updatedAuraInstanceIDs) == "table" and #updatedAuraInstanceIDs > 0 and type(GetAuraDataByAuraInstanceID) ~= "function" then
    return "missingAuraInstanceResolver"
  end

  return "nilPayload"
end

local function FullScanGroupAuras(self, unit, state)
  ResetTrackedDispels(state)
  harmfulAuraScanState.self = self
  harmfulAuraScanState.state = state
  harmfulAuraScanState.color = nil

  if type(ForEachAura) == "function" then
    ForEachAura(unit, DISPELLABLE_HARMFUL_FILTER, nil, HandleHarmfulAura, true)
  end

  state.initialized = true
  local color = harmfulAuraScanState.color
  harmfulAuraScanState.self = nil
  harmfulAuraScanState.state = nil
  harmfulAuraScanState.color = nil
  ApplyGroupAuraColor(self, color)
end

func.checkColors = function(self, event, unit, updateInfo)
  if not self or not self.Health then
    return
  end

  local auraUnit = ResolveAuraUnit(self, unit)
  if not auraUnit then
    return
  end

  simpleAuraStats.appliedPasses = (simpleAuraStats.appliedPasses or 0) + 1

  local state = GetGroupAuraState(self)
  local unitToken, unitGUID = ResolveUnitIdentity(auraUnit)
  if not unitToken then
    return
  end
  EnsureGroupStateIdentity(state, unitToken, unitGUID)
  if type(updateInfo) == "table" and ApplyIncrementalAuraUpdate(state, auraUnit, updateInfo) then
    ns.NoteSimpleAuraGroupIncrementalApply()
    ApplyGroupAuraColor(self, ResolveTrackedDispelColor(state))
    return
  end

  ns.NoteSimpleAuraGroupFullScan(ResolveIncrementalFallbackReason(state, updateInfo))
  FullScanGroupAuras(self, auraUnit, state)
end

func.QueueGroupAuraColorUpdate = function(self, event, unit, updateInfo)
  local auraUnit = ResolveAuraUnit(self, unit)
  if not auraUnit then
    return
  end

  local unitToken, unitGUID = ResolveUnitIdentity(auraUnit)
  if not unitToken then
    return
  end

  if event == "UNIT_AURA" then
    simpleAuraStats.ingressEvents = (simpleAuraStats.ingressEvents or 0) + 1
    NoteAuraPayload(updateInfo)
  end
  simpleAuraStats.queuedEvents = (simpleAuraStats.queuedEvents or 0) + 1

  local pending = pendingGroupColorUpdates[self]
  if type(pending) == "table" then
    if pending.unit ~= unitToken or pending.guid ~= unitGUID then
      pending.forceFullScan = true
      pending.updateInfo = nil
    end
    pending.unit = unitToken
    pending.guid = unitGUID
    if type(updateInfo) == "table" and pending.forceFullScan ~= true then
      pending.updateInfo = MergeAuraUpdateInfo(pending.updateInfo, updateInfo)
    else
      pending.forceFullScan = true
      pending.updateInfo = nil
    end
    return
  end

  pendingGroupColorUpdates[self] = {
    unit = unitToken,
    guid = unitGUID,
    updateInfo = type(updateInfo) == "table" and MergeAuraUpdateInfo(nil, updateInfo) or nil,
    forceFullScan = type(updateInfo) ~= "table",
  }

  local function Flush()
    local current = pendingGroupColorUpdates[self]
    pendingGroupColorUpdates[self] = nil
    if not current then
      return
    end

    simpleAuraStats.queueFlushes = (simpleAuraStats.queueFlushes or 0) + 1

    func.checkColors(self, event, current.unit, current.forceFullScan and nil or current.updateInfo)
    if type(func.RefreshSafeAuraWatch) == "function" then
      func.RefreshSafeAuraWatch(self, current.unit, current.forceFullScan and nil or current.updateInfo)
    end
  end

  local queueKey = self and self._rothGroupAuraColorKey
  if not queueKey then
    local frameName = self and self.GetName and self:GetName()
    queueKey = "group_aura_color:" .. (frameName or tostring(self))
    if self then
      self._rothGroupAuraColorKey = queueKey
    end
  end

  if defer and type(defer.RunNextFrame) == "function" then
    defer.RunNextFrame(queueKey, Flush, false)
  else
    Flush()
  end
end

function RothUI:canDispelDebuff(debuffType)
  if not debuffType or IsSecretValue(debuffType) then
    return false
  end

  local classFile = playerClassFile
  if not classFile or IsSecretValue(classFile) then
    _, classFile = UnitClass("player")
    playerClassFile = classFile
  end
  local role = playerRoleToken or ResolvePlayerRoleToken()

  if debuffType == "Magic" then
    return role == "HEALER"
  elseif debuffType == "Curse" then
    return classFile == "DRUID" or classFile == "MAGE" or classFile == "SHAMAN"
  elseif debuffType == "Disease" then
    return classFile == "MONK" or classFile == "PALADIN" or classFile == "PRIEST"
  elseif debuffType == "Poison" then
    return classFile == "DRUID" or classFile == "MONK" or classFile == "PALADIN"
  end

  return false
end
