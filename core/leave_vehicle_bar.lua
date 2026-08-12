-----------------------------
-- Leave Vehicle Bar
-----------------------------

local addon, ns = ...
local gcfg = ns.cfg
if not (gcfg and gcfg.bars and gcfg.bars.leave_vehicle) then return end

local cfg = gcfg.bars.leave_vehicle
local barRegistry = assert(ns and ns.BarRuntimeRegistry, "Roth_UI.leave_vehicle_bar: ns.BarRuntimeRegistry is required")
local moverRuntime = ns and ns.moverRuntime

if not gcfg.embeds.rActionBarStyler then return end
if not cfg.enable then return end

local num = 1
local buttonList = {}

local frame = CreateFrame("Frame", "rABS_LeaveVehicle", UIParent, "SecureHandlerStateTemplate")
barRegistry:RegisterFrame("leave_vehicle", frame)
frame:SetWidth(num * cfg.buttons.size + (num - 1) * cfg.buttons.margin + 2 * cfg.padding)
frame:SetHeight(cfg.buttons.size + 2 * cfg.padding)
frame:SetPoint(cfg.pos.a1, cfg.pos.af, cfg.pos.a2, cfg.pos.x, cfg.pos.y)
frame:SetScale(cfg.scale)

local button = CreateFrame("BUTTON", "rABS_LeaveVehicleButton", frame, "SecureHandlerClickTemplate, SecureHandlerStateTemplate")
barRegistry:RegisterFrame("leave_vehicle_button", button)
buttonList[#buttonList + 1] = button
button:SetSize(cfg.buttons.size, cfg.buttons.size)
button:SetPoint("BOTTOMLEFT", frame, cfg.padding, cfg.padding)
button:RegisterForClicks("AnyUp")
button:SetScript("OnClick", function()
  if UnitOnTaxi("player") then
    if TaxiRequestEarlyLanding then
      TaxiRequestEarlyLanding()
    end
  elseif VehicleExit then
    VehicleExit()
  end
end)

button:SetNormalTexture("INTERFACE\\PLAYERACTIONBARALT\\NATURAL")
button:SetPushedTexture("INTERFACE\\PLAYERACTIONBARALT\\NATURAL")
button:SetHighlightTexture("INTERFACE\\PLAYERACTIONBARALT\\NATURAL")
local nt = button:GetNormalTexture()
local pu = button:GetPushedTexture()
local hi = button:GetHighlightTexture()
if nt then
  nt:SetTexCoord(0.0859375, 0.1679688, 0.359375, 0.4414063)
end
if pu then
  pu:SetTexCoord(0.001953125, 0.08398438, 0.359375, 0.4414063)
end
if hi then
  hi:SetTexCoord(0.6152344, 0.6972656, 0.359375, 0.4414063)
  hi:SetBlendMode("ADD")
end

barRegistry:ApplyVisibilityDriver("leave_vehicle_button", button)
barRegistry:ApplyVisibilityDriver("leave_vehicle", frame)

frame.__buttonBarFaderButtons = buttonList
frame.mouseover = cfg.mouseover

if cfg.userplaced and cfg.userplaced.enable and type(moverRuntime) == "table" and type(moverRuntime.AttachLegacyDragFrame) == "function" then
  moverRuntime.AttachLegacyDragFrame(frame, "bars", false, -2, true)
end

if cfg.mouseover and cfg.mouseover.enable and type(_G.rButtonBarFader) == "function" then
  rButtonBarFader(frame, buttonList, cfg.mouseover.fadeIn, cfg.mouseover.fadeOut)
end
