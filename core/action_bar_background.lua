-----------------------------
-- Main action bar background + skin owner
-----------------------------

local addon, ns = ...
local gcfg = ns.cfg
if not (gcfg and gcfg.bars and gcfg.units and gcfg.units.player) then return end

local func = ns.func
local mediapath = ns.mediapath or "Interface\\AddOns\\Roth_UI\\media\\"
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local C_ActionBar = _G["C_ActionBar"]
local NUM_ACTIONBAR_BUTTONS = _G["NUM_ACTIONBAR_BUTTONS"] or 12
local frameRegistry = assert(ns and ns.frameRegistry, "Roth_UI action_bar_background: ns.frameRegistry is required")
local CanAccessValue = (ns.safety and ns.safety.CanAccess) or func.CanAccessValue or function(value)
  return not func.IsSecretValue(value)
end
local ResolveRegisteredFrame = assert(frameRegistry.ResolveFrame, "Roth_UI action_bar_background: frameRegistry.ResolveFrame is required")
local safety = assert(ns and ns.safety, "Roth_UI action_bar_background: safety is required")
local CanUseRegion = assert(safety.CanUseRegion, "Roth_UI action_bar_background: CanUseRegion is required")
local TryGet = assert(safety.TryGet, "Roth_UI action_bar_background: TryGet is required")
local TryMethod = assert(safety.TryMethod, "Roth_UI action_bar_background: TryMethod is required")
local MAIN_BAR_SYSTEM_INDEX = type(Enum) == "table"
  and type(Enum.EditModeActionBarSystemIndices) == "table"
  and Enum.EditModeActionBarSystemIndices.MainBar
  or nil

local backgroundFrame
local backgroundConfig
local backgroundPlayerFrame
local backgroundLayoutReady = false
local mainBarHooksInstalled = false
local auxiliaryHooks = setmetatable({}, { __mode = "k" })
local refreshQueued = false
local controller = CreateFrame("Frame")

local function IsAccessible(value)
  return CanAccessValue(value)
end

local function ReadOrdinaryBoolean(fn)
  if type(fn) ~= "function" then return false end
  local value = fn()
  return IsAccessible(value) and value == true
end

local function HasVehicleActionBarCompat()
  return C_ActionBar and ReadOrdinaryBoolean(C_ActionBar.HasVehicleActionBar) or false
end

local function HasOverrideActionBarCompat()
  return C_ActionBar and ReadOrdinaryBoolean(C_ActionBar.HasOverrideActionBar) or false
end

local function HasPlayerVehicleUI()
  if type(UnitHasVehicleUI) ~= "function" then return false end
  local value = UnitHasVehicleUI("player")
  return IsAccessible(value) and value == true
end

local function ResolvePlayerFrame()
  return (ns.unit and ns.unit.player) or ResolveRegisteredFrame(frameRegistry, "orbs", "Roth_UIPlayerFrame")
end

local function ResolvePlayerConfig(playerFrame)
  local cfg = playerFrame and playerFrame.cfg
  if type(cfg) == "table" then
    return cfg
  end
  return gcfg.units.player
end

local function ResolveMainBar()
  return _G.MainActionBar
end

local AUXILIARY_BARS = {
  "MultiBarBottomLeft",
  "MultiBarBottomRight",
  "MultiBarRight",
  "MultiBarLeft",
  "MultiBar5",
  "MultiBar6",
  "MultiBar7",
}

local function GetArtworkTier()
  local visible = 0
  for i = 1, #AUXILIARY_BARS do
    local frame = _G[AUXILIARY_BARS[i]]
    if CanUseRegion(frame) then
      local ok, shown = TryMethod(frame, "IsShown")
      if ok == true and IsAccessible(shown) and shown == true then
        visible = visible + 1
      end
    end
  end
  if visible >= 2 then return 3 end
  if visible == 1 then return 2 end
  return 1
end

local RefreshArtwork

local function RunQueuedRefresh()
  refreshQueued = false
  if RefreshArtwork then RefreshArtwork() end
end

local function QueueArtworkRefresh()
  if refreshQueued then return end
  refreshQueued = true

  local scheduler = ns and ns.defer
  if type(scheduler) == "table" and type(scheduler.RunNextFrame) == "function" then
    scheduler.RunNextFrame("action-bar-background", RunQueuedRefresh, false)
  elseif C_Timer and type(C_Timer.After) == "function" then
    C_Timer.After(0, RunQueuedRefresh)
  else
    RunQueuedRefresh()
  end
end

local function InstallAuxiliaryBarHooks()
  if type(hooksecurefunc) ~= "function" then return end
  for index = 1, #AUXILIARY_BARS do
    local frame = _G[AUXILIARY_BARS[index]]
    if CanUseRegion(frame) and not auxiliaryHooks[frame] then
      local gotShow, showMethod = TryGet(frame, "Show")
      local gotHide, hideMethod = TryGet(frame, "Hide")
      if gotShow == true and type(showMethod) == "function"
          and gotHide == true and type(hideMethod) == "function" then
        hooksecurefunc(frame, "Show", QueueArtworkRefresh)
        hooksecurefunc(frame, "Hide", QueueArtworkRefresh)
        auxiliaryHooks[frame] = true
      end
    end
  end
end

local function IsMainActionBarSystem(system)
  if not system then
    return false
  end

  local mainBar = ResolveMainBar()
  if system == mainBar then
    return true
  end

  local gotName, frameName = TryMethod(system, "GetName")
  if gotName == true and IsAccessible(frameName) and frameName == "MainActionBar" then
    return true
  end

  local gotIndex, systemIndex = TryGet(system, "systemIndex")
  if gotIndex == true and MAIN_BAR_SYSTEM_INDEX and IsAccessible(systemIndex)
      and systemIndex == MAIN_BAR_SYSTEM_INDEX then
    return true
  end

  return false
end

local function HideRegion(region)
  -- Keep Blizzard ownership and visibility state intact. Alpha-only suppression
  -- is sufficient for decorative regions and avoids fighting protected layout
  -- or grid visibility setters.
  if CanUseRegion(region) then TryMethod(region, "SetAlpha", 0) end
end

local function HideActionButtonBarArt(button)
  if not button then
    return
  end

  if not CanUseRegion(button) then return end
  local _, buttonName = TryMethod(button, "GetName")
  local _, slotArt = TryGet(button, "SlotArt")
  local _, slotBackground = TryGet(button, "SlotBackground")
  HideRegion(slotArt or (IsAccessible(buttonName) and buttonName and _G[buttonName .. "SlotArt"]) or nil)
  HideRegion(slotBackground or (IsAccessible(buttonName) and buttonName and _G[buttonName .. "SlotBackground"]) or nil)
  HideRegion(IsAccessible(buttonName) and buttonName and _G[buttonName .. "FloatingBG"] or nil)
end

local function ApplyMainBarVisualState()
  if InCombatLockdown and InCombatLockdown() then
    return
  end
  local mainBar = ResolveMainBar()
  if not CanUseRegion(mainBar) then return end

  local _, borderArt = TryGet(mainBar, "BorderArt")
  HideRegion(borderArt)

  local _, endCaps = TryGet(mainBar, "EndCaps")
  if CanUseRegion(endCaps) then
    local _, leftEndCap = TryGet(endCaps, "LeftEndCap")
    local _, rightEndCap = TryGet(endCaps, "RightEndCap")
    HideRegion(leftEndCap)
    HideRegion(rightEndCap)
  end

  for i = 1, NUM_ACTIONBAR_BUTTONS do
    HideActionButtonBarArt(_G["ActionButton" .. i])
  end

end

local function ResolveArtworkConfig()
  local playerFrame = ResolvePlayerFrame()
  local playerCfg = ResolvePlayerConfig(playerFrame)
  local artCfg = playerCfg and playerCfg.art and playerCfg.art.actionbarbackground
  if type(artCfg) ~= "table" then
    return nil
  end
  return artCfg, playerFrame
end

local function ApplyArtworkVisibility(frame)
  local artCfg = backgroundConfig
  if not frame or type(artCfg) ~= "table" or not backgroundLayoutReady then
    if frame then frame:Hide() end
    return
  end

  if artCfg.show == false then
    frame:Hide()
    return
  end

  if artCfg.combatfade and InCombatLockdown and InCombatLockdown() then
    frame:Hide()
    return
  end

  frame:Show()
end

local function ApplyArtworkLayout(frame, artCfg, playerFrame)
  if not (frame and artCfg) then return false end
  if InCombatLockdown and InCombatLockdown() then return false end

  -- The artwork remains a UIParent child. It may anchor to another frame, but
  -- never reparents into a protected unit/action frame.
  local pos = type(artCfg.pos) == "table" and artCfg.pos or {}
  local point = type(pos.a1) == "string" and pos.a1 or "BOTTOM"
  local relativePoint = type(pos.a2) == "string" and pos.a2 or point
  local relativeTo = (type(pos.af) == "string" and _G[pos.af]) or pos.af or UIParent
  if not CanUseRegion(relativeTo) then relativeTo = UIParent end
  local x = IsAccessible(pos.x) and tonumber(pos.x) or 0
  local y = IsAccessible(pos.y) and tonumber(pos.y) or 0
  local scale = IsAccessible(artCfg.scale) and tonumber(artCfg.scale) or 1
  if type(scale) ~= "number" or scale <= 0 then scale = 1 end

  frame:SetFrameStrata("LOW")
  frame:SetFrameLevel(0)
  frame:SetSize(788, 220)
  frame:ClearAllPoints()
  frame:SetPoint(point, relativeTo, relativePoint, x, y)
  frame:SetScale(scale)
  backgroundConfig = artCfg
  backgroundPlayerFrame = playerFrame
  backgroundLayoutReady = true
  ns.ActionBarBackground = frame

  if playerFrame then
    playerFrame.ActionBarBackground = frame
  end
  return true
end

local function EnsureArtworkFrame()
  local artCfg, playerFrame = ResolveArtworkConfig()
  backgroundConfig = artCfg
  backgroundPlayerFrame = playerFrame

  if type(artCfg) ~= "table" or artCfg.show == false then
    if backgroundFrame then backgroundFrame:Hide() end
    return nil
  end

  if InCombatLockdown and InCombatLockdown() then
    if backgroundFrame then ApplyArtworkVisibility(backgroundFrame) end
    return backgroundFrame
  end

  if not backgroundFrame then
    backgroundFrame = CreateFrame("Frame", "Roth_UIActionBarBackground", UIParent)
    backgroundFrame.texture = backgroundFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    backgroundFrame.texture:SetAllPoints(backgroundFrame)

    if func and type(func.applyDragFunctionality) == "function" then
      func.applyDragFunctionality(backgroundFrame)
    end
    backgroundFrame.RefreshActionBarArtwork = function() ns.RefreshActionBarArtwork() end
  end

  ApplyArtworkLayout(backgroundFrame, artCfg, playerFrame)
  return backgroundFrame
end

local function ResolveBarDimension(value, fallback)
  if not IsAccessible(value) then return fallback end
  local number = tonumber(value)
  if type(number) ~= "number" or number <= 0 then return fallback end
  return number
end

local function ResolveExpRepHeight(primaryCfg, secondaryCfg, primaryDefaults, secondaryDefaults)
  local h = ResolveBarDimension(primaryCfg and primaryCfg.height, nil)
  if h then return h end
  h = ResolveBarDimension(secondaryCfg and secondaryCfg.height, nil)
  if h then return h end
  h = ResolveBarDimension(primaryDefaults and primaryDefaults.height, nil)
  if h then return h end
  h = ResolveBarDimension(secondaryDefaults and secondaryDefaults.height, nil)
  if h then return h end
  return 1
end

RefreshArtwork = function()
  if InCombatLockdown and InCombatLockdown() then
    ApplyArtworkVisibility(backgroundFrame)
    return
  end

  InstallAuxiliaryBarHooks()
  ApplyMainBarVisualState()

  local frame = EnsureArtworkFrame()
  if not frame then
    return
  end

  local artCfg = backgroundConfig
  local playerFrame = backgroundPlayerFrame or ResolvePlayerFrame()
  local playerCfg = ResolvePlayerConfig(playerFrame)
  local texture = frame.texture
  if not (artCfg and texture and playerCfg) then
    return
  end

  local expCfg = type(playerCfg.expbar) == "table" and playerCfg.expbar or {}
  local repCfg = type(playerCfg.repbar) == "table" and playerCfg.repbar or {}
  local playerDefaults = (ns and ns.cfgDefaults and ns.cfgDefaults.units and ns.cfgDefaults.units.player) or {}
  local defaultExpCfg = playerDefaults.expbar or {}
  local defaultRepCfg = playerDefaults.repbar or {}
  local artScale = ResolveBarDimension(artCfg.scale, 1)
  local expDefaultW = ResolveBarDimension(expCfg.width, 365)
  local expDefaultH = ResolveExpRepHeight(expCfg, repCfg, defaultExpCfg, defaultRepCfg)
  local repDefaultW = ResolveBarDimension(repCfg.width, 365)
  local repDefaultH = ResolveExpRepHeight(repCfg, expCfg, defaultRepCfg, defaultExpCfg)

  local artworkTier = GetArtworkTier()
  local bar = tostring(artworkTier)
  if HasVehicleActionBarCompat() or HasOverrideActionBarCompat() or HasPlayerVehicleUI() then
    bar = "vehicle"
  end

  local expBar = playerFrame and playerFrame.Experience or ResolveRegisteredFrame(frameRegistry, "bars", "Roth_UIExpBar")
  local repBar = playerFrame and playerFrame.Reputation or ResolveRegisteredFrame(frameRegistry, "bars", "Roth_UIRepBar")
  local showXP = expBar and expBar.__rothActive == true
  local showRep = repBar and repBar.__rothActive == true
  local barCount = (showXP and 1 or 0) + (showRep and 1 or 0)

  local function PlaceBarFrame(targetFrame, shouldShow, y, w, h)
    if not targetFrame then
      return
    end

    if shouldShow then
      targetFrame:ClearAllPoints()
      targetFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, y * artScale)
      targetFrame:SetSize(w * artScale, h * artScale)
      targetFrame:Show()
    else
      targetFrame:Hide()
    end
  end

  local function HideExpRepBars()
    PlaceBarFrame(expBar, false, 0, expDefaultW, expDefaultH)
    PlaceBarFrame(repBar, false, 0, repDefaultW, repDefaultH)
  end

  local function PlaceExpRepBars(expY, expW, repY, repW)
    local resolvedExpW = ResolveBarDimension(expW, expDefaultW)
    local resolvedRepW = ResolveBarDimension(repW, repDefaultW)

    PlaceBarFrame(expBar, showXP, expY, resolvedExpW, expDefaultH)

    if showRep then
      if showXP then
        PlaceBarFrame(repBar, true, repY, resolvedRepW, repDefaultH)
      else
        PlaceBarFrame(repBar, true, expY, resolvedExpW, repDefaultH)
      end
    else
      PlaceBarFrame(repBar, false, repY, resolvedRepW, repDefaultH)
    end
  end

  if bar == "vehicle" then
    texture:SetTexture(mediapath .. "vehiclebar")
    HideExpRepBars()
  elseif bar == "3" and barCount == 2 then
    texture:SetTexture(mediapath .. "actionbar_3_2")
    PlaceExpRepBars(121, 367, 131, 367)
  elseif bar == "3" and barCount == 1 then
    texture:SetTexture(mediapath .. "actionbar_3_1")
    PlaceExpRepBars(121, 367, 131, 367)
  elseif bar == "3" then
    texture:SetTexture(mediapath .. "actionbar_3_0")
    HideExpRepBars()
  elseif bar == "2" and barCount == 2 then
    texture:SetTexture(mediapath .. "actionbar_2_2")
    PlaceExpRepBars(101, 389, 111, 400)
  elseif bar == "2" and barCount == 1 then
    texture:SetTexture(mediapath .. "actionbar_2_1")
    PlaceExpRepBars(101, 389, 111, 400)
  elseif bar == "2" then
    texture:SetTexture(mediapath .. "actionbar_2_0")
    HideExpRepBars()
  elseif bar == "1" and barCount == 2 then
    texture:SetTexture(mediapath .. "actionbar_1_2")
    PlaceExpRepBars(101, 389, 111, 400)
  elseif bar == "1" and barCount == 1 then
    texture:SetTexture(mediapath .. "actionbar_1_1")
    PlaceExpRepBars(101, 389, 111, 400)
  else
    texture:SetTexture(mediapath .. "actionbar_1_0")
    HideExpRepBars()
  end

  ApplyArtworkVisibility(frame)
end

function ns.RefreshActionBarArtwork()
  RefreshArtwork()
end

local function InstallMainBarHooks()
  if mainBarHooksInstalled then
    return
  end

  mainBarHooksInstalled = true

  local mainActionBarMixin = _G["MainActionBarMixin"]
  if type(mainActionBarMixin) == "table" and type(mainActionBarMixin.UpdateEndCaps) == "function" then
    hooksecurefunc(mainActionBarMixin, "UpdateEndCaps", function(self)
      if IsMainActionBarSystem(self) then
        ApplyMainBarVisualState()
      end
    end)
  end

  local editModeActionBarSystemMixin = _G["EditModeActionBarSystemMixin"]
  if type(editModeActionBarSystemMixin) == "table" and type(editModeActionBarSystemMixin.RefreshBarArt) == "function" then
    -- Any action-bar layout refresh can change the number of visible rows.
    -- Coalesce all systems into one next-frame artwork refresh.
    hooksecurefunc(editModeActionBarSystemMixin, "RefreshBarArt", QueueArtworkRefresh)
  end
end

controller:RegisterEvent("PLAYER_REGEN_DISABLED")
controller:RegisterEvent("PLAYER_REGEN_ENABLED")
controller:RegisterEvent("PLAYER_ENTERING_WORLD")
controller:RegisterEvent("UNIT_ENTERED_VEHICLE")
controller:RegisterEvent("UNIT_EXITED_VEHICLE")
controller:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
controller:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
controller:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_REGEN_DISABLED" then
    ApplyArtworkVisibility(backgroundFrame)
    return
  end
  if unit ~= nil and (not IsAccessible(unit) or unit ~= "player") then return end
  RefreshArtwork()
end)

InstallMainBarHooks()
RefreshArtwork()
