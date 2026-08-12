-----------------------------
-- Micro Menu Bar
-----------------------------

local addon, ns = ...
local gcfg = ns.cfg
if not (gcfg and gcfg.bars and gcfg.bars.micromenu) then return end

local cfg = gcfg.bars.micromenu
local barRegistry = assert(ns and ns.BarRuntimeRegistry, "Roth_UI.micromenu_bar: ns.BarRuntimeRegistry is required")
local moverRuntime = ns and ns.moverRuntime

local MainMenuBar = _G.MainActionBar or _G.MainMenuBar

if not gcfg.embeds.rActionBarStyler then return end
if not cfg.enable then return end
if ns and ns.disableProtectedActionBarOwnership then
  if _G.MicroMenu then
    barRegistry:RegisterFrame("micromenu", _G.MicroMenu, { dockSlot = "micromenu" })
  end
  return
end

local MICRO_BUTTONS = _G.MICRO_BUTTONS or {
  "CharacterMicroButton",
  "ProfessionMicroButton",
  "PlayerSpellsMicroButton",
  "AchievementMicroButton",
  "QuestLogMicroButton",
  "HousingMicroButton",
  "GuildMicroButton",
  "LFDMicroButton",
  "EJMicroButton",
  "CollectionsMicroButton",
  "MainMenuMicroButton",
  "HelpMicroButton",
  "StoreMicroButton",
}

local buttonList = {}
for _, buttonName in ipairs(MICRO_BUTTONS) do
  local button = _G[buttonName]
  if button then
    buttonList[#buttonList + 1] = button
  end
end

local CharacterMicroButton = _G.CharacterMicroButton
if not CharacterMicroButton then return end
local MicroMenu = _G.MicroMenu
if not MicroMenu then return end

local function ResolveAnchorFrame(anchor)
  if type(anchor) == "table" then
    return anchor
  end
  if type(anchor) == "string" and anchor ~= "" then
    return _G[anchor] or UIParent
  end
  return UIParent
end

local frame = CreateFrame("Frame", "rABS_MicroMenu", UIParent, "SecureHandlerStateTemplate")
barRegistry:RegisterFrame("micromenu", frame, { dockSlot = "micromenu" })
frame:SetPoint(cfg.pos and cfg.pos.a1 or "BOTTOM", ResolveAnchorFrame(cfg.pos and cfg.pos.af), cfg.pos and cfg.pos.a2 or "BOTTOM", cfg.pos and cfg.pos.x or -180, cfg.pos and cfg.pos.y or 97)
frame:SetScale(cfg.scale)
frame.__buttonBarFaderButtons = buttonList
frame.mouseover = cfg.mouseover

MicroMenu:SetParent(frame)

local layoutHelper = CreateFrame("Frame")
local layoutBusy = false
local layoutPending = false
local layoutNeedsDockRefresh = false

local function LayoutButtons(skipDockRefresh)
  if layoutBusy then
    return
  end
  layoutBusy = true

  local shouldRefresh = false
  xpcall(function()
    if MicroMenu:GetParent() ~= frame then
      MicroMenu:SetParent(frame)
    end

    MicroMenu.isStacked = false
    MicroMenu.isHorizontal = true
    MicroMenu.layoutFramesGoingRight = true
    MicroMenu.layoutFramesGoingUp = false
    if type(MicroMenu.numButtons) == "number" and MicroMenu.numButtons > 0 then
      MicroMenu.stride = MicroMenu.numButtons
    end

    local width = MicroMenu.GetWidth and MicroMenu:GetWidth() or CharacterMicroButton:GetWidth()
    local height = MicroMenu.GetHeight and MicroMenu:GetHeight() or CharacterMicroButton:GetHeight()
    if type(width) ~= "number" or width <= 0 then
      width = CharacterMicroButton:GetWidth()
    end
    if type(height) ~= "number" or height <= 0 then
      height = CharacterMicroButton:GetHeight()
    end

    local frameScale = frame.GetScale and frame:GetScale() or 1
    if type(frameScale) ~= "number" or frameScale <= 0 then
      frameScale = 1
    end

    local assignedVisualWidth = tonumber(frame.__dockAssignedWidth)
    local assignedVisualHeight = tonumber(frame.__dockAssignedHeight)
    local assignedLocalWidth = assignedVisualWidth and assignedVisualWidth > 0 and (assignedVisualWidth / frameScale) or nil
    local assignedLocalHeight = assignedVisualHeight and assignedVisualHeight > 0 and (assignedVisualHeight / frameScale) or nil
    local availableWidth = assignedLocalWidth and math.max(assignedLocalWidth - 2 * cfg.padding, 1) or width
    local contentScale = 1
    if width > 0 and availableWidth > 0 then
      contentScale = math.min(1, availableWidth / width)
    end

    if type(MicroMenu.SetScale) == "function" then
      MicroMenu:SetScale(contentScale)
    end

    local scaledWidth = width * contentScale
    local scaledHeight = height * contentScale
    local desiredHeight = scaledHeight + 2 * cfg.padding
    if assignedLocalHeight and assignedLocalHeight > 0 then
      desiredHeight = math.min(desiredHeight, assignedLocalHeight)
    end

    MicroMenu:ClearAllPoints()
    MicroMenu:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", cfg.padding, cfg.padding)
    frame:SetWidth(math.max(assignedLocalWidth or (scaledWidth + 2 * cfg.padding), 1))
    frame:SetHeight(math.max(desiredHeight, 1))
    frame.__dockGetVisualWidth = function(self)
      local visualWidth = tonumber(self.__dockAssignedWidth)
      if type(visualWidth) ~= "number" or visualWidth <= 0 then
        local scale = self.GetScale and self:GetScale() or 1
        if type(scale) ~= "number" or scale <= 0 then
          scale = 1
        end
        visualWidth = self:GetWidth() * scale
      end
      return visualWidth
    end

    shouldRefresh = not skipDockRefresh
  end, geterrorhandler())

  layoutBusy = false
  if shouldRefresh then
    barRegistry.NotifyChanged("micromenu", "layout")
  end
end

local function QueueLayout(skipDockRefresh)
  layoutPending = true
  if skipDockRefresh ~= true then
    layoutNeedsDockRefresh = true
  end
  layoutHelper:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local function FlushPendingLayout()
  if InCombatLockdown and InCombatLockdown() then
    return
  end

  local skipDockRefresh = not layoutNeedsDockRefresh
  layoutPending = false
  layoutNeedsDockRefresh = false
  LayoutButtons(skipDockRefresh)

  if not layoutPending then
    layoutHelper:UnregisterEvent("PLAYER_REGEN_ENABLED")
  end
end

frame.__dockApplyLayout = function(self, width, height)
  self.__dockAssignedWidth = width
  self.__dockAssignedHeight = height
  if InCombatLockdown and InCombatLockdown() then
    QueueLayout(true)
    return
  end
  LayoutButtons(true)
end

local function RequestLayout(skipDockRefresh)
  if InCombatLockdown and InCombatLockdown() then
    QueueLayout(skipDockRefresh)
    return
  end
  LayoutButtons(skipDockRefresh == true)
end

layoutHelper:SetScript("OnEvent", function()
  if not layoutPending then
    layoutHelper:UnregisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  FlushPendingLayout()
end)

for _, button in ipairs(buttonList) do
  if not button.__rABSLayoutHook then
    button.__rABSLayoutHook = true
    button:HookScript("OnShow", function()
      RequestLayout(false)
    end)
    button:HookScript("OnHide", function()
      RequestLayout(false)
    end)
    if type(button.UpdateMicroButton) == "function" then
      hooksecurefunc(button, "UpdateMicroButton", function()
        RequestLayout(false)
      end)
    end
  end
end

if not MicroMenu.__rABSLayoutHook then
  MicroMenu.__rABSLayoutHook = true
  MicroMenu:HookScript("OnShow", function()
    RequestLayout(false)
  end)
  MicroMenu:HookScript("OnSizeChanged", function()
    RequestLayout(false)
  end)
  if type(MicroMenu.Layout) == "function" then
    hooksecurefunc(MicroMenu, "Layout", function()
      RequestLayout(false)
    end)
  end
  if type(MicroMenu.UpdateScale) == "function" then
    hooksecurefunc(MicroMenu, "UpdateScale", function()
      RequestLayout(false)
    end)
  end
  if type(MicroMenu.ResetMicroMenuPosition) == "function" then
    hooksecurefunc(MicroMenu, "ResetMicroMenuPosition", function()
      RequestLayout(false)
    end)
  end
  if type(MicroMenu.OverrideMicroMenuPosition) == "function" then
    hooksecurefunc(MicroMenu, "OverrideMicroMenuPosition", function()
      RequestLayout(false)
    end)
  end
end

if type(_G.UpdateMicroButtons) == "function" and not frame.__rABSUpdateMicroButtonsHook then
  frame.__rABSUpdateMicroButtonsHook = true
  hooksecurefunc("UpdateMicroButtons", function()
    RequestLayout(false)
  end)
end

if MainMenuBar and not MainMenuBar.__rABSLayoutHook then
  MainMenuBar.__rABSLayoutHook = true
  MainMenuBar:HookScript("OnShow", function()
    RequestLayout(false)
  end)
end

RequestLayout(false)

if not cfg.show then
  frame:SetParent(ns.pastebin)
  return
end

barRegistry:ApplyVisibilityDriver("micromenu", frame)

if cfg.userplaced and cfg.userplaced.enable and type(moverRuntime) == "table" and type(moverRuntime.AttachLegacyDragFrame) == "function" then
  moverRuntime.AttachLegacyDragFrame(frame, "bars", false, -2, false)
end

if cfg.mouseover and cfg.mouseover.enable and type(_G.rButtonBarFader) == "function" then
  rButtonBarFader(frame, buttonList, cfg.mouseover.fadeIn, cfg.mouseover.fadeOut)
end

barRegistry.NotifyChanged("micromenu", "layout")
