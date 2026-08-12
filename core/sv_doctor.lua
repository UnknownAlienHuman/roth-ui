-- Roth_UI - SavedVariables doctor (No-Ace)
--
-- Scans SavedVariables tables for non-serializable values that can prevent saving.
-- Stores the last report in addon runtime memory for the current session.
--
local addonName, ns = ...

local safety = assert(ns and ns.safety, "Roth_UI: ns.safety is required by sv_doctor.lua")
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

local doctorApi = ns.persistenceDoctor or {}
ns.persistenceDoctor = doctorApi

local function IsBad(v)
  local tv = type(v)
  if tv == "function" or tv == "userdata" or tv == "thread" then return true end
  if IsSecret(v) then return true end
  return false
end

local function Scan(t, prefix, out, seen, depth)
  if type(t) ~= "table" then return end
  seen = seen or {}
  depth = depth or 0
  if depth > 64 then return end
  if seen[t] then return end
  seen[t] = true

  -- Avoid hard errors when a table value is marked forbidden by the client
  -- (attempted to index a forbidden table). In that case we record it and stop.
  if IsForbiddenTable(t) then
    out[#out+1] = { path = prefix, kind = 'forbidden_table', vtype = 'table' }
    return
  end

  for k, v in pairs(t) do
    local tk = type(k)
    local path = prefix .. "." .. tostring(k)
    if tk ~= "string" and tk ~= "number" then
      out[#out+1] = { path = path, kind = "bad_key_type", vtype = tk }
    elseif IsBad(k) then
      out[#out+1] = { path = path, kind = "bad_key_value", vtype = tk }
    elseif IsBad(v) then
      out[#out+1] = { path = path, kind = "bad_value", vtype = type(v) }
    elseif type(v) == "table" then
      Scan(v, path, out, seen, depth + 1)
    end
  end
end

local function GetScanLabels()
  local labels = GetStorageLabels()
  return type(labels) == "table" and labels or {}
end

local function GetScanNodeMap(payload)
  if type(payload) ~= "table" then
    return {}
  end
  return type(payload.nodes) == "table" and payload.nodes or {}
end

local function Store(issues, schemaReport)
  local state = GetDoctorState() or {}
  state.last = {
    at = time and time() or 0,
    count = #issues,
    top = {},
    schema = schemaReport,
  }
  -- store up to 50 issues for offline inspection
  for i = 1, math.min(50, #issues) do
    state.last.top[i] = issues[i]
  end
end

function doctorApi.Scan(verbose)
  local issues = {}
  local stores = GetScanStores()
  local labels = GetScanLabels()
  local storeNodes = GetScanNodeMap(stores)
  local labelNodes = GetScanNodeMap(labels)
  local nodeKeys = GetPersistenceSchemaNodeKeys()

  for i = 1, #nodeKeys do
    local key = nodeKeys[i]
    local store = storeNodes[key]
    if key == "config" and type(store) ~= "table" then
      store = GetConfigRoot()
    end
    if type(store) == "table" then
      Scan(store, labelNodes[key] or key, issues)
    end
  end

  local schemaReport = BuildSchemaReport()
  Store(issues, schemaReport)

  if verbose then
    print(("Roth_UI: SVDoctor issues=%d"):format(#issues))
    for i = 1, math.min(20, #issues) do
      local it = issues[i]
      print(("  #%d %s (%s:%s)"):format(i, it.path, it.kind, it.vtype or "?"))
    end
    if #issues > 20 then
      print(("  ... +%d more (see current session SVDoctor state)"):format(#issues - 20))
    end
    print(("Roth_UI: schema drift=%d (use /roth schema for details)"):format(schemaReport.driftCount or 0))
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
    if type(t) ~= "table" then return nil end
    t = t[path[i]]
  end
  return t
end

local function Fmt(v)
  if v == nil then return "nil" end
  local tv = type(v)
  if tv == "string" then return string.format("%q", v) end
  return tostring(v)
end

function doctorApi.TestReport()
  local stores = GetScanStores()
  local labels = GetScanLabels()
  local storeNodes = GetScanNodeMap(stores)
  local labelNodes = GetScanNodeMap(labels)
  local sv = storeNodes.config or GetConfigRoot()
  local rt = ns and ns.cfg
  local def = ns and ns.cfgDefaults

  local ok = true
  local function C(label, path)
    local svv = GetPath(sv, path)
    local rtv = GetPath(rt, path)
    local defv = GetPath(def, path)
    local pass = (svv == rtv) or (svv == nil and rtv == defv)
    if not pass then ok = false end
    print(string.format("Roth_UI SVTest: %s | saved=%s | runtime=%s | default=%s | %s",
      label, Fmt(svv), Fmt(rtv), Fmt(defv), pass and "PASS" or "FAIL"))
  end

  if type(sv) ~= "table" then
    print("Roth_UI SVTest: FAIL - " .. tostring(labelNodes.config or "config") .. " is missing (SavedVariables not loaded)")
    return false
  end

  local state = GetDoctorState() or {}
  state.testCounter = (tonumber(state.testCounter) or 0) + 1
  state.testLast = (date and date("%Y-%m-%d %H:%M:%S")) or state.testLast or "?"

  print("Roth_UI SVTest: SavedVariables present. __mode="..tostring(sv.__mode).." sessionCounter="..tostring(state.testCounter).." last="..tostring(state.testLast))
  local serviceRoot = GetConfigRoot()
  print("Roth_UI SVTest: serviceRoot_is_SV="..tostring(serviceRoot == sv).." runtime_has_cfg="..tostring(type(rt)=="table").." defaults_has_cfg="..tostring(type(def)=="table"))

  C("units.party.show", {"units","party","show"})
  C("units.party.scale", {"units","party","scale"})
  C("units.raid.show", {"units","raid","show"})
  C("units.raid.scale", {"units","raid","scale"})
  C("framesLocked", {"framesLocked"})

  print("Roth_UI SVTest: "..(ok and "OVERALL PASS" or "OVERALL FAIL").." (use /roth dump for more values)")
  return ok
end

ns.SVDoctorScan = doctorApi.Scan
ns.SVTestReport = doctorApi.TestReport
