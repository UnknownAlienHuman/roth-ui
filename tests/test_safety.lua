local function fail(message)
  error(message, 2)
end

local function expect(condition, message)
  if not condition then fail(message) end
end

local secretValues = setmetatable({}, { __mode = "k" })
local inaccessibleValues = {}
local function MarkSecret(value)
  secretValues[value] = true
  return value
end

_G.issecretvalue = function(value)
  return secretValues[value] == true
end
_G.canaccessvalue = function(value)
  return secretValues[value] ~= true and inaccessibleValues[value] ~= true
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
expect(safety.CopySerializableStrict(source) == nil,
  "strict copy accepted a table with secret/unsupported/cyclic descendants")
local strictCopy = safety.CopySerializableStrict({ nested = { value = 2 } })
expect(strictCopy.nested.value == 2, "strict copy rejected a complete serializable tree")
expect(strictCopy ~= source and strictCopy.nested ~= source.nested,
  "strict copy retained an input table reference")
expect(safety.CopySerializableStrict({ callback = function() end }) == nil,
  "strict copy accepted a function descendant")
expect(safety.CopySerializableStrict({ value = 0 / 0 }) == nil,
  "strict copy accepted NaN")
expect(safety.CopySerializableStrict({ value = math.huge }) == nil,
  "strict copy accepted positive infinity")
expect(safety.CopySerializableStrict({ value = -math.huge }) == nil,
  "strict copy accepted negative infinity")
expect(safety.CopySerializableStrict({ [math.huge] = "invalid key" }) == nil,
  "strict copy accepted an infinite numeric key")
local deep = {}
local cursor = deep
for _ = 1, 66 do cursor.child = {}; cursor = cursor.child end
expect(safety.CopySerializableStrict(deep) == nil, "strict copy accepted depth overflow")

local dirty = {
  keep = 1,
  hidden = secret,
  callback = function() end,
  nested = { value = 2 },
}
expect(safety.SanitizeSerializableInPlace(dirty) == true, "in-place sanitization failed")
expect(dirty.keep == 1 and dirty.nested.value == 2, "sanitization removed ordinary data")
expect(dirty.hidden == nil and dirty.callback == nil, "sanitization retained unsafe data")

local inaccessibleKey = "inaccessible-root-key"
inaccessibleValues[inaccessibleKey] = true
local atomicChild = { unsupported = function() end }
local atomicRoot = { child = atomicChild, [inaccessibleKey] = true }
expect(safety.SanitizeSerializableInPlace(atomicRoot) == false,
  "sanitizer accepted an inaccessible direct key")
expect(atomicRoot.child == atomicChild and atomicChild.unsupported ~= nil,
  "failed root scan partially applied queued removals")
inaccessibleValues[inaccessibleKey] = nil

local badNestedKey = "inaccessible-nested-key"
inaccessibleValues[badNestedKey] = true
local nestedRoot = { safe = 7, unsafeBranch = { [badNestedKey] = true } }
expect(safety.SanitizeSerializableInPlace(nestedRoot) == true,
  "unsafe child branch incorrectly failed the whole root scan")
expect(nestedRoot.safe == 7 and nestedRoot.unsafeBranch == nil,
  "unsafe child branch was not removed atomically")
local sharedDirty = { keep = true, unsupported = function() end }
local aliasedRoot = { { sharedDirty, [badNestedKey] = true }, sharedDirty }
expect(safety.SanitizeSerializableInPlace(aliasedRoot) == true,
  "rejected parent branch prevented sanitation of a valid shared child")
expect(aliasedRoot[1] == nil and aliasedRoot[2] == sharedDirty
    and sharedDirty.keep == true and sharedDirty.unsupported == nil,
  "discarded branch lost cleanup needed by a retained shared child")
inaccessibleValues[badNestedKey] = nil

local numericKeys = { [1] = "keep", [math.huge] = "drop", [-math.huge] = "drop" }
expect(safety.SanitizeSerializableInPlace(numericKeys) == true,
  "sanitizer rejected finite root data with non-finite numeric keys")
expect(numericKeys[1] == "keep" and numericKeys[math.huge] == nil and numericKeys[-math.huge] == nil,
  "sanitizer retained non-finite numeric keys")

local selfCycle = { value = true }
selfCycle.self = selfCycle
local mutualLeft, mutualRight = {}, {}
mutualLeft.right = mutualRight
mutualRight.left = mutualLeft
local shared = { value = 9 }
local graph = { self = selfCycle, left = mutualLeft, right = mutualRight, first = shared, second = shared }
expect(safety.SanitizeSerializableInPlace(graph) == true,
  "sanitizer rejected cyclic branches instead of cutting their edges")
expect(selfCycle.self == nil, "self-cycle edge survived sanitation")
expect(not (mutualLeft.right and mutualLeft.right.left == mutualLeft),
  "mutual cycle retained a back edge")
expect(graph.first == shared and graph.second == shared,
  "sanitizer broke valid shared child identity")

local depthRoot, depthCursor = {}, nil
depthCursor = depthRoot
for _ = 1, 21 do depthCursor.child = {}; depthCursor = depthCursor.child end
expect(safety.SanitizeSerializableInPlace(depthRoot) == true,
  "depth overflow in a child branch failed the root scan")
depthCursor = depthRoot
for _ = 1, 20 do depthCursor = depthCursor.child end
expect(depthCursor.child == nil, "depth-overflow child branch was retained")

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
local missingQuery = { IsForbidden = function() return false end }
local throwingQuery = {
  HasAccessConstraints = function() error("expected") end,
  IsForbidden = function() return false end,
}
local inaccessibleResult = {
  HasAccessConstraints = function() return secret end,
  IsForbidden = function() return false end,
}
local nonBooleanConstraint = {
  HasAccessConstraints = function() return 1 end,
  IsForbidden = function() return false end,
}
local nilForbidden = {
  HasAccessConstraints = function() return false end,
  IsForbidden = function() return nil end,
}
local nonBooleanAccess = {
  HasAccessConstraints = function() return true end,
  CanBeAccessedInContext = function() return 1 end,
  IsForbidden = function() return false end,
}

expect(safety.CanUseRegion(ordinaryRegion) == true, "ordinary region was rejected")
expect(safety.CanUseRegion(allowedRegion) == true, "accessible constrained region was rejected")
expect(safety.CanUseRegion(deniedRegion) == false, "inaccessible constrained region was accepted")
expect(safety.CanUseRegion(forbiddenRegion) == false, "forbidden region was accepted")
expect(safety.CanUseRegion(missingQuery) == false, "missing access query did not fail closed")
expect(safety.CanUseRegion(throwingQuery) == false, "failed access query did not fail closed")
expect(safety.CanUseRegion(inaccessibleResult) == false, "inaccessible access result did not fail closed")
expect(safety.CanUseRegion(nonBooleanConstraint) == false, "non-boolean constraint result did not fail closed")
expect(safety.CanUseRegion(nilForbidden) == false, "nil forbidden result did not fail closed")
expect(safety.CanUseRegion(nonBooleanAccess) == false, "non-boolean access result did not fail closed")

local ok, value = safety.TryCall(function() return 7 end)
expect(ok == true and value == 7, "TryCall lost ordinary result")
local failed = safety.TryCall(function() error("expected") end)
expect(failed == false, "TryCall did not contain an error")

print("safety boundary test: OK")
