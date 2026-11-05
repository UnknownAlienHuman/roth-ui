local function expect(condition, message)
  if not condition then error(message, 2) end
end

_G.issecretvalue = function() return false end
local blockedKey
_G.canaccessvalue = function(value) return blockedKey == nil or value ~= blockedKey end
_G.canaccessallvalues = function() return true end

local ns = {}
assert(loadfile("core/safety.lua"))("Roth_UI", ns)
local safety = ns.safety

local shared = { value = 7 }
expect(safety.CopySerializableStrict({ first = shared, second = shared }) == nil,
  "strict serialization accepted a shared-reference graph")

local loose = safety.CopySerializable({ first = shared, second = shared })
expect(type(loose) == "table" and loose.first == loose.second,
  "migration-oriented copy stopped preserving ordinary shared identity")

local ordinary = safety.CopySerializableStrict({ first = { value = 7 }, second = { value = 7 } })
expect(type(ordinary) == "table" and ordinary.first ~= ordinary.second,
  "strict serialization rejected an ordinary tree")

blockedKey = "restricted-key"
local invalidShared = { [blockedKey] = true, keep = 9 }
local looseRejected = safety.CopySerializable({ first = invalidShared, second = invalidShared })
expect(type(looseRejected) == "table" and looseRejected.first == nil and looseRejected.second == nil,
  "failed loose-copy branch leaked a partial memoized alias")

print("strict serialization alias test: OK")
