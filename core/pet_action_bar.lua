-----------------------------
-- Pet Action Bar
-----------------------------

local addon, ns = ...
local gcfg = ns.cfg
if not (gcfg and gcfg.bars and gcfg.bars.petbar) then return end

local cfg = gcfg.bars.petbar
local barRegistry = assert(ns and ns.BarRuntimeRegistry, "Roth_UI.pet_action_bar: ns.BarRuntimeRegistry is required")
local moverRuntime = ns and ns.moverRuntime

if not gcfg.embeds.rActionBarStyler then return end
if not cfg.enable then return end
if not _G.PetActionBar then return end
if ns and ns.disableProtectedActionBarOwnership then
  barRegistry:RegisterFrame("petbar", _G.PetActionBar)
  return
end

local num = NUM_PET_ACTION_SLOTS
local buttonList = {}

local frame = CreateFrame("Frame", "rABS_PetBar", UIParent, "SecureHandlerStateTemplate")
barRegistry:RegisterFrame("petbar", frame)
frame:SetWidth(num * cfg.buttons.size + (num - 1) * cfg.buttons.margin + 2 * cfg.padding)
frame:SetHeight(cfg.buttons.size + 2 * cfg.padding)
frame:ClearAllPoints()
frame:SetPoint(cfg.pos.a1, cfg.pos.af, cfg.pos.a2, cfg.pos.x, cfg.pos.y)
frame:SetScale(cfg.scale)

PetActionBar:ClearAllPoints()
PetActionBar:SetParent(frame)
PetActionBar:EnableMouse(false)

for i = 1, num do
  local button = _G["PetActionButton" .. i]
  if not button then
    break
  end
  buttonList[#buttonList + 1] = button
  button:SetSize(cfg.buttons.size, cfg.buttons.size)
  button:ClearAllPoints()
  if i == 1 then
    button:SetPoint("LEFT", frame, cfg.padding, 0)
  else
    local previous = _G["PetActionButton" .. i - 1]
    button:SetPoint("LEFT", previous, "RIGHT", cfg.buttons.margin, 0)
  end

  local cooldown = _G["PetActionButton" .. i .. "Cooldown"]
  if cooldown then
    cooldown:SetAllPoints(button)
  end
end

frame.__buttonBarFaderButtons = buttonList
frame.mouseover = cfg.mouseover

if not cfg.show then
  frame:SetParent(ns.pastebin)
  return
end

barRegistry:ApplyVisibilityDriver("petbar", frame)

if cfg.userplaced and cfg.userplaced.enable and type(moverRuntime) == "table" and type(moverRuntime.AttachLegacyDragFrame) == "function" then
  moverRuntime.AttachLegacyDragFrame(frame, "bars", false, -2, true)
end

if cfg.mouseover and cfg.mouseover.enable and type(_G.rButtonBarFader) == "function" then
  rButtonBarFader(frame, buttonList, cfg.mouseover.fadeIn, cfg.mouseover.fadeOut)
end
