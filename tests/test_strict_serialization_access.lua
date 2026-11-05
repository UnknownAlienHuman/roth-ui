local function expect(value, message)
  if not value then error(message, 2) end
end
local denied, nextCalls
local nativeNext = next
_G.next = function(value, key)
  if value == denied then nextCalls = nextCalls + 1 end
  return nativeNext(value, key)
end
_G.issecretvalue = function() return false end
_G.canaccessvalue = function() return true end
_G.canaccesstable = function(value) return value ~= denied end
local ns = {}
assert(loadfile("core/safety.lua"))("Roth_UI", ns)
local copy = ns.safety.CopySerializableStrict

denied, nextCalls = { hidden = true }, 0
expect(copy(denied) == nil and nextCalls == 0,
  "denied table was probed before the table-access gate")
expect(copy({ child = denied }) == nil and nextCalls == 0,
  "nested denied table bypassed the table-access gate")
denied = nil

local reads = 0
local proxy = setmetatable({}, {
  __index = function() reads = reads + 1; error("runtime object") end,
  __pairs = function() reads = reads + 1; error("runtime iterator") end,
})
expect(copy(proxy) == nil and copy({ child = proxy }) == nil,
  "strict serializer accepted a root or nested metatable")
expect(reads == 0, "strict serializer executed a metatable callback")
expect(copy(setmetatable({}, { __metatable = false })) == nil,
  "strict serializer accepted a protected metatable sentinel")
expect(copy(setmetatable({ x = 1 }, {})) == nil, "strict serializer accepted an inert metatable")
local source = { enabled = false, count = 2, child = { label = "ordinary" } }
local result = assert(copy(source))
expect(result ~= source and result.child ~= source.child and result.enabled == false
    and result.child.label == "ordinary", "ordinary detached copy regressed")
_G.next = nativeNext
print("strict serialization table-access and metatable rejection test: OK")
