local addonName, ns = ...

local persistence = assert(ns and ns.persistence, "Roth_UI: persistence service is required by debug_commands.lua")
local storeApi = assert(ns and ns.store, "Roth_UI: store service is required by debug_commands.lua")
local GetConfigStore = assert(persistence.GetConfigRoot, "Roth_UI: persistence.GetConfigRoot is required by debug_commands.lua")
local GetDebugState = assert(persistence.GetDebugState, "Roth_UI: persistence.GetDebugState is required by debug_commands.lua")
local GetConfigValue = assert(storeApi.GetConfigValue, "Roth_UI: store GetConfigValue is required by debug_commands.lua")
local GetPersistenceState = assert(persistence.GetRuntimeState, "Roth_UI: persistence.GetRuntimeState is required by debug_commands.lua")
local GetSVDoctorState = assert(persistence.GetDoctorState, "Roth_UI: persistence.GetDoctorState is required by debug_commands.lua")
local RunPersistenceDoctor = assert(persistence.RunDoctor, "Roth_UI: persistence.RunDoctor is required by debug_commands.lua")
local ReconcilePersistence = assert(persistence.Reconcile, "Roth_UI: persistence.Reconcile is required by debug_commands.lua")
local RebuildPersistenceRuntime = assert(persistence.RebuildRuntime, "Roth_UI: persistence.RebuildRuntime is required by debug_commands.lua")
local ReportPersistenceSchema = assert(persistence.ReportSchema, "Roth_UI: persistence.ReportSchema is required by debug_commands.lua")
local SetConfigValue = assert(storeApi.SetConfigValue, "Roth_UI: store SetConfigValue is required by debug_commands.lua")
local ClearRuntimeLog = assert(persistence.ClearLog, "Roth_UI: persistence.ClearLog is required by debug_commands.lua")

local debugCommands = ns.debugCommands or {}
ns.debugCommands = debugCommands

local function GetGroupFrameService()
  local service = ns and ns.groupFrameService
  if type(service) ~= "table" then
    return nil
  end
  return service
end

local function GetMoverRuntime()
  local moverRuntime = ns and ns.moverRuntime
  if type(moverRuntime) ~= "table" then
    return nil
  end
  return moverRuntime
end

local function ForEachMoverFrame(selection, callback)
  if type(selection) == "function" and callback == nil then
    callback = selection
    selection = "all"
  end
  if type(callback) ~= "function" then
    return false
  end

  local moverRuntime = GetMoverRuntime()
  local iterator = moverRuntime and moverRuntime.ForEachFrame or nil
  if type(iterator) ~= "function" then
    return false
  end

  iterator(selection or "all", callback)
  return true
end

local function PrintSettingsSnapshot(snapshot)
  local categories = snapshot.categories or {}
  local settings = snapshot.settings or {}

  print(("Roth_UI: settings registry registered=%s categories=%d settings=%d"):format(
    tostring(snapshot.registered == true),
    #categories,
    #settings
  ))

  for i = 1, #categories do
    local entry = categories[i]
    print(("  category %s id=%s parent=%s label=%s"):format(
      tostring(entry.key),
      tostring(entry.id),
      tostring(entry.parentKey),
      tostring(entry.name)
    ))
  end

  for i = 1, #settings do
    local entry = settings[i]
    print(("  setting %s category=%s type=%s reload=%s path=%s"):format(
      tostring(entry.variable),
      tostring(entry.categoryKey),
      tostring(entry.varType),
      tostring(entry.reloadRequired == true),
      tostring(entry.path)
    ))
  end
end

function debugCommands.ToggleDebug()
  local debugState = GetDebugState()
  debugState.enabled = not (debugState.enabled == true)
  print("Roth_UI: debug " .. (debugState.enabled and "enabled" or "disabled"))
  return true
end

function debugCommands.HandlePerf(cmd)
  local debugState = GetDebugState()
  local threshold = type(cmd) == "string" and cmd:match("^perf%s+([%d%.]+)$") or nil
  if threshold then
    debugState.perfThreshold = tonumber(threshold) or debugState.perfThreshold
  end

  if type(cmd) == "string" and cmd:match("clear") then
    if type(ClearRuntimeLog) == "function" then
      ClearRuntimeLog()
      print("Roth_UI: perf log cleared.")
      return true
    end
    print("Roth_UI: perf log clear is not available.")
    return false
  end

  if type(cmd) == "string" and cmd:match("on") then
    debugState.perfEnabled = true
  elseif type(cmd) == "string" and cmd:match("off") then
    debugState.perfEnabled = false
  elseif cmd == "perf" then
    debugState.perfEnabled = not (debugState.perfEnabled == true)
  end

  local thr = tonumber(debugState.perfThreshold) or 2
  print(("Roth_UI: perf logger %s (threshold %.2f ms)"):format(debugState.perfEnabled and "enabled" or "disabled", thr))
  return true
end

function debugCommands.RunSVTest()
  local runSVTest = persistence and persistence.RunSVTest or nil
  if type(runSVTest) == "function" then
    return runSVTest()
  end
  print("Roth_UI: SVTest is not available.")
  return false
end

function debugCommands.RunSchemaReport()
  if ReportPersistenceSchema(true) ~= nil then
    return true
  end
  print("Roth_UI: schema report is not available.")
  return false
end

function debugCommands.RunSettingsSchemaReport()
  local settingsUI = ns and ns.SettingsUI
  if settingsUI and type(settingsUI.GetDebugSnapshot) == "function" then
    local snapshot = settingsUI:GetDebugSnapshot() or {}
    PrintSettingsSnapshot(snapshot)
    return true
  end
  print("Roth_UI: settings registry is not available.")
  return false
end

function debugCommands.RunSmoke(mode)
  local normalizedMode = type(mode) == "string" and mode:lower() or "quick"
  print("Roth_UI: smoke start (" .. normalizedMode .. ")")
  debugCommands.RunSettingsSchemaReport()
  debugCommands.RunSchemaReport()
  debugCommands.RunSVReconcile()
  debugCommands.RunAuraStats(false)
  if normalizedMode == "full" then
    debugCommands.RunSVDoctor()
    debugCommands.PrintBlizzStatus()
  end
  print("Roth_UI: smoke done")
  return true
end

function debugCommands.RunAuraStats(reset)
  local statsFn = ns and ns.GetSimpleAuraStats
  local resetFn = ns and ns.ResetSimpleAuraStats
  if reset and type(resetFn) == "function" then
    resetFn()
  end

  if type(statsFn) == "function" then
    local stats = statsFn() or {}
    print(("Roth_UI: aura stats ingress=%d queued=%d flush=%d applied=%d"):format(
      tonumber(stats.ingressEvents) or 0,
      tonumber(stats.queuedEvents) or 0,
      tonumber(stats.queueFlushes) or 0,
      tonumber(stats.appliedPasses) or 0
    ))
    print(("  payload full=%d incremental=%d added=%d updated=%d removed=%d"):format(
      tonumber(stats.fullPayloads) or 0,
      tonumber(stats.incrementalPayloads) or 0,
      tonumber(stats.addedAuras) or 0,
      tonumber(stats.updatedAuras) or 0,
      tonumber(stats.removedAuras) or 0
    ))
    print(("  containers runs=%d skips=%d skipRate=%.2f%% iterFail=%d session=%.1fs"):format(
      tonumber(stats.containerRuns) or 0,
      tonumber(stats.containerSkips) or 0,
      (tonumber(stats.skipRate) or 0) * 100,
      tonumber(stats.iterationFailures) or 0,
      tonumber(stats.sessionSeconds) or 0
    ))
    print(("  group incremental=%d full=%d reasons init=%d nil=%d fullUpdate=%d missingResolver=%d"):format(
      tonumber(stats.groupIncrementalApplies) or 0,
      tonumber(stats.groupFullScans) or 0,
      tonumber(stats.groupFullScanInit) or 0,
      tonumber(stats.groupFullScanNilPayload) or 0,
      tonumber(stats.groupFullScanIsFullUpdate) or 0,
      tonumber(stats.groupFullScanMissingAuraInstanceResolver) or 0
    ))
    print(("  watch incremental=%d full=%d skips=%d reasons init=%d nil=%d fullUpdate=%d missingResolver=%d"):format(
      tonumber(stats.watchIncrementalApplies) or 0,
      tonumber(stats.watchFullScans) or 0,
      tonumber(stats.watchSkips) or 0,
      tonumber(stats.watchFullScanInit) or 0,
      tonumber(stats.watchFullScanNilPayload) or 0,
      tonumber(stats.watchFullScanIsFullUpdate) or 0,
      tonumber(stats.watchFullScanMissingAuraInstanceResolver) or 0
    ))
    print(("  dedupe group updated=%d removed=%d | watch updated=%d removed=%d | watchNoopPayload=%d"):format(
      tonumber(stats.groupUpdatedAuraIDDeduped) or 0,
      tonumber(stats.groupRemovedAuraIDDeduped) or 0,
      tonumber(stats.watchUpdatedAuraIDDeduped) or 0,
      tonumber(stats.watchRemovedAuraIDDeduped) or 0,
      tonumber(stats.watchNoopPayloads) or 0
    ))
    if reset then
      print("Roth_UI: aura stats reset.")
    end
    return true
  end

  print("Roth_UI: aura stats are not available.")
  return false
end

function debugCommands.RunSVDoctor()
  if RunPersistenceDoctor(true) ~= nil then
    return true
  end
  print("Roth_UI: SVDoctor is not available.")
  return false
end

function debugCommands.RunSVReconcile()
  local result = ReconcilePersistence()
  local accepted = (type(result) == "table" and result.driftAccepted == true)
  local registry = (type(result) == "table" and type(result.registryValidation) == "table") and result.registryValidation or nil
  if accepted then
    print("Roth_UI: persistence stores reconciled (policy accepted).")
  else
    local driftState = type(result) == "table" and result.driftAfter or nil
    local driftCount = tonumber(driftState and driftState.driftCount) or 0
    local mismatchCount = tonumber(driftState and driftState.targetMismatchCount) or 0
    print(("Roth_UI: persistence reconcile finished with unresolved drift (drift=%d targetMismatch=%d)."):format(
      driftCount,
      mismatchCount
    ))
    if type(registry) == "table" and registry.accepted ~= true then
      print(("Roth_UI: persistence domain registry invalid (missing=%d invalid=%d extra=%d)."):format(
        #(registry.missingDomains or {}),
        #(registry.invalidDomains or {}),
        #(registry.extraDomains or {})
      ))
      if #(registry.missingDomains or {}) > 0 then
        print("  missing domains: " .. table.concat(registry.missingDomains, ", "))
      end
      if #(registry.invalidDomains or {}) > 0 then
        print("  invalid domains: " .. table.concat(registry.invalidDomains, ", "))
      end
    end
  end

  debugCommands.RunSchemaReport()
  return true
end

function debugCommands.RunSVRebuild()
  RebuildPersistenceRuntime()
  print("Roth_UI: runtime cfg rebuilt from SavedVariables (no reload).")
  return true
end

function debugCommands.ToggleSecureBars(mode)
  local current = GetConfigValue({ "bars", "secureOwnerBars" }, false) == true
  local nextValue = current

  if type(mode) == "string" then
    local normalized = mode:lower()
    if normalized == "on" or normalized == "enable" then
      nextValue = true
    elseif normalized == "off" or normalized == "disable" then
      nextValue = false
    else
      nextValue = not current
    end
  else
    nextValue = not current
  end

  SetConfigValue({"bars", "secureOwnerBars"}, nextValue)
  print(("Roth_UI: secureOwnerBars %s. Reload required."):format(nextValue and "enabled" or "disabled"))
  return true
end

function debugCommands.RequestBlizzardRestore()
  SetConfigValue({"units", "party", "show"}, false, { markPendingReload = false })
  SetConfigValue({"units", "raid", "show"}, false, { markPendingReload = false })

  local groupFrameService = GetGroupFrameService()
  if type(groupFrameService) ~= "table" then
    print("Roth_UI: Blizzard restore is not available.")
    return false
  end

  local applyPolicy = groupFrameService.ApplyPolicy
  if type(applyPolicy) == "function" then
    applyPolicy()
  end

  local forceRestore = groupFrameService.ForceRestore
  if type(forceRestore) == "function" and forceRestore(true, true, true) then
    print("Roth_UI: Blizzard group frames restore requested.")
    if ns.IsAddOnLoadedCompat then
      if (not ns.IsAddOnLoadedCompat("Blizzard_UnitFrame")) or (not ns.IsAddOnLoadedCompat("Blizzard_CompactRaidFrames")) then
        print("Roth_UI: Blizzard party/raid addons not loaded; /reload may be required.")
      end
    end
    return true
  end

  print("Roth_UI: Blizzard restore is not available.")
  return false
end

function debugCommands.PrintBlizzStatus()
  local groupFrameService = GetGroupFrameService()
  local printStatus = type(groupFrameService) == "table" and groupFrameService.PrintStatus or nil
  if type(printStatus) == "function" and printStatus() == true then
    return true
  end
  print("Roth_UI: Blizzard status is not available.")
  return false
end

function debugCommands.ShowLog(lastN)
  if ns and type(ns.LogDump) == "function" then
    ns.LogDump(lastN)
    return true
  end
  print("Roth_UI: Logger is not available.")
  return false
end

function debugCommands.PrintDump()
  local sv = GetConfigStore()
  local rt = ns and ns.cfg

  local function PrintValue(label, path)
    local function GetPathValue(t)
      for i = 1, #path do
        if type(t) ~= "table" then
          return nil
        end
        t = t[path[i]]
      end
      return t
    end

    local svValue = GetPathValue(sv)
    local runtimeValue = GetPathValue(rt)
    print(string.format("Roth_UI: %s | saved=%s | runtime=%s", label, tostring(svValue), tostring(runtimeValue)))
  end

  PrintValue("units.player.show", {"units", "player", "show"})
  PrintValue("units.target.show", {"units", "target", "show"})
  PrintValue("units.focus.show", {"units", "focus", "show"})
  PrintValue("units.party.show", {"units", "party", "show"})
  PrintValue("units.raid.show", {"units", "raid", "show"})
  PrintValue("framesLocked", {"framesLocked"})

  if type(sv) == "table" then
    local persistenceState = GetPersistenceState()
    local meta = string.format("SV: __mode=%s __build=%s saveCounter=%s lastChange=%s path=%s pendingReload=%s",
      tostring(sv.__mode),
      tostring(sv.__build),
      tostring(persistenceState.saveCounter),
      tostring(persistenceState.lastChangeAt),
      tostring(persistenceState.lastChangePath),
      tostring(persistenceState.pendingReload))
    print("Roth_UI: " .. meta)

    local svDoctorState = GetSVDoctorState()
    if type(svDoctorState.last) == "table" then
      print(string.format("Roth_UI: SVDoctor last at=%s count=%s", tostring(svDoctorState.last.at), tostring(svDoctorState.last.count)))
    end
    return true
  end

  print("Roth_UI: SV is missing or not a table (SavedVariables not loaded?)")
  return false
end

function debugCommands.UnlockSelection(selection)
  local key = selection or "all"
  print("Roth_UI: " .. key .. " unlocked")
  SetConfigValue({"framesLocked"}, false, { markPendingReload = false })

  local moverRuntime = GetMoverRuntime()
  local setMoverUnlocked = moverRuntime and moverRuntime.SetUnlocked or nil
  local getDragHandle = moverRuntime and moverRuntime.GetDragHandle or nil
  if type(setMoverUnlocked) ~= "function" or type(getDragHandle) ~= "function" then
    print("Roth_UI: mover runtime is not available.")
    return false
  end

  ForEachMoverFrame(key, function(frame)
    if getDragHandle(frame) then
      setMoverUnlocked(frame, true)
    end
  end)
  return true
end

function debugCommands.LockSelection(selection)
  local key = selection or "all"
  print("Roth_UI: " .. key .. " locked")
  SetConfigValue({"framesLocked"}, true, { markPendingReload = false })

  local moverRuntime = GetMoverRuntime()
  local setMoverUnlocked = moverRuntime and moverRuntime.SetUnlocked or nil
  local getDragHandle = moverRuntime and moverRuntime.GetDragHandle or nil
  if type(setMoverUnlocked) ~= "function" or type(getDragHandle) ~= "function" then
    print("Roth_UI: mover runtime is not available.")
    return false
  end

  local function AnyMoverUnlocked()
    local anyUnlocked = false
    ForEachMoverFrame("all", function(frame)
      if anyUnlocked then
        return
      end

      local dragHandle = getDragHandle(frame)
      if dragHandle and dragHandle.IsShown and dragHandle:IsShown() then
        anyUnlocked = true
      end
    end)
    return anyUnlocked
  end

  ForEachMoverFrame(key, function(frame)
    if getDragHandle(frame) then
      setMoverUnlocked(frame, false)
    end
  end)

  if AnyMoverUnlocked() then
    if ns and type(ns.ShowMoveGrid) == "function" then
      ns.ShowMoveGrid()
    end
  elseif ns and type(ns.HideMoveGrid) == "function" then
    ns.HideMoveGrid()
  end

  return true
end

function debugCommands.ResetSelection(selection)
  local key = selection or "all"
  if InCombatLockdown and InCombatLockdown() then
    print("Reseting frames is not possible in combat.")
    return false
  end

  print("Roth_UI: " .. key .. " reset")

  local moverRuntime = GetMoverRuntime()
  local resetMoverLayout = moverRuntime and moverRuntime.ResetLayout or nil
  if type(resetMoverLayout) ~= "function" then
    print("Roth_UI: mover runtime is not available.")
    return false
  end

  ForEachMoverFrame(key, function(frame)
    resetMoverLayout(frame)
  end)

  if ns and type(ns.HideMoveGrid) == "function" then
    ns.HideMoveGrid()
  end

  return true
end
