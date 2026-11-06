-- Roth_UI - SavedVariables doctor (No-Ace)
--
-- Scans SavedVariables tables for non-serializable values that can prevent saving.
-- Stores the last report in addon runtime memory for the current session.
--
local _, private = ...
local ns = assert(private or _G.Roth_UI, "Roth_UI: main namespace is required")

local safety = assert(ns and ns.safety, "Roth_UI: ns.safety is required by sv_doctor.lua")
local CanAccess = assert(safety.CanAccess, "Roth_UI: safety.CanAccess is required by sv_doctor.lua")
local IsSecret = assert(safety.IsSecret, "Roth_UI: safety.IsSecret is required by sv_doctor.lua")
local IsForbiddenTable = assert(safety.IsForbiddenTable, "Roth_UI: safety.IsForbiddenTable is required by sv_doctor.lua")
local persistence = assert(ns and ns.persistence, "Roth_UI: persistence service is required by sv_doctor.lua")
local GetScanStores = assert(persistence.GetScanStores, "Roth_UI: persistence.GetScanStores is required by sv_doctor.lua")
local GetStorageLabels = assert(persistence.GetStorageLabels, "Roth_UI: persistence.GetStorageLabels is required by sv_doctor.lua")
local GetDoctorState = assert(persistence.GetDoctorState, "Roth_UI: persistence.GetDoctorState is required by sv_doctor.lua")
local GetConfigRoot = assert(persistence.GetConfigRoot, "Roth_UI: persistence.GetConfigRoot is required by sv_doctor.lua")
local GetPersistenceSchemaNodeKeys = assert(ns and ns.GetPersistenceSchemaNodeKeys, "Roth_UI: ns.GetPersistenceSchemaNodeKeys is required by sv_doctor.lua")
local reportApi = assert(ns and ns.persistenceReport, "Roth_UI: ns.persistenceReport is required by sv_doctor.lua")
local BuildSchemaReport = assert(reportApi.BuildSchemaReport, "Roth_UI: persistenceReport.BuildSchemaReport is required by sv_doctor.lua")

-- Diagnostics capture their read closures once. Do not leave live SavedVariables
-- node maps exposed as a general-purpose public persistence API.
persistence.GetScanStores = nil
persistence.GetStorageLabels = nil

local doctorApi = ns.persistenceDoctor or {}
ns.persistenceDoctor = doctorApi

local function IsOrdinaryTable(value)
  return CanAccess(value) and not IsSecret(value)
    and type(value) == "table" and not IsForbiddenTable(value)
end

local function IsBad(v)
  if not CanAccess(v) or IsSecret(v) then return true end
  local tv = type(v)
  return tv == "function" or tv == "userdata" or tv == "thread"
end

local function SafeType(v)
  if not CanAccess(v) or IsSecret(v) then return "restricted" end
  return type(v)
end

local function SafePathForKey(prefix, key)
  if not CanAccess(key) or IsSecret(key) then
    return prefix .. ".<restricted-key>", "restricted"
  end
  local keyType = type(key)
  if keyType == "string" or keyType == "number" then
    return prefix .. "." .. tostring(key), keyType
  end
  return prefix .. ".<invalid-key>", keyType
end

local function SafeLabel(value, fallback)
  if CanAccess(value) and not IsSecret(value) then
    local valueType = type(value)
    if valueType == "string" and value ~= "" then return value end
    if valueType == "number" then return tostring(value) end
  end
  return fallback
end

local function Scan(t, prefix, out, seen, depth)
  if not IsOrdinaryTable(t) then
    if CanAccess(t) and not IsSecret(t) and type(t) == "table" and IsForbiddenTable(t) then
      out[#out + 1] = { path = prefix, kind = "forbidden_table", vtype = "table" }
    end
    return
  end
  seen = seen or {}
  depth = depth or 0
  if depth > 64 or seen[t] then return end
  seen[t] = true

  for k, v in pairs(t) do
    local path, keyType = SafePathForKey(prefix, k)
    if keyType == "restricted" then
      out[#out + 1] = { path = path, kind = "bad_key_value", vtype = keyType }
    elseif keyType ~= "string" and keyType ~= "number" then
      out[#out + 1] = { path = path, kind = "bad_key_type", vtype = keyType }
    elseif IsBad(k) then
      out[#out + 1] = { path = path, kind = "bad_key_value", vtype = SafeType(k) }
    elseif IsBad(v) then
      out[#out + 1] = { path = path, kind = "bad_value", vtype = SafeType(v) }
    elseif type(v) == "table" then
      Scan(v, path, out, seen, depth + 1)
    end
  end
end

local function GetScanLabels()
  local labels = GetStorageLabels()
  return IsOrdinaryTable(labels) and labels or {}
end

local function GetScanNodeMap(payload)
  if not IsOrdinaryTable(payload) then return {} end
  local nodes = payload.nodes
  return IsOrdinaryTable(nodes) and nodes or {}
end

local function Store(issues, schemaReport)
  local state = GetDoctorState()
  if not IsOrdinaryTable(state) then return false end
  state.last = {
    at = time and time() or 0,
    count = #issues,
    top = {},
    schema = IsOrdinaryTable(schemaReport) and schemaReport or nil,
  }
  for i = 1, math.min(50, #issues) do
    state.last.top[i] = issues[i]
  end
  return true
end

function doctorApi.Scan(verbose)
  local issues = {}
  local stores = GetScanStores()
  local labels = GetScanLabels()
  local storeNodes = GetScanNodeMap(stores)
  local labelNodes = GetScanNodeMap(labels)
  local nodeKeys = GetPersistenceSchemaNodeKeys()
  if not IsOrdinaryTable(nodeKeys) then nodeKeys = {} end

  for i = 1, #nodeKeys do
    local key = nodeKeys[i]
    if CanAccess(key) and not IsSecret(key)
        and (type(key) == "string" or type(key) == "number") then
      local store = storeNodes[key]
      if key == "config" and not IsOrdinaryTable(store) then
        store = GetConfigRoot()
      end
      if IsOrdinaryTable(store) then
        local prefix = SafeLabel(labelNodes[key], SafeLabel(key, "node"))
        Scan(store, prefix, issues)
      else
        local storeType = SafeType(store)
        if storeType ~= "nil" then
          issues[#issues + 1] = {
            path = SafeLabel(labelNodes[key], SafeLabel(key, "node")),
            kind = "restricted_root",
            vtype = storeType,
          }
        end
      end
    end
  end

  local schemaReport = BuildSchemaReport()
  Store(issues, schemaReport)

  local showVerbose = CanAccess(verbose) and not IsSecret(verbose) and verbose == true
  if showVerbose then
    print(("Roth_UI: SVDoctor issues=%d"):format(#issues))
    for i = 1, math.min(20, #issues) do
      local issue = issues[i]
      print(("  #%d %s (%s:%s)"):format(i, issue.path, issue.kind, issue.vtype or "?"))
    end
    if #issues > 20 then
      print(("  ... +%d more (see current session SVDoctor state)"):format(#issues - 20))
    end
    local driftCount = 0
    if IsOrdinaryTable(schemaReport) then
      local value = schemaReport.driftCount
      if CanAccess(value) and not IsSecret(value) and type(value) == "number" then
        driftCount = value
      end
    end
    print(("Roth_UI: schema drift=%d (use /roth schema for details)"):format(driftCount))
  end

  return issues
end


-- Auto-scan on logout is disabled to avoid impacting SavedVariables persistence.
-- Use /roth svdoctor to run the scanner on demand.

-- ---------------------------------------------------------------------------

-- SV test: verifies that runtime cfg is actually built from SavedVariables.
-- Usage: /roth svtest
-- ---------------------------------------------------------------------------
local function GetPath(t, path)
  for i = 1, #path do
    if not IsOrdinaryTable(t) then return nil, true end
    local value = t[path[i]]
    if not CanAccess(value) or IsSecret(value) then return nil, true end
    t = value
  end
  return t, false
end

local function Fmt(v, restricted)
  if restricted or not CanAccess(v) or IsSecret(v) then return "<restricted>" end
  if v == nil then return "nil" end
  local valueType = type(v)
  if valueType == "string" then return string.format("%q", v) end
  if valueType == "number" or valueType == "boolean" then return tostring(v) end
  return "<" .. valueType .. ">"
end

local function ReadStateNumber(state, key, fallback)
  if not IsOrdinaryTable(state) then return fallback end
  local value = state[key]
  if not CanAccess(value) or IsSecret(value) then return fallback end
  value = tonumber(value)
  return type(value) == "number" and value or fallback
end

function doctorApi.TestReport()
  local stores = GetScanStores()
  local labels = GetScanLabels()
  local storeNodes = GetScanNodeMap(stores)
  local labelNodes = GetScanNodeMap(labels)
  local sv = storeNodes.config
  if not IsOrdinaryTable(sv) then sv = GetConfigRoot() end
  local runtime = ns and ns.cfg
  local defaults = ns and ns.cfgDefaults

  local overall = true
  local function Check(label, path)
    local savedValue, savedRestricted = GetPath(sv, path)
    local runtimeValue, runtimeRestricted = GetPath(runtime, path)
    local defaultValue, defaultRestricted = GetPath(defaults, path)
    local pass = not savedRestricted and not runtimeRestricted and not defaultRestricted
      and ((savedValue == runtimeValue) or (savedValue == nil and runtimeValue == defaultValue))
    if not pass then overall = false end
    print(string.format("Roth_UI SVTest: %s | saved=%s | runtime=%s | default=%s | %s",
      label,
      Fmt(savedValue, savedRestricted),
      Fmt(runtimeValue, runtimeRestricted),
      Fmt(defaultValue, defaultRestricted),
      pass and "PASS" or "FAIL"))
  end

  if not IsOrdinaryTable(sv) then
    local label = SafeLabel(labelNodes.config, "config")
    print("Roth_UI SVTest: FAIL - " .. label .. " is missing or restricted (SavedVariables not loaded)")
    return false
  end

  local state = GetDoctorState()
  if not IsOrdinaryTable(state) then
    print("Roth_UI SVTest: FAIL - runtime diagnostic state is unavailable")
    return false
  end
  state.testCounter = ReadStateNumber(state, "testCounter", 0) + 1
  local previousLast = state.testLast
  if not CanAccess(previousLast) or IsSecret(previousLast) or type(previousLast) ~= "string" then
    previousLast = "?"
  end
  state.testLast = (date and date("%Y-%m-%d %H:%M:%S")) or previousLast

  local mode, modeRestricted = GetPath(sv, { "__mode" })
  print("Roth_UI SVTest: SavedVariables present. __mode=" .. Fmt(mode, modeRestricted)
    .. " sessionCounter=" .. Fmt(state.testCounter)
    .. " last=" .. Fmt(state.testLast))

  local serviceRoot = GetConfigRoot()
  local sameRoot = IsOrdinaryTable(serviceRoot) and serviceRoot == sv
  print("Roth_UI SVTest: serviceRoot_is_SV=" .. tostring(sameRoot)
    .. " runtime_has_cfg=" .. tostring(IsOrdinaryTable(runtime))
    .. " defaults_has_cfg=" .. tostring(IsOrdinaryTable(defaults)))

  Check("units.party.show", { "units", "party", "show" })
  Check("units.party.scale", { "units", "party", "scale" })
  Check("units.raid.show", { "units", "raid", "show" })
  Check("units.raid.scale", { "units", "raid", "scale" })
  Check("framesLocked", { "framesLocked" })

  print("Roth_UI SVTest: " .. (overall and "OVERALL PASS" or "OVERALL FAIL")
    .. " (use /roth dump for more values)")
  return overall
end
