-- Lightweight one-owner skin for Blizzard action buttons.
--
-- Buttons, paging, visibility, state drivers and bindings remain Blizzard-owned.
-- Roth UI creates only additive artwork and adjusts ordinary child regions once
-- when a button is initialized. No replacement buttons, reparenting or OnUpdate.

local addonName, ns = ...

local cfg = assert(ns.cfg, "Roth_UI: config is required by action_button_skin.lua")
local barsCfg = cfg.bars or {}
local mediapath = ns.mediapath or "Interface\\AddOns\\Roth_UI\\media\\"

local skinned = setmetatable({}, { __mode = "k" })

local function Region(button, suffix, directKey)
  local direct = directKey and button[directKey]
  if direct then return direct end
  local name = button.GetName and button:GetName()
  return name and _G[name .. suffix] or nil
end

local function ApplyFont(fontString, size)
  if not (fontString and fontString.SetFont) then return end
  local font = cfg.font or STANDARD_TEXT_FONT
  local resolver = ns.func and ns.func.ResolveFontPath
  if type(resolver) == "function" then
    font = resolver(font)
  end
  fontString:SetFont(font, size, "OUTLINE")
end

local function EnsureArtwork(button)
  if button.__rothSkinBackground then return end

  local bg = button:CreateTexture(nil, "BACKGROUND", nil, -8)
  bg:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 3)
  bg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -3)
  bg:SetTexture(mediapath .. "backdrop")
  bg:SetVertexColor(0.08, 0.08, 0.08, 0.9)
  button.__rothSkinBackground = bg

  local border = button:CreateTexture(nil, "OVERLAY", nil, 6)
  border:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
  border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
  border:SetTexture(mediapath .. "icon_border")
  border:SetVertexColor(0.5, 0.5, 0.5, 0.8)
  button.__rothSkinBorder = border
end

local function ApplyButtonSkin(button)
  if not (button and button.GetName and button:GetName()) then return end
  EnsureArtwork(button)

  local icon = Region(button, "Icon", "icon") or button.Icon
  if icon then
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
  end

  local floating = Region(button, "FloatingBG")
  if floating then floating:Hide() end

  local hotkey = Region(button, "HotKey", "HotKey")
  if hotkey then
    ApplyFont(hotkey, 11)
    hotkey:SetAlpha(barsCfg.showHotkey == false and 0 or 1)
  end

  local name = Region(button, "Name", "Name")
  if name then
    ApplyFont(name, 10)
    name:SetAlpha(barsCfg.showMacroName == true and 1 or 0)
  end

  local count = Region(button, "Count", "Count")
  if count then
    ApplyFont(count, 11)
    count:SetAlpha(barsCfg.showStackCount == false and 0 or 1)
  end

  local cooldown = Region(button, "Cooldown", "cooldown") or button.Cooldown
  if cooldown and cooldown.SetSwipeColor then
    cooldown:SetSwipeColor(0, 0, 0, barsCfg.showCooldown == false and 0 or 0.8)
  end

  skinned[button] = true
end

local BUTTON_PREFIXES = {
  "ActionButton",
  "MultiBarBottomLeftButton",
  "MultiBarBottomRightButton",
  "MultiBarRightButton",
  "MultiBarLeftButton",
  "MultiBar5Button",
  "MultiBar6Button",
  "MultiBar7Button",
  "OverrideActionBarButton",
  "PetActionButton",
  "StanceButton",
  "PossessButton",
}

local function SkinKnownButtons()
  for p = 1, #BUTTON_PREFIXES do
    local prefix = BUTTON_PREFIXES[p]
    for i = 1, 12 do
      ApplyButtonSkin(_G[prefix .. i])
    end
  end
  ApplyButtonSkin(_G.ExtraActionButton1)
  ApplyButtonSkin(_G.ZoneAbilityFrame and _G.ZoneAbilityFrame.SpellButton)
end

local actionMixin = _G.ActionBarActionButtonMixin
if type(actionMixin) == "table" and type(actionMixin.OnLoad) == "function" then
  hooksecurefunc(actionMixin, "OnLoad", ApplyButtonSkin)
end

-- Some optional Blizzard button families are created after Roth UI loads. A
-- bounded one-shot rescan at login covers those without a permanent event loop.
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
  SkinKnownButtons()
  self:UnregisterEvent("PLAYER_LOGIN")
  self:SetScript("OnEvent", nil)
end)

SkinKnownButtons()
ns.RefreshActionButtonSkin = SkinKnownButtons
