local _, ns = ...

-- Own canonical account/char roots and domain access separately from sv_store.lua.
local safety = assert(ns and ns.safety, "Roth_UI: ns.safety is required by persistence_root_store.lua")
local CopySerializable = assert(safety.CopySerializable, "Roth_UI: safety.CopySerializable is required by persistence_root_store.lua")
local SanitizeSerializableInPlace = assert(safety.SanitizeSerializableInPlace, "Roth_UI: safety.SanitizeSerializableInPlace is required by persistence_root_store.lua")
local configOwner = assert(ns and ns.configPersistence, "Roth_UI: ns.configPersistence is required by persistence_root_store.lua")
local runtimeApi = assert(ns and ns.persistenceRuntime, "Roth_UI: ns.persistenceRuntime is required by persistence_root_store.lua")
local storeApi = ns.store or {}
ns.store = storeApi

local ACCOUNT_VAR = configOwner.ACCOUNT_DB_VAR or "Roth_UI_DB"
local CHAR_VAR = configOwner.CHAR_DB_VAR or "Roth_UI_DB_Char"
local PurgeLegacyRuntimeKeys = assert(runtimeApi.PurgeLegacyKeys, "Roth_UI: persistenceRuntime.PurgeLegacyKeys is required by persistence_root_store.lua")
local MigrateLegacyRuntimeState = assert(runtimeApi.MigrateLegacyState, "Roth_UI: persistenceRuntime.MigrateLegacyState is required by persistence_root_store.lua")

local function ResolveConfigOwnerMethod(methodName)
  local ownerMethod = configOwner[methodName]
  if type(ownerMethod) ~= "function" then
    error("Roth_UI: config persistence owner method is required by persistence_root_store.lua: " .. tostring(methodName))
  end
  return ownerMethod
end

local EnsureCanonicalPersistenceStores = ResolveConfigOwnerMethod("EnsureCanonicalStores")
local SetCanonicalConfigStore = ResolveConfigOwnerMethod("SetCanonicalConfigStore")
local SetCanonicalTemplateStore = ResolveConfigOwnerMethod("SetCanonicalTemplateStore")
local SetCanonicalOrbCharStore = ResolveConfigOwnerMethod("SetCanonicalOrbCharStore")
local AttachConfigProxy = ResolveConfigOwnerMethod("AttachCfgProxy")

local function GetCanonicalStores()
  return EnsureCanonicalPersistenceStores()
end

local function SetCanonicalConfigRoot(store)
  return SetCanonicalConfigStore(store)
end

local function SetCanonicalTemplateRoot(store)
  return SetCanonicalTemplateStore(store)
end

local function SetCanonicalOrbCharRoot(store)
  return SetCanonicalOrbCharStore(store)
end

local function SyncDomainCaches(domain, store)
  if domain == "config" and type(store) == "table" then
    AttachConfigProxy(store)
  end
end

local function EnsureOrbTemplateList(store)
  if type(store) ~= "table" or type(store.TEMPLATE_LIST) == "table" then
    return
  end

  local db = ns and ns.db
  if db and type(db.GetTemplateListDefaults) == "function" then
    local defaults = db:GetTemplateListDefaults()
    store.TEMPLATE_LIST = type(defaults) == "table" and defaults or {}
    return
  end

  store.TEMPLATE_LIST = {}
end

local function NormalizeAccountRoot(store)
  local root = CopySerializable(store)
  if type(root) ~= "table" then
    root = {}
  end

  if type(root.schema) ~= "table" then
    root.schema = {}
  end
  if type(root.account) ~= "table" then
    root.account = {}
  end
  if type(root.account.settings) ~= "table" then
    root.account.settings = {}
  end
  if type(root.account.templates) ~= "table" then
    root.account.templates = {}
  end

  root.schema.version = tonumber(root.schema.version) or 1
  PurgeLegacyRuntimeKeys(root.account.settings)
  SanitizeSerializableInPlace(root)
  EnsureOrbTemplateList(root.account.templates)
  return root
end

local function NormalizeCharRoot(store)
  local root = CopySerializable(store)
  if type(root) ~= "table" then
    root = {}
  end

  if type(root.schema) ~= "table" then
    root.schema = {}
  end
  if type(root.orbs) ~= "table" then
    root.orbs = {}
  end

  root.schema.version = tonumber(root.schema.version) or 1
  SanitizeSerializableInPlace(root)
  return root
end

local function SyncPersistenceCaches(stores)
  local activeStores = type(stores) == "table" and stores or GetCanonicalStores()
  if type(activeStores) ~= "table" then
    return nil
  end

  SyncDomainCaches("config", activeStores.settings)
  SyncDomainCaches("orbGlobal", activeStores.templates)
  SyncDomainCaches("orbChar", activeStores.orbChar)
  return activeStores
end

local function EnsureConfigRoot()
  local stores = GetCanonicalStores()
  local sv = stores and stores.settings
  if type(sv) ~= "table" then
    sv = SetCanonicalConfigRoot({})
  end

  MigrateLegacyRuntimeState(sv)
  SetCanonicalConfigRoot(sv)
  SyncDomainCaches("config", sv)
  return sv
end

local function GetPersistenceDomainRoot(domain, ensure)
  if domain == "config" then
    if ensure == false then
      local stores = GetCanonicalStores()
      local store = stores and stores.settings
      if type(store) == "table" then
        SyncDomainCaches("config", store)
      end
      return store
    end
    return EnsureConfigRoot()
  end

  local stores = GetCanonicalStores()
  local store
  if domain == "orbChar" then
    store = stores and stores.orbChar
    if type(store) ~= "table" and ensure == true then
      store = SetCanonicalOrbCharRoot({})
    end
  elseif domain == "orbGlobal" then
    store = stores and stores.templates
    if type(store) ~= "table" and ensure == true then
      store = SetCanonicalTemplateRoot({})
    end
  else
    return nil
  end

  if type(store) ~= "table" then
    return nil
  end

  if domain == "orbGlobal" then
    EnsureOrbTemplateList(store)
  end

  SyncDomainCaches(domain, store)
  return store
end

local function SetPersistenceDomainRoot(domain, store)
  if type(store) ~= "table" then
    return false
  end

  if domain == "config" then
    PurgeLegacyRuntimeKeys(store)
  end

  SanitizeSerializableInPlace(store)

  if domain == "orbGlobal" then
    EnsureOrbTemplateList(store)
  end

  if domain == "config" then
    store = SetCanonicalConfigRoot(store)
  elseif domain == "orbChar" then
    store = SetCanonicalOrbCharRoot(store)
  elseif domain == "orbGlobal" then
    store = SetCanonicalTemplateRoot(store)
  else
    return false
  end

  SyncDomainCaches(domain, store)
  return true
end

function ns.ReplacePersistenceRoots(opts)
  local payload = type(opts) == "table" and opts or {}
  local replaced = false

  if payload.accountRoot ~= nil then
    _G[ACCOUNT_VAR] = NormalizeAccountRoot(payload.accountRoot)
    replaced = true
  end

  if payload.charRoot ~= nil then
    _G[CHAR_VAR] = NormalizeCharRoot(payload.charRoot)
    replaced = true
  end

  if not replaced then
    return false
  end

  SyncPersistenceCaches(GetCanonicalStores())
  return true
end

function ns.ResetPersistenceRoots()
  _G[ACCOUNT_VAR] = nil
  _G[CHAR_VAR] = nil
  return true
end

storeApi.GetCanonicalStores = GetCanonicalStores
storeApi.GetDomainRoot = function(domain, ensure)
  return GetPersistenceDomainRoot(domain, ensure == true)
end
storeApi.SetDomainRoot = SetPersistenceDomainRoot
storeApi.GetConfigRoot = EnsureConfigRoot
storeApi.SetConfigRoot = function(store)
  return SetPersistenceDomainRoot("config", store)
end
storeApi.GetOrbCharRoot = function()
  return GetPersistenceDomainRoot("orbChar", false)
end
storeApi.EnsureOrbCharRoot = function()
  return GetPersistenceDomainRoot("orbChar", true)
end
storeApi.SetOrbCharRoot = function(store)
  return SetPersistenceDomainRoot("orbChar", store)
end
storeApi.GetOrbGlobalRoot = function()
  return GetPersistenceDomainRoot("orbGlobal", false)
end
storeApi.EnsureOrbGlobalRoot = function()
  return GetPersistenceDomainRoot("orbGlobal", true)
end
storeApi.SetOrbGlobalRoot = function(store)
  return SetPersistenceDomainRoot("orbGlobal", store)
end
storeApi.ReplaceRoots = ns.ReplacePersistenceRoots
storeApi.ResetRoots = ns.ResetPersistenceRoots
