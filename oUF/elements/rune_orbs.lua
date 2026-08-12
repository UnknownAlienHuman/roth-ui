local addonName, ns = ...

if select(2, UnitClass("player")) ~= "DEATHKNIGHT" then
  return
end

local oUF = (ns and (ns.oUF or _G.oUF)) or _G.oUF
if not oUF then
  return
end

local safety = ns and ns.safety
local IsSecretValue = safety and safety.IsSecret or function(v)
  local fn = _G.issecretvalue or _G.IsSecretValue
  return type(fn) == "function" and fn(v) or false
end

local floor = math.floor
local GetTime = GetTime
local GetRuneCooldown = GetRuneCooldown
local UnitHasVehicleUI = UnitHasVehicleUI
local UnitVehicleSkin = UnitVehicleSkin
local C_ActionBar = _G.C_ActionBar

local function HasVehicleActionBarCompat()
  return C_ActionBar and C_ActionBar.HasVehicleActionBar and C_ActionBar.HasVehicleActionBar() == true
end

local function HasOverrideActionBarCompat()
  return C_ActionBar and C_ActionBar.HasOverrideActionBar and C_ActionBar.HasOverrideActionBar() == true
end

local function GetOverrideBarSkinCompat()
  if not (C_ActionBar and C_ActionBar.GetOverrideBarSkin) then
    return nil
  end
  return C_ActionBar.GetOverrideBarSkin()
end

local genericRuneColors = {
  { 0, 1, 1 },
  { 0, 1, 1 },
  { 0, 1, 1 },
  { 1, 0, 1 },
}

local runemap = { 1, 2, 3, 4, 5, 6 }

local function GetColorRGB(color)
  if type(color) ~= "table" then
    return 1, 1, 1
  end
  if type(color.GetRGB) == "function" then
    return color:GetRGB()
  end
  return color.r or color[1] or 1, color.g or color[2] or 1, color.b or color[3] or 1
end

local function NormalizeRuneID(runeID)
  if runeID == nil or IsSecretValue(runeID) then
    return nil
  end
  local numeric = tonumber(runeID)
  if type(numeric) ~= "number" or numeric < 1 or numeric > 6 then
    return nil
  end
  return numeric
end

local function ResolveRuneColorRGB(altIndex)
  local specIndex = C_SpecializationInfo.GetSpecialization()
  local specID = specIndex and C_SpecializationInfo.GetSpecializationInfo(specIndex) or nil

  local color
  local colors = oUF and oUF.colors and oUF.colors.runes or nil
  if specID == 250 then
    color = (colors and colors[1]) or { r = 0.9686, g = 0.2549, b = 0.2235 }
  elseif specID == 251 then
    color = (colors and colors[2]) or { r = 0.5804, g = 0.7961, b = 0.9686 }
  elseif specID == 252 then
    color = (colors and colors[3]) or { r = 0.6784, g = 0.9216, b = 0.2588 }
  else
    color = genericRuneColors[altIndex] or { 1, 1, 1 }
  end

  return GetColorRGB(color)
end

local function RuneVisibility(self)
  local bar = self.RuneBar
  if not bar then
    return
  end

  local hasVehicle = (type(UnitHasVehicleUI) == "function" and UnitHasVehicleUI("player")) or false
  local hasVehicleBar = HasVehicleActionBarCompat()
  local hasOverrideBar = HasOverrideActionBarCompat()
  local vehicleSkin = type(UnitVehicleSkin) == "function" and UnitVehicleSkin("player") or nil
  local overrideSkin = GetOverrideBarSkinCompat()

  if hasVehicle
    or (hasVehicleBar and vehicleSkin and vehicleSkin ~= "")
    or (hasOverrideBar and overrideSkin and overrideSkin ~= 0) then
    bar:Hide()
  else
    bar:Show()
  end
end

local function OnUpdate(orb, elapsed)
  local duration = orb.duration + elapsed
  if duration >= orb.max then
    orb.fill:SetValue(1)
    orb.glow:Show()
    orb:SetScript("OnUpdate", nil)
    return
  end

  orb.duration = duration
  orb.fill:SetValue(duration)
end

local function UpdateType(self, _, runeID, altIndex)
  local normalizedRuneID = NormalizeRuneID(runeID) or runeID
  if IsSecretValue(normalizedRuneID) then
    return
  end

  local rune = self.RuneOrbs and self.RuneOrbs[runemap[normalizedRuneID]]
  if not rune then
    return
  end

  local r, g, b = ResolveRuneColorRGB(altIndex)
  rune.fill:SetStatusBarColor(r, g, b)
  rune.glow:SetVertexColor(r, g, b)
end

local function UpdateSpecialization(self, _, unitTarget)
  if unitTarget and unitTarget ~= "player" then
    return
  end

  for i = 1, 6 do
    UpdateType(self, nil, i, floor((i + 1) / 2))
  end
end

local function UpdateRune(self, _, runeID)
  local normalizedRuneID = NormalizeRuneID(runeID)
  if not normalizedRuneID then
    for i = 1, 6 do
      UpdateRune(self, nil, i)
    end
    return
  end

  local rune = self.RuneOrbs and self.RuneOrbs[runemap[normalizedRuneID]]
  if not rune then
    return
  end

  local startTime, duration, isReady = GetRuneCooldown(normalizedRuneID)
  if isReady then
    rune.fill:SetMinMaxValues(0, 1)
    rune.fill:SetValue(1)
    rune.glow:Show()
    rune:SetScript("OnUpdate", nil)
  elseif startTime and duration then
    rune.duration = GetTime() - startTime
    rune.max = duration
    rune.glow:Hide()
    rune.fill:SetMinMaxValues(1, duration)
    rune:SetScript("OnUpdate", OnUpdate)
  else
    -- GetRuneCooldown returned nil (rune system not yet ready); treat as ready
    rune.fill:SetMinMaxValues(0, 1)
    rune.fill:SetValue(1)
    rune.glow:Show()
    rune:SetScript("OnUpdate", nil)
  end
end

local function Update(self)
  for i = 1, 6 do
    UpdateRune(self, nil, i)
  end
end

local function ForceUpdate(element)
  local owner = element.__owner
  if not owner then
    return
  end
  RuneVisibility(owner)
  return Update(owner)
end

local function Enable(self, unit)
  local element = self.RuneOrbs
  if not element or unit ~= "player" then
    return
  end

  element.__owner = self
  element.ForceUpdate = ForceUpdate

  for i = 1, 6 do
    UpdateType(self, nil, i, floor((i + 1) / 2))
  end

  self:RegisterEvent("PLAYER_ENTERING_WORLD", RuneVisibility, true)
  self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", UpdateSpecialization, true)
  self:RegisterEvent("RUNE_POWER_UPDATE", UpdateRune, true)
  self:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR", RuneVisibility, true)
  self:RegisterEvent("UNIT_ENTERED_VEHICLE", RuneVisibility)
  self:RegisterEvent("UNIT_EXITED_VEHICLE", RuneVisibility)

  UpdateSpecialization(self, nil, "player")
  RuneVisibility(self)
  Update(self)
  return true
end

local function Disable(self)
  local element = self.RuneOrbs
  if not element then
    return
  end

  self:UnregisterEvent("PLAYER_ENTERING_WORLD", RuneVisibility)
  self:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED", UpdateSpecialization)
  self:UnregisterEvent("RUNE_POWER_UPDATE", UpdateRune)
  self:UnregisterEvent("UPDATE_OVERRIDE_ACTIONBAR", RuneVisibility)
  self:UnregisterEvent("UNIT_ENTERED_VEHICLE", RuneVisibility)
  self:UnregisterEvent("UNIT_EXITED_VEHICLE", RuneVisibility)
end

oUF:AddElement("RuneOrbs", Update, Enable, Disable)
