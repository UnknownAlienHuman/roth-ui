local _, ns = ...

-- Own persistence drift policy/state separately from sanitize/reconcile orchestration.
local configOwner = assert(ns and ns.configPersistence, "Roth_UI: ns.configPersistence is required by persistence_drift_service.lua")

local GetConfigSchemaPolicy = assert(configOwner.GetConfigSchemaPolicy, "Roth_UI: configPersistence.GetConfigSchemaPolicy is required by persistence_drift_service.lua")
local GetPersistenceDescriptors = assert(ns and ns.GetPersistenceDescriptors, "Roth_UI: ns.GetPersistenceDescriptors is required by persistence_drift_service.lua")
local GetPersistenceSchemaCatalog = assert(ns and ns.GetPersistenceSchemaCatalog, "Roth_UI: ns.GetPersistenceSchemaCatalog is required by persistence_drift_service.lua")
local GetPersistenceSchemaInfo = assert(ns and ns.GetPersistenceSchemaInfo, "Roth_UI: ns.GetPersistenceSchemaInfo is required by persistence_drift_service.lua")
local GetPersistenceSchemaNodeKeys = assert(ns and ns.GetPersistenceSchemaNodeKeys, "Roth_UI: ns.GetPersistenceSchemaNodeKeys is required by persistence_drift_service.lua")
local GetPersistenceDomainRegistry = assert(ns and ns.GetPersistenceDomainRegistry, "Roth_UI: ns.GetPersistenceDomainRegistry is required by persistence_drift_service.lua")
local ValidatePersistenceDomainRegistry = assert(ns and ns.ValidatePersistenceDomainRegistry, "Roth_UI: ns.ValidatePersistenceDomainRegistry is required by persistence_drift_service.lua")

local driftApi = ns.persistenceDrift or {}
ns.persistenceDrift = driftApi

local ORB_OWNER_FALLBACK = "core/orb_persistence_owner.lua"
local ACCOUNT_VAR = configOwner.ACCOUNT_DB_VAR or "Roth_UI_DB"
local CHAR_VAR = configOwner.CHAR_DB_VAR or "Roth_UI_DB_Char"

local function BuildEmptyDriftNode()
  return {
    patch = 0,
    targetPatch = 0,
    drift = false,
    targetMismatch = false,
  }
end

local function BuildDriftNode(node, domainPolicy)
  local expectedTargetPatch = tonumber(domainPolicy and domainPolicy.targetPatch)
  local observedTargetPatch = tonumber(node.targetPatch) or 0
  local effectiveTargetPatch = expectedTargetPatch or observedTargetPatch
  local item = {
    owner = node.owner,
    variable = node.variable,
    patch = tonumber(node.patch) or 0,
    targetPatch = observedTargetPatch,
    expectedTargetPatch = expectedTargetPatch,
    effectiveTargetPatch = effectiveTargetPatch,
  }
  item.targetMismatch = (expectedTargetPatch ~= nil) and (expectedTargetPatch > 0) and (observedTargetPatch ~= expectedTargetPatch)
  item.drift = (effectiveTargetPatch > 0) and (item.patch < effectiveTargetPatch)
  return item
end

function driftApi.BuildState(info)
  local policy = driftApi.GetPolicy()
  local domains = (type(policy) == "table" and type(policy.domains) == "table") and policy.domains or nil
  local nodeKeys = GetPersistenceSchemaNodeKeys()
  local state = {
    hasSchema = type(info) == "table",
    schemaVersion = (type(info) == "table" and tonumber(info.version)) or 0,
    driftCount = 0,
    targetMismatchCount = 0,
    hasDrift = false,
    nodeKeys = nodeKeys,
    nodes = {},
  }

  local catalog = state.hasSchema and GetPersistenceSchemaCatalog(info) or nil
  if type(catalog) ~= "table" then
    return state
  end

  for i = 1, #nodeKeys do
    local key = nodeKeys[i]
    local node = catalog[key]
    if type(node) == "table" then
      local item = BuildDriftNode(node, domains and domains[key])
      state.nodes[key] = item
      if item.drift then
        state.driftCount = state.driftCount + 1
      end
      if item.targetMismatch then
        state.targetMismatchCount = state.targetMismatchCount + 1
      end
    else
      state.nodes[key] = BuildEmptyDriftNode()
    end
  end

  state.hasDrift = state.driftCount > 0 or state.targetMismatchCount > 0
  return state
end

function driftApi.GetPolicy()
  local domains = {}
  local descriptors = GetPersistenceDescriptors() or {}
  local registry = GetPersistenceDomainRegistry()
  local registryValidation = ValidatePersistenceDomainRegistry(registry)
  local configDescriptor = type(descriptors.config) == "table" and descriptors.config or {}
  local orbDescriptor = type(descriptors.orb) == "table" and descriptors.orb or {}
  local configDomain = type(registry) == "table" and registry.config or nil
  local configPolicy = (type(configDomain) == "table" and type(configDomain.getSchemaPolicy) == "function")
    and configDomain.getSchemaPolicy()
    or GetConfigSchemaPolicy()
  domains.config = {
    owner = (type(configPolicy) == "table" and configPolicy.owner)
      or (type(configDomain) == "table" and configDomain.owner)
      or configDescriptor.owner
      or configOwner.OWNER_FILE
      or "core/config_persistence_owner.lua",
    variable = (type(configPolicy) == "table" and configPolicy.variable)
      or (type(configDomain) == "table" and configDomain.variable)
      or configDescriptor.variable
      or ACCOUNT_VAR,
    targetPatch = (type(configPolicy) == "table" and tonumber(configPolicy.targetPatch)) or 0,
  }

  local orbDomain = type(registry) == "table" and registry.orb or nil
  local orbPolicy = (type(orbDomain) == "table" and type(orbDomain.getSchemaPolicy) == "function")
    and orbDomain.getSchemaPolicy()
    or nil
  domains.orbChar = {
    owner = (type(orbPolicy) == "table" and orbPolicy.owner)
      or (type(orbDomain) == "table" and orbDomain.owner)
      or orbDescriptor.owner
      or ORB_OWNER_FALLBACK,
    variable = (type(orbPolicy) == "table" and type(orbPolicy.char) == "table" and orbPolicy.char.variable)
      or (type(orbDomain) == "table" and type(orbDomain.variables) == "table" and orbDomain.variables.char)
      or (type(orbDescriptor.char) == "table" and orbDescriptor.char.variable)
      or CHAR_VAR,
    targetPatch = (type(orbPolicy) == "table" and type(orbPolicy.char) == "table" and tonumber(orbPolicy.char.targetPatch))
      or 0,
  }
  domains.orbGlobal = {
    owner = (type(orbPolicy) == "table" and orbPolicy.owner)
      or (type(orbDomain) == "table" and orbDomain.owner)
      or orbDescriptor.owner
      or ORB_OWNER_FALLBACK,
    variable = (type(orbPolicy) == "table" and type(orbPolicy.global) == "table" and orbPolicy.global.variable)
      or (type(orbDomain) == "table" and type(orbDomain.variables) == "table" and orbDomain.variables.global)
      or (type(orbDescriptor.global) == "table" and orbDescriptor.global.variable)
      or ACCOUNT_VAR,
    targetPatch = (type(orbPolicy) == "table" and type(orbPolicy.global) == "table" and tonumber(orbPolicy.global.targetPatch))
      or 0,
  }

  return {
    mode = "strict",
    requiredSchemaVersion = 1,
    maxDriftCount = 0,
    maxTargetMismatchCount = 0,
    allowTargetMismatch = false,
    domains = domains,
    registryValidation = registryValidation,
  }
end

function driftApi.IsAccepted(state, policy)
  local st = (type(state) == "table") and state or {}
  local pl = (type(policy) == "table") and policy or driftApi.GetPolicy()
  local requiredSchemaVersion = tonumber(pl.requiredSchemaVersion) or 1
  local maxDriftCount = tonumber(pl.maxDriftCount) or 0
  local maxTargetMismatchCount = tonumber(pl.maxTargetMismatchCount) or 0
  local allowTargetMismatch = pl.allowTargetMismatch == true
  local schemaVersion = tonumber(st.schemaVersion) or 0
  local driftCount = tonumber(st.driftCount) or 0
  local targetMismatchCount = tonumber(st.targetMismatchCount) or 0

  if schemaVersion < requiredSchemaVersion then
    return false
  end
  if driftCount > maxDriftCount then
    return false
  end
  if allowTargetMismatch then
    return true
  end
  return targetMismatchCount <= maxTargetMismatchCount
end

function driftApi.GetState()
  return driftApi.BuildState(GetPersistenceSchemaInfo())
end

ns.GetPersistenceDriftPolicy = driftApi.GetPolicy
ns.IsPersistenceDriftAccepted = driftApi.IsAccepted
ns.GetPersistenceDriftState = driftApi.GetState
