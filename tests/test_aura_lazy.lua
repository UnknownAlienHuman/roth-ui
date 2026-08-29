local function fail(message)
  error(message, 2)
end
local function expect(condition, message)
  if not condition then fail(message) end
end

_G.STANDARD_TEXT_FONT = "font"
_G.AnchorUtil = { FlowLayoutAxis = { Horizontal = 1, Vertical = 2 } }
_G.AuraContainerSortMethod = { UnitFrameDebuff = 2, ExpirationOnly = 5 }
_G.AuraContainerSortDirection = { Normal = 0 }
_G.C_Spell = { DoesSpellExist = function() return true end }
_G.UnitClass = function() return "Priest", "PRIEST" end

local inCombat = false
_G.InCombatLockdown = function() return inCombat end

local initCallback
local oUF = {
  colors = { dispel = {} },
  objects = {},
  RegisterInitCallback = function(self, callback) initCallback = callback end,
}

local deferred
local ns = {
  oUF = oUF,
  cfg = { simpleAuras = { durationText = false, cooldownSwipe = true }, playerclass = "PRIEST" },
  func = {
    IsSecretValue = function() return false end,
    ResolveFontPath = function(value) return value end,
  },
  framePolicy = {
    DeferUntilOutOfCombat = function(key, callback)
      deferred = callback
      return true
    end,
  },
}

assert(loadfile("core/aura_runtime.lua"))("Roth_UI", ns)
expect(type(initCallback) == "function", "oUF init callback was not registered")

local createCount, groupCount, enableCount = 0, 0, 0
local onShow
local frame = {
  colors = { dispel = {} },
  cfg = { style = "target", auras = { show = true } },
}
function frame:IsVisible() return false end
function frame:HookScript(script, callback)
  expect(script == "OnShow", "unexpected lifecycle hook")
  onShow = callback
end
function frame:CreateAuras()
  createCount = createCount + 1
  local element = {}
  function element:SetSize() end
  function element:SetPoint() end
  function element:SetAlpha() end
  function element:AddGroup()
    groupCount = groupCount + 1
    return "Group1"
  end
  function element:AddSlot() return "Slot1" end
  function element:SetAuraGroupCandidateFilters() end
  return element
end
function frame:IsElementEnabled() return false end
function frame:EnableElement(name)
  expect(name == "Auras", "unexpected element enabled")
  enableCount = enableCount + 1
end

expect(ns.func.QueueAuraRegion(frame, {
  id = "test",
  filter = "HARMFUL",
  size = 16,
  maxFrameCount = 5,
  width = 80,
  height = 16,
}) == true, "spec was not queued")
expect(createCount == 0, "queueing a spec allocated an AuraContainer")

initCallback(frame)
expect(type(onShow) == "function", "first-show lifecycle was not attached")
expect(createCount == 0, "hidden frame allocated an AuraContainer during init")

inCombat = true
onShow(frame)
expect(createCount == 0, "combat first-show allocated an AuraContainer")
expect(type(deferred) == "function", "combat first-show was not deferred")

inCombat = false
deferred()
expect(createCount == 1, "deferred first-show did not create exactly one AuraContainer")
expect(groupCount == 1, "deferred first-show did not create exactly one group")
expect(enableCount == 1, "late-created Auras element was not enabled")

onShow(frame)
expect(createCount == 1 and groupCount == 1, "repeated OnShow rebuilt managed auras")

print("lazy managed aura lifecycle test: OK")
