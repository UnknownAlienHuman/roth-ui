-- Bootstrap: finalize config initialization.
--
-- By the time this file runs, config.lua has created the runtime config (ns.cfg)
-- by overlaying Roth_UI_DB.account.settings onto defaults.
-- We fire Roth_UI:ListenForLoaded callbacks for bounded internal consumers.

local _, ns = ...
local Roth_UI = assert(ns, "Roth_UI: main namespace is required by bootstrap.lua")

-- Clear the "reload required" hint once a reload actually happened.
if ns and type(ns.ClearPendingReloadHint) == "function" then
  ns.ClearPendingReloadHint()
end

if type(Roth_UI.InitConfig) == "function" then
  Roth_UI:InitConfig()
end
