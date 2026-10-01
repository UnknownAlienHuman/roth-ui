local function fail(message)
  error(message, 2)
end

local function expect(condition, message)
  if not condition then fail(message) end
end

local secretValues = setmetatable({}, { __mode = "k" })
_G.issecretvalue = function(value) return secretValues[value] == true end
_G.canaccessvalue = function(value) return secretValues[value] ~= true end
_G.canaccessallvalues = function(...) return true end

local ns = {}
assert(loadfile("core/safety.lua"))("Roth_UI", ns)
assert(loadfile("core/safety_aspects.lua"))("Roth_UI", ns)
local safety = assert(ns.safety)

local aspect = 2048
local ordinary = {
  HasAccessConstraints = function() return false end,
  IsForbidden = function() return false end,
  HasAnyForbiddenAspects = function(_, value) return value == 4096 end,
}
local restricted = {
  HasAccessConstraints = function() return false end,
  IsForbidden = function() return false end,
  HasAnyForbiddenAspects = function(_, value) return value == aspect end,
}
local legacy = {
  HasAccessConstraints = function() return false end,
  IsForbidden = function() return false end,
}
local broken = {
  HasAccessConstraints = function() return false end,
  IsForbidden = function() return false end,
  HasAnyForbiddenAspects = function() error("expected") end,
}

expect(safety.HasForbiddenAspect(ordinary, aspect) == false,
  "ordinary region reported a forbidden aspect")
expect(safety.CanUseRegionFor(ordinary, aspect) == true,
  "ordinary region was rejected for an allowed operation")
expect(safety.HasForbiddenAspect(restricted, aspect) == true,
  "operation-specific forbidden aspect was not detected")
expect(safety.CanUseRegionFor(restricted, aspect) == false,
  "operation-specific forbidden region was accepted")
expect(safety.HasForbiddenAspect(legacy, aspect) == false,
  "legacy region without the query API was rejected")
expect(safety.HasForbiddenAspect(broken, aspect) == true,
  "failed forbidden-aspect query did not fail closed")
expect(safety.HasForbiddenAspect(nil, aspect) == true,
  "nil region did not fail closed")
expect(safety.HasForbiddenAspect(ordinary, nil) == true,
  "nil aspect did not fail closed")

print("forbidden-aspect safety test: OK")
