local function expect(condition, message)
  if not condition then error(message, 2) end
end

local timers = {}
_G.C_Timer = { After = function(delay, callback)
  expect(delay == 0, "action-art scheduler used a non-zero delay")
  timers[#timers + 1] = callback
end }
_G.InCombatLockdown = function() return false end
_G.UnitHasVehicleUI = function() return false end
_G.C_ActionBar = {}
_G.MainActionBar = nil
_G.NUM_ACTIONBAR_BUTTONS = 0
_G.Enum = { EditModeActionBarSystemIndices = { MainBar = 1 } }
_G.hooksecurefunc = nil
_G.UIParent = {}

local controller
_G.CreateFrame = function()
  local frame = { events = {}, scripts = {} }
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:SetScript(script, callback) self.scripts[script] = callback end
  controller = frame
  return frame
end

local ns = {
  cfg = { bars = {}, units = { player = { art = { actionbarbackground = { show = false } } } } },
  func = { IsSecretValue = function() return false end },
  frameRegistry = { ResolveFrame = function() return nil end },
  safety = {
    TryCall = function(fn, ...)
      local ok, result = pcall(fn, ...)
      return ok, result
    end,
    CanAccess = function() return true end,
    CanUseRegion = function(value) return type(value) == "table" end,
    TryGet = function(value, key) return true, value and value[key] end,
    TryMethod = function(value, key, ...)
      if value and type(value[key]) == "function" then return true, value[key](value, ...) end
      return false
    end,
  },
  framePolicy = { DeferUntilOutOfCombat = function() return false end },
  moverRuntime = { ApplySavedLayout = function() end },
}

assert(loadfile("core/deferred_scheduler.lua"))("Roth_UI", ns)
assert(loadfile("core/action_bar_background.lua"))("Roth_UI", ns)
expect(controller and controller.scripts.OnEvent, "action-art controller was not created")
expect(type(ns.QueueActionBarArtworkRefresh) == "function", "action-art queue was not published")
expect(ns.RefreshActionBarArtwork == nil and ns.ActionBarBackground == nil,
  "action-art published a parallel direct route")

ns.QueueActionBarArtworkRefresh()
ns.QueueActionBarArtworkRefresh()
expect(#timers == 1, "action-art retained a second next-frame scheduler")
timers[1]()
expect(ns.ActionBarBackground == nil, "disabled action-art unexpectedly published artwork")

print("action-bar shared scheduler test: OK")
