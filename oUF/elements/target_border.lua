-- Roth_UI custom oUF element: RareIcon / target border.
-- Needed when using external oUF, because this element is not part of upstream oUF.

local _, ns = ...
local oUF = assert(ns and ns.oUF, "Roth_UI: ns.oUF is required by target_border.lua")
local safety = assert(ns and ns.safety, "Roth_UI: ns.safety is required by target_border.lua")
local IsSecretValue = assert(safety.IsSecret, "Roth_UI: safety.IsSecret is required by target_border.lua")
local CanAccess = assert(safety.CanAccess, "Roth_UI: safety.CanAccess is required by target_border.lua")

local function Update(self, event, unit)
  if not CanAccess(unit) then return end
  if unit ~= self.__unit then return end
  local qicon = self.RareIcon
  if not qicon then return end

  if qicon.PreUpdate then
    qicon:PreUpdate()
  end

  local class = UnitClassification(unit)
  if not CanAccess(class) or IsSecretValue(class) then class = nil end
  local level = UnitLevel(unit)
  local isBossLevel = CanAccess(level) and not IsSecretValue(level) and level == -1

  if class == "worldboss" or class == "rare" or class == "rareelite" or isBossLevel then
    qicon:SetTexture("Interface\\AddOns\\Roth_UI\\media\\target_boss")
  elseif class == "elite" then
    qicon:SetTexture("Interface\\AddOns\\Roth_UI\\media\\target_elite")
  else
    -- normal / trivial / minus etc.
    qicon:SetTexture("Interface\\AddOns\\Roth_UI\\media\\target")
  end

  if qicon.PostUpdate then
    qicon:PostUpdate()
  end
end

local function Path(self, ...)
  return (self.RareIcon.Override or Update)(self, ...)
end

local function ForceUpdate(element)
  return Path(element.__owner, "ForceUpdate", element.__owner.__unit)
end

local function Enable(self)
  local qicon = self.RareIcon
  if qicon then
    qicon.__owner = self
    qicon.ForceUpdate = ForceUpdate
    qicon:Show()
    self:RegisterEvent("UNIT_CLASSIFICATION_CHANGED", Path)
    return true
  end
end

local function Disable(self)
  if self.RareIcon then
    self.RareIcon:Hide()
    self:UnregisterEvent("UNIT_CLASSIFICATION_CHANGED", Path)
  end
end

oUF:AddElement("RareIcon", Path, Enable, Disable)
