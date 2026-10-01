local function fail(message)
  error(message, 2)
end

local function expect(condition, message)
  if not condition then fail(message) end
end

local controller = { events = {}, scripts = {} }
function controller:RegisterEvent(event) self.events[event] = true end
function controller:SetScript(script, callback) self.scripts[script] = callback end

local createCount = 0
_G.CreateFrame = function()
  createCount = createCount + 1
  expect(createCount == 1, "disabled artwork should create only the event controller")
  return controller
end
_G.InCombatLockdown = function() return false end
_G.UnitHasVehicleUI = function() return false end
_G.C_ActionBar = {}
_G.UIParent = {}
_G.Enum = {
  EditModeActionBarSystemIndices = {
    MainBar = 1,
  },
}
_G.hooksecurefunc = nil
_G.MainActionBar = nil
_G.C_Timer = nil

local resolveCount = 0
local ns = {
  cfg = {
    bars = {},
    units = {
      player = {
        art = {
          actionbarbackground = {
            show = false,
          },
        },
      },
    },
  },
  func = {
    IsSecretValue = function() return false end,
  },
  frameRegistry = {
    ResolveFrame = function()
      resolveCount = resolveCount + 1
      return nil
    end,
  },
  safety = {
    CanAccess = function() return true end,
    CanUseRegion = function() return false end,
    TryGet = function() return false, nil end,
    TryMethod = function() return false, nil end,
  },
}

assert(loadfile("core/action_bar_background.lua"))("Roth_UI", ns)
expect(type(ns.RefreshActionBarArtwork) == "function", "artwork refresh API was not published")
expect(type(controller.scripts.OnEvent) == "function", "action-bar event handler missing")
for _, event in ipairs({
  "PLAYER_REGEN_DISABLED",
  "PLAYER_REGEN_ENABLED",
  "PLAYER_ENTERING_WORLD",
  "UNIT_ENTERED_VEHICLE",
  "UNIT_EXITED_VEHICLE",
  "UPDATE_BONUS_ACTIONBAR",
  "UPDATE_OVERRIDE_ACTIONBAR",
}) do
  expect(controller.events[event] == true, "missing event registration: " .. event)
end

local initial = resolveCount
controller.scripts.OnEvent(controller, "PLAYER_ENTERING_WORLD", true, false)
expect(resolveCount == initial + 1,
  "PLAYER_ENTERING_WORLD booleans were incorrectly treated as a unit token")

local afterEntering = resolveCount
controller.scripts.OnEvent(controller, "UNIT_ENTERED_VEHICLE", "party1")
expect(resolveCount == afterEntering, "non-player vehicle event triggered a refresh")

controller.scripts.OnEvent(controller, "UNIT_ENTERED_VEHICLE", "player")
expect(resolveCount == afterEntering + 1, "player vehicle event did not refresh artwork")

local beforeCombat = resolveCount
controller.scripts.OnEvent(controller, "PLAYER_REGEN_DISABLED")
expect(resolveCount == beforeCombat, "combat entry performed structural refresh")

controller.scripts.OnEvent(controller, "PLAYER_REGEN_ENABLED")
expect(resolveCount == beforeCombat + 1, "combat exit did not refresh artwork")

print("action-bar event routing test: OK")
