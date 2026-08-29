-- Lazy loader for the settings/import/debug companion addon.

local addonName, ns = ...

local OPTIONS_ADDON = "Roth_UI_Options"
local C_AddOns = assert(C_AddOns, "Roth_UI: C_AddOns is required by options_loader.lua")

function ns.IsOptionsAddonLoaded()
  return C_AddOns.IsAddOnLoaded(OPTIONS_ADDON) == true
end

function ns.LoadOptionsAddon()
  if ns.IsOptionsAddonLoaded() then
    return true
  end

  if InCombatLockdown and InCombatLockdown() then
    return false, "combat"
  end

  local loaded, reason = C_AddOns.LoadAddOn(OPTIONS_ADDON)
  if loaded == true or ns.IsOptionsAddonLoaded() then
    return true
  end
  return false, reason or "unavailable"
end

ns.optionsAddonName = OPTIONS_ADDON
