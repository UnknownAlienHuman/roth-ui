local function expect(value, message)
  if not value then error(message, 2) end
end

_G.issecretvalue = function() return false end
_G.canaccessvalue = function() return true end
_G.canaccesstable = function() return true end
_G.STANDARD_TEXT_FONT = "font"
_G.AnchorUtil = { FlowLayoutAxis = { Horizontal = 1, Vertical = 2 } }
_G.AuraContainerSortMethod = { UnitFrameDebuff = 2, ExpirationOnly = 5 }
_G.AuraContainerSortDirection = { Normal = 0 }
_G.C_Spell = { DoesSpellExist = function() return true end }
_G.UnitClass = function() return "Priest", "PRIEST" end
_G.InCombatLockdown = function() return false end

local initCallback
local ns = {
  cfg = { simpleAuras = {}, playerclass = "PRIEST" },
  func = { IsSecretValue = function() return false end },
  oUF = { colors = { dispel = {} } },
  framePolicy = { DeferForObject = function() return false end },
}
function ns.oUF:RegisterInitCallback(callback) initCallback = callback end
assert(loadfile("core/safety.lua"))("Roth_UI", ns)
assert(loadfile("core/aura_runtime.lua"))("Roth_UI", ns)

local frame = {
  visible = true,
  allowed = true,
  colors = { dispel = {} },
  creates = 0,
  updates = 0,
  elements = {},
}
function frame:HasAccessConstraints() return not self.allowed end
function frame:CanBeAccessedInContext() return self.allowed end
function frame:IsForbidden() return false end
function frame:IsVisible() return self.visible end
function frame:HookScript(_, callback) self.onShow = callback end
function frame:IsElementEnabled() return self.enabled == true end
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
  local element = { allowed = true }
  self.elements[#self.elements + 1] = element
  function element:HasAccessConstraints() return not self.allowed end
  function element:CanBeAccessedInContext() return self.allowed end
  function element:IsForbidden() return false end
  function element:SetEnabled(value) self.enabled = value end
  function element:SetSize() end
  function element:SetPoint() end
  function element:AddGroup()
    if frame.failNext then
      frame.failNext = false
      error("injected group failure")
    end
    return "group"
  end
  return element
end

local function queue(id)
  local spec = { id = id, filter = "HARMFUL", size = 16, maxFrameCount = 1 }
  expect(ns.func.QueueAuraRegion(frame, spec), "spec rejected: " .. id)
  return spec
end

local failed = queue("failed")
local healthy = queue("healthy")
frame.failNext = true
initCallback(frame)
expect(failed.creationFailed == true and healthy.element ~= nil,
  "terminal failure blocked a healthy sibling")
expect(frame.__rothAuraRegionsSettled == true,
  "completed success/failure batch did not enter terminal settled state")
expect(frame.creates == 2 and frame.updates == 1, "unexpected first-batch work")

for _ = 1, 50 do frame.onShow(frame) end
expect(frame.creates == 2 and frame.updates == 1,
  "terminal aura batch repeated allocation or owner refresh work")

local late = queue("late")
expect(late.element ~= nil and frame.__rothAuraRegionsSettled == true,
  "new specification did not open and settle one new creation batch")
expect(frame.creates == 3 and frame.updates == 2,
  "late specification repeated old work or missed its one update")

print("managed aura terminal creation-batch test: OK")
