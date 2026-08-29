---------------------------------------------
--  Roth_UI - slashcmd
---------------------------------------------

local addon, ns = ...
local InCombatLockdown = InCombatLockdown

local function GetDebugCommands()
  local commands = ns and ns.debugCommands
  if type(commands) == "table" then
    return commands
  end

  local loader = ns and ns.LoadOptionsAddon
  if type(loader) == "function" then
    loader()
  end
  commands = ns and ns.debugCommands
  if type(commands) == "table" then
    return commands
  end
  return nil
end

local function GetSettingsActions()
  local actions = ns and ns.settingsActions
  if type(actions) ~= "table" then
    return nil
  end
  return actions
end

local function CallDebug(methodName, ...)
  local debugCommands = GetDebugCommands()
  local method = type(debugCommands) == "table" and debugCommands[methodName] or nil
  if type(method) == "function" then
    return method(...)
  end
  return nil
end

local function CallSettings(methodName, ...)
  local settingsActions = GetSettingsActions()
  local method = type(settingsActions) == "table" and settingsActions[methodName] or nil
  if type(method) == "function" then
    return method(...)
  end
  return nil
end

local function RunDebug(methodName, unavailableMessage, ...)
  if CallDebug(methodName, ...) == nil then
    print(unavailableMessage)
  end
end

local function RunSettings(methodName, unavailableMessage, ...)
  if CallSettings(methodName, ...) == nil then
    print(unavailableMessage)
  end
end

local function NormalizeCommand(cmd)
  cmd = type(cmd) == "string" and cmd or ""
  cmd = cmd:lower()
  cmd = cmd:gsub("^%s+", "")
  cmd = cmd:gsub("%s+$", "")
  return cmd
end

local function MatchAnyPattern(cmd, patterns)
  if type(cmd) ~= "string" or type(patterns) ~= "table" then
    return false
  end

  for i = 1, #patterns do
    if cmd:match(patterns[i]) then
      return true
    end
  end

  return false
end

local COMMAND_GROUP_ORDER = {
  "settings",
  "debug",
  "movers",
}

local COMMAND_GROUP_LABELS = {
  settings = "Settings",
  debug = "Diagnostics",
  movers = "Movers",
}

local commands = {}
local PrintHelp

local function AddCommand(patterns, helpText, handler, group)
  commands[#commands + 1] = {
    patterns = patterns,
    helpText = helpText,
    handler = handler,
    group = COMMAND_GROUP_LABELS[group] and group or "debug",
  }
end

local function AddSelectionCommand(verb, selection, methodName, helpText)
  AddCommand({ "^" .. verb .. selection .. "$" }, helpText, function()
    RunDebug(methodName, "Roth_UI: mover controls are not available.", selection)
  end, "movers")
end

AddCommand({ "^help$" }, nil, function()
  PrintHelp()
end, "debug")

AddCommand({ "^options$" }, "|c00FF3300/roth options|r, open the settings category", function()
  RunSettings("OpenOptions", "Roth_UI: settings category is not available.")
end, "settings")

AddCommand({ "^config$" }, "|c00FF3300/roth config|r, open the Health Orb settings page", function()
  if InCombatLockdown and InCombatLockdown() then
    return
  end
  RunSettings("OpenOrbOptions", "Roth_UI: Health Orb settings are not available.")
end, "settings")

AddCommand({ "^debug$" }, "|c00FF3300/roth debug|r, toggle SavedVariables debug prints", function()
  RunDebug("ToggleDebug", "Roth_UI: debug controls are not available.")
end, "debug")

AddCommand({ "^perf$", "^perf%s+.+$" }, "|c00FF3300/roth perf [on|off|clear|<ms>]|r, perf spike logger", function(cmd)
  RunDebug("HandlePerf", "Roth_UI: perf controls are not available.", cmd)
end, "debug")

AddCommand({ "^svtest$" }, "|c00FF3300/roth svtest|r, run SavedVariables smoke checks", function()
  RunDebug("RunSVTest", "Roth_UI: SVTest is not available.")
end, "debug")

AddCommand({ "^schema$", "^svschema$" }, "|c00FF3300/roth schema|r, print persistence schema patch/drift report", function()
  RunDebug("RunSchemaReport", "Roth_UI: schema report is not available.")
end, "debug")

AddCommand({ "^settingsschema$", "^uischema$" }, "|c00FF3300/roth settingsschema|r, print registered Settings categories and controls", function()
  RunDebug("RunSettingsSchemaReport", "Roth_UI: settings registry is not available.")
end, "debug")

AddCommand({ "^smoke$", "^smoke%s+%S+$" }, "|c00FF3300/roth smoke [full]|r, run bundled runtime smoke checks", function(cmd)
  local mode = cmd:match("^smoke%s+(%S+)$") or "quick"
  RunDebug("RunSmoke", "Roth_UI: smoke is not available.", mode)
end, "debug")

AddCommand({ "^svcheck$", "^svdoctor$", "^doctor$" }, "|c00FF3300/roth svdoctor|r, run persistence doctor checks", function()
  RunDebug("RunSVDoctor", "Roth_UI: SVDoctor is not available.")
end, "debug")

AddCommand({ "^svreconcile$", "^reconcile$" }, "|c00FF3300/roth svreconcile|r, run persistence reconcile + schema report", function()
  RunDebug("RunSVReconcile", "Roth_UI: persistence reconcile is not available.")
end, "debug")

AddCommand({ "^svrebuild$" }, "|c00FF3300/roth svrebuild|r, rebuild runtime config from SavedVariables", function()
  RunDebug("RunSVRebuild", "Roth_UI: SVRebuildRuntime is not available.")
end, "debug")

AddCommand({ "^svreset$", "^factoryreset$" }, "|c00FF3300/roth svreset|r, wipe Roth_UI SavedVariables and reload", function()
  RunSettings("ResetAll", "Roth_UI: settings reset is not available.")
end, "settings")

AddCommand({ "^resettemplates$" }, "|c00FF3300/roth resettemplates|r, wipe shared orb templates and reload", function()
  RunSettings("ResetTemplateLibrary", "Roth_UI: template reset is not available.")
end, "settings")

AddCommand({ "^blizzrestore$", "^restoreblizz$" }, "|c00FF3300/roth blizzrestore|r, force restore Blizzard party/raid frames", function()
  RunDebug("RequestBlizzardRestore", "Roth_UI: Blizzard restore is not available.")
end, "debug")

AddCommand({ "^blizzstatus$" }, "|c00FF3300/roth blizzstatus|r, print Blizzard party/raid frame state", function()
  RunDebug("PrintBlizzStatus", "Roth_UI: Blizzard status is not available.")
end, "debug")

AddCommand({ "^export$", "^export%s+full$" }, "|c00FF3300/roth export|r, open the settings export dialog", function()
  RunSettings("ShowExport", "Roth_UI: export dialog is not available.", "full")
end, "settings")

AddCommand({ "^import$", "^import%s+full$" }, "|c00FF3300/roth import|r, open the settings import dialog", function()
  RunSettings("ShowImport", "Roth_UI: import dialog is not available.", "full")
end, "settings")

AddCommand({ "^log$", "^log%s+%d+$" }, "|c00FF3300/roth log [N]|r, dump last N log lines (default 80)", function(cmd)
  RunDebug("ShowLog", "Roth_UI: Logger is not available.", cmd:match("^log%s+(%d+)$"))
end, "debug")

AddCommand({ "^dump$" }, "|c00FF3300/roth dump|r, show saved+runtime values for key toggles", function()
  RunDebug("PrintDump", "Roth_UI: dump is not available.")
end, "debug")

AddSelectionCommand("lock", "art", "LockSelection", "|c00FF3300/roth lockart|r, lock art movers")
AddSelectionCommand("unlock", "art", "UnlockSelection", "|c00FF3300/roth unlockart|r, unlock art movers")
AddSelectionCommand("reset", "art", "ResetSelection", "|c00FF3300/roth resetart|r, reset art movers")

AddSelectionCommand("lock", "orbs", "LockSelection", "|c00FF3300/roth lockorbs|r, lock orb movers")
AddSelectionCommand("unlock", "orbs", "UnlockSelection", "|c00FF3300/roth unlockorbs|r, unlock orb movers")
AddSelectionCommand("reset", "orbs", "ResetSelection", "|c00FF3300/roth resetorbs|r, reset orb movers")

AddSelectionCommand("lock", "bars", "LockSelection", "|c00FF3300/roth lockbars|r, lock bar movers")
AddSelectionCommand("unlock", "bars", "UnlockSelection", "|c00FF3300/roth unlockbars|r, unlock bar movers")
AddSelectionCommand("reset", "bars", "ResetSelection", "|c00FF3300/roth resetbars|r, reset bar movers")

AddSelectionCommand("lock", "units", "LockSelection", "|c00FF3300/roth lockunits|r, lock unit movers")
AddSelectionCommand("unlock", "units", "UnlockSelection", "|c00FF3300/roth unlockunits|r, unlock unit movers")
AddSelectionCommand("reset", "units", "ResetSelection", "|c00FF3300/roth resetunits|r, reset unit movers")

AddSelectionCommand("lock", "all", "LockSelection", "|c00FF3300/roth lockall|r, lock all movers")
AddSelectionCommand("unlock", "all", "UnlockSelection", "|c00FF3300/roth unlockall|r, unlock all movers")
AddSelectionCommand("reset", "all", "ResetSelection", "|c00FF3300/roth resetall|r, reset all movers")

PrintHelp = function()
  print("|c00FF3300Roth_UI command list:|r")
  for groupIndex = 1, #COMMAND_GROUP_ORDER do
    local group = COMMAND_GROUP_ORDER[groupIndex]
    local groupPrinted = false
    for i = 1, #commands do
      local entry = commands[i]
      local helpText = entry.helpText
      if entry.group == group and type(helpText) == "string" and helpText ~= "" then
        if not groupPrinted then
          print(("|c00FF3300%s:|r"):format(COMMAND_GROUP_LABELS[group] or group))
          groupPrinted = true
        end
        print(helpText)
      end
    end
  end
end

local function SlashCmd(cmd)
  cmd = NormalizeCommand(cmd)
  if cmd == "" then
    PrintHelp()
    return
  end

  for i = 1, #commands do
    local entry = commands[i]
    if MatchAnyPattern(cmd, entry.patterns) then
      entry.handler(cmd)
      return
    end
  end

  PrintHelp()
end

_G["SlashCmdList"] = _G["SlashCmdList"] or {}
_G["SlashCmdList"]["roth"] = SlashCmd
SLASH_roth1 = "/roth"

print("|c00FF3300Roth_UI loaded.|r")
print("|c00FF3300/roth|r to display the command list")
