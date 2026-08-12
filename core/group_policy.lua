local addonName, ns = ...

local func = assert(ns and ns.func, "Roth_UI: ns.func is required by group_policy.lua")
local policy = assert(ns and ns.framePolicy, "Roth_UI: framePolicy is required by group_policy.lua")
local groupFrames = assert(policy.groupFrames, "Roth_UI: framePolicy.groupFrames is required by group_policy.lua")
local persistence = assert(ns and ns.persistence, "Roth_UI: persistence service is required by group_policy.lua")
local RebuildPersistenceRuntime = assert(persistence.RebuildRuntime, "Roth_UI: persistence.RebuildRuntime is required by group_policy.lua")

local IsRothEnabled = assert(groupFrames.IsRothEnabled or ns.IsRothEnabled or policy.IsRothEnabled, "Roth_UI: groupFrames.IsRothEnabled is required by group_policy.lua")
local SafeLoadAddOn = assert(groupFrames.SafeLoadAddOn, "Roth_UI: groupFrames.SafeLoadAddOn is required by group_policy.lua")
local SafeSetParent = assert(groupFrames.SafeSetParent, "Roth_UI: groupFrames.SafeSetParent is required by group_policy.lua")
local SafeCallMethod = assert(groupFrames.SafeCallMethod, "Roth_UI: groupFrames.SafeCallMethod is required by group_policy.lua")
local ParkFrame = assert(groupFrames.ParkFrame, "Roth_UI: groupFrames.ParkFrame is required by group_policy.lua")
local ReapplyBlizzardPartyFrames = assert(groupFrames.ReapplyPartyFrames, "Roth_UI: groupFrames.ReapplyPartyFrames is required by group_policy.lua")
local ReapplyBlizzardRaidFrames = assert(groupFrames.ReapplyRaidFrames, "Roth_UI: groupFrames.ReapplyRaidFrames is required by group_policy.lua")
local SafeGetCVar = assert(groupFrames.SafeGetCVar, "Roth_UI: groupFrames.SafeGetCVar is required by group_policy.lua")
local IsAddOnEnabled = assert(groupFrames.IsAddOnEnabled, "Roth_UI: groupFrames.IsAddOnEnabled is required by group_policy.lua")
local QueueRefresh = assert(groupFrames.QueueRefresh, "Roth_UI: groupFrames.QueueRefresh is required by group_policy.lua")
local CanShowRaidFrame = assert(groupFrames.CanShowRaidFrame, "Roth_UI: groupFrames.CanShowRaidFrame is required by group_policy.lua")
local DeferUntilOutOfCombat = assert(groupFrames.DeferUntilOutOfCombat, "Roth_UI: groupFrames.DeferUntilOutOfCombat is required by group_policy.lua")

function func:HideBlizzardPartyFrames()
  if InCombatLockdown and InCombatLockdown() then
    return
  end
  if ns and ns.Log then
    ns.Log("HideBlizzardPartyFrames")
  end

  SafeLoadAddOn("Blizzard_UnitFrame")
  SafeLoadAddOn("Blizzard_CompactRaidFrames")

  ParkFrame(_G.PartyFrame)
  ParkFrame(_G.CompactPartyFrame)
end

function func:ShowBlizzardPartyFrames()
  if InCombatLockdown and InCombatLockdown() then
    return
  end
  if ns and ns.Log then
    ns.Log("ShowBlizzardPartyFrames")
  end

  SafeLoadAddOn("Blizzard_UnitFrame")
  SafeLoadAddOn("Blizzard_CompactRaidFrames")

  ReapplyBlizzardPartyFrames()

  QueueRefresh("frame_policy_show_party", function()
    local compactPartyFrame = _G.CompactPartyFrame
    local shouldShowCompact = compactPartyFrame and type(compactPartyFrame.ShouldShow) == "function" and compactPartyFrame:ShouldShow() or false

    SafeSetParent(_G.PartyFrame, UIParent)
    SafeSetParent(compactPartyFrame, _G.PartyFrame or UIParent)
    SafeCallMethod(_G.PartyFrame, "Show")
    if shouldShowCompact then
      SafeCallMethod(compactPartyFrame, "Show")
    else
      SafeCallMethod(compactPartyFrame, "Hide")
    end
  end)
end

function func:HideBlizzardRaidFrames()
  if InCombatLockdown and InCombatLockdown() then
    return
  end
  if ns and ns.Log then
    ns.Log("HideBlizzardRaidFrames")
  end

  SafeLoadAddOn("Blizzard_CompactRaidFrames")
  ReapplyBlizzardRaidFrames()

  ParkFrame(_G.CompactRaidFrameContainer)
  ParkFrame(_G.RaidFrame)
  ParkFrame(_G.RaidParentFrame)

  SafeSetParent(_G.CompactRaidFrameManager, UIParent)
  if type(_G.CompactRaidFrameManager_UpdateShown) == "function" then
    _G.CompactRaidFrameManager_UpdateShown()
  end
  SafeCallMethod(_G.CompactRaidFrameManager, "Show")
end

function func:ShowBlizzardRaidFrames()
  if InCombatLockdown and InCombatLockdown() then
    return
  end
  if ns and ns.Log then
    ns.Log("ShowBlizzardRaidFrames")
  end

  SafeLoadAddOn("Blizzard_CompactRaidFrames")
  if type(_G.CompactRaidFrameManager_SetSetting) == "function" then
    _G.CompactRaidFrameManager_SetSetting("IsShown", "1")
  end
  ReapplyBlizzardRaidFrames()

  QueueRefresh("frame_policy_show_raid", function()
    SafeSetParent(_G.CompactRaidFrameManager, UIParent)
    SafeSetParent(_G.CompactRaidFrameContainer, UIParent)
    if CanShowRaidFrame() then
      SafeSetParent(_G.RaidFrame, UIParent)
    end

    SafeCallMethod(_G.CompactRaidFrameManager, "Show")
    SafeCallMethod(_G.CompactRaidFrameContainer, "Show")
    if CanShowRaidFrame() then
      SafeCallMethod(_G.RaidFrame, "Show")
    end
  end)
end

function func:ApplyGroupFramePolicy()
  RebuildPersistenceRuntime()

  local cfg = ns and ns.cfg
  if not (cfg and cfg.units) then
    return
  end

  if DeferUntilOutOfCombat(self, "__groupPolicyPending", "__groupPolicyRegenHook", function(owner)
    func.ApplyGroupFramePolicy(owner)
  end) then
    return
  end

  if ns and ns.Log then
    ns.Log("ApplyGroupFramePolicy party.show=%s raid.show=%s", tostring(cfg.units.party and cfg.units.party.show), tostring(cfg.units.raid and cfg.units.raid.show))
  end

  local useParty = IsRothEnabled(cfg.units.party and cfg.units.party.show)
  local useRaid = IsRothEnabled(cfg.units.raid and cfg.units.raid.show)
  local wantParty = not useParty
  local wantRaid = not useRaid

  if useParty then
    self:HideBlizzardPartyFrames()
  else
    self:ShowBlizzardPartyFrames()
  end

  if useRaid then
    self:HideBlizzardRaidFrames()
  else
    self:ShowBlizzardRaidFrames()
  end

  if (wantParty or wantRaid) and type(self.ForceRestoreBlizzardGroupFrames) == "function" then
    local force = false
    if wantParty and not IsAddOnEnabled("Blizzard_UnitFrame") then
      force = true
    end
    if (wantParty or wantRaid) and not IsAddOnEnabled("Blizzard_CompactRaidFrames") then
      force = true
    end
    local showParty = SafeGetCVar("showPartyFrames")
    if wantParty and (showParty == "0" or showParty == "false") then
      force = true
    end
    local showRaid = SafeGetCVar("showRaidFrames")
    if wantRaid and (showRaid == "0" or showRaid == "false") then
      force = true
    end
    self:ForceRestoreBlizzardGroupFrames(force, wantParty, wantRaid)
  end

  if type(ns.ApplyPartyEnabled) == "function" then
    ns.ApplyPartyEnabled(useParty)
  end
  if type(ns.ApplyRaidEnabled) == "function" then
    ns.ApplyRaidEnabled(useRaid)
  end
end

ns.groupFrameService = ns.groupFrameService or {}
local groupFrameService = ns.groupFrameService

groupFrameService.ApplyPolicy = function()
  if type(func.ApplyGroupFramePolicy) == "function" then
    return func.ApplyGroupFramePolicy(func)
  end
  return false
end

groupFrameService.ForceRestore = function(force, wantParty, wantRaid)
  if type(func.ForceRestoreBlizzardGroupFrames) == "function" then
    return func.ForceRestoreBlizzardGroupFrames(func, force, wantParty, wantRaid)
  end
  return false
end

groupFrameService.PrintStatus = function()
  if type(func.DebugBlizzardGroupFrames) == "function" then
    return func.DebugBlizzardGroupFrames(func)
  end
  return false
end
