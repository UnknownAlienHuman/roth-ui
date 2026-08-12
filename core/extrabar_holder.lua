-----------------------------
-- Extra Action Holder
-----------------------------

local addon, ns = ...
local gcfg = ns.cfg
if not (gcfg and gcfg.bars and gcfg.bars.extrabar) then return end

local cfg = gcfg.bars.extrabar
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local defer = ns and ns.defer
local barRegistry = assert(ns and ns.BarRuntimeRegistry, "Roth_UI.extrabar_holder: ns.BarRuntimeRegistry is required")

if not gcfg.embeds.rActionBarStyler then return end
if not cfg.enable then return end
if not (_G.ExtraActionBarFrame and _G.ExtraActionButton1) then return end

local EXTRA_HOLDER_TEXTURE = "Interface\\AddOns\\Roth_UI\\media\\simplesquare_glow"

local buttonList = {}
local button = ExtraActionButton1

-- Keep Blizzard ownership of ExtraActionBarFrame itself. This holder only owns
-- Roth positioning, drag, and optional mouseover visuals.
local frame = CreateFrame("Frame", "rABS_ExtraBar", UIParent)
barRegistry:RegisterFrame("extrabar", frame)
frame:SetFrameStrata("LOW")
frame:SetFrameLevel(0)

local holderArt = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
holderArt:SetTexture(EXTRA_HOLDER_TEXTURE)
holderArt:SetVertexColor(0, 0, 0, 1)
holderArt:SetAllPoints(frame)
frame.holderArt = holderArt

buttonList[#buttonList + 1] = button
frame.__buttonBarFaderButtons = buttonList
frame.mouseover = cfg.mouseover

local function ResolveShownFrame(target)
  if target and target.IsShown and target:IsShown() then
    return target
  end
  return nil
end

local function ResolveHolderTarget(container)
  return ResolveShownFrame(container) or ResolveShownFrame(_G.ExtraActionBarFrame) or container
end

local function ResolveTargetDimension(target, axis)
  if not target then
    return 0
  end

  local getter = axis == "height" and target.GetHeight or target.GetWidth
  if type(getter) ~= "function" then
    return 0
  end

  local value = getter(target)
  if type(value) ~= "number" or value <= 0 then
    return 0
  end

  return value
end

local function ApplyHolderLayout()
  local container = _G.ExtraAbilityContainer
  local target = ResolveHolderTarget(container)
  if not (container and target) then
    return
  end

  local width = ResolveTargetDimension(target, "width")
  local height = ResolveTargetDimension(target, "height")
  if width <= 0 or height <= 0 then
    width = ResolveTargetDimension(container, "width")
    height = ResolveTargetDimension(container, "height")
  end

  local padding = tonumber(cfg.padding) or 0
  local scale = container.GetScale and container:GetScale() or 1
  if type(scale) ~= "number" or scale <= 0 then
    scale = 1
  end

  frame:SetSize(width + 2 * padding, height + 2 * padding)
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", container, "CENTER")
  frame:SetScale(scale)

  if frame.holderArt then
    frame.holderArt:ClearAllPoints()
    frame.holderArt:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)
    frame.holderArt:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 4, -4)
  end
end

local function ShouldShowHolder()
  return ResolveShownFrame(_G.ExtraAbilityContainer) ~= nil
end

local function UpdateHolderVisibility()
  frame:SetShown(ShouldShowHolder())
  frame:SetAlpha(1)
end

local syncToken = 0
local function ScheduleRuntimeSync()
  syncToken = syncToken + 1
  local token = syncToken

  local function Sync()
    if token ~= syncToken then
      return
    end
    ApplyHolderLayout()
    UpdateHolderVisibility()
  end

  Sync()
  if defer and type(defer.RunNextFrame) == "function" then
    defer.RunNextFrame("rabs:extrabar_sync", Sync, false)
    return
  end
end

local function ApplyMouseoverState()
  frame.mouseover = cfg.mouseover

  if type(_G.rButtonBarFaderUpdate) == "function" then
    _G.rButtonBarFaderUpdate(
      frame,
      cfg.mouseover and cfg.mouseover.fadeIn,
      cfg.mouseover and cfg.mouseover.fadeOut,
      cfg.mouseover and cfg.mouseover.enable == true
    )
  elseif cfg.mouseover and cfg.mouseover.enable and type(_G.rButtonBarFader) == "function" then
    _G.rButtonBarFader(frame, buttonList, cfg.mouseover.fadeIn, cfg.mouseover.fadeOut)
  end

  if not (cfg.mouseover and cfg.mouseover.enable) then
    frame:SetAlpha(1)
  end
end

frame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_ENTERING_WORLD" or event == "UPDATE_EXTRA_ACTIONBAR" then
    ScheduleRuntimeSync()
  end
end)
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UPDATE_EXTRA_ACTIONBAR")

if _G.ExtraAbilityContainer and _G.ExtraAbilityContainer.HookScript then
  _G.ExtraAbilityContainer:HookScript("OnShow", ScheduleRuntimeSync)
  _G.ExtraAbilityContainer:HookScript("OnHide", ScheduleRuntimeSync)
  _G.ExtraAbilityContainer:HookScript("OnSizeChanged", ScheduleRuntimeSync)
end

if ExtraActionBarFrame.HookScript then
  ExtraActionBarFrame:HookScript("OnShow", ScheduleRuntimeSync)
  ExtraActionBarFrame:HookScript("OnHide", ScheduleRuntimeSync)
end

hooksecurefunc(_G, "ExtraActionBar_Update", ScheduleRuntimeSync)

ApplyHolderLayout()
ApplyMouseoverState()
ScheduleRuntimeSync()

barRegistry:RegisterMouseoverRefresher("extrabar", function()
  ApplyHolderLayout()
  ApplyMouseoverState()
  ScheduleRuntimeSync()
end)
