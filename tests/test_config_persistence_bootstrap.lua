local function expect(condition, message)
  if not condition then error(message, 2) end
end

_G.issecretvalue = function() return false end
local deniedKey
_G.canaccessvalue = function(value) return value ~= deniedKey or deniedKey == nil end
_G.UnitName = function() return "Tester" end
_G.UnitClass = function() return "Warrior", "WARRIOR" end
_G.C_SpecializationInfo = { GetSpecialization = function() return 1 end }

local ns = { safety = {} }
assert(loadfile("core/safety.lua"))("Roth_UI", ns)
assert(loadfile("core/persistence_runtime_state.lua"))("Roth_UI", ns)
assert(loadfile("core/config_persistence_owner.lua"))("Roth_UI", ns)

-- LoadSavedVariablesFirst makes these declared roots available before the
-- first addon file initializes configuration and creates unit config views.
_G.Roth_UI_DB = {
  schema = { version = 1 },
  account = {
    settings = {
      units = {
        player = {
          size = 777,
          portrait = false,
          castbar = false,
        },
        party = { show = 0 },
        raid = { show = "blizzard" },
      },
    },
    templates = {},
  },
}
_G.Roth_UI_DB_Char = { schema = { version = 1 }, orbs = {} }

local defaults = {
  units = {
    player = {
      size = 100,
      portrait = { show = true },
      castbar = { show = true, hideDefault = true },
    },
    party = { show = true },
    raid = { show = true },
  },
  font = "default.ttf",
}
ns.configPersistence.InitializeConfigDefaults(defaults)

local playerView = assert(ns.GetUnitConfig("player"))
expect(playerView.size == 777,
  "first-file config view did not use values from the preloaded SavedVariables root")
expect(type(playerView.portrait) == "table" and playerView.portrait.show == true,
  "saved false at a default table path was not repaired from defaults")
expect(type(playerView.castbar) == "table" and playerView.castbar.show == false,
  "legacy castbar=false was not migrated before table-shape repair")
expect(ns.cfg.units.party.show == 0 and ns.cfg.units.raid.show == "blizzard",
  "legacy provider show values were overwritten during config reconciliation")

local malformedUnit = { units = { player = false } }
ns.ReconcileConfigStore(malformedUnit)
expect(type(malformedUnit.units.player) == "table" and malformedUnit.units.player.size == 100,
  "malformed units.player shape was not repaired")

local malformedPortrait = { units = { player = { portrait = false } } }
ns.ReconcileConfigStore(malformedPortrait)
expect(type(malformedPortrait.units.player.portrait) == "table"
    and malformedPortrait.units.player.portrait.show == true,
  "malformed nested portrait shape was not repaired")

local cyclic = { units = { player = { portrait = {} } } }
cyclic.units.player.loop = cyclic
expect(type(ns.ReconcileConfigStore(cyclic)) == "table",
  "cyclic legacy input prevented config reconciliation")
expect(cyclic.units.player.loop == nil,
  "cyclic legacy input was not sanitized before recursive default seeding")

deniedKey = "restricted-key"
local unreadableRoot = { [deniedKey] = true, child = { invalid = function() end } }
local recovered = ns.ReconcileConfigStore(unreadableRoot)
expect(recovered ~= unreadableRoot and recovered.units.player.size == 100,
  "failed sanitation exposed an unreadable root to runtime consumers")
expect(unreadableRoot.child.invalid ~= nil,
  "recovery partially changed the rejected root")
deniedKey = nil

_G.Roth_UI_DB = false
_G.Roth_UI_DB_Char = "malformed"
ns.configPersistence.InitializeConfigDefaults(defaults)
expect(ns.cfg.units.player.size == 100 and type(Roth_UI_DB_Char.orbs) == "table",
  "wrong-type SavedVariables roots did not initialize a complete default config")
ns.cfg.units.player.size = 222
ns.configPersistence.InitializeConfigDefaults(defaults)
expect(ns.GetUnitConfig("player").size == 222,
  "repeated initialization overwrote existing persisted values")

assert(loadfile("core/persistence_root_store.lua"))("Roth_UI", ns)
local replacement = {
  schema = { version = 1 },
  account = {
    settings = { units = { player = { size = 444 } } },
    templates = {},
  },
}
expect(ns.ReplacePersistenceRoots({ accountRoot = replacement }) == true,
  "ordinary account-root replacement was rejected")
expect(ns.store.GetConfigRoot().units.player.size == 444 and ns.cfg.units.player.size == 444,
  "root replacement did not rebind the config proxy to the canonical SavedVariables root")

print("config persistence bootstrap and malformed-shape test: OK")
