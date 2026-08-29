local addonName, ns = ...
local Roth_UI = ns
local LSM = assert(LibStub("LibSharedMedia-3.0"), "Roth_UI: LibSharedMedia-3.0 is required")

-- LoadOnDemand companion addons attach to the main runtime namespace through
-- this single explicit bridge.
_G.Roth_UI = Roth_UI

-- Retail 12.1 requires the current external oUF release. No compatibility path
-- for pre-14 oUF color or element contracts is retained.
Roth_UI.oUF = assert(_G.oUF, "Roth_UI: oUF 14.0.2 or newer is required")
Roth_UI.rLib = Roth_UI.rLib or _G.rLib

-- ---------------------------------------------------------------------------
-- No-Ace configuration bootstrap
--
-- config.lua defines defaults and overlays SavedVariables into:
--   ns.cfg      (runtime config)
--
-- We keep the original "ListenForLoaded" callback model so external module
-- addons can safely run after config is finalized, but we no longer create an
-- AceDB profile. Persistence is intentionally split by ownership:
--   * Roth_UI_DB.account.settings   -> main UI config
--   * Roth_UI_DB.account.templates  -> shared orb templates
--   * Roth_UI_DB_Char.orbs          -> character orb state
-- ---------------------------------------------------------------------------

local mediaCallbacks = {}
local loadedCallbacks = {}
local configLoaded = false

local function SafeInvoke(fn, ...)
  if type(fn) ~= "function" then
    return false
  end
  local safety = Roth_UI and Roth_UI.safety
  local tryCall = safety and safety.TryCall
  if type(tryCall) ~= "function" then
    return false
  end
  return tryCall(fn, ...)
end

local function EnsureConfigRoot()
  local persistence = assert(ns and ns.persistence, "Roth_UI: persistence service is required by init.lua")
  local getConfigRoot = assert(persistence.GetConfigRoot, "Roth_UI: persistence.GetConfigRoot is required by init.lua")
  return getConfigRoot()
end

--- Finalize config initialization and notify listeners.
-- Called from core/bootstrap.lua.
function Roth_UI:InitConfig()
  if configLoaded then
    return
  end

  -- Ensure SV exists (config.lua should have seeded it already).
  EnsureConfigRoot()

  configLoaded = true

  for _, callback in pairs(loadedCallbacks) do
    SafeInvoke(callback)
  end
end

--- Callback to get notifications when LibSharedMedia registers new content.
LSM.RegisterCallback(Roth_UI, "LibSharedMedia_Registered", function(name, mediaType, key)
  if configLoaded then
    for _, callback in pairs(mediaCallbacks) do
      SafeInvoke(callback, name, mediaType, key)
    end
  end
end)

--- Allows a callback to be registered for when LibSharedMedia registers new content.
function Roth_UI:ListenForMediaChange(callback)
  table.insert(mediaCallbacks, callback)
end

function Roth_UI:ListenForLoaded(callback)
  if configLoaded then
    SafeInvoke(callback)
    return
  end
  table.insert(loadedCallbacks, callback)
end
