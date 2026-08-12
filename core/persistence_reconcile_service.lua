local _, ns = ...

-- Own sanitize/reconcile orchestration separately from schema and drift builders.
local safety = assert(ns and ns.safety, "Roth_UI: ns.safety is required by persistence_reconcile_service.lua")
local SanitizeSerializableInPlace = assert(safety.SanitizeSerializableInPlace, "Roth_UI: safety.SanitizeSerializableInPlace is required by persistence_reconcile_service.lua")
local runtimeApi = assert(ns and ns.persistenceRuntime, "Roth_UI: ns.persistenceRuntime is required by persistence_reconcile_service.lua")
local driftApi = assert(ns and ns.persistenceDrift, "Roth_UI: ns.persistenceDrift is required by persistence_reconcile_service.lua")
local storeApi = assert(ns and ns.store, "Roth_UI: ns.store is required by persistence_reconcile_service.lua")
local PurgeLegacyRuntimeKeys = assert(runtimeApi.PurgeLegacyKeys, "Roth_UI: persistenceRuntime.PurgeLegacyKeys is required by persistence_reconcile_service.lua")
local GetRuntimePersistenceState = assert(ns and ns.GetRuntimePersistenceState, "Roth_UI: ns.GetRuntimePersistenceState is required by persistence_reconcile_service.lua")
local GetPersistenceStores = assert(ns and ns.GetPersistenceStores, "Roth_UI: ns.GetPersistenceStores is required by persistence_reconcile_service.lua")
local GetPersistenceSchemaInfo = assert(ns and ns.GetPersistenceSchemaInfo, "Roth_UI: ns.GetPersistenceSchemaInfo is required by persistence_reconcile_service.lua")
local GetPersistenceDomainRegistry = assert(ns and ns.GetPersistenceDomainRegistry, "Roth_UI: ns.GetPersistenceDomainRegistry is required by persistence_reconcile_service.lua")
local ValidatePersistenceDomainRegistry = assert(ns and ns.ValidatePersistenceDomainRegistry, "Roth_UI: ns.ValidatePersistenceDomainRegistry is required by persistence_reconcile_service.lua")
local BuildDriftState = assert(driftApi.BuildState, "Roth_UI: persistenceDrift.BuildState is required by persistence_reconcile_service.lua")
local GetPersistenceDriftPolicy = assert(ns and ns.GetPersistenceDriftPolicy, "Roth_UI: ns.GetPersistenceDriftPolicy is required by persistence_reconcile_service.lua")
local IsPersistenceDriftAccepted = assert(ns and ns.IsPersistenceDriftAccepted, "Roth_UI: ns.IsPersistenceDriftAccepted is required by persistence_reconcile_service.lua")

function ns.SanitizePersistenceStores(opts)
  opts = opts or {}
  local stores = GetPersistenceStores()

  local sv = stores and stores.config
  if type(sv) == "table" then
    if opts.logoutEvent == true then
      local persistenceState = GetRuntimePersistenceState()
      persistenceState.logoutCounter = (tonumber(persistenceState.logoutCounter) or 0) + 1
    end
    PurgeLegacyRuntimeKeys(sv)
    SanitizeSerializableInPlace(sv)
  end

  if opts.skipOrbStores ~= true then
    local orbPersistence = ns and ns.orbPersistence
    if type(orbPersistence) == "table" and type(orbPersistence.SanitizeStores) == "function" then
      orbPersistence.SanitizeStores()
      stores = GetPersistenceStores()
    else
      local glob = stores and stores.orbGlobal
      if type(glob) == "table" then
        SanitizeSerializableInPlace(glob)
      end

      local ch = stores and stores.orbChar
      if type(ch) == "table" then
        SanitizeSerializableInPlace(ch)
      end
    end
  end

  return stores
end
storeApi.SanitizeStores = ns.SanitizePersistenceStores

function ns.ReconcilePersistenceStores()
  local policy = GetPersistenceDriftPolicy()
  local registry = GetPersistenceDomainRegistry() or {}
  local registryValidation = ValidatePersistenceDomainRegistry(registry)
  local beforeInfo = GetPersistenceSchemaInfo()
  local driftBefore = BuildDriftState(beforeInfo)
  local executedDomains = {}

  local configDomain = type(registry) == "table" and registry.config or nil
  if type(configDomain) == "table" and type(configDomain.reconcile) == "function" then
    configDomain.reconcile()
    executedDomains[#executedDomains + 1] = "config"
  else
    executedDomains[#executedDomains + 1] = "config(skipped)"
  end

  local orbDomain = type(registry) == "table" and registry.orb or nil
  if type(orbDomain) == "table" and type(orbDomain.reconcile) == "function" then
    orbDomain.reconcile()
    executedDomains[#executedDomains + 1] = "orb"
  else
    executedDomains[#executedDomains + 1] = "orb(skipped)"
  end

  -- Registry-owned reconcile is authoritative for orb stores; avoid hidden fallback writes here.
  ns.SanitizePersistenceStores({ skipOrbStores = true, logoutEvent = false })
  local afterInfo = GetPersistenceSchemaInfo()
  local driftAfter = BuildDriftState(afterInfo)
  local driftAccepted = IsPersistenceDriftAccepted(driftAfter, policy)
  local registryAccepted = not (type(registryValidation) == "table") or registryValidation.accepted == true
  local accepted = driftAccepted and registryAccepted

  afterInfo.driftBefore = driftBefore
  afterInfo.driftAfter = driftAfter
  afterInfo.driftPolicy = policy
  afterInfo.registryValidation = registryValidation
  afterInfo.driftAcceptedRaw = driftAccepted
  afterInfo.driftAccepted = accepted

  ns._lastPersistenceReconcileAt = (time and time()) or (ns._lastPersistenceReconcileAt or 0) + 1
  ns._lastPersistenceReconcile = {
    at = ns._lastPersistenceReconcileAt,
    policy = policy,
    driftBefore = driftBefore,
    driftAfter = driftAfter,
    accepted = accepted,
    registry = {
      hasConfigDomain = type(configDomain) == "table",
      hasOrbDomain = type(orbDomain) == "table",
      executed = executedDomains,
      validation = registryValidation,
    },
  }

  return afterInfo
end
storeApi.ReconcileStores = ns.ReconcilePersistenceStores
