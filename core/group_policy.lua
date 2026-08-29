-- One-owner group-frame visibility policy.
-- Blizzard remains responsible for frame construction, layout, CVars and
-- addon enable state; Roth UI only suppresses the default visual roots when its
-- own party/raid frames are enabled.

local addonName, ns = ...

local func = assert(ns and ns.func, "Roth_UI: ns.func is required by group_policy.lua")
local policy = assert(ns and ns.framePolicy, "Roth_UI: framePolicy is required by group_policy.lua")
local SetSuppressed = assert(policy.SetSuppressed, "Roth_UI: framePolicy.SetSuppressed is required")
local IsRothEnabled = assert(policy.IsRothEnabled, "Roth_UI: framePolicy.IsRothEnabled is required")
local DeferUntilOutOfCombat = assert(policy.DeferUntilOutOfCombat, "Roth_UI: framePolicy.DeferUntilOutOfCombat is required")

local function ApplyPartyPolicy(useRoth)
  SetSuppressed(_G.PartyFrame, useRoth)
  SetSuppressed(_G.CompactPartyFrame, useRoth)
end

local function ApplyRaidPolicy(useRoth)
  SetSuppressed(_G.CompactRaidFrameContainer, useRoth)
  SetSuppressed(_G.RaidFrame, useRoth)
  SetSuppressed(_G.RaidParentFrame, useRoth)
end

function func:ApplyGroupFramePolicy()
  local cfg = ns.cfg
  if not (cfg and cfg.units) then return false end
  if DeferUntilOutOfCombat("group-policy", function() func:ApplyGroupFramePolicy() end) then return false end

  local useParty = IsRothEnabled(cfg.units.party and cfg.units.party.show)
  local useRaid = IsRothEnabled(cfg.units.raid and cfg.units.raid.show)
  ApplyPartyPolicy(useParty)
  ApplyRaidPolicy(useRaid)

  if type(ns.ApplyPartyEnabled) == "function" then ns.ApplyPartyEnabled(useParty) end
  if type(ns.ApplyRaidEnabled) == "function" then ns.ApplyRaidEnabled(useRaid) end
  return true
end

ns.groupFrameService = {
  ApplyPolicy = function() return func:ApplyGroupFramePolicy() end,
  PrintStatus = function()
    print(("Roth_UI: party=%s raid=%s"):format(
      tostring(policy.GetSuppressionState(_G.PartyFrame)),
      tostring(policy.GetSuppressionState(_G.CompactRaidFrameContainer))))
    return true
  end,
}
