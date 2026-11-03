local function expect(ok, message)
  if not ok then error(message, 2) end
end

local inaccessible = {}
local unitCalls = 0
local registered
local oUF = {
  AddElement = function(_, name, update, enable)
    expect(name == "RareIcon", "custom element name changed")
    registered = { update = update, enable = enable }
  end,
}
local ns = {
  oUF = oUF,
  safety = {
    CanAccess = function(value) return value ~= inaccessible end,
    IsSecret = function() return false end,
  },
}
_G.UnitClassification = function() unitCalls = unitCalls + 1; return inaccessible end
_G.UnitLevel = function() unitCalls = unitCalls + 1; return inaccessible end
assert(loadfile("oUF/elements/target_border.lua"))("Roth_UI", ns)

local icon = { texture = nil, shown = false }
function icon:Show() self.shown = true end
function icon:Hide() self.shown = false end
function icon:SetTexture(value) self.texture = value end
local frame = { __unit = "target", RareIcon = icon }
function frame:RegisterEvent(_, callback) self.callback = callback end
function frame:UnregisterEvent() end
expect(registered.enable(frame) == true, "element failed to enable")
frame.callback(frame, "UNIT_CLASSIFICATION_CHANGED", "target")
expect(unitCalls == 2, "accessible unit was not evaluated")
expect(icon.texture:match("Interface\\AddOns\\Roth_UI\\media\\target$"),
  "inaccessible classification and level must use the ordinary target texture")

frame.callback(frame, "UNIT_CLASSIFICATION_CHANGED", inaccessible)
expect(unitCalls == 2, "inaccessible unit token reached classification APIs")

print("target border access-boundary test: OK")
