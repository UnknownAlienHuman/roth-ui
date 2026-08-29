-- One-owner Blizzard unit-frame visibility policy.
-- oUF owns Roth frame lifecycle and castbar events. This module never polls
-- casts, hooks Blizzard Show methods, reparents frames or calls private update
-- functions.

local addonName, ns = ...

local func = assert(ns and ns.func, "Roth_UI: ns.func is required by unit_policy.lua")
local policy = assert(ns and ns.framePolicy, "Roth_UI: framePolicy is required by unit_policy.lua")
local SetSuppressed = assert(policy.SetSuppressed, "Roth_UI: framePolicy.SetSuppressed is required")
local IsRothEnabled = assert(policy.IsRothEnabled, "Roth_UI: framePolicy.IsRothEnabled is required")
local DeferUntilOutOfCombat = assert(policy.DeferUntilOutOfCombat, "Roth_UI: framePolicy.DeferUntilOutOfCombat is required")

local function SetRothFrameShown(frame, shown)
  if not frame then return end
  if shown then frame:Show() else frame:Hide() end
end

function func:ApplyUnitFramePolicy()
  local cfg = ns.cfg
  if not (cfg and cfg.units) then return false end
  if DeferUntilOutOfCombat("unit-policy", function() func:ApplyUnitFramePolicy() end) then return false end

  local usePlayer = IsRothEnabled(cfg.units.player and cfg.units.player.show)
  local useTarget = IsRothEnabled(cfg.units.target and cfg.units.target.show)
  local useFocus = IsRothEnabled(cfg.units.focus and cfg.units.focus.show)
  local usePet = IsRothEnabled(cfg.units.pet and cfg.units.pet.show)
  local useBoss = IsRothEnabled(cfg.units.boss and cfg.units.boss.show)

  SetSuppressed(_G.PlayerFrame, usePlayer)
  SetSuppressed(_G.RuneFrame, usePlayer)
  SetSuppressed(_G.TargetFrame, useTarget)
  SetSuppressed(_G.FocusFrame, useFocus)
  SetSuppressed(_G.PetFrame, usePet)
  SetSuppressed(_G.BossTargetFrameContainer, useBoss)
  for i = 1, 8 do SetSuppressed(_G["Boss" .. i .. "TargetFrame"], useBoss) end

  if ns.unit then
    SetRothFrameShown(ns.unit.player, usePlayer)
    SetRothFrameShown(ns.unit.target, useTarget)
    SetRothFrameShown(ns.unit.focus, useFocus)
    SetRothFrameShown(ns.unit.pet, usePet)
  end
  return true
end
