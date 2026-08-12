-----------------------------
-- INIT
-----------------------------

local addon, ns = ...
local gcfg = ns.cfg
if not (gcfg and gcfg.bars and gcfg.bars.bar5 and gcfg.bars.bar4) then return end
local cfg = gcfg.bars.bar5
local barRegistry = assert(ns and ns.BarRuntimeRegistry, "Roth_UI.action_bar_bar5: ns.BarRuntimeRegistry is required")
local RegisterManagedMultiBarFrame = assert(ns.RegisterManagedMultiBarFrame, "Roth_UI.action_bar_bar5: RegisterManagedMultiBarFrame is required")
local moverRuntime = ns and ns.moverRuntime

-----------------------------
-- FUNCTIONS
-----------------------------
if type(gcfg.embeds) == "table" and gcfg.embeds.rActionBarStyler == false then return end
if not cfg.enable then return end
if not _G.MultiBarLeft then return end
local secureActionBars = ns and ns.secureActionBarRuntime
if secureActionBars and type(secureActionBars.IsEnabled) == "function" and secureActionBars.IsEnabled() then
  if gcfg.bars.bar4.combineBar4AndBar5 then
    return
  end
  secureActionBars.SpawnAuxBar("bar5")
  return
end
if gcfg.bars.bar4.combineBar4AndBar5 then return end
if ns and ns.disableProtectedActionBarOwnership then
  barRegistry:RegisterFrame("bar5", _G.MultiBarLeft, {
    role = "aux",
    proxyKeys = { "PROXY_SHOW_ACTIONBAR_5" },
    visibilityFrame = _G.MultiBarLeft,
  })
  return
end

local num = NUM_ACTIONBAR_BUTTONS
local buttonList = {}

local frame = CreateFrame("Frame", "rABS_MultiBarLeft", UIParent)
local holder = CreateFrame("Frame", nil, frame, "SecureHandlerStateTemplate")
barRegistry:RegisterFrame("bar5", frame, {
  role = "aux",
  proxyKeys = { "PROXY_SHOW_ACTIONBAR_5" },
  visibilityFrame = holder,
})
if cfg.vert == true then
  frame:SetHeight(cfg.buttons.size + 2 * cfg.padding)
  frame:SetWidth(num * cfg.buttons.size + (num - 1) * cfg.buttons.margin + 2 * cfg.padding)
else
  frame:SetWidth(cfg.buttons.size + 2 * cfg.padding)
  frame:SetHeight(num * cfg.buttons.size + (num - 1) * cfg.buttons.margin + 2 * cfg.padding)
end
frame:SetPoint(cfg.pos.a1, cfg.pos.af, cfg.pos.a2, cfg.pos.x, cfg.pos.y)
frame:SetScale(cfg.scale)
holder:SetAllPoints(frame)

MultiBarLeft:SetParent(holder)
MultiBarLeft:EnableMouse(false)

for i = 1, num do
  local button = _G["MultiBarLeftButton" .. i]
  if not button then
    break
  end
  buttonList[#buttonList + 1] = button
  button:SetSize(cfg.buttons.size, cfg.buttons.size)
  button:ClearAllPoints()

  if cfg.vert == true then
    if i == 1 then
      button:SetPoint("LEFT", holder, cfg.padding, 0)
    else
      button:SetPoint("LEFT", _G["MultiBarLeftButton" .. (i - 1)], "RIGHT", cfg.buttons.margin, 0)
    end
  else
    if i == 1 then
      button:SetPoint("TOPRIGHT", holder, -cfg.padding, -cfg.padding)
    else
      button:SetPoint("TOP", _G["MultiBarLeftButton" .. (i - 1)], "BOTTOM", 0, -cfg.buttons.margin)
    end
  end
end

barRegistry:ApplyVisibilityDriver("bar5", holder)

if cfg.userplaced and cfg.userplaced.enable and type(moverRuntime) == "table" and type(moverRuntime.AttachLegacyDragFrame) == "function" then
  moverRuntime.AttachLegacyDragFrame(frame, "bars", true, -2, true)
end

frame.__buttonBarFaderButtons = buttonList
frame.mouseover = cfg.mouseover

if cfg.mouseover and cfg.mouseover.enable and type(_G.rButtonBarFader) == "function" then
  rButtonBarFader(frame, buttonList, cfg.mouseover.fadeIn, cfg.mouseover.fadeOut)
end

RegisterManagedMultiBarFrame("bar5")
