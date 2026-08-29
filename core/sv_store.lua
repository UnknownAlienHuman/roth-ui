-- Roth_UI: low-level SavedVariables path/value API
--
-- Ownership model:
--   * config_persistence_owner.lua owns config reconcile/schema/proxy policy
--     using defaults declared in config.lua.
--   * persistence_runtime_state.lua owns volatile runtime-state buckets + legacy migration.
--   * persistence_root_store.lua owns canonical roots/domain access:
--       store.GetDomainRoot / store.SetDomainRoot / store.ReplaceRoots / store.ResetRoots
--       store.GetConfigRoot / store.GetOrbCharRoot / store.GetOrbGlobalRoot
--   * persistence_control_plane.lua owns the public ns.persistence facade + lifecycle bootstrap.
--   * sv_store.lua owns low-level path/value access used by modules:
--       ns.SVGet / ns.SVSet / ns.SVRebuildRuntime / ns.store.*

local _, ns = ...

local safety = assert(ns and ns.safety, "Roth_UI: ns.safety is required by sv_store.lua")
local IsSecret = assert(safety.IsSecret, "Roth_UI: safety.IsSecret is required by sv_store.lua")
local IsForbiddenTable = assert(safety.IsForbiddenTable, "Roth_UI: safety.IsForbiddenTable is required by sv_store.lua")
local IsSerializablePrimitive = assert(safety.IsSerializablePrimitive, "Roth_UI: safety.IsSerializablePrimitive is required by sv_store.lua")
local CopySerializable = assert(safety.CopySerializable, "Roth_UI: safety.CopySerializable is required by sv_store.lua")
local storeApi = assert(ns and ns.store, "Roth_UI: ns.store is required by sv_store.lua")
ns.persistence = ns.persistence or {}
local GetDomainRoot = assert(storeApi.GetDomainRoot, "Roth_UI: store.GetDomainRoot is required by sv_store.lua")
local SetDomainRoot = assert(storeApi.SetDomainRoot, "Roth_UI: store.SetDomainRoot is required by sv_store.lua")
local GetConfigRoot = assert(storeApi.GetConfigRoot, "Roth_UI: store.GetConfigRoot is required by sv_store.lua")

local function EnsurePath(root, path)
  local t = root
  for i = 1, #path do
    local k = path[i]
    local v = t[k]
    if type(v) ~= "table" or IsSecret(v) or IsForbiddenTable(v) then
      v = {}
      t[k] = v
    end
    t = v
  end
  return t
end

local function GetPath(root, path)
  local t = root
  for i = 1, #path do
    if type(t) ~= "table" then return nil end
    t = t[path[i]]
  end
  return t
end

local function SetPath(root, path, value)
  if #path == 0 then return end
  if #path == 1 then
    root[path[1]] = value
    return
  end
  local unpackFn = _G.unpack or (table and table.unpack)
  local prefix = { unpackFn(path, 1, #path - 1) }
  local parent = EnsurePath(root, prefix)
  parent[path[#path]] = value
end

local function NormalizeSerializableValue(value)
  if value == nil then
    return nil, true
  end

  if IsSerializablePrimitive(value) and not IsSecret(value) then
    return value, true
  end

  if type(value) == "table" then
    local serial = CopySerializable(value)
    if serial == nil then
      return nil, false
    end
    return serial, true
  end

  return nil, false
end

function ns.SVGet(path, default)
  if type(path) ~= "table" then
    return default
  end
  local sv = GetConfigRoot()
  local v = GetPath(sv, path)
  if v == nil then
    return default
  end
  return v
end

storeApi.ReadPath = GetPath
storeApi.GetConfigValue = function(path, default)
  return ns.SVGet(path, default)
end
storeApi.SetConfigValue = function(path, value, opts)
  return ns.SVSet(path, value, opts)
end
local function GetOrbDefaultsRoot()
  local db = ns and ns.db
  if type(db) ~= "table" or type(db.GetOrbDefaults) ~= "function" then
    return nil
  end

  local defaults = db:GetOrbDefaults()
  return type(defaults) == "table" and defaults or nil
end

storeApi.GetOrbConfig = function(orbType)
  if type(orbType) ~= "string" or orbType == "" then
    return nil
  end
  local root = GetDomainRoot("orbChar", false)
  local config = type(root) == "table" and root[orbType] or nil
  if type(config) == "table" then
    return config
  end
  local defaults = GetOrbDefaultsRoot()
  config = type(defaults) == "table" and defaults[orbType] or nil
  return type(config) == "table" and config or nil
end
storeApi.GetOrbDefaults = function(orbType)
  local defaults = GetOrbDefaultsRoot()
  if type(orbType) ~= "string" or orbType == "" then
    return defaults
  end

  local config = type(defaults) == "table" and defaults[orbType] or nil
  return type(config) == "table" and config or nil
end

local function BuildOrbPath(orbType, path)
  if type(orbType) ~= "string" or orbType == "" or type(path) ~= "table" then
    return nil
  end

  local fullPath = { orbType }
  for i = 1, #path do
    fullPath[#fullPath + 1] = path[i]
  end
  return fullPath
end

local function SetDomainValue(domain, path, value)
  if type(path) ~= "table" or #path == 0 then
    return false
  end

  local root = GetDomainRoot(domain, true)
  if type(root) ~= "table" then
    return false
  end

  local serial, ok = NormalizeSerializableValue(value)
  if not ok then
    return false
  end

  SetPath(root, path, serial)
  return SetDomainRoot(domain, root)
end

storeApi.GetOrbCharValue = function(orbType, path, default)
  local root = GetDomainRoot("orbChar", false)
  local fullPath = BuildOrbPath(orbType, path)
  if not fullPath then
    return default
  end
  local value = GetPath(root, fullPath)
  if value == nil then
    return default
  end
  return value
end

storeApi.GetOrbConfigValue = function(orbType, path, default)
  if type(orbType) ~= "string" or orbType == "" or type(path) ~= "table" or #path == 0 then
    return default
  end

  local root = GetDomainRoot("orbChar", false)
  local config = type(root) == "table" and root[orbType] or nil
  local value = type(config) == "table" and GetPath(config, path) or nil
  if value ~= nil then
    return value
  end

  local defaults = GetOrbDefaultsRoot()
  config = type(defaults) == "table" and defaults[orbType] or nil
  value = type(config) == "table" and GetPath(config, path) or nil
  if value ~= nil then
    return value
  end

  return default
end

storeApi.SetOrbCharValue = function(orbType, path, value)
  local fullPath = BuildOrbPath(orbType, path)
  if not fullPath then
    return false
  end
  return SetDomainValue("orbChar", fullPath, value)
end

storeApi.SetOrbConfigValue = function(orbType, path, value)
  local fullPath = BuildOrbPath(orbType, path)
  if not fullPath then
    return false
  end
  return SetDomainValue("orbChar", fullPath, value)
end

storeApi.GetOrbGlobalValue = function(path, default)
  local root = GetDomainRoot("orbGlobal", false)
  local value = GetPath(root, path)
  if value == nil then
    return default
  end
  return value
end

storeApi.SetOrbGlobalValue = function(path, value)
  return SetDomainValue("orbGlobal", path, value)
end

function ns.GetOrbCharStore()
  return storeApi.GetOrbCharRoot()
end

function ns.SetOrbCharStore(store)
  return storeApi.SetOrbCharRoot(store)
end

function ns.GetOrbGlobalStore()
  return storeApi.GetOrbGlobalRoot()
end

function ns.SetOrbGlobalStore(store)
  return storeApi.SetOrbGlobalRoot(store)
end

function ns.GetOrbCharValue(orbType, path, default)
  return storeApi.GetOrbCharValue(orbType, path, default)
end

function ns.SetOrbCharValue(orbType, path, value)
  return storeApi.SetOrbCharValue(orbType, path, value)
end

function ns.GetOrbGlobalValue(path, default)
  return storeApi.GetOrbGlobalValue(path, default)
end

function ns.SetOrbGlobalValue(path, value)
  return storeApi.SetOrbGlobalValue(path, value)
end

function ns.SVSet(path, value, opts)
  if type(path) ~= "table" or #path == 0 then
    return false
  end

  opts = (type(opts) == "table") and opts or nil

  local sv = GetConfigRoot()

  local serial, ok = NormalizeSerializableValue(value)
  if not ok then
    return false
  end

  SetPath(sv, path, serial)

  local markPendingReload = true
  if opts and opts.markPendingReload == false then
    markPendingReload = false
  end

  if markPendingReload then
    local persistenceState = ns.GetRuntimePersistenceState()
    persistenceState.pendingReload = true
  end
  local persistenceState = ns.GetRuntimePersistenceState()
  persistenceState.saveCounter = (tonumber(persistenceState.saveCounter) or 0) + 1
  persistenceState.lastChangeAt = (time and time()) or ((tonumber(persistenceState.lastChangeAt) or 0) + 1)
  persistenceState.lastChangePath = table.concat(path, ".")
  return true
end

function ns.SVRebuildRuntime()
  GetConfigRoot()
  return true
end
storeApi.RebuildRuntime = ns.SVRebuildRuntime
