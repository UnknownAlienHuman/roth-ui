local _, ns = ...
local InCombatLockdown = InCombatLockdown

-- Keep the public persistence facade and lifecycle bootstrap out of sv_store.lua.
local safety = assert(ns and ns.safety, "Roth_UI: ns.safety is required by persistence_control_plane.lua")
local CopySerializableStrict = assert(safety.CopySerializableStrict,
  "Roth_UI: safety.CopySerializableStrict is required by persistence_control_plane.lua")
local TryCall = assert(safety.TryCall, "Roth_UI: safety.TryCall is required by persistence_control_plane.lua")
local storeApi = assert(ns and ns.store, "Roth_UI: ns.store is required by persistence_control_plane.lua")
local runtimeApi = assert(ns and ns.persistenceRuntime, "Roth_UI: ns.persistenceRuntime is required by persistence_control_plane.lua")
local persistenceApi = assert(ns and ns.persistence, "Roth_UI: ns.persistence is required by persistence_control_plane.lua")
local GetCanonicalStores = assert(storeApi.GetCanonicalStores, "Roth_UI: store.GetCanonicalStores is required by persistence_control_plane.lua")
local GetPersistenceDescriptors = assert(storeApi.GetPersistenceDescriptors, "Roth_UI: store.GetPersistenceDescriptors is required by persistence_control_plane.lua")
local GetPersistenceSchemaNodeKeys = assert(ns and ns.GetPersistenceSchemaNodeKeys, "Roth_UI: ns.GetPersistenceSchemaNodeKeys is required by persistence_control_plane.lua")
local GetConfigRoot = assert(storeApi.GetConfigRoot, "Roth_UI: store.GetConfigRoot is required by persistence_control_plane.lua")
local GetPersistenceStores = assert(storeApi.GetPersistenceStores, "Roth_UI: store.GetPersistenceStores is required by persistence_control_plane.lua")
local ReplacePersistenceRoots = assert(storeApi.ReplaceRoots, "Roth_UI: store.ReplaceRoots is required by persistence_control_plane.lua")
local ResetPersistenceRoots = assert(storeApi.ResetRoots, "Roth_UI: store.ResetRoots is required by persistence_control_plane.lua")
local ReconcilePersistenceStores = assert(storeApi.ReconcileStores, "Roth_UI: store.ReconcileStores is required by persistence_control_plane.lua")
local SanitizePersistenceStores = assert(storeApi.SanitizeStores, "Roth_UI: store.SanitizeStores is required by persistence_control_plane.lua")
local GetRuntimeDebugState = assert(runtimeApi.GetDebugState, "Roth_UI: persistenceRuntime.GetDebugState is required by persistence_control_plane.lua")
local GetRuntimeLog = assert(runtimeApi.GetLog, "Roth_UI: persistenceRuntime.GetLog is required by persistence_control_plane.lua")
local ClearRuntimeLog = assert(runtimeApi.ClearLog, "Roth_UI: persistenceRuntime.ClearLog is required by persistence_control_plane.lua")
local GetRuntimePersistenceState = assert(runtimeApi.GetPersistenceState, "Roth_UI: persistenceRuntime.GetPersistenceState is required by persistence_control_plane.lua")
local GetRuntimeSVDoctorState = assert(runtimeApi.GetSVDoctorState, "Roth_UI: persistenceRuntime.GetSVDoctorState is required by persistence_control_plane.lua")

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
  if type(canonical) ~= "table" then
    return nil
  end

  local snapshot = CopySerializableStrict({
    accountRoot = canonical.accountRoot,
    charRoot = canonical.charRoot,
  })
  if type(snapshot) ~= "table" or type(snapshot.accountRoot) ~= "table"
      or type(snapshot.charRoot) ~= "table" then
    return nil
  end
  return snapshot
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
  if staged.accountRoot ~= nil and type(staged.accountRoot) ~= "table" then
    return nil, "Transfer account root is invalid."
  end
  if staged.charRoot ~= nil and type(staged.charRoot) ~= "table" then
    return nil, "Transfer character root is invalid."
  end

  return staged
end

local function ReconcileAccepted()
  local ok, result = TryCall(ReconcilePersistenceStores)
  if ok ~= true or type(result) ~= "table" or result.driftAccepted ~= true then
    return false, result
  end
  return true, result
end

local function RestoreSnapshot(snapshot)
  if type(snapshot) ~= "table" or ReplacePersistenceRoots(snapshot) ~= true then
    return false
  end
  return ReconcileAccepted()
end

persistenceApi.GetConfigRoot = function()
  return GetConfigRoot()
end

persistenceApi.GetStores = function()
  return GetPersistenceStores()
end

persistenceApi.GetCanonicalStores = function()
  return GetCanonicalStores()
end

persistenceApi.GetDebugState = function()
  return GetRuntimeDebugState()
end

persistenceApi.GetLog = function()
  return GetRuntimeLog()
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

persistenceApi.ApplyTransferRoots = function(payload)
  -- Root replacement changes live authoritative state. Reject in combat and
  -- commit only a detached, complete document with an owned rollback snapshot.
  if InCombatLockdown and InCombatLockdown() then
    return false, "Persistence import is blocked in combat."
  end

  local staged, validationError = ValidateTransferPayload(payload)
  if not staged then
    return false, validationError
  end

  local snapshot = SnapshotCanonicalRoots()
  if not snapshot then
    return false, "Current persistence state cannot be snapshotted safely."
  end

  if ReplacePersistenceRoots(staged) ~= true then
    RestoreSnapshot(snapshot)
    return false, "Persistence root replacement failed."
  end

  if ReconcileAccepted() then
    return true
  end

  if RestoreSnapshot(snapshot) ~= true then
    return false, "Imported persistence was rejected and rollback did not complete."
  end
  return false, "Imported persistence was rejected by schema reconciliation."
end

persistenceApi.GetSchemaInfo = function()
  return ns.GetPersistenceSchemaInfo()
end

persistenceApi.GetSchemaCatalog = function()
  return ns.GetPersistenceSchemaCatalog()
end

persistenceApi.GetDriftState = function()
  return ns.GetPersistenceDriftState()
end

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

persistenceApi.ResetRoots = function()
  return ResetPersistenceRoots()
end

persistenceApi.ReloadUI = function()
  if type(ReloadUI) ~= "function" then
    return false
  end
  local ok, result = TryCall(ReloadUI)
  return ok == true and result ~= false
end

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
  if ResetPersistenceRoots() ~= true then
    return false
  end
  if persistenceApi.ReloadUI() == true then
    return true
  end

  RestoreSnapshot(snapshot)
  return false
end

persistenceApi.ReplaceRoots = function(payload)
  return ReplacePersistenceRoots(payload)
end

persistenceApi.Reconcile = function()
  return ReconcilePersistenceStores()
end

-- Compatibility facade for the existing diagnostic command; reconciliation remains
-- the single implementation and owner of runtime rebinding.
persistenceApi.RebuildRuntime = persistenceApi.Reconcile

persistenceApi.Sanitize = function(opts)
  return SanitizePersistenceStores(opts)
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
    ReconcilePersistenceStores()
    if ns and ns.RefreshOrbsVisual then
      ns.RefreshOrbsVisual()
    end
    return
  end

  if event == "PLAYER_LOGOUT" then
    SanitizePersistenceStores({ logoutEvent = true })
  end
end)
