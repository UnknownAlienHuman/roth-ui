local function expect(condition, message)
  if not condition then error(message, 2) end
end

_G.issecretvalue = function() return false end
_G.canaccessvalue = function() return true end
_G.canaccessallvalues = nil

local ns = { safety = {} }
assert(loadfile("core/safety.lua"))("Roth_UI", ns)
local copyStrict = assert(ns.safety.CopySerializableStrict)

local ordinary = { alpha = "one", nested = { beta = 2 } }
local copied = copyStrict(ordinary, {
  maxDepth = 4,
  maxTables = 4,
  maxEntries = 4,
  maxStringBytes = 32,
})
expect(type(copied) == "table" and copied ~= ordinary and copied.nested ~= ordinary.nested,
  "bounded strict copy rejected an ordinary detached tree")

expect(copyStrict({ a = 1, b = 2, c = 3 }, { maxEntries = 2 }) == nil,
  "strict copy ignored the entry budget")
expect(copyStrict({ a = {}, b = {} }, { maxTables = 2 }) == nil,
  "strict copy ignored the table budget")
expect(copyStrict({ key = "12345" }, { maxStringBytes = 7 }) == nil,
  "strict copy ignored the aggregate string-byte budget")
expect(copyStrict({ nested = { deeper = { value = true } } }, { maxDepth = 1 }) == nil,
  "strict copy ignored the depth budget")

local shared = {}
expect(copyStrict({ first = shared, second = shared }) == nil,
  "strict copy accepted a shared-reference graph")
local cyclic = {}
cyclic.self = cyclic
expect(copyStrict(cyclic) == nil, "strict copy accepted a cycle")

print("strict serialization budget test: OK")
