local function expect(condition, message)
  if not condition then error(message, 2) end
end

_G.floor = math.floor
_G.unpack = table.unpack or unpack
_G.InCombatLockdown = function() return false end
_G.IsShiftKeyDown = function() return false end
_G.IsControlKeyDown = function() return false end
_G.IsAltKeyDown = function() return false end
_G.CreateFrame = function() error("mover input test must not allocate frames", 2) end
_G.GameTooltip = nil
_G.Enum = {
  ForbiddenAspect = {
    UntrustedLayoutScriptExecution = 8,
  },
}

local blocked = {}
local secret = {}
local forbiddenTables = setmetatable({}, { __mode = "k" })
_G.issecretvalue = function(value) return value == secret end
_G.canaccessvalue = function(value) return value ~= blocked end
_G.canaccessallvalues = function(...)
  for index = 1, select("#", ...) do
    if select(index, ...) == blocked then return false end
  end
  return true
end
_G.canaccesstable = function(value) return forbiddenTables[value] ~= true end

local originalTonumber = tonumber
_G.tonumber = function(value, base)
  if value == blocked then
    error("restricted mover value reached tonumber", 2)
  end
  return originalTonumber(value, base)
end

local function Region(name)
  local frame = {
    name = name,
    point = nil,
    scale = 1,
    width = 100,
    height = 40,
  }
  function frame:HasAccessConstraints() return false end
  function frame:CanBeAccessedInContext() return true end
  function frame:IsForbidden() return false end
  function frame:HasAnyForbiddenAspects(aspect)
    return aspect == Enum.ForbiddenAspect.UntrustedLayoutScriptExecution
      and self.layoutRestricted == true
  end
  function frame:GetName() return self.name end
  function frame:GetNumPoints()
    if self.numPoints ~= nil then return self.numPoints end
    return self.point and 1 or 0
  end
  function frame:GetPoint()
    if not self.point then return nil end
    return unpack(self.point)
  end
  function frame:ClearAllPoints()
    self.point = nil
    self.clearCalls = (self.clearCalls or 0) + 1
  end
  function frame:SetPoint(...)
    local args = { ... }
    self.setPointCalls = (self.setPointCalls or 0) + 1
    if self.failPoint == args[1] then
      self.failPoint = nil
      error("synthetic SetPoint failure")
    end
    self.point = args
  end
  function frame:GetScale() return self.scale end
  function frame:SetScale(value)
    self.scaleCalls = (self.scaleCalls or 0) + 1
    self.scale = value
  end
  function frame:GetSize() return self.width, self.height end
  function frame:SetSize(width, height)
    self.sizeCalls = (self.sizeCalls or 0) + 1
    self.width, self.height = width, height
  end
  return frame
end

_G.UIParent = Region("UIParent")
_G.RestrictedAnchor = Region("RestrictedAnchor")
_G.RestrictedAnchor.layoutRestricted = true

local store = {}
local function pathKey(path) return table.concat(path, ".") end
local ns = {
  cfg = {},
  func = {
    IsSecretValue = _G.issecretvalue,
  },
  store = {
    GetConfigValue = function(path) return store[pathKey(path)] end,
    SetConfigValue = function(path, value) store[pathKey(path)] = value end,
  },
  framePolicy = {
    DeferForObject = function() return false end,
  },
}

assert(loadfile("core/safety.lua"))("Roth_UI", ns)
assert(loadfile("core/safety_aspects.lua"))("Roth_UI", ns)
assert(loadfile("core/mover_runtime.lua"))("Roth_UI", ns)

local frame = Region("Roth_TestMover")
_G.Roth_TestMover = frame
frame.point = { "CENTER", UIParent, "CENTER", 11, 12 }

local pointPath = "movers.point.Roth_TestMover"
local scalePath = "movers.scale.Roth_TestMover"
local sizePath = "movers.size.Roth_TestMover"

store[pointPath] = { a1 = "TOP", af = "UIParent", a2 = "TOP", x = blocked, y = 2 }
local ok, failure = pcall(ns.ApplySavedMoverLayout, frame, { size = false, scale = false })
expect(ok, "restricted point raised instead of being rejected: " .. tostring(failure))
expect(frame.point[1] == "CENTER" and frame.point[4] == 11,
  "restricted point mutated the frame")

store[pointPath] = { a1 = "NOT_A_POINT", af = "UIParent", a2 = "CENTER", x = 1, y = 2 }
ns.ApplySavedMoverLayout(frame, { size = false, scale = false })
expect(frame.point[1] == "CENTER" and frame.point[4] == 11,
  "invalid anchor point mutated the frame")

local forbiddenPoint = { a1 = "TOP", af = "UIParent", a2 = "TOP", x = 1, y = 2 }
forbiddenTables[forbiddenPoint] = true
store[pointPath] = forbiddenPoint
ns.ApplySavedMoverLayout(frame, { size = false, scale = false })
expect(frame.point[1] == "CENTER" and frame.point[4] == 11,
  "inaccessible point table mutated the frame")

store[pointPath] = { a1 = "TOP", af = "RestrictedAnchor", a2 = "TOP", x = 3, y = 4 }
ns.ApplySavedMoverLayout(frame, { size = false, scale = false })
expect(frame.point[1] == "TOP" and frame.point[2] == UIParent and frame.point[4] == 3,
  "restricted anchor did not fall back to UIParent")

store[pointPath] = { a1 = "BOTTOM", af = "Roth_TestMover", a2 = "BOTTOM", x = 5, y = 6 }
ns.ApplySavedMoverLayout(frame, { size = false, scale = false })
expect(frame.point[1] == "BOTTOM" and frame.point[2] == UIParent,
  "self anchor was not replaced with UIParent")


frame.point = { "CENTER", UIParent, "CENTER", 31, 32 }
frame.numPoints = 2
store[pointPath] = { a1 = "TOP", af = "UIParent", a2 = "TOP", x = 1, y = 2 }
ns.ApplySavedMoverLayout(frame, { size = false, scale = false })
expect(frame.point[1] == "CENTER" and frame.point[4] == 31,
  "multi-anchor frame lost geometry through a partial rollback snapshot")
frame.numPoints = nil

frame.point = { "CENTER", UIParent, "CENTER", 21, 22 }
frame.failPoint = "TOPLEFT"
store[pointPath] = { a1 = "TOPLEFT", af = "UIParent", a2 = "TOPLEFT", x = 7, y = 8 }
ns.ApplySavedMoverLayout(frame, { size = false, scale = false })
expect(frame.point[1] == "CENTER" and frame.point[2] == UIParent
    and frame.point[4] == 21 and frame.point[5] == 22,
  "failed SetPoint did not restore the previous anchor transaction")

store[scalePath] = 0 / 0
store[sizePath] = { w = math.huge, h = 60 }
local oldScale, oldWidth, oldHeight = frame.scale, frame.width, frame.height
ns.ApplySavedMoverLayout(frame, { point = false })
expect(frame.scale == oldScale and frame.width == oldWidth and frame.height == oldHeight,
  "non-finite mover geometry reached native setters")

print("mover persisted-input access, anchor and rollback test: OK")
