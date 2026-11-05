local function expect(value, message)
  if not value then error(message, 2) end
end
_G.issecretvalue = function() return false end
_G.canaccessvalue = function() return true end
_G.canaccesstable = function() return true end
_G.UnitName = function() return "Tester" end
_G.UnitClass = function() return "Priest", "PRIEST" end
_G.C_SpecializationInfo = { GetSpecialization = function() return 1 end }
_G.InCombatLockdown = function() return false end
_G.CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
local reloads = 0
_G.ReloadUI = function() reloads = reloads + 1 end
local ns = { persistence = {} }
for _, path in ipairs({ "core/safety.lua", "core/persistence_runtime_state.lua", "core/config_persistence_owner.lua" }) do
  assert(loadfile(path))("Roth_UI", ns)
end
ns.configPersistence.InitializeConfigDefaults({ units = {} })
assert(loadfile("core/persistence_root_store.lua"))("Roth_UI", ns)
local reconcileHook
ns.store.GetPersistenceDescriptors = function() return {} end
ns.store.ReconcileStores = function()
  if reconcileHook then
    local hook = reconcileHook
    reconcileHook = nil
    hook()
  end
  return { driftAccepted = true }
end
ns.store.SanitizeStores = function() end
ns.GetPersistenceSchemaNodeKeys = function() return {} end
assert(loadfile("core/persistence_control_plane.lua"))("Roth_UI", ns)
local persistence = ns.persistence
local function payload(marker)
  return { accountRoot = { account = { settings = { marker = marker }, templates = {} } } }
end

local nestedReset, nestedImport, nestedExport, nestedReconcile
reconcileHook = function()
  nestedReset = persistence.ResetAndReload()
  nestedImport = persistence.ApplyTransferRootsAndReload(payload("nested"))
  nestedExport = persistence.GetTransferRoots("full")
  nestedReconcile = persistence.Reconcile()
end
expect(persistence.ApplyTransferRootsAndReload(payload("outer")) == true, "outer transaction failed")
expect(nestedReset == false and nestedImport == false, "reentrant callback started a second root mutation")
expect(nestedExport == nil and nestedReconcile == nil, "reentrant callback observed or reconciled intermediate roots")
expect(Roth_UI_DB.account.settings.marker == "outer" and reloads == 1,
  "nested work changed the committed result or reloaded twice")

local before = Roth_UI_DB
reconcileHook = function() error("injected rejection") end
expect(persistence.ApplyTransferRootsAndReload(payload("rejected")) == false,
  "failing reconciliation reported success")
expect(Roth_UI_DB == before, "failed transaction lost exact root identity")
expect(persistence.ApplyTransferRootsAndReload(payload("recovered")) == true,
  "failed transaction retained its exclusive lock")
expect(Roth_UI_DB.account.settings.marker == "recovered", "later transaction did not commit")
expect(type(persistence.GetTransferRoots("full")) == "table", "export remained blocked after cleanup")
print("persistence reentrancy and exclusive-lock cleanup test: OK")
