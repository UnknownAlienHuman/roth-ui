-- Retail 12.1 managed-aura hardening loaded after aura_runtime_12_1.lua.
--
-- This guard closes legacy compatibility gaps without reading AuraData:
-- 1. fail closed when oUF lacks frame:CreateAuras(), so legacy Buffs/Debuffs
--    placeholders cannot reactivate the removed raw UNIT_AURA element;
-- 2. preserve the old healer-watch "PLAYER" caster restriction through
--    CustomAuraContainer:SetAuraGroupCandidateFilters();
-- 3. apply that candidate-filter upgrade only once per managed group;
-- 4. detach Roth UI's obsolete UNIT_AURA callback while preserving oUF's own
--    element handlers via per-function UnregisterEvent.

local addonName, ns = ...

local func = assert(ns and ns.func, "Roth_UI: ns.func is required by aura_runtime_12_1_guard.lua")
local cfg = ns.cfg
local type = type
local tonumber = tonumber
local next = next
local UnitClass = UnitClass

local IsSecretValue = assert(
  type(func.IsSecretValue) == "function" and func.IsSecretValue,
  "Roth_UI: func.IsSecretValue is required by aura_runtime_12_1_guard.lua"
)

local SPELL_IDS_BY_CLASS = {
  PRIEST = { 139, 17, 77489, 41635 },
  PALADIN = { 223306, 53563, 6940, 287280, 156910, 200025 },
  DRUID = { 33763, 774, 8936, 102342, 102351, 48438, 155777 },
  SHAMAN = { 61295 },
  MONK = { 119611, 124682 },
}

local function WarnOnce(key, message)
  ns.__rothAuraGuardWarnings = ns.__rothAuraGuardWarnings or {}
  if ns.__rothAuraGuardWarnings[key] then
    return
  end
  ns.__rothAuraGuardWarnings[key] = true
  print("|cffff8000Roth_UI:|r " .. message)
end

local function HasManagedAuraAPI(frame)
  return frame and type(frame.CreateAuras) == "function"
end

local function ClearLegacyField(frame, field)
  if not (frame and field) then
    return
  end

  frame[field] = nil
  if field == "AuraWatch" then
    frame.__rothAuraWatch = nil
    frame.__rothManagedAuraWatch = nil
  end
end

local function FailClosed(frame, field)
  ClearLegacyField(frame, field)
  WarnOnce(
    "missingCreateAuras",
    "oUF 14.0.2 or newer is required for Retail 12.1 managed auras; aura display was disabled."
  )
  return nil
end

local setupNativeAuraFrame = func.SetupNativeAuraFrame
if type(setupNativeAuraFrame) == "function" then
  func.SetupNativeAuraFrame = function(legacyFrame, showTimers)
    local owner = legacyFrame and legacyFrame.GetParent and legacyFrame:GetParent()
    if not HasManagedAuraAPI(owner) then
      if legacyFrame and legacyFrame.Hide then
        legacyFrame:Hide()
      end
      return FailClosed(nil, nil)
    end
    return setupNativeAuraFrame(legacyFrame, showTimers)
  end
end

local createBuffs = func.createBuffs
if type(createBuffs) == "function" then
  func.createBuffs = function(frame)
    if not HasManagedAuraAPI(frame) then
      return FailClosed(frame, "Buffs")
    end
    return createBuffs(frame)
  end
end

local createDebuffs = func.createDebuffs
if type(createDebuffs) == "function" then
  func.createDebuffs = function(frame)
    if not HasManagedAuraAPI(frame) then
      return FailClosed(frame, "Debuffs")
    end
    return createDebuffs(frame)
  end
end

local function ResolvePlayerClassToken()
  local classToken = cfg and cfg.playerclass
  if not IsSecretValue(classToken) and type(classToken) == "string" and classToken ~= "" then
    return classToken
  end

  local _, fallback = UnitClass("player")
  if not IsSecretValue(fallback) and type(fallback) == "string" and fallback ~= "" then
    return fallback
  end
  return nil
end

local function BuildHealerWatchFilters()
  local spellIDs = SPELL_IDS_BY_CLASS[ResolvePlayerClassToken()]
  if type(spellIDs) ~= "table" then
    return nil
  end

  local includeSpellIDs = {}
  for i = 1, #spellIDs do
    local spellID = tonumber(spellIDs[i])
    if spellID and spellID > 0 then
      includeSpellIDs[spellID] = true
    end
  end

  if next(includeSpellIDs) == nil then
    return nil
  end

  return {
    includeSpellIDs = includeSpellIDs,
    isFromPlayerOrPlayerPet = true,
  }
end

local function HardenAuraWatch(element)
  if not element or element.__rothOwnCasterFilterApplied == true then
    return element
  end

  local groupKey = element.__rothAuraWatchGroupKey
  if not groupKey or type(element.SetAuraGroupCandidateFilters) ~= "function" then
    return element
  end

  local filters = BuildHealerWatchFilters()
  if not filters then
    return element
  end

  element:SetAuraGroupCandidateFilters(groupKey, filters)
  element.__rothOwnCasterFilterApplied = true
  return element
end

local createSafeAuraWatch = func.CreateSafeAuraWatch
if type(createSafeAuraWatch) == "function" then
  func.CreateSafeAuraWatch = function(frame)
    if not HasManagedAuraAPI(frame) then
      return FailClosed(frame, "AuraWatch")
    end
    return HardenAuraWatch(createSafeAuraWatch(frame))
  end
end

local refreshSafeAuraWatch = func.RefreshSafeAuraWatch
if type(refreshSafeAuraWatch) == "function" then
  func.RefreshSafeAuraWatch = function(frame)
    if not HasManagedAuraAPI(frame) then
      return FailClosed(frame, "AuraWatch")
    end
    return HardenAuraWatch(refreshSafeAuraWatch(frame))
  end
end

local function DetachLegacyUnitAuraCallback(frame)
  if frame and type(frame.UnregisterEvent) == "function" then
    frame:UnregisterEvent("UNIT_AURA", DetachLegacyUnitAuraCallback)
  end
end

func.QueueGroupAuraColorUpdate = DetachLegacyUnitAuraCallback

ns.auraRuntime12_1Guard = {
  failClosedWithoutManagedAPI = true,
  healerWatchOwnCasterOnly = true,
  healerWatchFilterAppliedOnce = true,
  legacyUnitAuraCallbackDetached = true,
}
