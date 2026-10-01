-- Lightweight one-owner skin for Blizzard action buttons.
--
-- Buttons, paging, visibility, state drivers and bindings remain Blizzard-owned.
-- Roth UI creates additive artwork and adjusts ordinary child regions once the
-- current execution context can safely access them. No replacement buttons,
-- reparenting or permanent polling.

local addonName, ns = ...

local cfg = assert(ns.cfg, "Roth_UI: config is required by action_button_skin.lua")
local barsCfg = cfg.bars or {}
local mediapath = ns.mediapath or "Interface\\AddOns\\Roth_UI\\media\\"
local safety = assert(ns and ns.safety, "Roth_UI: safety is required by action_button_skin.lua")
local CanAccess = assert(safety.CanAccess, "Roth_UI: safety.CanAccess is required by action_button_skin.lua")
local CanUseRegion = assert(safety.CanUseRegion, "Roth_UI: safety.CanUseRegion is required by action_button_skin.lua")
local CanUseRegionFor = assert(safety.CanUseRegionFor, "Roth_UI: safety.CanUseRegionFor is required by action_button_skin.lua")
local TryGet = assert(safety.TryGet, "Roth_UI: safety.TryGet is required by action_button_skin.lua")
local TryMethod = assert(safety.TryMethod, "Roth_UI: safety.TryMethod is required by action_button_skin.lua")
local InCombatLockdown = InCombatLockdown
local CreateFrame = CreateFrame
local rawget = rawget
local type = type
local setmetatable = setmetatable

local SET_TEXTURE_ASPECT = type(Enum) == "table"
  and type(Enum.ForbiddenAspect) == "table"
  and Enum.ForbiddenAspect.SetTexture
  or nil

local artworkStates = setmetatable({}, { __mode = "k" })
local pendingButtons = setmetatable({}, { __mode = "k" })
local regenFrame
local ApplyButtonSkin

local function CanSetTexture(region)
  if SET_TEXTURE_ASPECT ~= nil then
    return CanUseRegionFor(region, SET_TEXTURE_ASPECT)
  end
  return CanUseRegion(region)
end

local function Region(button, suffix, directKey)
  if directKey then
    local got, direct = TryGet(button, directKey)
    if got == true and CanAccess(direct) and direct ~= nil then
      return direct
    end
  end

  local gotName, name = TryMethod(button, "GetName")
  if gotName ~= true or not CanAccess(name) or type(name) ~= "string" or name == "" then
    return nil
  end
  return rawget(_G, name .. suffix)
end

local function ApplyFont(fontString, size)
  if not CanUseRegion(fontString) then return false end
  local font = cfg.font or STANDARD_TEXT_FONT
  local resolver = ns.func and ns.func.ResolveFontPath
  if type(resolver) == "function" then
    font = resolver(font)
  end
  return TryMethod(fontString, "SetFont", font, size, "OUTLINE") == true
end

local function CreateArtwork(button, layer, subLevel, texturePath, inset, color)
  local created, texture = TryMethod(button, "CreateTexture", nil, layer, nil, subLevel)
  if created ~= true or not CanSetTexture(texture) then
    return nil
  end

  if TryMethod(texture, "SetTexture", texturePath) ~= true then
    return nil
  end
  TryMethod(texture, "SetPoint", "TOPLEFT", button, "TOPLEFT", -inset, inset)
  TryMethod(texture, "SetPoint", "BOTTOMRIGHT", button, "BOTTOMRIGHT", inset, -inset)
  TryMethod(texture, "SetVertexColor", color[1], color[2], color[3], color[4])
  return texture
end

local function EnsureArtwork(button)
  local state = artworkStates[button]
  if not state then
    state = {}
    artworkStates[button] = state
  end

  if not state.backgroundAttempted then
    state.backgroundAttempted = true
    state.background = CreateArtwork(
      button, "BACKGROUND", -8, mediapath .. "backdrop", 3,
      { 0.08, 0.08, 0.08, 0.9 }
    )
  end
  if not state.borderAttempted then
    state.borderAttempted = true
    state.border = CreateArtwork(
      button, "OVERLAY", 6, mediapath .. "icon_border", 2,
      { 0.5, 0.5, 0.5, 0.8 }
    )
  end
end

local function EnsureRegenFrame()
  if regenFrame then return end

  regenFrame = CreateFrame("Frame")
  regenFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local work = pendingButtons
    pendingButtons = setmetatable({}, { __mode = "k" })
    for button in pairs(work) do
      ApplyButtonSkin(button)
    end
  end)
end

local function QueueButton(button)
  if not button then return end
  pendingButtons[button] = true
  EnsureRegenFrame()
  regenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

ApplyButtonSkin = function(button)
  if not button then return false end
  if InCombatLockdown and InCombatLockdown() then
    QueueButton(button)
    return false
  end
  if not CanUseRegion(button) then return false end

  local gotName, buttonName = TryMethod(button, "GetName")
  if gotName ~= true or not CanAccess(buttonName) or type(buttonName) ~= "string" or buttonName == "" then
    return false
  end

  EnsureArtwork(button)

  local icon = Region(button, "Icon", "icon") or Region(button, "Icon", "Icon")
  if CanUseRegion(icon) then
    TryMethod(icon, "ClearAllPoints")
    TryMethod(icon, "SetPoint", "TOPLEFT", button, "TOPLEFT", 1, -1)
    TryMethod(icon, "SetPoint", "BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    TryMethod(icon, "SetTexCoord", 0.1, 0.9, 0.1, 0.9)
  end

  local floating = Region(button, "FloatingBG")
  if CanUseRegion(floating) then TryMethod(floating, "Hide") end

  local hotkey = Region(button, "HotKey", "HotKey")
  if CanUseRegion(hotkey) then
    ApplyFont(hotkey, 11)
    TryMethod(hotkey, "SetAlpha", barsCfg.showHotkey == false and 0 or 1)
  end

  local name = Region(button, "Name", "Name")
  if CanUseRegion(name) then
    ApplyFont(name, 10)
    TryMethod(name, "SetAlpha", barsCfg.showMacroName == true and 1 or 0)
  end

  local count = Region(button, "Count", "Count")
  if CanUseRegion(count) then
    ApplyFont(count, 11)
    TryMethod(count, "SetAlpha", barsCfg.showStackCount == false and 0 or 1)
  end

  local cooldown = Region(button, "Cooldown", "cooldown") or Region(button, "Cooldown", "Cooldown")
  if CanUseRegion(cooldown) then
    TryMethod(cooldown, "SetSwipeColor", 0, 0, 0, barsCfg.showCooldown == false and 0 or 0.8)
  end

  return true
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
      ApplyButtonSkin(rawget(_G, prefix .. i))
    end
  end
  ApplyButtonSkin(rawget(_G, "ExtraActionButton1"))
  local zoneAbility = rawget(_G, "ZoneAbilityFrame")
  if CanUseRegion(zoneAbility) then
    local got, spellButton = TryGet(zoneAbility, "SpellButton")
    if got == true then ApplyButtonSkin(spellButton) end
  end
end

local actionMixin = rawget(_G, "ActionBarActionButtonMixin")
if type(actionMixin) == "table" and type(actionMixin.OnLoad) == "function" and type(hooksecurefunc) == "function" then
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
