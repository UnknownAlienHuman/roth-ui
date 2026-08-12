local addonName, ns = ...

local func = assert(ns and ns.func, "Roth_UI: ns.func is required by frame_policy.lua")
local safety = ns and ns.safety
local defer = ns and ns.defer

local policy = ns.framePolicy or {}
ns.framePolicy = policy
local groupFrames = policy.groupFrames or {}
policy.groupFrames = groupFrames

local InCombatLockdown = _G.InCombatLockdown
local UnitFullName = _G.UnitFullName
local UnitName = _G.UnitName

local function IsForbidden(frame)
  if not frame then
    return false
  end
  if safety and type(safety.IsForbiddenTable) == "function" and safety.IsForbiddenTable(frame) then
    return true
  end
  if type(frame.IsForbidden) == "function" then
    return frame:IsForbidden() and true or false
  end
  return false
end

local function SafeCall(fn, ...)
  if type(fn) ~= "function" then
    return
  end
  return fn(...)
end

local function SafeCallMethod(frame, method)
  if not frame or IsForbidden(frame) then
    return
  end
  local fn = frame[method]
  if type(fn) == "function" then
    return fn(frame)
  end
end

local function SafeCallMethodArgs(frame, method, ...)
  if not frame or IsForbidden(frame) then
    return
  end
  local fn = frame[method]
  if type(fn) == "function" then
    return fn(frame, ...)
  end
end

local function SafeSetParent(frame, parent)
  if not frame or not parent or IsForbidden(frame) or IsForbidden(parent) or frame == parent then
    return
  end
  if type(frame.GetParent) == "function" and frame:GetParent() == parent then
    return
  end
  SafeCallMethodArgs(frame, "SetParent", parent)
end

local function SafeRegisterEvent(frame, event)
  if frame and event and type(frame.RegisterEvent) == "function" then
    frame:RegisterEvent(event)
  end
end

local function SafeSetCVar(name, value)
  if name and C_CVar and C_CVar.SetCVar then
    C_CVar.SetCVar(name, value)
  end
end

local function SafeGetCVar(name)
  if name and C_CVar and C_CVar.GetCVar then
    return C_CVar.GetCVar(name)
  end
  return nil
end

local function SafeGetCVarDefault(name)
  if name and C_CVar and C_CVar.GetCVarDefault then
    return C_CVar.GetCVarDefault(name)
  end
  return nil
end

local function SafeSetCVarDefaultOr(name, fallback)
  if not name then
    return
  end
  local defaultValue = SafeGetCVarDefault(name)
  if defaultValue ~= nil then
    SafeSetCVar(name, defaultValue)
    return
  end
  if fallback ~= nil then
    SafeSetCVar(name, fallback)
  end
end

local function ForceShow(frame)
  if not frame then
    return
  end
  SafeCallMethodArgs(frame, "SetAlpha", 1)
  SafeCallMethodArgs(frame, "SetShown", true)
  SafeCallMethod(frame, "Show")
end

local function FrameName(frame)
  if not frame then
    return "nil"
  end
  if IsForbidden(frame) then
    return "forbidden"
  end
  if type(frame.GetName) == "function" then
    local name = frame:GetName()
    if name then
      return name
    end
  end
  return tostring(frame)
end

local function GetPlayerCharacterName()
  local unitName, realmName
  if type(UnitFullName) == "function" then
    unitName, realmName = UnitFullName("player")
  elseif type(UnitName) == "function" then
    unitName, realmName = UnitName("player")
  end

  if not unitName or unitName == "" then
    return nil
  end
  if realmName and realmName ~= "" then
    return unitName .. "-" .. realmName
  end
  return unitName
end

-- Shared combat-lockdown deferral for frame policy recovery/apply paths.
local function DeferUntilOutOfCombat(owner, pendingKey, hookKey, callback)
  if type(owner) ~= "table" or type(pendingKey) ~= "string" or pendingKey == "" or type(hookKey) ~= "string" or hookKey == "" or type(callback) ~= "function" then
    return false
  end
  if not (type(InCombatLockdown) == "function" and InCombatLockdown()) then
    return false
  end

  owner[pendingKey] = true
  if owner[hookKey] then
    return true
  end

  local frame = CreateFrame("Frame")
  owner[hookKey] = frame
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:SetScript("OnEvent", function()
    if owner[pendingKey] then
      owner[pendingKey] = nil
      callback(owner)
    end
  end)
  return true
end

local hiddenParent
local function GetHiddenParent()
  if hiddenParent then
    return hiddenParent
  end
  hiddenParent = CreateFrame("Frame")
  hiddenParent:Hide()
  return hiddenParent
end

local function ParkFrame(frame)
  if not frame or IsForbidden(frame) then
    return
  end
  SafeSetParent(frame, GetHiddenParent())
  SafeCallMethod(frame, "Hide")
end

local function EnsureRaidFrameCompat()
  if type(_G.RaidFinderFrame_UpdateTab) ~= "function" then
    if not func.__raidFinderStub then
      func.__raidFinderStub = function() end
    end
    _G.RaidFinderFrame_UpdateTab = func.__raidFinderStub
  end

  local raidFrame = _G.RaidFrame
  if raidFrame and type(raidFrame.GetTitleText) ~= "function" then
    raidFrame.GetTitleText = function(self)
      return self.TitleText
    end
  end
end

local function IsRaidFinderReal()
  local fn = _G.RaidFinderFrame_UpdateTab
  return type(fn) == "function" and fn ~= func.__raidFinderStub
end

local function CanShowRaidFrame()
  local raidFrame = _G.RaidFrame
  if not raidFrame then
    return false
  end
  if type(raidFrame.GetTitleText) == "function" then
    return IsRaidFinderReal()
  end
  return false
end

local function DoesAddOnExist(name)
  if not name or not (C_AddOns and C_AddOns.DoesAddOnExist) then
    return false
  end
  local exists = C_AddOns.DoesAddOnExist(name)
  return exists and true or false
end

local function SafeLoadAddOn(name)
  if not name or not DoesAddOnExist(name) or not (C_AddOns and C_AddOns.LoadAddOn) then
    return
  end
  C_AddOns.LoadAddOn(name)
end

local function SafeEnableAddOn(name)
  if not name or not DoesAddOnExist(name) or not (C_AddOns and C_AddOns.EnableAddOn) then
    return
  end

  local player = GetPlayerCharacterName()
  C_AddOns.EnableAddOn(name)
  if player then
    C_AddOns.EnableAddOn(name, player)
  end
end

local function SafeSaveAddOns()
  if C_AddOns and C_AddOns.SaveAddOns then
    C_AddOns.SaveAddOns()
  end
end

local function GetAddOnEnableState(name, character)
  if not name or not (C_AddOns and C_AddOns.GetAddOnEnableState) then
    return nil
  end
  return C_AddOns.GetAddOnEnableState(name, character)
end

local function IsAddOnEnabled(name)
  if not name then
    return true
  end

  local player = GetPlayerCharacterName()
  if player then
    local stateChar = GetAddOnEnableState(name, player)
    if type(stateChar) == "number" then
      return stateChar > 0
    end
  end

  local state = GetAddOnEnableState(name, nil)
  if type(state) == "number" then
    return state > 0
  end

  return true
end

local function ReapplyBlizzardPartyFrames()
  local partyFrame = _G.PartyFrame
  if partyFrame and not IsForbidden(partyFrame) then
    local hasActiveMemberFrames = false
    local pool = partyFrame.PartyMemberFramePool
    if type(pool) == "table" and type(pool.EnumerateActive) == "function" then
      for _ in pool:EnumerateActive() do
        hasActiveMemberFrames = true
        break
      end
    end

    if not hasActiveMemberFrames and type(partyFrame.InitializePartyMemberFrames) == "function" then
      partyFrame:InitializePartyMemberFrames()
    end

    SafeCallMethod(partyFrame, "UpdateSpacingAndLayout")
    SafeCallMethod(partyFrame, "UpdatePartyFrames")
    SafeCallMethod(partyFrame, "UpdatePartyMemberBackground")
    SafeCallMethod(partyFrame, "UpdatePaddingAndLayout")
  end

  local compactPartyFrame = _G.CompactPartyFrame
  if not compactPartyFrame and type(_G.CompactPartyFrame_Generate) == "function" then
    compactPartyFrame = _G.CompactPartyFrame_Generate()
  end

  if compactPartyFrame and not IsForbidden(compactPartyFrame) then
    SafeCallMethod(compactPartyFrame, "UpdateVisibility")
    if type(compactPartyFrame.ShouldShow) == "function" and compactPartyFrame:ShouldShow() then
      SafeCallMethod(compactPartyFrame, "RefreshMembers")
    else
      SafeCallMethod(compactPartyFrame, "UpdateLayout")
    end
  end
end

local function ReapplyBlizzardRaidFrames()
  EnsureRaidFrameCompat()
  if type(_G.CompactRaidFrameManager_UpdateShown) == "function" then
    _G.CompactRaidFrameManager_UpdateShown()
  end
end

local function QueueRefresh(key, fn)
  if type(key) ~= "string" or key == "" or type(fn) ~= "function" then
    return
  end

  if defer and type(defer.RunWithRetry) == "function" then
    defer.RunWithRetry("frame_policy:" .. key, fn)
    return
  end

  fn()
end

local function IsRothEnabled(value)
  if value == nil then
    return true
  end

  local valueType = type(value)
  if valueType == "boolean" then
    return value
  end
  if valueType == "number" then
    return value ~= 0
  end
  if valueType == "string" then
    local normalized = value:lower()
    if normalized == "false" or normalized == "0" or normalized == "blizzard" or normalized == "off" then
      return false
    end
    if normalized == "true" or normalized == "1" or normalized == "roth" or normalized == "on" then
      return true
    end
  end

  return true
end

local function ApplyBlizzUnitFrameState(frame, useRoth)
  if not frame or IsForbidden(frame) then
    return
  end
  if useRoth then
    ParkFrame(frame)
    return
  end
  SafeSetParent(frame, UIParent)
  ForceShow(frame)
end

policy.IsForbidden = IsForbidden
policy.SafeCall = SafeCall
policy.SafeCallMethod = SafeCallMethod
policy.SafeCallMethodArgs = SafeCallMethodArgs
policy.SafeSetParent = SafeSetParent
policy.SafeRegisterEvent = SafeRegisterEvent
policy.SafeSetCVar = SafeSetCVar
policy.SafeGetCVar = SafeGetCVar
policy.SafeGetCVarDefault = SafeGetCVarDefault
policy.SafeSetCVarDefaultOr = SafeSetCVarDefaultOr
policy.ForceShow = ForceShow
policy.FrameName = FrameName
policy.GetPlayerCharacterName = GetPlayerCharacterName
policy.DeferUntilOutOfCombat = DeferUntilOutOfCombat
policy.GetHiddenParent = GetHiddenParent
policy.ParkFrame = ParkFrame
policy.EnsureRaidFrameCompat = EnsureRaidFrameCompat
policy.CanShowRaidFrame = CanShowRaidFrame
policy.DoesAddOnExist = DoesAddOnExist
policy.SafeLoadAddOn = SafeLoadAddOn
policy.SafeEnableAddOn = SafeEnableAddOn
policy.SafeSaveAddOns = SafeSaveAddOns
policy.GetAddOnEnableState = GetAddOnEnableState
policy.IsAddOnEnabled = IsAddOnEnabled
policy.ReapplyBlizzardPartyFrames = ReapplyBlizzardPartyFrames
policy.ReapplyBlizzardRaidFrames = ReapplyBlizzardRaidFrames
policy.QueueRefresh = QueueRefresh
policy.IsRothEnabled = IsRothEnabled
policy.ApplyBlizzUnitFrameState = ApplyBlizzUnitFrameState

groupFrames.SafeRegisterEvent = SafeRegisterEvent
groupFrames.SafeGetCVar = SafeGetCVar
groupFrames.SafeSetCVarDefaultOr = SafeSetCVarDefaultOr
groupFrames.SafeCall = SafeCall
groupFrames.SafeCallMethod = SafeCallMethod
groupFrames.SafeSetParent = SafeSetParent
groupFrames.ForceShow = ForceShow
groupFrames.FrameName = FrameName
groupFrames.IsForbidden = IsForbidden
groupFrames.CanShowRaidFrame = CanShowRaidFrame
groupFrames.SafeLoadAddOn = SafeLoadAddOn
groupFrames.SafeEnableAddOn = SafeEnableAddOn
groupFrames.SafeSaveAddOns = SafeSaveAddOns
groupFrames.GetAddOnEnableState = GetAddOnEnableState
groupFrames.IsAddOnEnabled = IsAddOnEnabled
groupFrames.ReapplyPartyFrames = ReapplyBlizzardPartyFrames
groupFrames.ReapplyRaidFrames = ReapplyBlizzardRaidFrames
groupFrames.QueueRefresh = QueueRefresh
groupFrames.GetPlayerCharacterName = GetPlayerCharacterName
groupFrames.ParkFrame = ParkFrame
groupFrames.DeferUntilOutOfCombat = DeferUntilOutOfCombat
groupFrames.IsRothEnabled = IsRothEnabled

ns.IsRothEnabled = ns.IsRothEnabled or IsRothEnabled
