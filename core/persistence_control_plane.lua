local _, ns = ...
local InCombatLockdown = InCombatLockdown

-- Keep the public persistence facade and lifecycle bootstrap out of sv_store.lua.
local safety = assert(ns and ns.safety, "Roth_UI: ns.safety is required by persistence_control_plane.lua")
local CopySerializableStrict = assert(safety.CopySerializableStrict,
  "Roth_UI: safety.CopySerializableStrict is required by persistence_control_plane.lua")
local CanAccess = assert(safety.CanAccess,
  "Roth_UI: safety.CanAccess is required by persistence_control_plane.lua")
local TryCall = assert(safety.TryCall, "Roth_UI: safety.TryCall is required by persistence_control_plane.lua")
local storeApi = assert(ns and ns.store, "Roth_UI: ns.store is required by persistence_control_plane.lua")
local runtimeApi = assert(ns and ns.persistenceRuntime, "Roth_UI: ns.persistenceRuntime is required by persistence_control_plane.lua")
local persistenceApi = assert(ns and ns.persistence, "Roth_UI: ns.persistence is required by persistence_control_plane.lua")
local GetCanonicalStores = assert(storeApi.GetCanonicalStores, "Roth_UI: store.GetCanonicalStores is required by persistence_control_plane.lua")
local GetPersistenceDescriptors = assert(storeApi.GetPersistenceDescriptors, "Roth_UI: store.GetPersistenceDescriptors is required by persistence_control_plane.lua")
local GetPersistenceSchemaNodeKeys = assert(ns and ns.GetPersistenceSchemaNodeKeys, "Roth_UI: ns.GetPersistenceSchemaNodeKeys is required by persistence_control_plane.lua")
local GetConfigRoot = assert(storeApi.GetConfigRoot, "Roth_UI: store.GetConfigRoot is required by persistence_control_plane.lua")
local CommitPersistenceRoots = assert(storeApi.CommitRoots, "Roth_UI: store.CommitRoots is required by persistence_control_plane.lua")
local ResetPersistenceRoots = assert(storeApi.ResetRoots, "Roth_UI: store.ResetRoots is required by persistence_control_plane.lua")
local RestorePersistenceRoots = assert(storeApi.RestoreRoots, "Roth_UI: store.RestoreRoots is required by persistence_control_plane.lua")
local ReconcilePersistenceStores = assert(storeApi.ReconcileStores, "Roth_UI: store.ReconcileStores is required by persistence_control_plane.lua")
local SanitizePersistenceStores = assert(storeApi.SanitizeStores, "Roth_UI: store.SanitizeStores is required by persistence_control_plane.lua")
local GetRuntimeDebugState = assert(runtimeApi.GetDebugState, "Roth_UI: persistenceRuntime.GetDebugState is required by persistence_control_plane.lua")
local ClearRuntimeLog = assert(runtimeApi.ClearLog, "Roth_UI: persistenceRuntime.ClearLog is required by persistence_control_plane.lua")
local GetRuntimePersistenceState = assert(runtimeApi.GetPersistenceState, "Roth_UI: persistenceRuntime.GetPersistenceState is required by persistence_control_plane.lua")
local GetRuntimeSVDoctorState = assert(runtimeApi.GetSVDoctorState, "Roth_UI: persistenceRuntime.GetSVDoctorState is required by persistence_control_plane.lua")

-- The control plane retains the mutation closures; later runtime modules must
-- not receive a second raw route around validation, snapshot and rollback.
storeApi.CommitRoots = nil
storeApi.ResetRoots = nil
storeApi.RestoreRoots = nil
storeApi.GetCanonicalStores = nil
storeApi.GetPersistenceStores = nil
storeApi.GetDomainRoot = nil
storeApi.SetDomainRoot = nil
storeApi.GetConfigRoot = nil
ns.GetPersistenceStores = nil
if type(ns.configPersistence) == "table" then
  ns.configPersistence.ReconcileConfigStore = nil
end

local function BuildPersistenceStorageLabel(variable, path, fallback)
  if type(variable) == "string" and variable ~= "" and type(path) == "string" and path ~= "" then
    return variable .. "." .. path
  end
  return fallback
end

local function BuildPersistenceNodePayload(nodes)
  return {
    nodes = type(nodes) == "table" and nodes or {},
  }
end

local function BuildScanStoreNodeMap(canonical)
  local nodes = {}
  local nodeKeys = GetPersistenceSchemaNodeKeys()
  for i = 1, #nodeKeys do
    local key = nodeKeys[i]
    if key == "config" then
      nodes[key] = type(canonical) == "table" and canonical.settings or nil
    elseif key == "orbChar" then
      nodes[key] = type(canonical) == "table" and canonical.orbChar or nil
    elseif key == "orbGlobal" then
      nodes[key] = type(canonical) == "table" and canonical.templates or nil
    end
  end
  return nodes
end

local function BuildStorageLabelNodeMap(descriptors)
  local desc = type(descriptors) == "table" and descriptors or {}
  local configNode = type(desc.config) == "table" and desc.config or {}
  local orbDescriptor = type(desc.orb) == "table" and desc.orb or {}
  local orbCharNode = type(orbDescriptor.char) == "table" and orbDescriptor.char or {}
  local orbGlobalNode = type(orbDescriptor.global) == "table" and orbDescriptor.global or {}
  local nodes = {}
  local nodeKeys = GetPersistenceSchemaNodeKeys()
  for i = 1, #nodeKeys do
    local key = nodeKeys[i]
    if key == "config" then
      nodes[key] = configNode.storageId or BuildPersistenceStorageLabel(configNode.variable, configNode.path, "Roth_UI_DB.account.settings")
    elseif key == "orbChar" then
      nodes[key] = orbCharNode.storageId or BuildPersistenceStorageLabel(orbCharNode.variable, orbCharNode.path, "Roth_UI_DB_Char.orbs")
    elseif key == "orbGlobal" then
      nodes[key] = orbGlobalNode.storageId or BuildPersistenceStorageLabel(orbGlobalNode.variable, orbGlobalNode.path, "Roth_UI_DB.account.templates")
    end
  end
  return nodes
end

local function SnapshotCanonicalRoots()
  local canonical = GetCanonicalStores()
  if type(canonical) ~= "table"
      or type(canonical.accountRoot) ~= "table"
      or type(canonical.charRoot) ~= "table" then
    return nil
  end

  local references = {
    accountRoot = canonical.accountRoot,
    charRoot = canonical.charRoot,
  }
  -- Exact references are the authoritative rollback snapshot. A detached
  -- strict copy is only a fallback if the raw restore owner fails; requiring it
  -- here would make import/reset unable to recover malformed legacy stores.
  local detached = CopySerializableStrict(references)
  if type(detached) ~= "table" or type(detached.accountRoot) ~= "table"
      or type(detached.charRoot) ~= "table" then
    detached = nil
  end

  return {
    references = references,
    detached = detached,
  }
end

local ROOT_SCHEMA_VERSION = 1

local function ValidateRootSchema(root, label)
  local schema = root.schema
  if schema == nil then
    return true
  end
  if type(schema) ~= "table" then
    return false, label .. " persistence root has an invalid schema table."
  end
  local version = schema.version
  if version == nil then
    return true
  end
  if type(version) ~= "number" or version % 1 ~= 0
      or version < 1 or version > ROOT_SCHEMA_VERSION then
    return false, label .. " persistence root schema version is not supported."
  end
  return true
end

local function ValidateAccountRoot(root)
  if type(root) ~= "table" then
    return false, "Transfer account root is invalid."
  end
  local schemaOk, schemaError = ValidateRootSchema(root, "Account")
  if not schemaOk then return false, schemaError end
  if type(root.account) ~= "table"
      or type(root.account.settings) ~= "table"
      or type(root.account.templates) ~= "table" then
    return false, "Transfer account root is missing account.settings or account.templates."
  end
  return true
end

local function ValidateCharacterRoot(root)
  if type(root) ~= "table" then
    return false, "Transfer character root is invalid."
  end
  local schemaOk, schemaError = ValidateRootSchema(root, "Character")
  if not schemaOk then return false, schemaError end
  if type(root.orbs) ~= "table" then
    return false, "Transfer character root is missing the orbs table."
  end
  return true
end

local function ValidateTransferPayload(payload)
  local staged = CopySerializableStrict(payload)
  if type(staged) ~= "table" then
    return nil, "Transfer payload is not a complete serializable table."
  end

  local hasRoot = false
  for key in pairs(staged) do
    if key ~= "accountRoot" and key ~= "charRoot" then
      return nil, "Transfer payload contains an unsupported root."
    end
    hasRoot = true
  end
  if not hasRoot then
    return nil, "Transfer payload does not contain a persistence root."
  end
  if staged.accountRoot ~= nil then
    local valid, validationError = ValidateAccountRoot(staged.accountRoot)
    if not valid then return nil, validationError end
  end
  if staged.charRoot ~= nil then
    local valid, validationError = ValidateCharacterRoot(staged.charRoot)
    if not valid then return nil, validationError end
  end

  return staged
end

local function ReconcileAccepted()
  local ok, result = TryCall(ReconcilePersistenceStores)
  if ok ~= true or not CanAccess(result) or type(result) ~= "table" then
    return false, result
  end
  local driftAccepted = result.driftAccepted
  if not CanAccess(driftAccepted) or driftAccepted ~= true then
    return false, result
  end
  return true, result
end

local function TryBooleanCall(fn, ...)
  local ok, result = TryCall(fn, ...)
  return ok == true and CanAccess(result) and result == true
end

local function ReloadInterface()
  if type(ReloadUI) ~= "function" then
    return false
  end
  local ok, result = TryCall(ReloadUI)
  if ok ~= true or not CanAccess(result) then
    return false
  end
  return result ~= false
end

local function RestoreSnapshot(snapshot)
  if type(snapshot) ~= "table" then
    return false
  end

  -- Reattach the exact pre-transaction roots first. File-scope unit layouts
  -- retain read-only views into those tables until ReloadUI completes; copying
  -- the snapshot would restore values but leave those live views orphaned.
  local restored = TryBooleanCall(RestorePersistenceRoots, snapshot.references)
  if not restored and type(snapshot.detached) == "table" then
    restored = TryBooleanCall(CommitPersistenceRoots, snapshot.detached)
  end
  if not restored then
    return false
  end

  local accepted = ReconcileAccepted()
  return accepted == true
end

local function CommitTransferRoots(staged)
  local snapshot = SnapshotCanonicalRoots()
  if not snapshot then
    return false, "Current persistence state cannot be snapshotted safely."
  end

  if not TryBooleanCall(CommitPersistenceRoots, staged) then
    if RestoreSnapshot(snapshot) ~= true then
      return false, "Persistence root replacement failed and rollback did not complete."
    end
    return false, "Persistence root replacement failed."
  end

  if ReconcileAccepted() ~= true then
    if RestoreSnapshot(snapshot) ~= true then
      return false, "Imported persistence was rejected and rollback did not complete."
    end
    return false, "Imported persistence was rejected by schema reconciliation."
  end

  if ReloadInterface() ~= true then
    if RestoreSnapshot(snapshot) ~= true then
      return false, "Import reload failed and rollback did not complete."
    end
    return false, "Import reload failed; the previous persistence state was restored."
  end

  return true
end

persistenceApi.GetConfigRoot = function()
  return GetConfigRoot()
end

persistenceApi.GetDebugState = function()
  return GetRuntimeDebugState()
end

persistenceApi.ClearLog = function()
  return ClearRuntimeLog()
end

persistenceApi.GetScanStores = function()
  local canonical = GetCanonicalStores()
  if type(canonical) ~= "table" then
    return BuildPersistenceNodePayload({})
  end
  return BuildPersistenceNodePayload(BuildScanStoreNodeMap(canonical))
end

persistenceApi.GetStorageLabels = function()
  local descriptors = GetPersistenceDescriptors() or {}
  return BuildPersistenceNodePayload(BuildStorageLabelNodeMap(descriptors))
end

persistenceApi.GetTransferRoots = function(mode)
  if mode ~= "full" and mode ~= "account" and mode ~= "char" then
    return nil, "Unknown persistence transfer mode."
  end

  local canonical = GetCanonicalStores()
  if type(canonical) ~= "table" then
    return nil, "Canonical persistence stores are unavailable."
  end

  local source = {}
  if mode == "full" or mode == "account" then
    source.accountRoot = canonical.accountRoot
  end
  if mode == "full" or mode == "char" then
    source.charRoot = canonical.charRoot
  end

  local payload = CopySerializableStrict(source)
  if type(payload) ~= "table" then
    return nil, "SavedVariables contain unsupported, cyclic or aliased data."
  end
  if source.accountRoot ~= nil and type(payload.accountRoot) ~= "table" then
    return nil, "Account SavedVariables could not be copied completely."
  end
  if source.charRoot ~= nil and type(payload.charRoot) ~= "table" then
    return nil, "Character SavedVariables could not be copied completely."
  end
  return payload
end

local function ApplyTransferRootsAndReload(payload)
  -- Root replacement changes live authoritative state. Reject in combat and
  -- commit only a detached, complete document with an owned rollback snapshot.
  if InCombatLockdown and InCombatLockdown() then
    return false, "Persistence import is blocked in combat."
  end

  local staged, validationError = ValidateTransferPayload(payload)
  if not staged then
    return false, validationError
  end

  return CommitTransferRoots(staged)
end

persistenceApi.ApplyTransferRootsAndReload = ApplyTransferRootsAndReload

persistenceApi.GetRuntimeState = function()
  return GetRuntimePersistenceState()
end

persistenceApi.GetDoctorState = function()
  return GetRuntimeSVDoctorState()
end

persistenceApi.RunDoctor = function(verbose)
  local doctorApi = ns and ns.persistenceDoctor
  local scan = type(doctorApi) == "table" and doctorApi.Scan or nil
  if type(scan) == "function" then
    return scan(verbose)
  end
  return nil
end

persistenceApi.RunSVTest = function()
  local doctorApi = ns and ns.persistenceDoctor
  local testReport = type(doctorApi) == "table" and doctorApi.TestReport or nil
  if type(testReport) == "function" then
    return testReport()
  end
  return false
end

persistenceApi.ReloadUI = ReloadInterface

persistenceApi.ResetAndReload = function()
  if InCombatLockdown and InCombatLockdown() then
    return false
  end
  if type(ReloadUI) ~= "function" then
    return false
  end

  local snapshot = SnapshotCanonicalRoots()
  if not snapshot then
    return false
  end
  if not TryBooleanCall(ResetPersistenceRoots) then
    RestoreSnapshot(snapshot)
    return false
  end
  if ReloadInterface() == true then
    return true
  end

  RestoreSnapshot(snapshot)
  return false
end

persistenceApi.Reconcile = function()
  return ReconcilePersistenceStores()
end


persistenceApi.ReportSchema = function(verbose)
  local reportApi = ns and ns.persistenceReport
  local reportSchema = type(reportApi) == "table" and reportApi.Report or nil
  if type(reportSchema) == "function" then
    return reportSchema(verbose)
  end
  return nil
end

-- SavedVariables are already available and migrated before this file because
-- the TOC opts into LoadSavedVariablesFirst. Only player-ready reconciliation
-- and logout sanitation need retained event ownership here.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then
    self:UnregisterEvent("PLAYER_LOGIN")
    local accepted = ReconcileAccepted()
    if accepted == true and ns and type(ns.RefreshOrbsVisual) == "function" then
      TryCall(ns.RefreshOrbsVisual)
    end
    return
  end

  if event == "PLAYER_LOGOUT" then
    TryCall(SanitizePersistenceStores, { logoutEvent = true })
  end
end)
