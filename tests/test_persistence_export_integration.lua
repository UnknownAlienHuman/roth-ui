local function expect(value, message)
  if not value then error(message, 2) end
end

local denied
_G.issecretvalue = function() return false end
_G.canaccessvalue = function() return true end
_G.canaccesstable = function(value) return value ~= denied end
_G.UnitName = function() return "Tester" end
_G.UnitClass = function() return "Priest", "PRIEST" end
_G.C_SpecializationInfo = { GetSpecialization = function() return 1 end }
_G.InCombatLockdown = function() return false end
_G.CreateFrame = function()
  return { RegisterEvent = function() end, SetScript = function() end }
end

-- Use the actual config owner, root store and strict copier. An isolated facade
-- stub cannot detect migration hidden behind a supposedly read-only getter.
local ns = { persistence = {} }
for _, path in ipairs({ "core/safety.lua", "core/persistence_runtime_state.lua",
    "core/config_persistence_owner.lua" }) do
  assert(loadfile(path))("Roth_UI", ns)
end
ns.configPersistence.InitializeConfigDefaults({ units = { player = { size = 100 } } })
assert(loadfile("core/persistence_root_store.lua"))("Roth_UI", ns)
ns.store.GetPersistenceDescriptors = function() return {} end
ns.store.ReconcileStores = function() error("export must not reconcile") end
ns.store.SanitizeStores = function() error("export must not sanitize") end
ns.GetPersistenceSchemaNodeKeys = function() return {} end
assert(loadfile("core/persistence_control_plane.lua"))("Roth_UI", ns)
local export = ns.persistence.GetTransferRoots
local account, character = Roth_UI_DB, Roth_UI_DB_Char

account.schema, character.schema = nil, nil
local full = assert(export("full"))
expect(Roth_UI_DB == account and Roth_UI_DB_Char == character, "export replaced root identity")
expect(account.schema == nil and character.schema == nil, "export repaired live schema metadata")
expect(full.accountRoot ~= account and full.charRoot ~= character, "export exposed a live root")
full.accountRoot.account.settings.units.player.size = 999
expect(account.account.settings.units.player.size == 100, "export retained a nested live reference")

local originalAccount = account.account
account.account = nil
export("account")
expect(account.account == nil and account.schema == nil, "export rebuilt a missing account shape")
account.account = originalAccount

Roth_UI_DB_Char = nil
expect(export("full") == nil and export("char") == nil, "missing selected root produced an incomplete export")
expect(Roth_UI_DB_Char == nil, "export seeded a missing character root")
expect(type(export("account")) == "table", "account-only export depended on the unselected character root")
Roth_UI_DB_Char = false
expect(export("char") == nil and Roth_UI_DB_Char == false, "export repaired a wrong-type character root")
Roth_UI_DB_Char = character

local calls = 0
Roth_UI_DB = setmetatable({}, { __index = function() calls = calls + 1; error("runtime proxy") end })
expect(export("account") == nil and calls == 0, "export evaluated an untrusted metatable")
expect(getmetatable(Roth_UI_DB) ~= nil, "export stripped a live metatable")
Roth_UI_DB = account

denied = account
expect(export("account") == nil, "export traversed a table denied by the table-access predicate")
denied = nil
local shared = {}
account.account.settings.shared, character.orbs.shared = shared, shared
expect(export("full") == nil, "export accepted an alias spanning both roots")
expect(account.account.settings.shared == shared and character.orbs.shared == shared,
  "failed export modified the shared live graph")
account.account.settings.shared, character.orbs.shared = nil, nil
expect(type(export("full")) == "table", "failed export prevented a later ordinary export")
print("real-owner immutable export and failed-read recovery test: OK")
