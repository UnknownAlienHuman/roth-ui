local function expect(value, message)
  if not value then error(message, 2) end
end
local noop = function() end
_G.issecretvalue = function() return false end
_G.canaccessvalue = function() return true end
_G.canaccessallvalues = function() return true end
_G.InCombatLockdown = function() return false end
_G.LibStub = function() return { Register = noop } end
local attach
local ns = {
  cfg = { font = "font.ttf" },
  frameRegistry = { Register = noop },
  framePolicy = { DeferForObject = function() return false end },
  oUF = { RegisterInitCallback = function(_, callback) attach = callback end },
}
assert(loadfile("core/safety.lua"))("Roth_UI", ns)
assert(loadfile("core/lib.lua"))("Roth_UI", ns)
local owner = { visible = false, hooks = 0, creations = 0, updates = 0 }
function owner:IsVisible() return self.visible end
function owner:HookScript(_, callback) self.onShow = callback; self.hooks = self.hooks + 1 end
function owner:IsElementEnabled() return self.enabled == true end
function owner:EnableElement(name)
  expect(name == "Portrait", "wrong element enabled")
  self.enabled = true
  -- Pinned oUF Enable installs ForceUpdate and shows the model, but does not
  -- call Update/SetUnit. The late owner must request the first element update.
  self.Portrait.ForceUpdate = function()
    self.updates = self.updates + 1
    self.Portrait.assigned = true
  end
end
owner.__rothPortraitFactory = function()
  owner.creations = owner.creations + 1
  return {}
end
attach(owner)
attach(owner)
expect(owner.hooks == 1, "portrait lifecycle attached twice")
expect(owner.creations == 0, "hidden portrait eagerly created")
owner.visible = true
owner.onShow(owner)
expect(owner.Portrait.assigned and owner.updates == 1,
  "late portrait enabled but never assigned its current unit")
owner.onShow(owner)
expect(owner.creations == 1 and owner.updates == 1, "repeated show rebuilt or refreshed portrait")
print("lazy portrait first-update and single-attachment test: OK")
