-----------------------------
-- Stance Bar
-----------------------------

local addon, ns = ...
local gcfg = ns.cfg
if not (gcfg and gcfg.bars and gcfg.bars.stancebar) then return end

local cfg = gcfg.bars.stancebar
local barRegistry = assert(ns and ns.BarRuntimeRegistry, "Roth_UI.stance_bar: ns.BarRuntimeRegistry is required")
local moverRuntime = ns and ns.moverRuntime

if not gcfg.embeds.rActionBarStyler then return end
if not cfg.enable then return end
if not _G.StanceBar then return end
if ns and ns.disableProtectedActionBarOwnership then
  barRegistry:RegisterFrame("stancebar", _G.StanceBar, { dockSlot = "stancebar" })
  return
end

local maxButtons = NUM_STANCE_SLOTS or 10
local num = maxButtons
local buttonList = {}
local sync = CreateFrame("Frame")

local frame = CreateFrame("Frame", "rABS_StanceBar", UIParent, "SecureHandlerStateTemplate")
barRegistry:RegisterFrame("stancebar", frame, { dockSlot = "stancebar" })
frame:SetWidth(num * cfg.buttons.size + (num - 1) * cfg.buttons.margin + 2 * cfg.padding)
frame:SetHeight(cfg.buttons.size + 2 * cfg.padding)
frame:ClearAllPoints()
frame:SetPoint(cfg.pos.a1, cfg.pos.af, cfg.pos.a2, cfg.pos.x, cfg.pos.y)
frame:SetScale(cfg.scale)

local function GetVisibleStanceCount()
  local forms = (type(GetNumShapeshiftForms) == "function") and GetNumShapeshiftForms() or 0
  if type(forms) ~= "number" then
    forms = 0
  end
  forms = math.min(forms, maxButtons)
  if forms < 1 then
    forms = 1
  end
  return forms
end

local function GetShownStanceCount()
  local shown = 0
  for _, button in ipairs(buttonList) do
    if button and button.IsShown and button:IsShown() then
      shown = shown + 1
    end
  end
  if shown > 0 then
    return shown
  end
  return GetVisibleStanceCount()
end

local function ResolveStanceFrameWidth()
  local visible = GetShownStanceCount()
  return visible * cfg.buttons.size + math.max(visible - 1, 0) * cfg.buttons.margin + 2 * cfg.padding
end

local lastAppliedWidth = nil
local pendingWidthRefresh = false

local function QueueStanceWidthRefresh()
  pendingWidthRefresh = true
  sync:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local function UpdateStanceFrameWidth()
  local width = ResolveStanceFrameWidth()
  if lastAppliedWidth == width then
    pendingWidthRefresh = false
    sync:UnregisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    QueueStanceWidthRefresh()
    return
  end
  pendingWidthRefresh = false
  sync:UnregisterEvent("PLAYER_REGEN_ENABLED")
  lastAppliedWidth = width
  frame:SetWidth(width)
  barRegistry.NotifyChanged("stancebar", "layout")
end

frame.__dockGetVisualWidth = function(self)
  local scale = self.GetScale and self:GetScale() or 1
  if type(scale) ~= "number" or scale <= 0 then
    scale = 1
  end
  return ResolveStanceFrameWidth() * scale
end

StanceBar:SetParent(frame)
StanceBar:ClearAllPoints()
StanceBar:SetAllPoints(frame)
StanceBar:EnableMouse(false)

for i = 1, num do
  local button = _G["StanceButton" .. i]
  if not button then
    break
  end
  buttonList[#buttonList + 1] = button
  button:SetSize(cfg.buttons.size, cfg.buttons.size)
  button:ClearAllPoints()
  if not button.__rABSStanceWidthHook then
    button.__rABSStanceWidthHook = true
    button:HookScript("OnShow", UpdateStanceFrameWidth)
    button:HookScript("OnHide", UpdateStanceFrameWidth)
  end
  if i == 1 then
    button:SetPoint("LEFT", frame, "LEFT", cfg.padding, 0)
  else
    local previous = _G["StanceButton" .. i - 1]
    button:SetPoint("LEFT", previous, "RIGHT", cfg.buttons.margin, 0)
  end
end

frame.__buttonBarFaderButtons = buttonList
frame.mouseover = cfg.mouseover

if not cfg.show then
  frame:SetParent(ns.pastebin)
  return
end

barRegistry:ApplyVisibilityDriver("stancebar", frame)

if cfg.userplaced and cfg.userplaced.enable and type(moverRuntime) == "table" and type(moverRuntime.AttachLegacyDragFrame) == "function" then
  moverRuntime.AttachLegacyDragFrame(frame, "bars", false, -2, true)
end

UpdateStanceFrameWidth()
barRegistry.NotifyChanged("stancebar", "layout")

do
  sync:RegisterEvent("PLAYER_ENTERING_WORLD")
  sync:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
  sync:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
  sync:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" and not pendingWidthRefresh then
      self:UnregisterEvent("PLAYER_REGEN_ENABLED")
      return
    end
    UpdateStanceFrameWidth()
  end)
end
