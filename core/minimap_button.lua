-- Roth UI minimap button.
--
-- The button is addon-owned, fixed-position and eventless. It does not modify
-- the Minimap object, install polling, or create another Settings owner.

local addonName, ns = ...

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local Minimap = Minimap
local type = type

if not Minimap then return end

local function PrintHelp()
  local slashList = _G.SlashCmdList
  local handler = type(slashList) == "table" and slashList.roth or nil
  if type(handler) == "function" then
    handler("help")
  else
    print("Roth_UI: use /roth for commands.")
  end
end

local function OpenOptions()
  if InCombatLockdown and InCombatLockdown() == true then
    print("Roth_UI: settings cannot be opened during combat.")
    return false
  end

  local actions = ns and ns.settingsActions
  local open = type(actions) == "table" and actions.OpenOptions or nil
  if type(open) ~= "function" then
    print("Roth_UI: settings category is not available.")
    return false
  end
  return open() == true
end

local button = CreateFrame("Button", "Roth_UIMinimapButton", Minimap)
button:SetSize(31, 31)
button:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", -4, -4)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel((Minimap.GetFrameLevel and Minimap:GetFrameLevel() or 0) + 8)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -7)
icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -7, 7)
icon:SetTexture("Interface\\AddOns\\Roth_UI\\media\\d3_head_diablo.tga")
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local border = button:CreateTexture(nil, "OVERLAY")
border:SetAllPoints(button)
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local highlight = button:CreateTexture(nil, "HIGHLIGHT")
highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
highlight:SetBlendMode("ADD")

button:SetScript("OnClick", function(_, mouseButton)
  if mouseButton == "RightButton" then
    PrintHelp()
  else
    OpenOptions()
  end
end)

button:SetScript("OnEnter", function(self)
  local tooltip = _G.GameTooltip
  if not tooltip then return end
  tooltip:SetOwner(self, "ANCHOR_LEFT")
  tooltip:ClearLines()
  tooltip:AddLine("Roth UI")
  tooltip:AddLine("Left-click: open settings", 1, 1, 1)
  tooltip:AddLine("Right-click: show commands", 1, 1, 1)
  tooltip:Show()
end)

button:SetScript("OnLeave", function()
  local tooltip = _G.GameTooltip
  if tooltip then tooltip:Hide() end
end)

ns.MinimapButton = button
