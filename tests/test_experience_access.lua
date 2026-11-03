local function expect(ok, message)
  if not ok then error(message, 2) end
end

local restrictedNumber = 907
local update
local enable
local ns = {
  safety = { CanAccess = function(value) return value ~= restrictedNumber end },
  cfg = { units = { player = { expbar = { show = true } } } },
  QueueActionBarArtworkRefresh = function() end,
}
local oUF = { AddElement = function(_, name, callback, enableCallback)
  expect(name == "Experience", "unexpected custom element")
  update, enable = callback, enableCallback
end }
ns.oUF = oUF
_G.UnitHasVehicleUI = function() return false end
_G.IsXPUserDisabled = function() return false end
_G.UnitLevel = function() return 70 end
_G.GetMaxLevelForPlayerExpansion = function() return 80 end
_G.UnitXP = function() return restrictedNumber end
_G.UnitXPMax = function() return restrictedNumber end
_G.GetXPExhaustion = function() return restrictedNumber end

assert(loadfile("oUF/elements/experience.lua"))("Roth_UI", ns)
local values = {}
local element = {
  SetMinMaxValues = function(_, min, max) values.min, values.max = min, max end,
  SetValue = function(_, value) values.current = value end,
  Show = function() end,
  Hide = function() end,
}
function element:IsObjectType() return true end
function element:GetStatusBarTexture() return true end
local frame = { __unit = "player", cfg = { expbar = { show = true } }, Experience = element }
function frame:RegisterEvent() end
function frame:UnregisterEvent() end
expect(enable(frame, "player") == true, "experience element did not enable")
update(frame, "PLAYER_ENTERING_WORLD")
expect(values.current == 0, "inaccessible XP current reached the StatusBar")
expect(values.max == 1, "inaccessible XP maximum reached the StatusBar")
expect(element.Rested == nil, "unexpected rested widget appeared")

print("experience value access-boundary test: OK")
