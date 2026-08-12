-----------------------------
-- INIT
-----------------------------

--get the addon namespace
local addon, ns = ...
local gcfg = ns.cfg
if not (gcfg and gcfg.bars and gcfg.bars.bar3) then return end
--get some values from the namespace
local cfg = gcfg.bars.bar3
local barRegistry = assert(ns and ns.BarRuntimeRegistry, "Roth_UI.action_bar_bar3: ns.BarRuntimeRegistry is required")
local RegisterManagedMultiBarFrame = assert(ns.RegisterManagedMultiBarFrame, "Roth_UI.action_bar_bar3: RegisterManagedMultiBarFrame is required")
local moverRuntime = ns and ns.moverRuntime

-----------------------------
-- FUNCTIONS
-----------------------------
if type(gcfg.embeds) == "table" and gcfg.embeds.rActionBarStyler == false then return end
if not cfg.enable then return end

if not _G.MultiBarBottomRight then return end
local secureActionBars = ns and ns.secureActionBarRuntime
if secureActionBars and type(secureActionBars.IsEnabled) == "function" and secureActionBars.IsEnabled() then
  secureActionBars.SpawnAuxBar("bar3")
  return
end
if ns and ns.disableProtectedActionBarOwnership then
  barRegistry:RegisterFrame("bar3", _G.MultiBarBottomRight, {
    role = "aux",
    proxyKeys = { "PROXY_SHOW_ACTIONBAR_3" },
    visibilityFrame = _G.MultiBarBottomRight,
  })
  return
end
local num = NUM_ACTIONBAR_BUTTONS
local buttonList = {}

--create the frame to hold the buttons
local frame = CreateFrame("Frame", "rABS_MultiBarBottomRight", UIParent)
local holder = CreateFrame("Frame", nil, frame, "SecureHandlerStateTemplate")
barRegistry:RegisterFrame("bar3", frame, {
  role = "aux",
  proxyKeys = { "PROXY_SHOW_ACTIONBAR_3" },
  visibilityFrame = holder,
})
frame:SetWidth(num * cfg.buttons.size + (num - 1) * cfg.buttons.margin + 2 * cfg.padding)
frame:SetHeight(cfg.buttons.size + 2 * cfg.padding)
frame:SetPoint(cfg.pos.a1, cfg.pos.af, cfg.pos.a2, cfg.pos.x, cfg.pos.y)
frame:SetScale(cfg.scale)
holder:SetAllPoints(frame)

--move the buttons into position and reparent them
MultiBarBottomRight:SetParent(holder)
MultiBarBottomRight:EnableMouse(false)

for i = 1, num do
  local button = _G["MultiBarBottomRightButton" .. i]
  if not button then
    break
  end
  buttonList[#buttonList + 1] = button   --add the button object to the list
  button:SetSize(cfg.buttons.size, cfg.buttons.size)
  button:ClearAllPoints()
  if i == 1 then
    button:SetPoint("LEFT", holder, cfg.padding, 0)
  else
    local previous = _G["MultiBarBottomRightButton" .. i - 1]
    button:SetPoint("LEFT", previous, "RIGHT", cfg.buttons.margin, 0)
  end
end

--show/hide the frame on a given state driver
barRegistry:ApplyVisibilityDriver("bar3", holder)

--create drag frame and drag functionality
if cfg.userplaced and cfg.userplaced.enable and type(moverRuntime) == "table" and type(moverRuntime.AttachLegacyDragFrame) == "function" then
  moverRuntime.AttachLegacyDragFrame(frame, "bars", true, -2, true)
end

frame.__buttonBarFaderButtons = buttonList
frame.mouseover = cfg.mouseover

--create the mouseover functionality
if cfg.mouseover and cfg.mouseover.enable and type(_G.rButtonBarFader) == "function" then
  rButtonBarFader(frame, buttonList, cfg.mouseover.fadeIn, cfg.mouseover.fadeOut)   --frame, buttonList, fadeIn, fadeOut
end

RegisterManagedMultiBarFrame("bar3")
