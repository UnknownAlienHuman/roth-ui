local function expect(condition, message)
  if not condition then error(message, 2) end
end

local inCombat = false
_G.InCombatLockdown = function() return inCombat end

local moverLayout = { point = "saved" }
local moverResets = 0
local resetCalls = 0
local reloadCalls = 0
local resetResult = false

_G.Roth_UI = {
  persistence = {
    ResetAndReload = function()
      resetCalls = resetCalls + 1
      if not resetResult then return false end
      moverLayout = nil -- ResetCanonicalRoots replaces the config root, including movers.
      reloadCalls = reloadCalls + 1
      return true
    end,
  },
  moverRuntime = {
    ForEachFrame = function()
      error("Reset All must not walk movers before replacing canonical roots")
    end,
    ResetLayout = function()
      moverResets = moverResets + 1
    end,
  },
}

assert(loadfile("core/settings_actions.lua"))("Roth_UI", _G.Roth_UI)
local actions = assert(_G.Roth_UI.settingsActions)

expect(actions.ResetAll() == false, "failed persistence reset reported success")
expect(resetCalls == 1, "failed reset did not call persistence exactly once")
expect(moverLayout and moverLayout.point == "saved", "failed reset changed saved mover layout")
expect(moverResets == 0, "Reset All performed per-mover resets")
expect(reloadCalls == 0, "failed reset reloaded the UI")

resetResult = true
expect(actions.ResetAll() == true, "successful root reset/reload failed")
expect(resetCalls == 2, "successful reset did not call persistence exactly once")
expect(moverLayout == nil, "successful canonical root reset retained mover layout")
expect(moverResets == 0, "successful Reset All performed redundant mover resets")
expect(reloadCalls == 1, "successful reset did not reload exactly once")

inCombat = true
expect(actions.ResetAll() == false, "combat reset was not refused")
expect(resetCalls == 2 and reloadCalls == 1, "combat refusal reached persistence or reload")
expect(moverResets == 0, "combat refusal reset mover layouts")

print("settings actions reset test: OK")
