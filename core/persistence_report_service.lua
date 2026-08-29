local addonName = ...
local ns = assert(_G.Roth_UI, "Roth_UI_Options: Roth_UI namespace is required")

-- Own persistence schema/drift reporting separately from SV scanning and reconcile orchestration.
local GetPersistenceSchemaInfo = assert(ns and ns.GetPersistenceSchemaInfo, "Roth_UI: ns.GetPersistenceSchemaInfo is required by persistence_report_service.lua")
local GetPersistenceSchemaCatalog = assert(ns and ns.GetPersistenceSchemaCatalog, "Roth_UI: ns.GetPersistenceSchemaCatalog is required by persistence_report_service.lua")
local GetPersistenceSchemaNodeKeys = assert(ns and ns.GetPersistenceSchemaNodeKeys, "Roth_UI: ns.GetPersistenceSchemaNodeKeys is required by persistence_report_service.lua")
local GetPersistenceDriftPolicy = assert(ns and ns.GetPersistenceDriftPolicy, "Roth_UI: ns.GetPersistenceDriftPolicy is required by persistence_report_service.lua")
local GetPersistenceDriftState = assert(ns and ns.GetPersistenceDriftState, "Roth_UI: ns.GetPersistenceDriftState is required by persistence_report_service.lua")
local GetPersistenceRegistryState = assert(ns and ns.GetPersistenceRegistryState, "Roth_UI: ns.GetPersistenceRegistryState is required by persistence_report_service.lua")
local IsPersistenceDriftAccepted = assert(ns and ns.IsPersistenceDriftAccepted, "Roth_UI: ns.IsPersistenceDriftAccepted is required by persistence_report_service.lua")

local reportApi = ns.persistenceReport or {}
ns.persistenceReport = reportApi

local function BuildSchemaReportEntry(node)
  node = (type(node) == "table") and node or {}
  local patch = tonumber(node.patch) or 0
  local target = tonumber(node.targetPatch) or 0
  return {
    owner = node.owner,
    variable = node.variable,
    patch = patch,
    targetPatch = target,
    effectiveTargetPatch = tonumber(node.effectiveTargetPatch),
    expectedTargetPatch = tonumber(node.expectedTargetPatch),
    targetMismatch = node.targetMismatch == true,
    drift = (target > 0) and (patch < target),
  }
end

function reportApi.BuildSchemaReport()
  local info = GetPersistenceSchemaInfo()
  local catalog = type(info) == "table" and GetPersistenceSchemaCatalog(info) or nil
  local nodeKeys = GetPersistenceSchemaNodeKeys()
  local policy = GetPersistenceDriftPolicy()
  local driftState = GetPersistenceDriftState()
  local registryState = GetPersistenceRegistryState()
  local report = {
    at = time and time() or 0,
    available = type(info) == "table",
    driftCount = 0,
    targetMismatchCount = 0,
    nodeKeys = nodeKeys,
    nodes = {},
    policy = policy,
    registry = registryState,
  }

  local function Add(key, node)
    local entry = BuildSchemaReportEntry(node)
    report.nodes[key] = entry
    if entry.drift then
      report.driftCount = report.driftCount + 1
    end
    if entry.targetMismatch then
      report.targetMismatchCount = report.targetMismatchCount + 1
    end
  end

  for i = 1, #nodeKeys do
    local key = nodeKeys[i]
    Add(key, type(catalog) == "table" and catalog[key] or nil)
  end

  if type(driftState) == "table" and type(driftState.driftCount) == "number" then
    report.driftCount = driftState.driftCount
    report.targetMismatchCount = tonumber(driftState.targetMismatchCount) or report.targetMismatchCount
    for i = 1, #nodeKeys do
      local key = nodeKeys[i]
      local src = driftState.nodes and driftState.nodes[key]
      local dst = report.nodes[key]
      if type(src) == "table" and type(dst) == "table" then
        dst.effectiveTargetPatch = tonumber(src.effectiveTargetPatch)
        dst.expectedTargetPatch = tonumber(src.expectedTargetPatch)
        dst.targetMismatch = src.targetMismatch == true
        dst.drift = src.drift == true
      end
    end
  end
  report.accepted = IsPersistenceDriftAccepted(driftState, policy)
  if type(report.registry) == "table" and report.registry.accepted ~= true then
    report.accepted = false
  end
  return report
end

function reportApi.PrintSchemaReport(report)
  local payload = type(report) == "table" and report or {}
  print(("Roth_UI: schema drift=%d targetMismatch=%d accepted=%s"):format(
    payload.driftCount or 0,
    payload.targetMismatchCount or 0,
    tostring(payload.accepted == true)
  ))
  local function PrintNode(label, entry)
    entry = (type(entry) == "table") and entry or {}
    print(("  %s: patch=%s target=%s expected=%s drift=%s targetMismatch=%s"):format(
      label,
      tostring(entry.patch),
      tostring(entry.targetPatch),
      tostring(entry.expectedTargetPatch),
      tostring(entry.drift == true),
      tostring(entry.targetMismatch == true)
    ))
  end
  local nodeKeys = type(payload.nodeKeys) == "table" and payload.nodeKeys or {}
  for i = 1, #nodeKeys do
    local key = nodeKeys[i]
    PrintNode(key, payload.nodes and payload.nodes[key])
  end
  if type(payload.policy) == "table" then
    print(("  policy: mode=%s requiredSchemaVersion=%s maxDrift=%s maxTargetMismatch=%s allowTargetMismatch=%s"):format(
      tostring(payload.policy.mode),
      tostring(payload.policy.requiredSchemaVersion),
      tostring(payload.policy.maxDriftCount),
      tostring(payload.policy.maxTargetMismatchCount),
      tostring(payload.policy.allowTargetMismatch == true)
    ))
  end
  if type(payload.registry) == "table" then
    print(("  registry: accepted=%s missing=%d invalid=%d extra=%d"):format(
      tostring(payload.registry.accepted == true),
      #(payload.registry.missingDomains or {}),
      #(payload.registry.invalidDomains or {}),
      #(payload.registry.extraDomains or {})
    ))
  end
end

function reportApi.Report(verbose)
  local report = reportApi.BuildSchemaReport()
  if verbose then
    reportApi.PrintSchemaReport(report)
  end
  return report
end

ns.PersistenceSchemaReport = reportApi.Report
