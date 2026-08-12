local _, ns = ...

-- Own volatile runtime-only persistence state separately from SavedVariables stores.
local safety = assert(ns and ns.safety, "Roth_UI: ns.safety is required by persistence_runtime_state.lua")
local CopySerializable = assert(safety.CopySerializable, "Roth_UI: safety.CopySerializable is required by persistence_runtime_state.lua")

local runtimeApi = ns.persistenceRuntime or {}
ns.persistenceRuntime = runtimeApi

local LEGACY_RUNTIME_KEYS = runtimeApi.LEGACY_RUNTIME_KEYS or {
  _debug = true,
  _log = true,
  _logoutCounter = true,
  _perf = true,
  _perfThreshold = true,
  _pendingReload = true,
  _saveCounter = true,
  _lastChangeAt = true,
  _lastChangePath = true,
  _svDoctorLast = true,
  __svtest_counter = true,
  __svtest_last = true,
}
runtimeApi.LEGACY_RUNTIME_KEYS = LEGACY_RUNTIME_KEYS

local function EnsureRuntimeState()
  local runtimeState = ns._runtimeState
  if type(runtimeState) ~= "table" then
    runtimeState = {}
    ns._runtimeState = runtimeState
  end
  return runtimeState
end

local function EnsureRuntimeBucket(key)
  local runtimeState = EnsureRuntimeState()
  local bucket = runtimeState[key]
  if type(bucket) ~= "table" then
    bucket = {}
    runtimeState[key] = bucket
  end
  return bucket
end

local function PurgeLegacyRuntimeKeys(store)
  if type(store) ~= "table" then
    return
  end

  for key in pairs(LEGACY_RUNTIME_KEYS) do
    store[key] = nil
  end
end

local function MigrateLegacyRuntimeState(store)
  if type(store) ~= "table" then
    return
  end

  local debugState = EnsureRuntimeBucket("debug")
  if debugState.enabled == nil and type(store._debug) == "boolean" then
    debugState.enabled = store._debug
  end
  if debugState.perfEnabled == nil and type(store._perf) == "boolean" then
    debugState.perfEnabled = store._perf
  end
  local perfThreshold = tonumber(store._perfThreshold)
  if debugState.perfThreshold == nil and perfThreshold then
    debugState.perfThreshold = perfThreshold
  end

  local runtimeLog = EnsureRuntimeBucket("logger")
  if type(store._log) == "table" and type(runtimeLog.lines) ~= "table" then
    runtimeLog.lines = CopySerializable(store._log) or {}
  end

  local persistenceState = EnsureRuntimeBucket("persistence")
  if persistenceState.pendingReload == nil and store._pendingReload ~= nil then
    persistenceState.pendingReload = store._pendingReload == true
  end
  local saveCounter = tonumber(store._saveCounter)
  if persistenceState.saveCounter == nil and saveCounter then
    persistenceState.saveCounter = saveCounter
  end
  local lastChangeAt = tonumber(store._lastChangeAt)
  if persistenceState.lastChangeAt == nil and lastChangeAt then
    persistenceState.lastChangeAt = lastChangeAt
  end
  if persistenceState.lastChangePath == nil and type(store._lastChangePath) == "string" then
    persistenceState.lastChangePath = store._lastChangePath
  end
  local logoutCounter = tonumber(store._logoutCounter)
  if persistenceState.logoutCounter == nil and logoutCounter then
    persistenceState.logoutCounter = logoutCounter
  end

  local svDoctorState = EnsureRuntimeBucket("svDoctor")
  if svDoctorState.last == nil and type(store._svDoctorLast) == "table" then
    svDoctorState.last = CopySerializable(store._svDoctorLast) or {}
  end
  local svTestCounter = tonumber(store.__svtest_counter)
  if svDoctorState.testCounter == nil and svTestCounter then
    svDoctorState.testCounter = svTestCounter
  end
  if svDoctorState.testLast == nil and type(store.__svtest_last) == "string" then
    svDoctorState.testLast = store.__svtest_last
  end

  PurgeLegacyRuntimeKeys(store)
end

runtimeApi.EnsureState = EnsureRuntimeState
runtimeApi.EnsureBucket = EnsureRuntimeBucket
runtimeApi.PurgeLegacyKeys = PurgeLegacyRuntimeKeys
runtimeApi.MigrateLegacyState = MigrateLegacyRuntimeState

local function GetRuntimeState()
  return EnsureRuntimeState()
end

local function GetRuntimeDebugState()
  return EnsureRuntimeBucket("debug")
end

local function GetRuntimePersistenceState()
  return EnsureRuntimeBucket("persistence")
end

local function GetRuntimeLog()
  local loggerState = EnsureRuntimeBucket("logger")
  if type(loggerState.lines) ~= "table" then
    loggerState.lines = {}
  end
  return loggerState.lines
end

local function ClearRuntimeLog()
  local loggerState = EnsureRuntimeBucket("logger")
  loggerState.lines = {}
  return loggerState.lines
end

local function GetRuntimeSVDoctorState()
  return EnsureRuntimeBucket("svDoctor")
end

local function ClearPendingReloadHint()
  local persistenceState = EnsureRuntimeBucket("persistence")
  persistenceState.pendingReload = nil
end

runtimeApi.GetState = GetRuntimeState
runtimeApi.GetDebugState = GetRuntimeDebugState
runtimeApi.GetPersistenceState = GetRuntimePersistenceState
runtimeApi.GetLog = GetRuntimeLog
runtimeApi.ClearLog = ClearRuntimeLog
runtimeApi.GetSVDoctorState = GetRuntimeSVDoctorState
runtimeApi.ClearPendingReloadHint = ClearPendingReloadHint

ns.GetRuntimeState = GetRuntimeState
ns.GetRuntimeDebugState = GetRuntimeDebugState
ns.GetRuntimePersistenceState = GetRuntimePersistenceState
ns.GetRuntimeLog = GetRuntimeLog
ns.ClearRuntimeLog = ClearRuntimeLog
ns.GetRuntimeSVDoctorState = GetRuntimeSVDoctorState
ns.ClearPendingReloadHint = ClearPendingReloadHint
