local addonName, ns = ...

local persistence = assert(ns and ns.persistence, "Roth_UI: persistence service is required by settings_actions.lua")
local ResetPersistenceAndReload = assert(persistence.ResetAndReload, "Roth_UI: persistence.ResetAndReload is required by settings_actions.lua")
local InCombatLockdown = InCombatLockdown

local actions = ns.settingsActions or {}
ns.settingsActions = actions

local function GetMoverRuntime()
  local moverRuntime = ns and ns.moverRuntime
  if type(moverRuntime) ~= "table" then
    return nil
  end
  return moverRuntime
end

local function EnsureOptionsLoaded(unavailableMessage)
  local loader = ns and ns.LoadOptionsAddon
  if type(loader) ~= "function" then
    print(unavailableMessage)
    return false
  end
  local loaded, reason = loader()
  if loaded then
    return true
  end
  if reason == "combat" then
    print("Roth_UI: options cannot be loaded during combat.")
  else
    print(unavailableMessage)
  end
  return false
end

local function OpenSettingsCategory(categoryKey, unavailableMessage)
  if not EnsureOptionsLoaded(unavailableMessage) then
    return false
  end
  local settingsUI = ns and ns.SettingsUI
  local openCategory = type(settingsUI) == "table" and settingsUI.Open or nil
  if type(openCategory) ~= "function" then
    print(unavailableMessage)
    return false
  end

  if openCategory(settingsUI, categoryKey) then
    return true
  end

  print(unavailableMessage)
  return false
end

function actions.ResetAll()
  if InCombatLockdown and InCombatLockdown() then
    print("Roth_UI: reset settings is not possible in combat.")
    return false
  end

  local moverRuntime = GetMoverRuntime()
  local forEachMoverFrame = moverRuntime and moverRuntime.ForEachFrame or nil
  local resetMoverLayout = moverRuntime and moverRuntime.ResetLayout or nil
  if type(forEachMoverFrame) == "function" and type(resetMoverLayout) == "function" then
    forEachMoverFrame("all", function(frame)
      resetMoverLayout(frame)
    end)
  end

  print("Roth_UI: Settings reset. Reloading UI...")
  if ResetPersistenceAndReload() ~= true then
    print("Roth_UI: failed to reset settings. UI was not reloaded.")
    return false
  end
  return true
end

function actions.ReloadSession()
  if InCombatLockdown and InCombatLockdown() then
    print("Roth_UI: reload is not possible in combat.")
    return false
  end

  local reloadFn = type(persistence.ReloadUI) == "function" and persistence.ReloadUI or nil
  if not reloadFn then
    print("Roth_UI: reload is not available.")
    return false
  end

  if reloadFn() ~= true then
    print("Roth_UI: reload is not available.")
    return false
  end
  return true
end

function actions.OpenOptions()
  return OpenSettingsCategory("root", "Roth_UI: settings category is not available.")
end

function actions.OpenOrbOptions()
  return OpenSettingsCategory("orb_health", "Roth_UI: Health Orb settings are not available.")
end

function actions.ResetTemplateLibrary()
  local orbPersistence = ns and ns.orbPersistence
  local resetTemplates = type(orbPersistence) == "table" and orbPersistence.ResetTemplateLibrary or nil
  if type(resetTemplates) ~= "function" then
    print("Roth_UI: template reset is not available.")
    return false
  end

  if resetTemplates() ~= true then
    return false
  end

  print("Roth_UI: template library reset. Reloading UI...")
  return actions.ReloadSession()
end

local function ShowTransferDialog(methodName, unavailableMessage, mode)
  if not EnsureOptionsLoaded(unavailableMessage) then
    return false
  end
  local transfer = ns and ns.transfer
  local method = type(transfer) == "table" and transfer[methodName] or nil
  if type(method) ~= "function" then
    print(unavailableMessage)
    return false
  end

  return method(mode or "full")
end

function actions.ShowExport(mode)
  return ShowTransferDialog("ShowExportDialog", "Roth_UI: export dialog is not available.", mode)
end

function actions.ShowImport(mode)
  return ShowTransferDialog("ShowImportDialog", "Roth_UI: import dialog is not available.", mode)
end
