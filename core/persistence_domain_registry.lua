local _, ns = ...

-- Own persistence descriptors, domain registry, and store mapping separately from schema catalog builders.
local configOwner = assert(ns and ns.configPersistence, "Roth_UI: ns.configPersistence is required by persistence_domain_registry.lua")
local storeApi = assert(ns and ns.store, "Roth_UI: ns.store is required by persistence_domain_registry.lua")

local GetDomainRoot = assert(storeApi.GetDomainRoot, "Roth_UI: store.GetDomainRoot is required by persistence_domain_registry.lua")
local GetConfigRoot = assert(storeApi.GetConfigRoot, "Roth_UI: store.GetConfigRoot is required by persistence_domain_registry.lua")

local GetConfigPersistenceInfo = assert(configOwner.GetConfigPersistenceInfo, "Roth_UI: configPersistence.GetConfigPersistenceInfo is required by persistence_domain_registry.lua")
local GetConfigSchemaPolicy = assert(configOwner.GetConfigSchemaPolicy, "Roth_UI: configPersistence.GetConfigSchemaPolicy is required by persistence_domain_registry.lua")
local ReconcileConfigStore = assert(configOwner.ReconcileConfigStore, "Roth_UI: configPersistence.ReconcileConfigStore is required by persistence_domain_registry.lua")

local registryApi = ns.persistenceRegistry or {}
ns.persistenceRegistry = registryApi

local CONFIG_OWNER_FALLBACK = configOwner.OWNER_FILE or "core/config_persistence_owner.lua"
local ORB_OWNER_FALLBACK = "core/orb_persistence_owner.lua"
local ACCOUNT_VAR = configOwner.ACCOUNT_DB_VAR or "Roth_UI_DB"
local CHAR_VAR = configOwner.CHAR_DB_VAR or "Roth_UI_DB_Char"

local function BuildStorageId(variable, path)
  if type(variable) ~= "string" or variable == "" then
    return nil
  end
  if type(path) ~= "string" or path == "" then
    return variable
  end
  return variable .. "." .. path
end

local function BuildPersistenceNode(owner, variable, path)
  return {
    owner = owner,
    variable = variable,
    path = path,
    storageId = BuildStorageId(variable, path),
  }
end

function registryApi.GetOrbPersistenceOwner()
  local owner = ns and ns.orbPersistence
  if type(owner) == "table" then
    return owner
  end
  return nil
end

function registryApi.GetConfigDescriptor()
  local info = GetConfigPersistenceInfo()
  local owner = (type(info) == "table" and info.owner) or CONFIG_OWNER_FALLBACK
  local variable = (type(info) == "table" and info.variable) or ACCOUNT_VAR
  local path = (type(info) == "table" and info.path) or "account.settings"
  return BuildPersistenceNode(owner, variable, path)
end

local function BuildFallbackOrbDescriptor()
  local owner = ORB_OWNER_FALLBACK
  return {
    key = "orb",
    owner = owner,
    char = BuildPersistenceNode(owner, CHAR_VAR, "orbs"),
    global = BuildPersistenceNode(owner, ACCOUNT_VAR, "account.templates"),
  }
end

function registryApi.GetOrbDescriptor()
  local orbOwner = registryApi.GetOrbPersistenceOwner()
  if type(orbOwner) == "table" and type(orbOwner.GetPersistenceInfo) == "function" then
    local descriptor = orbOwner.GetPersistenceInfo()
    if type(descriptor) == "table" then
      return descriptor
    end
  end

  return BuildFallbackOrbDescriptor()
end

function registryApi.BuildFallbackOrbSchemaInfo(descriptor, stores)
  local charNode = type(descriptor.char) == "table" and descriptor.char or {}
  local globalNode = type(descriptor.global) == "table" and descriptor.global or {}
  local charStore = type(stores) == "table" and stores.orbChar or GetDomainRoot("orbChar", false)
  local globalStore = type(stores) == "table" and stores.orbGlobal or GetDomainRoot("orbGlobal", false)

  return {
    owner = descriptor.owner or ORB_OWNER_FALLBACK,
    char = {
      variable = charNode.variable or CHAR_VAR,
      path = charNode.path or "orbs",
      patch = (type(charStore) == "table" and tonumber(charStore.__schemaPatch)) or 0,
      targetPatch = 0,
    },
    global = {
      variable = globalNode.variable or ACCOUNT_VAR,
      path = globalNode.path or "account.templates",
      patch = (type(globalStore) == "table" and tonumber(globalStore.__schemaPatch)) or 0,
      targetPatch = 0,
    },
  }
end

function registryApi.BuildFallbackOrbSchemaPolicy(descriptor)
  return {
    owner = descriptor.owner or ORB_OWNER_FALLBACK,
    char = {
      variable = (type(descriptor.char) == "table" and descriptor.char.variable) or CHAR_VAR,
      path = (type(descriptor.char) == "table" and descriptor.char.path) or "orbs",
      targetPatch = 0,
    },
    global = {
      variable = (type(descriptor.global) == "table" and descriptor.global.variable) or ACCOUNT_VAR,
      path = (type(descriptor.global) == "table" and descriptor.global.path) or "account.templates",
      targetPatch = 0,
    },
    mode = "strict",
  }
end

function registryApi.GetDescriptors()
  return {
    config = registryApi.GetConfigDescriptor(),
    orb = registryApi.GetOrbDescriptor(),
  }
end
ns.GetPersistenceDescriptors = registryApi.GetDescriptors
storeApi.GetPersistenceDescriptors = ns.GetPersistenceDescriptors

function registryApi.GetDomainRegistry()
  local configDescriptor = registryApi.GetConfigDescriptor()
  local orbDescriptor = registryApi.GetOrbDescriptor()
  local configDomainOwner = configDescriptor.owner or CONFIG_OWNER_FALLBACK
  local orbOwner = orbDescriptor.owner or ORB_OWNER_FALLBACK

  return {
    config = {
      key = "config",
      owner = configDomainOwner,
      variable = configDescriptor.variable or ACCOUNT_VAR,
      path = configDescriptor.path or "account.settings",
      getSchemaPolicy = function()
        return GetConfigSchemaPolicy()
      end,
      reconcile = function()
        ReconcileConfigStore(GetConfigRoot())
      end,
    },
    orb = {
      key = "orb",
      owner = orbOwner,
      variables = {
        char = (type(orbDescriptor.char) == "table" and orbDescriptor.char.variable) or CHAR_VAR,
        global = (type(orbDescriptor.global) == "table" and orbDescriptor.global.variable) or ACCOUNT_VAR,
      },
      paths = {
        char = (type(orbDescriptor.char) == "table" and orbDescriptor.char.path) or "orbs",
        global = (type(orbDescriptor.global) == "table" and orbDescriptor.global.path) or "account.templates",
      },
      getSchemaPolicy = function()
        local ownerService = registryApi.GetOrbPersistenceOwner()
        if type(ownerService) == "table" and type(ownerService.GetSchemaPolicy) == "function" then
          local policy = ownerService.GetSchemaPolicy()
          if type(policy) == "table" then
            return policy
          end
        end
        return registryApi.BuildFallbackOrbSchemaPolicy(orbDescriptor)
      end,
      reconcile = function()
        local ownerService = registryApi.GetOrbPersistenceOwner()
        if type(ownerService) == "table" and type(ownerService.ReconcileStores) == "function" then
          ownerService.ReconcileStores()
          return true
        end
        return false
      end,
    },
  }
end
ns.GetPersistenceDomainRegistry = registryApi.GetDomainRegistry

function registryApi.GetRequiredDomainKeys()
  return {
    "config",
    "orb",
  }
end
ns.GetRequiredPersistenceDomainKeys = registryApi.GetRequiredDomainKeys

function registryApi.ValidateDomainRegistry(registry)
  local reg = (type(registry) == "table") and registry or registryApi.GetDomainRegistry()
  local required = registryApi.GetRequiredDomainKeys()
  local report = {
    requiredCount = #required,
    registeredCount = 0,
    missingDomains = {},
    invalidDomains = {},
    extraDomains = {},
    accepted = false,
  }

  local requiredSet = {}
  for i = 1, #required do
    local key = required[i]
    requiredSet[key] = true
    local domain = reg[key]
    if type(domain) ~= "table" then
      report.missingDomains[#report.missingDomains + 1] = key
    else
      report.registeredCount = report.registeredCount + 1
      local hasOwner = (type(domain.owner) == "string" and domain.owner ~= "")
      local hasPolicy = type(domain.getSchemaPolicy) == "function"
      local hasReconcile = type(domain.reconcile) == "function"
      if not (hasOwner and hasPolicy and hasReconcile) then
        report.invalidDomains[#report.invalidDomains + 1] = key
      end
    end
  end

  for key, domain in pairs(reg) do
    if type(domain) == "table" and not requiredSet[key] then
      report.extraDomains[#report.extraDomains + 1] = key
    end
  end

  table.sort(report.missingDomains)
  table.sort(report.invalidDomains)
  table.sort(report.extraDomains)
  report.accepted = (#report.missingDomains == 0) and (#report.invalidDomains == 0)
  return report
end
ns.ValidatePersistenceDomainRegistry = registryApi.ValidateDomainRegistry

function registryApi.GetRegistryState()
  local registry = registryApi.GetDomainRegistry()
  return registryApi.ValidateDomainRegistry(registry)
end
ns.GetPersistenceRegistryState = registryApi.GetRegistryState

function ns.GetPersistenceStores()
  return {
    config = GetConfigRoot(),
    orbGlobal = GetDomainRoot("orbGlobal", false),
    orbChar = GetDomainRoot("orbChar", false),
  }
end
storeApi.GetPersistenceStores = ns.GetPersistenceStores
