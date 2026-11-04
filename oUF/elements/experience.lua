local _, ns = ...

local oUF = (ns and (ns.oUF or _G.oUF)) or _G.oUF
if not oUF then
  return
end

local type = type
local math_min = math.min
local UnitXP = UnitXP
local UnitXPMax = UnitXPMax
local GetXPExhaustion = GetXPExhaustion
local UnitHasVehicleUI = UnitHasVehicleUI
local CanAccess = assert(ns.safety and ns.safety.CanAccess, "Roth_UI: value access guard is required")

local function PlayerHasVehicleUI()
  if type(UnitHasVehicleUI) ~= "function" then return false end
  local value = UnitHasVehicleUI("player")
  return CanAccess(value) and value == true
end
local UnitLevel = UnitLevel
local IsXPUserDisabled = IsXPUserDisabled
local GetMaxLevelForPlayerExpansion = GetMaxLevelForPlayerExpansion

local function AccessibleNumber(value, fallback)
  if not CanAccess(value) or type(value) ~= "number" then
    return fallback
  end
  return value
end

local function IsEnabledInConfig(self)
  local frameCfg = self and self.cfg
  local expCfg = frameCfg and frameCfg.expbar
  if type(expCfg) == "table" then
    return expCfg.show ~= false
  end
  local globalCfg = ns and ns.cfg
  local units = globalCfg and globalCfg.units
  local playerCfg = units and units.player
  local cfg = playerCfg and playerCfg.expbar
  if type(cfg) == "table" then
    return cfg.show ~= false
  end
  return true
end

local function IsPlayerAtMaxLevel()
  if type(IsXPUserDisabled) == "function" then
    local disabled = IsXPUserDisabled()
    if CanAccess(disabled) and disabled == true then return true end
  end

  local level = type(UnitLevel) == "function" and UnitLevel("player") or nil
  level = AccessibleNumber(level)
  if level == nil then
    return false
  end

  local maxLevel = type(GetMaxLevelForPlayerExpansion) == "function" and GetMaxLevelForPlayerExpansion() or nil
  maxLevel = AccessibleNumber(maxLevel)
  if maxLevel == nil then
    maxLevel = _G.MAX_PLAYER_LEVEL
  end
  maxLevel = AccessibleNumber(maxLevel)
  if maxLevel == nil then
    return false
  end

  return level >= maxLevel
end

local function RefreshActionBarArtwork(self)
  if ns and type(ns.QueueActionBarArtworkRefresh) == "function" then
    ns.QueueActionBarArtworkRefresh()
    return
  end
  if ns and type(ns.RefreshActionBarArtwork) == "function" then
    ns.RefreshActionBarArtwork()
    return
  end
  local artwork = self and self.ActionBarBackground
  local refresh = artwork and artwork.RefreshActionBarArtwork
  if type(refresh) == "function" then
    refresh(artwork)
  end
end

local function SetVisibility(self, element, shouldShow)
  local previous = element.__rothActive == true
  if shouldShow then
    element.__rothActive = true
    element:Show()
  else
    element.__rothActive = false
    element:Hide()
    if element.Rested then
      element.Rested:Hide()
    end
  end

  if previous ~= shouldShow and type(element.PostVisibility) == "function" then
    element:PostVisibility(shouldShow)
  end

  return previous ~= shouldShow
end

local function Update(self, event, unit)
  -- Unitless events carry booleans (world entry) or numbers (level-up),
  -- not unit tokens. Only unit-event payloads participate in this filter.
  if event == "PLAYER_XP_UPDATE" or event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
    if not CanAccess(unit) or unit ~= self.__unit then return end
  end

  local experience = self.Experience
  if not experience then
    return
  end

  if type(experience.PreUpdate) == "function" then
    experience:PreUpdate(self.__unit)
  end

  local shouldShow = IsEnabledInConfig(self)
    and not IsPlayerAtMaxLevel()
    and not PlayerHasVehicleUI()

  local visibilityChanged = SetVisibility(self, experience, shouldShow)
  if not shouldShow then
    if visibilityChanged then RefreshActionBarArtwork(self) end
    return
  end

  local current = type(UnitXP) == "function" and UnitXP(self.__unit) or 0
  local maximum = type(UnitXPMax) == "function" and UnitXPMax(self.__unit) or 0
  current = AccessibleNumber(current, 0)
  maximum = AccessibleNumber(maximum, 0)
  if maximum <= 0 then
    maximum = 1
  end

  experience:SetMinMaxValues(0, maximum)
  experience:SetValue(current)

  local restedExhaustion = type(GetXPExhaustion) == "function" and GetXPExhaustion() or nil
  restedExhaustion = AccessibleNumber(restedExhaustion)
  if experience.Rested then
    if type(restedExhaustion) == "number" and restedExhaustion > 0 then
      experience.Rested:SetMinMaxValues(0, maximum)
      experience.Rested:SetValue(math_min(current + restedExhaustion, maximum))
      experience.Rested:Show()
    else
      experience.Rested:Hide()
    end
  end

  if type(experience.PostUpdate) == "function" then
    experience:PostUpdate(self.__unit, current, maximum, restedExhaustion)
  end

  if visibilityChanged then
    RefreshActionBarArtwork(self)
  end
end

local function Path(self, ...)
  return (self.Experience.Override or Update)(self, ...)
end

local function ForceUpdate(element)
  return Path(element.__owner, "ForceUpdate", element.__owner.__unit)
end

local function Enable(self, unit)
  local experience = self.Experience
  if not experience or unit ~= "player" then
    return
  end

  experience.__owner = self
  experience.ForceUpdate = ForceUpdate

  if experience:IsObjectType("StatusBar") and not experience:GetStatusBarTexture() then
    experience:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
  end

  if experience.Rested then
    if experience.Rested:IsObjectType("StatusBar") and not experience.Rested:GetStatusBarTexture() then
      experience.Rested:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
    end
    experience.Rested:SetFrameLevel(experience:GetFrameLevel() - 1)
  end

  self:RegisterEvent("PLAYER_ENTERING_WORLD", Path, true)
  -- Use the general event route and filter its documented unitTarget payload
  -- in Update, without relying on native RegisterUnitEvent support.
  self:RegisterEvent("PLAYER_XP_UPDATE", Path, true)
  self:RegisterEvent("PLAYER_LEVEL_UP", Path, true)
  self:RegisterEvent("UPDATE_EXHAUSTION", Path, true)
  self:RegisterEvent("ENABLE_XP_GAIN", Path, true)
  self:RegisterEvent("DISABLE_XP_GAIN", Path, true)
  self:RegisterEvent("UNIT_ENTERED_VEHICLE", Path)
  self:RegisterEvent("UNIT_EXITED_VEHICLE", Path)

  return true
end

local function Disable(self)
  local experience = self.Experience
  if not experience then
    return
  end

  experience.__rothActive = false
  experience:Hide()
  if experience.Rested then
    experience.Rested:Hide()
  end

  self:UnregisterEvent("PLAYER_ENTERING_WORLD", Path)
  self:UnregisterEvent("PLAYER_XP_UPDATE", Path)
  self:UnregisterEvent("PLAYER_LEVEL_UP", Path)
  self:UnregisterEvent("UPDATE_EXHAUSTION", Path)
  self:UnregisterEvent("ENABLE_XP_GAIN", Path)
  self:UnregisterEvent("DISABLE_XP_GAIN", Path)
  self:UnregisterEvent("UNIT_ENTERED_VEHICLE", Path)
  self:UnregisterEvent("UNIT_EXITED_VEHICLE", Path)
end

oUF:AddElement("Experience", Path, Enable, Disable)
