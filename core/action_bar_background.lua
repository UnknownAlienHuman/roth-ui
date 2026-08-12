-----------------------------
-- Main action bar background + skin owner
-----------------------------

local addon, ns = ...
local gcfg = ns.cfg
if not (gcfg and gcfg.bars and gcfg.bars.bar1 and gcfg.units and gcfg.units.player) then return end

local func = ns.func
local mediapath = ns.mediapath or "Interface\\AddOns\\Roth_UI\\media\\"
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local IsAddOnLoaded = ns.IsAddOnLoadedCompat or (C_AddOns and C_AddOns.IsAddOnLoaded)
local C_ActionBar = _G["C_ActionBar"]
local NUM_ACTIONBAR_BUTTONS = _G["NUM_ACTIONBAR_BUTTONS"] or 12
local barRuntimeRegistry = assert(ns and ns.BarRuntimeRegistry, "Roth_UI_rActionBarStyler.background: ns.BarRuntimeRegistry is required")
local GetArtworkTier = assert(barRuntimeRegistry.GetArtworkTier, "Roth_UI_rActionBarStyler.background: GetArtworkTier is required")
local RegisterBarRuntimeListener = assert(barRuntimeRegistry.RegisterListener, "Roth_UI_rActionBarStyler.background: RegisterListener is required")
local frameRegistry = assert(ns and ns.frameRegistry, "Roth_UI_rActionBarStyler.background: ns.frameRegistry is required")
local ResolveRegisteredFrame = assert(frameRegistry.ResolveFrame, "Roth_UI_rActionBarStyler.background: frameRegistry.ResolveFrame is required")
local MAIN_BAR_SYSTEM_INDEX = type(Enum) == "table"
  and type(Enum.EditModeActionBarSystemIndices) == "table"
  and Enum.EditModeActionBarSystemIndices.MainBar
  or nil

local backgroundFrame
local mainBarHooksInstalled = false

local function HasVehicleActionBarCompat()
  return C_ActionBar and C_ActionBar.HasVehicleActionBar and C_ActionBar.HasVehicleActionBar() == true
end

local function HasOverrideActionBarCompat()
  return C_ActionBar and C_ActionBar.HasOverrideActionBar and C_ActionBar.HasOverrideActionBar() == true
end

local function GetOverrideBarSkinCompat()
  return C_ActionBar and C_ActionBar.GetOverrideBarSkin and C_ActionBar.GetOverrideBarSkin() or nil
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
  return _G["MainActionBar"] or _G["MainMenuBar"] or _G["MainMenuBarArtFrame"]
end

local function IsMainActionBarSystem(system)
  if not system then
    return false
  end

  local mainBar = ResolveMainBar()
  if system == mainBar then
    return true
  end

  local frameName = system.GetName and system:GetName() or nil
  if frameName == "MainActionBar" then
    return true
  end

  if MAIN_BAR_SYSTEM_INDEX and system.systemIndex == MAIN_BAR_SYSTEM_INDEX then
    return true
  end

  return false
end

local function HideRegion(region)
  if not region then
    return
  end
  if region.Hide then
    region:Hide()
  end
  if region.SetAlpha then
    region:SetAlpha(0)
  end
  if region.SetShown then
    region:SetShown(false)
  end
end

local function HideActionButtonBarArt(button)
  if not button then
    return
  end

  local buttonName = button.GetName and button:GetName() or nil
  HideRegion(button.SlotArt or (buttonName and _G[buttonName .. "SlotArt"]) or nil)
  HideRegion(button.SlotBackground or (buttonName and _G[buttonName .. "SlotBackground"]) or nil)
  HideRegion(buttonName and _G[buttonName .. "FloatingBG"] or nil)
end

local function ApplyMainBarVisualState()
  local mainBar = ResolveMainBar()
  if not mainBar then
    return
  end

  mainBar.hideBarArt = true
  mainBar.enableDividers = false

  HideRegion(mainBar.BorderArt)

  if mainBar.EndCaps then
    HideRegion(mainBar.EndCaps.LeftEndCap)
    HideRegion(mainBar.EndCaps.RightEndCap)
    HideRegion(mainBar.EndCaps)
  end

  HideRegion(_G["GryphonLeft"])
  HideRegion(_G["GryphonRight"])

  for i = 1, NUM_ACTIONBAR_BUTTONS do
    HideActionButtonBarArt(_G["ActionButton" .. i])
  end

  if type(mainBar.UpdateDividers) == "function" then
    mainBar:UpdateDividers()
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
  local artCfg = frame and frame.__rothArtworkConfig
  if not frame or type(artCfg) ~= "table" then
    return
  end

  if artCfg.show == false then
    frame:Hide()
    return
  end

  if artCfg.combatfade and InCombatLockdown() then
    frame:Hide()
    return
  end

  frame:Show()
end

local function ApplyArtworkLayout(frame, artCfg, playerFrame)
  if not (frame and artCfg) then
    return
  end

  frame:SetParent(playerFrame or UIParent)
  frame:SetFrameStrata("LOW")
  frame:SetFrameLevel(0)
  frame:SetSize(788, 220)
  frame:ClearAllPoints()
  frame:SetPoint(artCfg.pos.a1, artCfg.pos.af, artCfg.pos.a2, artCfg.pos.x, artCfg.pos.y)
  frame:SetScale(artCfg.scale)
  frame.__rothArtworkConfig = artCfg
  ns.ActionBarBackground = frame

  if playerFrame then
    playerFrame.ActionBarBackground = frame
  end
end

local function EnsureArtworkFrame()
  local artCfg, playerFrame = ResolveArtworkConfig()
  if type(artCfg) ~= "table" or artCfg.show == false then
    return nil
  end

  if not backgroundFrame then
    backgroundFrame = CreateFrame("Frame", "Roth_UIActionBarBackground", playerFrame or UIParent)
    backgroundFrame.texture = backgroundFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    backgroundFrame.texture:SetAllPoints(backgroundFrame)

    if func and type(func.applyDragFunctionality) == "function" then
      func.applyDragFunctionality(backgroundFrame)
    end

    backgroundFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    backgroundFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    backgroundFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    backgroundFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
    backgroundFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
    backgroundFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
    backgroundFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
    backgroundFrame:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
  end

  ApplyArtworkLayout(backgroundFrame, artCfg, playerFrame)
  return backgroundFrame
end

local function ResolveBarDimension(value, fallback)
  local n = tonumber(value)
  if type(n) ~= "number" or n <= 0 then
    return fallback
  end
  return n
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

local function RefreshArtwork()
  ApplyMainBarVisualState()

  local frame = EnsureArtworkFrame()
  if not frame then
    return
  end

  local artCfg = frame.__rothArtworkConfig
  local playerFrame = ResolvePlayerFrame()
  local playerCfg = ResolvePlayerConfig(playerFrame)
  local texture = frame.texture
  if not (artCfg and texture and playerCfg) then
    return
  end

  if InCombatLockdown() then
    ApplyArtworkVisibility(frame)
    return
  end

  if type(IsAddOnLoaded) == "function" and IsAddOnLoaded("Bartender4") then
    texture:SetTexture(mediapath .. "actionbar_3_2")
    ApplyArtworkVisibility(frame)
    return
  end

  local expCfg = playerCfg.expbar or {}
  local repCfg = playerCfg.repbar or {}
  local playerDefaults = (ns and ns.cfgDefaults and ns.cfgDefaults.units and ns.cfgDefaults.units.player) or {}
  local defaultExpCfg = playerDefaults.expbar or {}
  local defaultRepCfg = playerDefaults.repbar or {}
  local expDefaultW = ResolveBarDimension(expCfg.width, 365)
  local expDefaultH = ResolveExpRepHeight(expCfg, repCfg, defaultExpCfg, defaultRepCfg)
  local repDefaultW = ResolveBarDimension(repCfg.width, 365)
  local repDefaultH = ResolveExpRepHeight(repCfg, expCfg, defaultRepCfg, defaultExpCfg)

  local artworkTier = GetArtworkTier()
  local vehicleSkin = UnitVehicleSkin("player")
  local overrideSkin = GetOverrideBarSkinCompat()
  local hasVehicleSkin = vehicleSkin ~= nil and vehicleSkin ~= 0 and vehicleSkin ~= ""
  local hasOverrideSkin = overrideSkin ~= nil and overrideSkin ~= 0 and overrideSkin ~= ""

  local bar = tostring(artworkTier)
  if ((HasVehicleActionBarCompat() and hasVehicleSkin) or (HasOverrideActionBarCompat() and hasOverrideSkin)) or UnitHasVehicleUI("player") then
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
      targetFrame:SetPoint("BOTTOM", "UIParent", "BOTTOM", 0, y * artCfg.scale)
      targetFrame:SetSize(w * artCfg.scale, h * artCfg.scale)
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
  elseif type(IsAddOnLoaded) == "function" and IsAddOnLoaded("ElvUI") then
    texture:SetTexture(mediapath .. "actionbar_3_0")
    if barCount > 0 then
      PlaceExpRepBars(121, 367, 131, 367)
    else
      HideExpRepBars()
    end
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
    hooksecurefunc(editModeActionBarSystemMixin, "RefreshBarArt", function(self)
      if IsMainActionBarSystem(self) then
        RefreshArtwork()
      end
    end)
  end
end

local frame = EnsureArtworkFrame()
if frame then
  frame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
      ApplyArtworkVisibility(self)
      return
    end

    if unit and unit ~= "player" then
      return
    end

    RefreshArtwork()
  end)
  frame.RefreshActionBarArtwork = RefreshArtwork
end

InstallMainBarHooks()
RegisterBarRuntimeListener("background_refresh", RefreshArtwork)
if type(_G["MultiActionBar_Update"]) == "function" then
  hooksecurefunc("MultiActionBar_Update", RefreshArtwork)
end
RefreshArtwork()
