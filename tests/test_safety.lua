local function fail(message)
  error(message, 2)
end

local function expect(condition, message)
  if not condition then fail(message) end
end

local secretValues = setmetatable({}, { __mode = "k" })
local function MarkSecret(value)
  secretValues[value] = true
  return value
end

_G.issecretvalue = function(value)
  return secretValues[value] == true
end
_G.canaccessvalue = function(value)
  return secretValues[value] ~= true
end
_G.canaccessallvalues = function(...)
  for index = 1, select("#", ...) do
    if secretValues[select(index, ...)] == true then return false end
  end
  return true
end

local ns = {}
assert(loadfile("core/safety.lua"))("Roth_UI", ns)
local safety = assert(ns.safety)

local secret = MarkSecret({ token = "hidden" })
expect(safety.IsSecret(secret) == true, "secret marker was not detected")
expect(safety.CanAccess(secret) == false, "secret value was reported accessible")
expect(safety.CanAccessAll(1, "two", secret) == false, "tuple gate ignored a secret value")
expect(safety.CanAccessAll(1, "two", false) == true, "ordinary tuple was rejected")

local cyclic = { value = 3 }
cyclic.self = cyclic
local source = {
  ordinary = 1,
  nested = { value = 2 },
  hidden = secret,
  callback = function() end,
  cyclic = cyclic,
}
local copy = safety.CopySerializable(source)
expect(type(copy) == "table", "ordinary table was not copied")
expect(copy.ordinary == 1 and copy.nested.value == 2, "ordinary values were lost")
expect(copy.hidden == nil, "secret value crossed serialization boundary")
expect(copy.callback == nil, "function crossed serialization boundary")
expect(copy.cyclic.value == 3 and copy.cyclic.self == nil, "cycle was not cut safely")

local dirty = {
  keep = 1,
  hidden = secret,
  callback = function() end,
  nested = { value = 2 },
}
expect(safety.SanitizeSerializableInPlace(dirty) == true, "in-place sanitization failed")
expect(dirty.keep == 1 and dirty.nested.value == 2, "sanitization removed ordinary data")
expect(dirty.hidden == nil and dirty.callback == nil, "sanitization retained unsafe data")

local ordinaryRegion = {
  HasAccessConstraints = function() return false end,
  IsForbidden = function() return false end,
}
local allowedRegion = {
  HasAccessConstraints = function() return true end,
  CanBeAccessedInContext = function() return true end,
  IsForbidden = function() return false end,
}
local deniedRegion = {
  HasAccessConstraints = function() return true end,
  CanBeAccessedInContext = function() return false end,
  IsForbidden = function() return false end,
}
local forbiddenRegion = {
  HasAccessConstraints = function() return false end,
  IsForbidden = function() return true end,
}

expect(safety.CanUseRegion(ordinaryRegion) == true, "ordinary region was rejected")
expect(safety.CanUseRegion(allowedRegion) == true, "accessible constrained region was rejected")
expect(safety.CanUseRegion(deniedRegion) == false, "inaccessible constrained region was accepted")
expect(safety.CanUseRegion(forbiddenRegion) == false, "forbidden region was accepted")

local ok, value = safety.TryCall(function() return 7 end)
expect(ok == true and value == 7, "TryCall lost ordinary result")
local failed = safety.TryCall(function() error("expected") end)
expect(failed == false, "TryCall did not contain an error")

print("safety boundary test: OK")
