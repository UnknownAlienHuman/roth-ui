-----------------------------
-- INIT
-----------------------------

--get the addon namespace
local addon, ns = ...
local gcfg = ns.cfg
if not (gcfg and gcfg.bars and gcfg.bars.bar2) then return end
--get some values from the namespace
local cfg = gcfg.bars.bar2
local safety = assert(ns and ns.safety, "Roth_UI.action_bar_bar2: ns.safety is required")
local TryCall = assert(safety.TryCall, "Roth_UI.action_bar_bar2: safety.TryCall is required")
local barRegistry = assert(ns and ns.BarRuntimeRegistry, "Roth_UI.action_bar_bar2: ns.BarRuntimeRegistry is required")
local RegisterManagedMultiBarFrame = assert(ns.RegisterManagedMultiBarFrame, "Roth_UI.action_bar_bar2: RegisterManagedMultiBarFrame is required")
local moverRuntime = ns and ns.moverRuntime

-----------------------------
-- FUNCTIONS
-----------------------------
if type(gcfg.embeds) == "table" and gcfg.embeds.rActionBarStyler == false then return end
if not cfg.enable then return end

if not _G.MultiBarBottomLeft then return end
local secureActionBars = ns and ns.secureActionBarRuntime
if secureActionBars and type(secureActionBars.IsEnabled) == "function" and secureActionBars.IsEnabled() then
  secureActionBars.SpawnAuxBar("bar2")
  return
end
if ns and ns.disableProtectedActionBarOwnership then
  barRegistry:RegisterFrame("bar2", _G.MultiBarBottomLeft, {
    role = "aux",
    proxyKeys = { "PROXY_SHOW_ACTIONBAR_2" },
    visibilityFrame = _G.MultiBarBottomLeft,
  })
  return
end
local num = NUM_ACTIONBAR_BUTTONS
local buttonList = {}

--create the frame to hold the buttons
local frame = CreateFrame("Frame", "rABS_MultiBarBottomLeft", UIParent)
local holder = CreateFrame("Frame", nil, frame, "SecureHandlerStateTemplate")
barRegistry:RegisterFrame("bar2", frame, {
  role = "aux",
  proxyKeys = { "PROXY_SHOW_ACTIONBAR_2" },
  visibilityFrame = holder,
})
if cfg.uselayout2x6 then
  frame:SetWidth(cfg.buttons.size * num / 2 + (num / 2 - 1) * cfg.buttons.margin + 2 * cfg.padding)
  frame:SetHeight(cfg.buttons.size * num / 6 + (num / 6 - 1) * cfg.buttons.margin + 2 * cfg.padding)
else
  frame:SetWidth(num * cfg.buttons.size + (num - 1) * cfg.buttons.margin + 2 * cfg.padding)
  frame:SetHeight(cfg.buttons.size + 2 * cfg.padding)
end
if cfg.uselayout2x6 then
  local layoutCfg = gcfg.bars.bar2
  frame:SetPoint(layoutCfg.pos.a1, layoutCfg.pos.af, layoutCfg.pos.a2,
    layoutCfg.pos.x + ((layoutCfg.buttons.size * num / 2 + layoutCfg.buttons.margin * num / 2) / 2), layoutCfg.pos.y)
else
  frame:SetPoint(cfg.pos.a1, cfg.pos.af, cfg.pos.a2, cfg.pos.x, cfg.pos.y)
end
frame:SetScale(cfg.scale)
holder:SetAllPoints(frame)

--move the buttons into position and reparent them
MultiBarBottomLeft:SetParent(holder)
MultiBarBottomLeft:EnableMouse(false)

for i = 1, num do
  local button = _G["MultiBarBottomLeftButton" .. i]
  if not button then
    break
  end
  buttonList[#buttonList + 1] = button   --add the button object to the list
  button:SetSize(cfg.buttons.size, cfg.buttons.size)
  button:ClearAllPoints()
  if i == 1 then
    button:SetPoint("BOTTOMLEFT", holder, cfg.padding, cfg.padding)
  else
    local previous = _G["MultiBarBottomLeftButton" .. i - 1]
    if cfg.uselayout2x6 and i == (num / 2 + 1) then
      previous = _G["MultiBarBottomLeftButton1"]
      button:SetPoint("BOTTOM", previous, "TOP", 0, cfg.buttons.margin)
    else
      button:SetPoint("LEFT", previous, "RIGHT", cfg.buttons.margin, 0)
    end
  end
end

-- show/hide the frame on a given state driver
local helper
local pending

local function updatestate()
  if InCombatLockdown and InCombatLockdown() then
    pending = true
    if helper then helper:RegisterEvent("PLAYER_REGEN_ENABLED") end
    return
  end
  if helper then helper:UnregisterEvent("PLAYER_REGEN_ENABLED") end
  pending = false
  local ok = TryCall(barRegistry.ApplyVisibilityDriver, "bar2", holder)
  if not ok and helper and helper.UnregisterEvent then
    helper:UnregisterEvent("UNIT_EXITED_VEHICLE")
  end
end

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

RegisterManagedMultiBarFrame("bar2")

helper = CreateFrame("Frame")   -- driver refresh helper
helper:RegisterEvent("UNIT_EXITED_VEHICLE")
helper:RegisterEvent("PLAYER_LOGIN")
helper:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_REGEN_ENABLED" and not pending then
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  updatestate()
end)
