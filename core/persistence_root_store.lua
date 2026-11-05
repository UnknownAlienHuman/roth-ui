local _, ns = ...

-- Own canonical account/char roots and domain access separately from sv_store.lua.
local safety = assert(ns and ns.safety, "Roth_UI: ns.safety is required by persistence_root_store.lua")
local SanitizeSerializableInPlace = assert(safety.SanitizeSerializableInPlace, "Roth_UI: safety.SanitizeSerializableInPlace is required by persistence_root_store.lua")
local CanAccess = assert(safety.CanAccess, "Roth_UI: safety.CanAccess is required by persistence_root_store.lua")
local configOwner = assert(ns and ns.configPersistence, "Roth_UI: ns.configPersistence is required by persistence_root_store.lua")
local runtimeApi = assert(ns and ns.persistenceRuntime, "Roth_UI: ns.persistenceRuntime is required by persistence_root_store.lua")
local storeApi = ns.store or {}
ns.store = storeApi

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
local ReplaceCanonicalRoots = ResolveConfigOwnerMethod("ReplaceCanonicalRoots")
local ResetCanonicalRoots = ResolveConfigOwnerMethod("ResetCanonicalRoots")

-- Root-store internals capture the writer closures once. No later module gets a
-- second mutable SavedVariables-root API through the config owner table.
configOwner.EnsureCanonicalRootTables = nil
configOwner.EnsureCanonicalStores = nil
configOwner.GetConfigRoot = nil
configOwner.GetCanonicalTemplateStore = nil
configOwner.GetCanonicalOrbCharStore = nil
configOwner.GetConfigDefaults = nil
configOwner.SetCanonicalConfigStore = nil
configOwner.SetCanonicalTemplateStore = nil
configOwner.SetCanonicalOrbCharStore = nil
configOwner.ReplaceCanonicalRoots = nil
configOwner.ResetCanonicalRoots = nil
configOwner.AttachCfgProxy = nil
configOwner.RefreshRuntimeConfig = nil
configOwner.InitializeConfigDefaults = nil

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

local function NormalizeAccountRoot(root)
  if type(root) ~= "table" then
    return nil
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
  EnsureOrbTemplateList(root.account.templates)
  return root
end

local function NormalizeCharRoot(root)
  if type(root) ~= "table" then
    return nil
  end
  if type(root.schema) ~= "table" then
    root.schema = {}
  end
  if type(root.orbs) ~= "table" then
    root.orbs = {}
  end

  root.schema.version = tonumber(root.schema.version) or 1
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
  if not CanAccess(domain) or safety.IsSecret(domain)
      or (domain ~= "config" and domain ~= "orbChar" and domain ~= "orbGlobal") then
    return false
  end
  if SanitizeSerializableInPlace(store) ~= true then
    return false
  end

  if domain == "config" then
    PurgeLegacyRuntimeKeys(store)
  end

  if domain == "orbGlobal" then
    EnsureOrbTemplateList(store)
  end

  if domain == "config" then
    store = SetCanonicalConfigRoot(store)
  elseif domain == "orbChar" then
    store = SetCanonicalOrbCharRoot(store)
  else
    store = SetCanonicalTemplateRoot(store)
  end

  SyncDomainCaches(domain, store)
  return true
end

local function CommitPersistenceRoots(payload)
  if type(payload) ~= "table" then
    return false
  end

  local hasRoot = false
  for key in pairs(payload) do
    if key ~= "accountRoot" and key ~= "charRoot" then
      return false
    end
    hasRoot = true
  end
  if not hasRoot then
    return false
  end

  local normalized = {}
  if payload.accountRoot ~= nil then
    normalized.accountRoot = NormalizeAccountRoot(payload.accountRoot)
    if type(normalized.accountRoot) ~= "table" then return false end
  end
  if payload.charRoot ~= nil then
    normalized.charRoot = NormalizeCharRoot(payload.charRoot)
    if type(normalized.charRoot) ~= "table" then return false end
  end
  if ReplaceCanonicalRoots(normalized) ~= true then
    return false
  end

  SyncPersistenceCaches(GetCanonicalStores())
  return true
end

local function ResetPersistenceRoots()
  return ResetCanonicalRoots()
end

local function RestorePersistenceRootReferences(snapshot)
  if type(snapshot) ~= "table"
      or type(snapshot.accountRoot) ~= "table"
      or type(snapshot.charRoot) ~= "table" then
    return false
  end

  -- Transaction rollback must restore the exact roots that existing unit
  -- configuration views reference. This path is internal to the control plane;
  -- ordinary imports still pass through strict detached validation above.
  if ReplaceCanonicalRoots({
    accountRoot = snapshot.accountRoot,
    charRoot = snapshot.charRoot,
  }) ~= true then
    return false
  end

  SyncPersistenceCaches(GetCanonicalStores())
  return true
end

storeApi.GetCanonicalStores = GetCanonicalStores
storeApi.GetDomainRoot = function(domain, ensure)
  return GetPersistenceDomainRoot(domain, ensure == true)
end
storeApi.SetDomainRoot = SetPersistenceDomainRoot
storeApi.GetConfigRoot = EnsureConfigRoot
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
storeApi.CommitRoots = CommitPersistenceRoots
storeApi.ResetRoots = ResetPersistenceRoots
storeApi.RestoreRoots = RestorePersistenceRootReferences
