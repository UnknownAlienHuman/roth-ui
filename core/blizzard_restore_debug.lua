local addonName, ns = ...

local func = assert(ns and ns.func, "Roth_UI: ns.func is required by blizzard_restore_debug.lua")
local policy = assert(ns and ns.framePolicy, "Roth_UI: framePolicy is required by blizzard_restore_debug.lua")
local groupFrames = assert(policy.groupFrames, "Roth_UI: framePolicy.groupFrames is required by blizzard_restore_debug.lua")

local SafeCall = assert(groupFrames.SafeCall, "Roth_UI: groupFrames.SafeCall is required by blizzard_restore_debug.lua")
local SafeCallMethod = assert(groupFrames.SafeCallMethod, "Roth_UI: groupFrames.SafeCallMethod is required by blizzard_restore_debug.lua")
local SafeSetParent = assert(groupFrames.SafeSetParent, "Roth_UI: groupFrames.SafeSetParent is required by blizzard_restore_debug.lua")
local SafeRegisterEvent = assert(groupFrames.SafeRegisterEvent, "Roth_UI: groupFrames.SafeRegisterEvent is required by blizzard_restore_debug.lua")
local SafeGetCVar = assert(groupFrames.SafeGetCVar, "Roth_UI: groupFrames.SafeGetCVar is required by blizzard_restore_debug.lua")
local SafeSetCVarDefaultOr = assert(groupFrames.SafeSetCVarDefaultOr, "Roth_UI: groupFrames.SafeSetCVarDefaultOr is required by blizzard_restore_debug.lua")
local ForceShow = assert(groupFrames.ForceShow, "Roth_UI: groupFrames.ForceShow is required by blizzard_restore_debug.lua")
local FrameName = assert(groupFrames.FrameName, "Roth_UI: groupFrames.FrameName is required by blizzard_restore_debug.lua")
local IsForbidden = assert(groupFrames.IsForbidden, "Roth_UI: groupFrames.IsForbidden is required by blizzard_restore_debug.lua")
local CanShowRaidFrame = assert(groupFrames.CanShowRaidFrame, "Roth_UI: groupFrames.CanShowRaidFrame is required by blizzard_restore_debug.lua")
local SafeLoadAddOn = assert(groupFrames.SafeLoadAddOn, "Roth_UI: groupFrames.SafeLoadAddOn is required by blizzard_restore_debug.lua")
local SafeEnableAddOn = assert(groupFrames.SafeEnableAddOn, "Roth_UI: groupFrames.SafeEnableAddOn is required by blizzard_restore_debug.lua")
local SafeSaveAddOns = assert(groupFrames.SafeSaveAddOns, "Roth_UI: groupFrames.SafeSaveAddOns is required by blizzard_restore_debug.lua")
local GetAddOnEnableState = assert(groupFrames.GetAddOnEnableState, "Roth_UI: groupFrames.GetAddOnEnableState is required by blizzard_restore_debug.lua")
local ReapplyBlizzardPartyFrames = assert(groupFrames.ReapplyPartyFrames, "Roth_UI: groupFrames.ReapplyPartyFrames is required by blizzard_restore_debug.lua")
local ReapplyBlizzardRaidFrames = assert(groupFrames.ReapplyRaidFrames, "Roth_UI: groupFrames.ReapplyRaidFrames is required by blizzard_restore_debug.lua")
local QueueRefresh = assert(groupFrames.QueueRefresh, "Roth_UI: groupFrames.QueueRefresh is required by blizzard_restore_debug.lua")
local GetPlayerCharacterName = assert(groupFrames.GetPlayerCharacterName, "Roth_UI: groupFrames.GetPlayerCharacterName is required by blizzard_restore_debug.lua")
local DeferUntilOutOfCombat = assert(groupFrames.DeferUntilOutOfCombat, "Roth_UI: groupFrames.DeferUntilOutOfCombat is required by blizzard_restore_debug.lua")

function func:ForceRestoreBlizzardGroupFrames(forceCVars, wantParty, wantRaid)
  if wantParty == nil then wantParty = true end
  if wantRaid == nil then wantRaid = true end

  self.__blizzRestoreForceCVars = forceCVars and true or false
  self.__blizzRestoreWantParty = wantParty
  self.__blizzRestoreWantRaid = wantRaid
  if DeferUntilOutOfCombat(self, "__blizzRestorePending", "__blizzRestoreRegenHook", function(owner)
    local force = owner.__blizzRestoreForceCVars
    local restoreParty = owner.__blizzRestoreWantParty
    local restoreRaid = owner.__blizzRestoreWantRaid
    owner.__blizzRestoreForceCVars = nil
    owner.__blizzRestoreWantParty = nil
    owner.__blizzRestoreWantRaid = nil
    func.ForceRestoreBlizzardGroupFrames(owner, force, restoreParty, restoreRaid)
  end) then
    return
  end

  if ns and ns.Log then
    ns.Log("ForceRestoreBlizzardGroupFrames")
  end

  local needCompact = wantParty or wantRaid
  if wantParty then SafeEnableAddOn("Blizzard_UnitFrame") end
  if needCompact then SafeEnableAddOn("Blizzard_CompactRaidFrames") end
  SafeSaveAddOns()
  if wantParty then SafeLoadAddOn("Blizzard_UnitFrame") end
  if needCompact then SafeLoadAddOn("Blizzard_CompactRaidFrames") end

  if forceCVars then
    if wantParty then
      SafeSetCVarDefaultOr("useCompactPartyFrames", "1")
      SafeSetCVarDefaultOr("showPartyFrames", "1")
    end
    if wantRaid then
      SafeSetCVarDefaultOr("useCompactRaidFrames", "1")
      SafeSetCVarDefaultOr("showRaidFrames", "1")
      SafeSetCVarDefaultOr("raidOptionIsShown", "1")
      SafeSetCVarDefaultOr("raidFramesDisplay", "1")
    end
  end

  if needCompact then
    SafeRegisterEvent(UIParent, "GROUP_ROSTER_UPDATE")
  end

  if wantRaid then
    SafeCall(_G.CompactRaidFrameManager_RegisterEvents)
    if type(_G.CompactRaidFrameManager_SetSetting) == "function" then
      _G.CompactRaidFrameManager_SetSetting("IsShown", "1")
    end
    ReapplyBlizzardRaidFrames()
  end

  QueueRefresh("frame_policy_force_restore", function()
    if wantParty then
      ReapplyBlizzardPartyFrames()
      local compactPartyFrame = _G.CompactPartyFrame
      local shouldShowCompact = compactPartyFrame and type(compactPartyFrame.ShouldShow) == "function" and compactPartyFrame:ShouldShow() or false

      SafeSetParent(_G.PartyFrame, UIParent)
      ForceShow(_G.PartyFrame)
      SafeSetParent(compactPartyFrame, _G.PartyFrame or UIParent)
      if shouldShowCompact then
        ForceShow(compactPartyFrame)
      else
        SafeCallMethod(compactPartyFrame, "Hide")
      end

      local partyParent = _G.PartyFrame and _G.PartyFrame.GetParent and _G.PartyFrame:GetParent() or nil
      if partyParent and not IsForbidden(partyParent) then
        SafeSetParent(partyParent, UIParent)
        ForceShow(partyParent)
      end
    end

    if wantRaid then
      ReapplyBlizzardRaidFrames()
      SafeSetParent(_G.CompactRaidFrameManager, UIParent)
      SafeSetParent(_G.CompactRaidFrameContainer, UIParent)
      ForceShow(_G.CompactRaidFrameManager)
      ForceShow(_G.CompactRaidFrameContainer)
      if CanShowRaidFrame() then
        SafeSetParent(_G.RaidFrame, UIParent)
        ForceShow(_G.RaidFrame)
      end
      if _G.RaidParentFrame and CanShowRaidFrame() then
        SafeSetParent(_G.RaidParentFrame, UIParent)
        ForceShow(_G.RaidParentFrame)
      end
    end

    if (wantParty or wantRaid) and type(_G.UIParent_ManageFramePositions) == "function" then
      _G.UIParent_ManageFramePositions()
    end
  end)
end

function func:DebugBlizzardGroupFrames()
  local function DumpFrame(label, frame)
    if not frame then
      print(("Roth_UI: %s = nil"):format(label))
      return
    end
    if IsForbidden(frame) then
      print(("Roth_UI: %s = forbidden"):format(label))
      return
    end

    local shown = (frame.IsShown and frame:IsShown()) or false
    local visible = (frame.IsVisible and frame:IsVisible()) or false
    local alpha = (frame.GetAlpha and frame:GetAlpha()) or 0
    local scale = (frame.GetScale and frame:GetScale()) or 0
    local parent = (frame.GetParent and frame:GetParent()) or nil
    local parentName = FrameName(parent)
    local parentShown = (parent and parent.IsShown and parent:IsShown()) or false
    local parentVisible = (parent and parent.IsVisible and parent:IsVisible()) or false
    local parent2 = (parent and parent.GetParent and parent:GetParent()) or nil
    local parentName2 = FrameName(parent2)
    local parent2Shown = (parent2 and parent2.IsShown and parent2:IsShown()) or false
    local parent2Visible = (parent2 and parent2.IsVisible and parent2:IsVisible()) or false
    local showIsHide = (frame.Show and frame.Hide and frame.Show == frame.Hide) and "true" or "false"

    print(("Roth_UI: %s shown=%s visible=%s alpha=%.2f scale=%.2f parent=%s showIsHide=%s"):format(
      label, tostring(shown), tostring(visible), tonumber(alpha) or 0, tonumber(scale) or 0, parentName, showIsHide))
    if parent then
      print(("Roth_UI: %s parent shown=%s visible=%s parent2=%s p2shown=%s p2vis=%s"):format(
        label, tostring(parentShown), tostring(parentVisible), tostring(parentName2), tostring(parent2Shown), tostring(parent2Visible)))
    end
  end

  print("Roth_UI: Blizzard group frame status")
  print(("Roth_UI: useCompactPartyFrames=%s useCompactRaidFrames=%s raidFramesDisplay=%s showPartyFrames=%s showRaidFrames=%s raidOptionIsShown=%s"):format(
    tostring(SafeGetCVar("useCompactPartyFrames")),
    tostring(SafeGetCVar("useCompactRaidFrames")),
    tostring(SafeGetCVar("raidFramesDisplay")),
    tostring(SafeGetCVar("showPartyFrames")),
    tostring(SafeGetCVar("showRaidFrames")),
    tostring(SafeGetCVar("raidOptionIsShown"))))

  do
    local partyState = GetAddOnEnableState("Blizzard_UnitFrame", nil)
    local raidState = GetAddOnEnableState("Blizzard_CompactRaidFrames", nil)
    local playerName = GetPlayerCharacterName()
    local partyStateChar = playerName and GetAddOnEnableState("Blizzard_UnitFrame", playerName) or nil
    local raidStateChar = playerName and GetAddOnEnableState("Blizzard_CompactRaidFrames", playerName) or nil
    print(("Roth_UI: Blizzard_UnitFrame enableState=%s char=%s loaded=%s"):format(
      tostring(partyState), tostring(partyStateChar), tostring(ns.IsAddOnLoadedCompat("Blizzard_UnitFrame"))))
    print(("Roth_UI: Blizzard_CompactRaidFrames enableState=%s char=%s loaded=%s"):format(
      tostring(raidState), tostring(raidStateChar), tostring(ns.IsAddOnLoadedCompat("Blizzard_CompactRaidFrames"))))
  end

  if type(_G.CompactRaidFrameManager_GetSetting) == "function" then
    local isShown = _G.CompactRaidFrameManager_GetSetting("IsShown")
    print(("Roth_UI: CompactRaidFrameManager IsShown=%s"):format(tostring(isShown)))
  end

  DumpFrame("PartyFrame", _G.PartyFrame)
  DumpFrame("CompactPartyFrame", _G.CompactPartyFrame)
  DumpFrame("CompactRaidFrameManager", _G.CompactRaidFrameManager)
  DumpFrame("CompactRaidFrameContainer", _G.CompactRaidFrameContainer)
  DumpFrame("RaidFrame", _G.RaidFrame)
  DumpFrame("RaidParentFrame", _G.RaidParentFrame)
end

function func:ShowBlizzardGroupFrames()
  if InCombatLockdown and InCombatLockdown() then
    return
  end

  SafeLoadAddOn("Blizzard_UnitFrame")
  SafeLoadAddOn("Blizzard_CompactRaidFrames")
  ReapplyBlizzardPartyFrames()
  if type(_G.CompactRaidFrameManager_SetSetting) == "function" then
    _G.CompactRaidFrameManager_SetSetting("IsShown", "1")
  end
  ReapplyBlizzardRaidFrames()

  QueueRefresh("frame_policy_show_blizz_groups", function()
    local compactPartyFrame = _G.CompactPartyFrame
    local shouldShowCompact = compactPartyFrame and type(compactPartyFrame.ShouldShow) == "function" and compactPartyFrame:ShouldShow() or false

    SafeSetParent(_G.PartyFrame, UIParent)
    SafeSetParent(compactPartyFrame, _G.PartyFrame or UIParent)
    SafeSetParent(_G.CompactRaidFrameManager, UIParent)
    SafeSetParent(_G.CompactRaidFrameContainer, UIParent)
    if CanShowRaidFrame() then
      SafeSetParent(_G.RaidFrame, UIParent)
    end
    SafeCallMethod(_G.CompactRaidFrameManager, "Show")
    SafeCallMethod(_G.CompactRaidFrameContainer, "Show")
    SafeCallMethod(_G.PartyFrame, "Show")
    if shouldShowCompact then
      SafeCallMethod(compactPartyFrame, "Show")
    else
      SafeCallMethod(compactPartyFrame, "Hide")
    end
    if CanShowRaidFrame() then
      SafeCallMethod(_G.RaidFrame, "Show")
    end
  end)
end
