-----------------------------
-- INIT
-----------------------------

local addon, ns = ...
local gcfg = ns.cfg
if not (gcfg and gcfg.bars and gcfg.bars.overridebar) then return end
local cfg = gcfg.bars.overridebar
local barRegistry = assert(ns and ns.BarRuntimeRegistry, "Roth_UI.action_bar_overridebar: ns.BarRuntimeRegistry is required")

-----------------------------
-- FUNCTIONS
-----------------------------
if type(gcfg.embeds) == "table" and gcfg.embeds.rActionBarStyler == false then return end
if not cfg.enable then return end

local overrideBar = _G.OverrideActionBar
if not overrideBar then return end

local function RegisterOverrideBar(reason)
  barRegistry:RegisterFrame("overridebar", overrideBar)
  if type(reason) == "string" and reason ~= "" then
    barRegistry.NotifyChanged("overridebar", reason)
  end
end

-- Keep OverrideActionBar Blizzard-owned. We only observe its layout/visibility
-- changes so Roth-owned artwork/listeners can follow without reparenting the
-- protected frame or relaying out its secure buttons.
if not overrideBar.__rothThinFollowerHooks then
  overrideBar.__rothThinFollowerHooks = true
  overrideBar:HookScript("OnShow", function()
    RegisterOverrideBar("visibility")
  end)
  overrideBar:HookScript("OnHide", function()
    barRegistry.NotifyChanged("overridebar", "visibility")
  end)
  if type(overrideBar.CalcSize) == "function" then
    hooksecurefunc(overrideBar, "CalcSize", function()
      RegisterOverrideBar("layout")
    end)
  end
  if type(overrideBar.UpdateSkin) == "function" then
    hooksecurefunc(overrideBar, "UpdateSkin", function()
      RegisterOverrideBar("layout")
    end)
  end
end

RegisterOverrideBar("register")
