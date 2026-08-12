local addonName, ns = ...
local Roth_UI = ns
local LSM = LibStub("LibSharedMedia-3.0")

-- Expose the main addon namespace globally so LoadOnDemand module-addons can
-- attach to the same config/state without duplicating logic.
-- (This is intentionally lightweight: modules only read from this table.)
_G.Roth_UI = Roth_UI

-- Emergency combat-stability fallback:
-- direct ownership of Blizzard protected bars/buttons taints retail 12.x combat UI.
Roth_UI.disableProtectedActionBarOwnership = true

-- External oUF support: make oUF available on the addon namespace table
Roth_UI.oUF = Roth_UI.oUF or _G.oUF
Roth_UI.rLib = Roth_UI.rLib or _G.rLib

-- Prepatch (oUF 13.0.0): oUF switched many color flows to ColorMixin objects
-- and calls :GetRGB() internally. Older Roth_UI code used plain {r,g,b} tables,
-- which would break on oUF 13 (nil method GetRGB). Keep this forward/backward
-- compatible by wrapping plain RGB into a table that supports BOTH:
--   * array-style [1],[2],[3]
--   * fields r,g,b
--   * method GetRGB()
-- If CreateColor exists, we also attach GetRGB from the ColorMixin instance.
local function Roth_MakeColor(r, g, b)
  if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
    return nil
  end
  if _G.CreateColor then
    local c = _G.CreateColor(r, g, b)
    -- ensure array-style access for older oUF
    c[1], c[2], c[3] = r, g, b
    return c
  end
  local t = { r, g, b, r = r, g = g, b = b }
  function t:GetRGB()
    return r, g, b
  end
  return t
end

-- Ensure oUF has color tables and that power colors are GetRGB()-compatible.
-- Do NOT overwrite existing ColorMixin objects coming from oUF.
if Roth_UI.oUF then
  local oUF = Roth_UI.oUF
  oUF.colors = oUF.colors or {}
  oUF.colors.power = oUF.colors.power or {}

  if _G.PowerBarColor then
    for token, c in pairs(_G.PowerBarColor) do
      if type(token) == "string" and type(c) == "table" then
        local r = c.r or c[1]
        local g = c.g or c[2]
        local b = c.b or c[3]
        local existing = oUF.colors.power[token]
        if not (type(existing) == "table" and existing.GetRGB) then
          local wrapped = Roth_MakeColor(r, g, b)
          if wrapped then
            oUF.colors.power[token] = wrapped
          end
        end
      end
    end
  end
end

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
