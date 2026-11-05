local function expect(condition, message)
  if not condition then error(message, 2) end
end

_G.UIParent = {}
local attached = 0
local ns = {
  cfg = {},
  func = {
    IsSecretValue = function() return false end,
    AttachCombatFader = function() attached = attached + 1 return true end,
    applyDragFunctionality = function() end,
  },
  safety = {
    IsSecret = function() return false end,
    CanAccess = function() return true end,
  },
}
assert(loadfile("core/bars.lua"))("Roth_UI", ns)
expect(type(ns.bars) == "table", "bar constructors did not load through the direct fader owner")
expect(_G.rCombatFrameFader == nil, "bar constructors rely on a retired global fader alias")
expect(attached == 0, "bar module attached a fader during namespace load")

print("bar direct fader owner test: OK")
