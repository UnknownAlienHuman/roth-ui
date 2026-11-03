local function expect(condition, message)
  if not condition then error(message, 2) end
end

local secretValues = setmetatable({}, { __mode = "k" })
local function MarkSecret(value)
  secretValues[value] = true
  return value
end

local roots = {
  config = { nested = { value = 1 } },
  orbChar = { HEALTH = { color = { r = 0.25 }, toggle = false } },
  orbGlobal = { __selection = { HEALTH = "saved" } },
}
local ns = {
  safety = {
    IsSecret = function(value) return secretValues[value] == true end,
    CanAccess = function(value) return secretValues[value] ~= true end,
    IsForbiddenTable = function() return false end,
    IsSerializablePrimitive = function(value)
      local kind = type(value)
      return kind == "string" or kind == "number" or kind == "boolean"
    end,
    CopySerializable = function(value)
      if type(value) ~= "table" then return value end
      local copy = {}
      for key, child in pairs(value) do
        if type(child) == "table" then
          local nested = {}
          for nestedKey, nestedValue in pairs(child) do nested[nestedKey] = nestedValue end
          copy[key] = nested
        else
          copy[key] = child
        end
      end
      return copy
    end,
    CopySerializableStrict = function(value)
      local seen = {}
      local function copyStrict(source, depth)
        if depth > 64 then return nil end
        local kind = type(source)
        if secretValues[source] then return nil end
        if kind == "string" or kind == "number" or kind == "boolean" then return source end
        if kind ~= "table" or seen[source] then return nil end
        seen[source] = true
        local result = {}
        for key, child in pairs(source) do
          if type(key) ~= "string" and type(key) ~= "number" then return nil end
          local copied = copyStrict(child, depth + 1)
          if copied == nil then return nil end
          result[key] = copied
        end
        seen[source] = nil
        return result
      end
      return copyStrict(value, 0)
    end,
  },
  store = {},
  GetRuntimePersistenceState = function() return {} end,
}
ns.store.GetDomainRoot = function(domain) return roots[domain] end
ns.store.SetDomainRoot = function(domain, root) roots[domain] = root return true end
ns.store.GetConfigRoot = function() return roots.config end
ns.db = {
  GetOrbDefaults = function()
    return { HEALTH = { color = { r = 0.5 }, toggle = true } }
  end,
}

assert(loadfile("core/sv_store.lua"))("Roth_UI", ns)

local view = ns.SVGet({ "nested" })
view.value = 99
expect(roots.config.nested.value == 1, "SVGet table result mutated persisted config")

view = ns.store.ReadPath(roots.config, { "nested" })
view.value = 77
expect(roots.config.nested.value == 1, "ReadPath table result mutated persisted config")

view = ns.store.GetOrbConfigValue("HEALTH", { "color" })
view.r = 0.9
expect(roots.orbChar.HEALTH.color.r == 0.25, "orb config value read mutated persisted orb data")
expect(ns.store.GetOrbConfigValue("HEALTH", { "toggle" }, true) == false,
  "saved false orb option did not override true default")

view = ns.store.GetOrbGlobalValue({ "__selection" })
view.HEALTH = "changed"
expect(roots.orbGlobal.__selection.HEALTH == "saved", "orb global value read mutated persisted template selection")

local missingDefault = { nested = { flag = true } }
view = ns.SVGet({ "missing" }, missingDefault)
view.nested.flag = false
expect(missingDefault.nested.flag == true, "SVGet returned a mutable table default")

local hotPath = ns.store.GetOrbConfig("HEALTH")
hotPath.color.r = 0.7
expect(roots.orbChar.HEALTH.color.r == 0.7, "GetOrbConfig hot-path reference contract unexpectedly changed")

local oldValue = roots.config.nested
local invalid = { hidden = function() end }
expect(ns.SVSet({ "nested" }, invalid) == false, "invalid nested table write was accepted")
expect(roots.config.nested == oldValue and roots.config.nested.value == 1,
  "invalid nested table write replaced the persisted value")
local cyclicWrite = { value = 2 }
cyclicWrite.self = cyclicWrite
expect(ns.SVSet({ "nested" }, cyclicWrite) == false, "cyclic table write was accepted")
expect(roots.config.nested == oldValue, "cyclic write damaged the persisted value")
expect(ns.SVSet({ "nested" }, { hidden = MarkSecret({ token = "secret" }) }) == false,
  "nested secret table write was accepted")
expect(roots.config.nested == oldValue, "nested secret write damaged the persisted value")
local tooDeep = {}
local tooDeepCursor = tooDeep
for _ = 1, 66 do tooDeepCursor.child = {}; tooDeepCursor = tooDeepCursor.child end
expect(ns.SVSet({ "nested" }, tooDeep) == false, "depth-overflow table write was accepted")
expect(roots.config.nested == oldValue, "depth-overflow write damaged the persisted value")
expect(ns.SVSet({ function() end }, 2) == false, "function path key was accepted")
expect(ns.SVSet({ MarkSecret("hidden") }, 2) == false, "secret path key was accepted")
expect(roots.config.nested == oldValue, "invalid path write damaged the persisted value")

print("SavedVariables read isolation test: OK")
