local _, ns = ...

-- Own schema node keys and catalog builders separately from descriptor/domain registry.
local configOwner = assert(ns and ns.configPersistence, "Roth_UI: ns.configPersistence is required by persistence_schema_registry.lua")
local registryApi = assert(ns and ns.persistenceRegistry, "Roth_UI: ns.persistenceRegistry is required by persistence_schema_registry.lua")

local GetConfigSchemaInfo = assert(configOwner.GetConfigSchemaInfo, "Roth_UI: configPersistence.GetConfigSchemaInfo is required by persistence_schema_registry.lua")
local GetPersistenceStores = assert(ns and ns.GetPersistenceStores, "Roth_UI: ns.GetPersistenceStores is required by persistence_schema_registry.lua")
local GetConfigDescriptor = assert(registryApi.GetConfigDescriptor, "Roth_UI: persistenceRegistry.GetConfigDescriptor is required by persistence_schema_registry.lua")
local GetOrbDescriptor = assert(registryApi.GetOrbDescriptor, "Roth_UI: persistenceRegistry.GetOrbDescriptor is required by persistence_schema_registry.lua")
local GetOrbPersistenceOwner = assert(registryApi.GetOrbPersistenceOwner, "Roth_UI: persistenceRegistry.GetOrbPersistenceOwner is required by persistence_schema_registry.lua")
local BuildFallbackOrbSchemaInfo = assert(registryApi.BuildFallbackOrbSchemaInfo, "Roth_UI: persistenceRegistry.BuildFallbackOrbSchemaInfo is required by persistence_schema_registry.lua")

local SCHEMA_NODE_KEYS = {
  "config",
  "orbChar",
  "orbGlobal",
}

local function CopySchemaNodeKeys()
  local out = {}
  for i = 1, #SCHEMA_NODE_KEYS do
    out[i] = SCHEMA_NODE_KEYS[i]
  end
  return out
end

function ns.GetPersistenceSchemaNodeKeys()
  return CopySchemaNodeKeys()
end

local function NormalizeSchemaNode(node, fallback)
  local src = (type(node) == "table") and node or {}
  local fb = (type(fallback) == "table") and fallback or {}
  local patch = tonumber(src.patch)
  if patch == nil then
    patch = tonumber(fb.patch) or 0
  end
  local targetPatch = tonumber(src.targetPatch)
  if targetPatch == nil then
    targetPatch = tonumber(fb.targetPatch) or 0
  end
  local out = {
    owner = src.owner or fb.owner,
    variable = src.variable or fb.variable,
    patch = patch,
    targetPatch = targetPatch,
  }
  out.drift = (out.targetPatch > 0) and (out.patch < out.targetPatch)
  return out
end

local function BuildSchemaCatalog(configInfo, orbInfo)
  local configDescriptor = GetConfigDescriptor()
  local orbDescriptor = GetOrbDescriptor()
  local orbOwner = (type(orbInfo) == "table" and orbInfo.owner) or orbDescriptor.owner or "core/orb_persistence_owner.lua"
  return {
    config = NormalizeSchemaNode(configInfo, {
      owner = configDescriptor.owner or configOwner.OWNER_FILE or "core/config_persistence_owner.lua",
      variable = configDescriptor.variable or "Roth_UI_DB",
    }),
    orbChar = NormalizeSchemaNode(orbInfo and orbInfo.char, {
      owner = orbOwner,
      variable = (type(orbDescriptor.char) == "table" and orbDescriptor.char.variable) or "Roth_UI_DB_Char",
    }),
    orbGlobal = NormalizeSchemaNode(orbInfo and orbInfo.global, {
      owner = orbOwner,
      variable = (type(orbDescriptor.global) == "table" and orbDescriptor.global.variable) or "Roth_UI_DB",
    }),
  }
end

local function BuildSchemaCatalogFromInfo(info)
  if type(info) ~= "table" then
    return nil
  end
  if type(info.catalog) == "table" then
    return info.catalog
  end

  local orbInfo = type(info.orb) == "table" and info.orb or nil
  return {
    config = NormalizeSchemaNode(info.config, {}),
    orbChar = NormalizeSchemaNode(orbInfo and orbInfo.char, {}),
    orbGlobal = NormalizeSchemaNode(orbInfo and orbInfo.global, {}),
  }
end

function ns.GetPersistenceSchemaInfo()
  local stores = GetPersistenceStores()
  local orbDescriptor = GetOrbDescriptor()
  local configInfo = GetConfigSchemaInfo()
  local ownerService = GetOrbPersistenceOwner()

  local orbInfo = (type(ownerService) == "table" and type(ownerService.GetSchemaInfo) == "function")
    and ownerService.GetSchemaInfo({
      char = stores and stores.orbChar,
      global = stores and stores.orbGlobal,
    })
    or nil
  if type(orbInfo) ~= "table" then
    orbInfo = BuildFallbackOrbSchemaInfo(orbDescriptor, stores)
  end

  local catalog = BuildSchemaCatalog(configInfo, orbInfo)
  local orbOwner = (type(orbInfo) == "table" and orbInfo.owner) or orbDescriptor.owner or "core/orb_persistence_owner.lua"
  return {
    version = 1,
    config = catalog.config,
    orb = {
      owner = orbOwner,
      char = catalog.orbChar,
      global = catalog.orbGlobal,
    },
    catalog = catalog,
  }
end

function ns.GetPersistenceSchemaCatalog(info)
  local schemaInfo = info
  if schemaInfo == nil then
    schemaInfo = ns.GetPersistenceSchemaInfo()
  end
  return BuildSchemaCatalogFromInfo(schemaInfo)
end
