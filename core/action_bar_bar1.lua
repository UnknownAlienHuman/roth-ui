-----------------------------
-- INIT
-----------------------------

local addon, ns = ...
local gcfg = ns.cfg
if not (gcfg and gcfg.bars and gcfg.bars.bar1) then return end
local cfg = gcfg.bars.bar1
local barRegistry = assert(ns and ns.BarRuntimeRegistry, "Roth_UI.action_bar_bar1: ns.BarRuntimeRegistry is required")

-----------------------------
-- FUNCTIONS
-----------------------------
if type(gcfg.embeds) == "table" and gcfg.embeds.rActionBarStyler == false then return end
if not cfg.enable then return end

local secureActionBars = ns and ns.secureActionBarRuntime
if secureActionBars and type(secureActionBars.IsEnabled) == "function" and secureActionBars.IsEnabled() then
  secureActionBars.SpawnMainBar()
  return
end

local mainBar = _G.MainActionBar or _G.MainMenuBar
if not mainBar then return end

-- Ship mode keeps the Blizzard main bar as the only protected owner until a
-- real Roth-owned secure main-bar stack exists. Do not reparent or relayout
-- Blizzard action buttons here.
barRegistry:RegisterFrame("bar1", mainBar, { role = "main" })
