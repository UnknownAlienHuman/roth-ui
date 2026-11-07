local function expect(condition, message)
  if not condition then error(message, 2) end
end

_G.issecretvalue = function() return false end
_G.canaccessvalue = function() return true end
_G.canaccesstable = function() return true end
_G.UnitName = function() return "Tester" end
_G.UnitClass = function() return "Warrior", "WARRIOR" end
_G.C_SpecializationInfo = { GetSpecialization = function() return 1 end }

local ns = { safety = {} }
assert(loadfile("core/safety.lua"))("Roth_UI", ns)
assert(loadfile("core/persistence_runtime_state.lua"))("Roth_UI", ns)
assert(loadfile("core/config_persistence_owner.lua"))("Roth_UI", ns)

local shared = { value = 7 }
_G.Roth_UI_DB = {
  schema = { version = 1 },
  account = {
    settings = {
      units = {
        player = { left = shared, right = shared },
      },
    },
    templates = {},
  },
}
_G.Roth_UI_DB_Char = { schema = { version = 1 }, orbs = {} }

local defaults = { units = { player = { left = {}, right = {} } } }
ns.configPersistence.InitializeConfigDefaults(defaults)

local first = assert(ns.GetUnitConfig("player"))
local second = assert(ns.GetUnitConfig("player"))
expect(not rawequal(first, second),
  "unit config views were retained in a global source-to-proxy cache")
expect(rawequal(first.left, first.right),
  "one read-only proxy graph did not preserve shared descendant identity")
expect(not rawequal(first.left, second.left),
  "separate view graphs unexpectedly shared cached descendants")

local tostringCalls = 0
local hostileKey = setmetatable({}, {
  __tostring = function()
    tostringCalls = tostringCalls + 1
    error("hostile key was stringified")
  end,
})
local ok, message = pcall(function() first[hostileKey] = true end)
expect(ok == false and tostring(message):find("runtime config view is read%-only") ~= nil,
  "read-only write did not fail with the fixed owner message")
expect(tostringCalls == 0, "read-only rejection stringified an arbitrary key")

assert(loadfile("core/persistence_root_store.lua"))("Roth_UI", ns)
local source = _G.Roth_UI_DB.account.settings.units.player
local weak = setmetatable({ source, first }, { __mode = "v" })
local replacement = {
  schema = { version = 1 },
  account = {
    settings = { units = { player = { left = {}, right = {} } } },
    templates = {},
  },
}
expect(ns.store.CommitRoots({ accountRoot = replacement }) == true,
  "replacement root commit failed")
source, first, second = nil, nil, nil
for _ = 1, 4 do collectgarbage("collect") end
expect(weak[1] == nil and weak[2] == nil,
  "replaced config source/proxy graph remained retained after root replacement")

print("read-only config view lifetime test: OK")
