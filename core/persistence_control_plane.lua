local addon, ns = ...

-- Keep the public persistence facade and lifecycle bootstrap out of sv_store.lua.
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
local RebuildRuntime = assert(storeApi.RebuildRuntime, "Roth_UI: store.RebuildRuntime is required by persistence_control_plane.lua")
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
  persistenceApi.Sanitize({ logoutEvent = false })

  local canonical = GetCanonicalStores()
  if type(canonical) ~= "table" then
    return {}
  end

  local payload = {}
  if mode == "full" or mode == "account" then
    payload.accountRoot = canonical.accountRoot
  end
  if mode == "full" or mode == "char" then
    payload.charRoot = canonical.charRoot
  end
  return payload
end

persistenceApi.ApplyTransferRoots = function(payload)
  if type(payload) ~= "table" then
    return false
  end

  if next(payload) ~= nil and ReplacePersistenceRoots(payload) ~= true then
    return false
  end

  persistenceApi.Reconcile()
  persistenceApi.RebuildRuntime()
  return true
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
  ReloadUI()
  return true
end

persistenceApi.ResetAndReload = function()
  if not persistenceApi.ResetRoots() then
    return false
  end
  return persistenceApi.ReloadUI()
end

persistenceApi.ReplaceRoots = function(payload)
  return ReplacePersistenceRoots(payload)
end

persistenceApi.Reconcile = function()
  return ReconcilePersistenceStores()
end

persistenceApi.Sanitize = function(opts)
  return SanitizePersistenceStores(opts)
end

persistenceApi.RebuildRuntime = function()
  return RebuildRuntime()
end

persistenceApi.ReportSchema = function(verbose)
  local reportApi = ns and ns.persistenceReport
  local reportSchema = type(reportApi) == "table" and reportApi.Report or nil
  if type(reportSchema) == "function" then
    return reportSchema(verbose)
  end
  return nil
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= addon then
      return
    end
    GetConfigRoot()
    return
  end

  if event == "PLAYER_LOGIN" then
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
