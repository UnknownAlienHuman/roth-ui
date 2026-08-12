-- Roth_UI custom oUF element: RareIcon / target border.
-- Needed when using external oUF, because this element is not part of upstream oUF.

local addon, ns = ...
local oUF = (ns and (ns.oUF or _G.oUF)) or _G.oUF
if not oUF then return end

local IsSecretValue = (ns and ns.safety and ns.safety.IsSecret) or function(v)
  local fn = _G.issecretvalue or _G.IsSecretValue
  return type(fn) == "function" and fn(v) or false
end

local function Update(self, event, unit)
  if unit ~= self.unit then return end
  local qicon = self.RareIcon
  if not qicon then return end

  if qicon.PreUpdate then
    qicon:PreUpdate()
  end

  local class = UnitClassification(unit)
  if IsSecretValue(class) then class = nil end
  local level = UnitLevel(unit)
  local isBossLevel = (not IsSecretValue(level) and level == -1)

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
  return Path(element.__owner, "ForceUpdate", element.__owner.unit)
end

local function Enable(self)
  local qicon = self.RareIcon
  if qicon then
    qicon.__owner = self
    qicon.ForceUpdate = ForceUpdate
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
