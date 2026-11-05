local function expect(value, message)
  if not value then error(message, 2) end
end

_G.issecretvalue = function() return false end
_G.canaccessvalue = function() return true end
_G.STANDARD_TEXT_FONT = "font"
_G.AnchorUtil = { FlowLayoutAxis = { Horizontal = 1, Vertical = 2 } }
_G.AuraContainerSortMethod = { UnitFrameDebuff = 2, ExpirationOnly = 5 }
_G.AuraContainerSortDirection = { Normal = 0 }
_G.C_Spell = { DoesSpellExist = function() return true end }
_G.UnitClass = function() return "Priest", "PRIEST" end
local inCombat = false
_G.InCombatLockdown = function() return inCombat end

local initCallback, deferred
local ns = {
  cfg = { simpleAuras = {}, playerclass = "PRIEST" },
  func = { IsSecretValue = function() return false end },
  oUF = { colors = { dispel = {} } },
  framePolicy = { DeferForObject = function(_, _, callback)
    deferred = callback
    return true
  end },
}
function ns.oUF:RegisterInitCallback(callback) initCallback = callback end
assert(loadfile("core/safety.lua"))("Roth_UI", ns)
assert(loadfile("core/aura_runtime.lua"))("Roth_UI", ns)

local function newFrame()
  local frame = { visible = false, allowed = true, colors = { dispel = {} }, creates = 0, hooks = 0, updates = 0, elements = {} }
  function frame:HasAccessConstraints() return not self.allowed end
  function frame:CanBeAccessedInContext() return self.allowed end
  function frame:IsForbidden() return false end
  function frame:IsVisible() return self.visible end
  function frame:HookScript(_, callback) self.hooks = self.hooks + 1; self.onShow = callback end
  function frame:IsElementEnabled() return self.enabled == true end
  -- oUF 14.2.1 elements/auras.lua: Enable does not assign a unit, and
  -- ouf.lua:EnableElement does nothing for an already active element.
  function frame:EnableElement()
    if self.enabled then return end
    self.enabled = true
    for _, element in ipairs(self.elements) do element:SetEnabled(true) end
  end
  function frame:UpdateAllElements(event)
    expect(event == "RothAuraCreated", "unexpected initialization update")
    self.updates = self.updates + 1
    for _, element in ipairs(self.elements) do element.unit = "target" end
  end
  function frame:CreateAuras()
    self.creates = self.creates + 1
    local element = { allowed = true, filters = 0 }
    self.elements[#self.elements + 1] = element
    function element:HasAccessConstraints() return not self.allowed end
    function element:CanBeAccessedInContext() return self.allowed end
    function element:IsForbidden() return false end
    function element:SetEnabled(value) self.enabled = value end
    function element:SetSize() end
    function element:SetPoint() end
    function element:AddGroup()
      if frame.failGroup then frame.failGroup = false; error("injected group failure") end
      return "group"
    end
    function element:SetAuraGroupCandidateFilters() self.filters = self.filters + 1 end
    return element
  end
  return frame
end

local function queue(frame, id, filters)
  local spec = { id = id, filter = "HARMFUL", size = 16, maxFrameCount = 1, candidateFilters = filters }
  expect(ns.func.QueueAuraRegion(frame, spec), "spec rejected")
  return spec
end

local failures = {}
local function case(name, callback)
  inCombat, deferred = false, nil
  local ok, message = pcall(callback)
  if not ok then failures[#failures + 1] = name .. ": " .. tostring(message) end
end

case("hidden before combat drain", function()
  local frame = newFrame()
  local spec = queue(frame, "first")
  initCallback(frame)
  frame.visible, inCombat = true, true
  frame.onShow(frame)
  expect(type(deferred) == "function" and frame.creates == 0, "combat creation was not deferred")
  frame.visible, inCombat = false, false
  deferred()
  expect(frame.creates == 0, "hidden owner allocated managed aura objects from stale work")
  frame.visible = true
  frame.onShow(frame)
  expect(frame.creates == 1, "later visible owner did not initialize exactly once")
  expect(spec.element.unit == "target" and spec.element.enabled and frame.updates == 1,
    "late-created container was not activated and assigned through oUF")
end)

case("late registration and idempotent attachment", function()
  local frame = newFrame()
  queue(frame, "first")
  frame.visible = true
  initCallback(frame)
  initCallback(frame)
  expect(frame.hooks == 1, "repeated initialization attached duplicate OnShow hooks")
  local second = queue(frame, "second")
  expect(frame.creates == 2 and second.element ~= nil, "late spec was hidden by the completed flag")
  expect(second.element.enabled and second.element.unit == "target" and frame.updates == 2,
    "adding a region to an active Auras element left it disabled or unassigned")
  frame.onShow(frame)
  expect(frame.creates == 2 and frame.updates == 2, "completed regions were rebuilt or refreshed")
end)

case("creation failure isolation", function()
  local frame = newFrame()
  local first = queue(frame, "failed")
  local second = queue(frame, "healthy")
  frame.failGroup, frame.visible = true, true
  initCallback(frame)
  expect(frame.__rothAuraRegionsCreating == nil, "failure stranded the creation lock")
  expect(first.creationFailed == true and second.element ~= nil, "one failed region blocked a healthy sibling")
  expect(frame.creates == 2, "unexpected allocation count after partial failure")
  frame.onShow(frame)
  expect(frame.creates == 2 and frame.updates == 1,
    "failed adoption retried allocation or refreshed a healthy sibling again")
end)

case("current object access at deferred execution", function()
  local frame = newFrame()
  queue(frame, "first")
  initCallback(frame)
  frame.visible, inCombat = true, true
  frame.onShow(frame)
  frame.allowed, inCombat = false, false
  deferred()
  expect(frame.creates == 0, "deferred work used an owner denied in its current context")
  frame.allowed = true
  frame.onShow(frame)
  expect(frame.creates == 1, "denied deferred work prevented later permitted initialization")
end)

case("filter setter object boundary", function()
  local frame = newFrame()
  local generation = "initial"
  local spec = queue(frame, "filters", function() return nil, generation end)
  frame.visible = true
  initCallback(frame)
  spec.element.allowed, generation = false, "changed"
  ns.func.RefreshAuraFilters(frame)
  expect(spec.element.filters == 0 and spec.candidateFingerprint == "initial",
    "denied container was mutated or marked refreshed")
  spec.element.allowed = true
  ns.func.RefreshAuraFilters(frame)
  expect(spec.element.filters == 1 and spec.candidateFingerprint == "changed",
    "permitted configuration refresh did not recover")
end)

expect(#failures == 0, table.concat(failures, "\n"))
print("managed aura stale-work, adoption-failure and access tests: OK")
