local function expect(condition, message)
  if not condition then error(message, 2) end
end
_G.STANDARD_TEXT_FONT = "font"
_G.AnchorUtil = { FlowLayoutAxis = { Horizontal = 1, Vertical = 2 } }
_G.AuraContainerSortMethod = { UnitFrameDebuff = 2, ExpirationOnly = 5 }
_G.AuraContainerSortDirection = { Normal = 0 }
_G.C_Spell = { DoesSpellExist = function() return true end }
_G.UnitClass = function() return "Priest", "PRIEST" end
_G.issecretvalue = function() return false end
_G.canaccessvalue = function() return true end
local inCombat = false
_G.InCombatLockdown = function() return inCombat end
local initCallback, deferred
local ns = {
  oUF = {
    colors = { dispel = {} }, objects = {},
    RegisterInitCallback = function(_, callback) initCallback = callback end,
  },
  cfg = { simpleAuras = { durationText = false, cooldownSwipe = true }, playerclass = "PRIEST" },
  func = { IsSecretValue = function() return false end, ResolveFontPath = function(value) return value end },
  framePolicy = { DeferForObject = function(_, _, callback) deferred = callback; return true end },
}
assert(loadfile("core/safety.lua"))("Roth_UI", ns)
assert(loadfile("core/aura_runtime.lua"))("Roth_UI", ns)
expect(type(initCallback) == "function", "oUF init callback was not registered")
local createCount, groupCount, enableCount, updateCount = 0, 0, 0, 0
local onShow
local frame = { colors = { dispel = {} }, cfg = { style = "target", auras = { show = true } }, visible = false }
function frame:IsVisible() return self.visible end
function frame:HasAccessConstraints() return false end
function frame:IsForbidden() return false end
function frame:HookScript(script, callback)
  expect(script == "OnShow", "unexpected lifecycle hook")
  onShow = callback
end
function frame:CreateAuras()
  createCount = createCount + 1
  local element = {}
  function element:HasAccessConstraints() return false end
  function element:IsForbidden() return false end
  function element:SetSize() end
  function element:SetPoint() end
  function element:SetAlpha() end
  function element:SetEnabled() end
  function element:AddGroup() groupCount = groupCount + 1; return "Group1" end
  function element:AddSlot() return "Slot1" end
  function element:SetAuraGroupCandidateFilters() end
  return element
end
function frame:IsElementEnabled() return self.enabled == true end
function frame:EnableElement(name)
  expect(name == "Auras", "unexpected element enabled")
  self.enabled = true
  enableCount = enableCount + 1
end
function frame:UpdateAllElements(event)
  expect(event == "RothAuraCreated", "unexpected initial unit-assignment update")
  updateCount = updateCount + 1
end
expect(ns.func.QueueAuraRegion(frame, {
  id = "test", filter = "HARMFUL", size = 16, maxFrameCount = 5, width = 80, height = 16,
}) == true, "spec was not queued")
expect(createCount == 0, "queueing a spec allocated an AuraContainer")
initCallback(frame)
expect(type(onShow) == "function" and createCount == 0, "hidden frame did not retain lazy first-show lifecycle")
inCombat, frame.visible = true, true
onShow(frame)
expect(createCount == 0 and type(deferred) == "function", "combat first-show was not deferred")
inCombat = false
deferred()
expect(createCount == 1 and groupCount == 1, "deferred first-show did not create exactly one container and group")
expect(enableCount == 1 and updateCount == 1, "late-created Auras were not enabled and assigned through oUF")
onShow(frame)
expect(createCount == 1 and groupCount == 1 and updateCount == 1, "repeated OnShow rebuilt or refreshed managed auras")
deferred, inCombat = nil, true
onShow(frame)
expect(deferred == nil, "completed aura setup queued needless combat-exit work")
print("lazy managed aura lifecycle test: OK")
