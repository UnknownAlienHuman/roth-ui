-- Bootstrap: finalize config initialization.
--
-- By the time this file runs, config.lua has created the runtime config (ns.cfg)
-- by overlaying Roth_UI_DB.account.settings onto defaults.
-- We now fire Roth_UI:ListenForLoaded callbacks for module-addons.

local addonName, ns = ...
local Roth_UI = _G.Roth_UI or ns

-- Clear the "reload required" hint once a reload actually happened.
if ns and type(ns.ClearPendingReloadHint) == "function" then
  ns.ClearPendingReloadHint()
end

if type(Roth_UI.InitConfig) == "function" then
  Roth_UI:InitConfig()
end
