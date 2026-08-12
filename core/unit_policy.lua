local addonName, ns = ...

local func = assert(ns and ns.func, "Roth_UI: ns.func is required by unit_policy.lua")
local policy = assert(ns and ns.framePolicy, "Roth_UI: framePolicy is required by unit_policy.lua")
local persistence = assert(ns and ns.persistence, "Roth_UI: persistence service is required by unit_policy.lua")
local RebuildPersistenceRuntime = assert(persistence.RebuildRuntime, "Roth_UI: persistence.RebuildRuntime is required by unit_policy.lua")

local IsRothEnabled = assert(ns.IsRothEnabled or policy.IsRothEnabled, "Roth_UI: IsRothEnabled is required by unit_policy.lua")
local IsForbidden = assert(policy.IsForbidden, "Roth_UI: framePolicy.IsForbidden is required by unit_policy.lua")
local SafeLoadAddOn = assert(policy.SafeLoadAddOn, "Roth_UI: SafeLoadAddOn is required by unit_policy.lua")
local SafeCallMethod = assert(policy.SafeCallMethod, "Roth_UI: SafeCallMethod is required by unit_policy.lua")
local ApplyBlizzUnitFrameState = assert(policy.ApplyBlizzUnitFrameState, "Roth_UI: ApplyBlizzUnitFrameState is required by unit_policy.lua")
local DeferUntilOutOfCombat = assert(policy.DeferUntilOutOfCombat, "Roth_UI: DeferUntilOutOfCombat is required by unit_policy.lua")

local playerCastbarHooksInstalled = false
local playerCastbarPolicyHideDefault = false
local playerRuneShowHookInstalled = false
local playerRuneUpdateArtHookInstalled = false
local playerRunePolicyHideDefault = false

local function EnforcePlayerCastbarVisualPolicy(castbar)
  if not castbar or IsForbidden(castbar) then
    return
  end

  if playerCastbarPolicyHideDefault and not castbar.isInEditMode then
    SafeCallMethod(castbar, "Hide")
  end
end

local function EnsurePlayerCastbarHooks(castbar)
  if playerCastbarHooksInstalled or not castbar or IsForbidden(castbar) then
    return
  end
  playerCastbarHooksInstalled = true

  hooksecurefunc(castbar, "UpdateShownState", function(self)
    EnforcePlayerCastbarVisualPolicy(self)
  end)
end

local function ApplyPlayerCastbarPolicy(cfg, usePlayer)
  local playerCfg = cfg and cfg.units and cfg.units.player or nil
  local castbarCfg = playerCfg and playerCfg.castbar or nil
  local hideDefaultCastbar = usePlayer and type(castbarCfg) == "table" and castbarCfg.hideDefault == true
  local castbar = _G.PlayerCastingBarFrame or _G.CastingBarFrame

  if not castbar or IsForbidden(castbar) then
    return
  end

  local wasHiddenByPolicy = playerCastbarPolicyHideDefault == true
  playerCastbarPolicyHideDefault = hideDefaultCastbar and true or false
  EnsurePlayerCastbarHooks(castbar)
  if playerCastbarPolicyHideDefault then
    EnforcePlayerCastbarVisualPolicy(castbar)
    return
  end

  if wasHiddenByPolicy and type(castbar.UpdateIsShown) == "function" then
    castbar:UpdateIsShown()
  end
end

local function EnforcePlayerRuneVisualPolicy(runeFrame)
  if not runeFrame or IsForbidden(runeFrame) then
    return
  end

  if playerRunePolicyHideDefault then
    SafeCallMethod(runeFrame, "Hide")
  end
end

local function EnsurePlayerRuneHooks(runeFrame)
  if runeFrame and not IsForbidden(runeFrame) and not playerRuneShowHookInstalled then
    playerRuneShowHookInstalled = true
    hooksecurefunc(runeFrame, "Show", function(self)
      EnforcePlayerRuneVisualPolicy(self)
    end)
  end

  if not playerRuneUpdateArtHookInstalled and type(_G.PlayerFrame_UpdateArt) == "function" then
    playerRuneUpdateArtHookInstalled = true
    hooksecurefunc(_G, "PlayerFrame_UpdateArt", function(self)
      if self == _G.PlayerFrame or self == nil then
        EnforcePlayerRuneVisualPolicy(_G.RuneFrame)
      end
    end)
  end
end

local function RefreshPlayerRuneFrameState(runeFrame)
  if not runeFrame or IsForbidden(runeFrame) then
    return
  end

  local playerFrame = _G.PlayerFrame
  if type(_G.PlayerFrame_UpdateArt) == "function" and playerFrame then
    _G.PlayerFrame_UpdateArt(playerFrame)
    return
  end

  if playerFrame and playerFrame.state == "vehicle" and type(_G.PlayerFrame_ToVehicleArt) == "function" then
    _G.PlayerFrame_ToVehicleArt(playerFrame)
    return
  end

  if playerFrame and type(_G.PlayerFrame_ToPlayerArt) == "function" then
    _G.PlayerFrame_ToPlayerArt(playerFrame)
    return
  end

  SafeCallMethod(runeFrame, "Show")
end

local function ApplyPlayerRunePolicy(usePlayer)
  local runeFrame = _G.RuneFrame
  local hideDefaultRunes = usePlayer and runeFrame ~= nil
  local wasHiddenByPolicy = playerRunePolicyHideDefault == true

  playerRunePolicyHideDefault = hideDefaultRunes and true or false
  EnsurePlayerRuneHooks(runeFrame)
  if playerRunePolicyHideDefault then
    EnforcePlayerRuneVisualPolicy(runeFrame)
    return
  end

  if wasHiddenByPolicy then
    RefreshPlayerRuneFrameState(runeFrame)
  end
end

function func:ApplyUnitFramePolicy()
  RebuildPersistenceRuntime()

  local cfg = ns and ns.cfg
  if not (cfg and cfg.units) then
    return
  end

  if DeferUntilOutOfCombat(self, "__unitPolicyPending", "__unitPolicyRegenHook", function(owner)
    func.ApplyUnitFramePolicy(owner)
  end) then
    return
  end

  local usePlayer = IsRothEnabled(cfg.units.player and cfg.units.player.show)
  local useTarget = IsRothEnabled(cfg.units.target and cfg.units.target.show)
  local useFocus = IsRothEnabled(cfg.units.focus and cfg.units.focus.show)
  local needBlizzard = (not usePlayer) or (not useTarget) or (not useFocus)

  if needBlizzard and not ns.IsAddOnLoadedCompat("Blizzard_UnitFrame") then
    SafeLoadAddOn("Blizzard_UnitFrame")
  end

  ApplyBlizzUnitFrameState(_G.PlayerFrame, usePlayer)
  ApplyBlizzUnitFrameState(_G.TargetFrame, useTarget)
  ApplyBlizzUnitFrameState(_G.FocusFrame, useFocus)
  ApplyPlayerCastbarPolicy(cfg, usePlayer)
  ApplyPlayerRunePolicy(usePlayer)

  if ns and ns.unit then
    if usePlayer then SafeCallMethod(ns.unit.player, "Show") else SafeCallMethod(ns.unit.player, "Hide") end
    if useTarget then SafeCallMethod(ns.unit.target, "Show") else SafeCallMethod(ns.unit.target, "Hide") end
    if useFocus then SafeCallMethod(ns.unit.focus, "Show") else SafeCallMethod(ns.unit.focus, "Hide") end
  end

  if type(_G.UIParent_ManageFramePositions) == "function" then
    _G.UIParent_ManageFramePositions()
  end
end
