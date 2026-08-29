local function fail(message)
  error(message, 2)
end

local function expect(condition, message)
  if not condition then fail(message) end
end

local eventHandler
local registeredEvents = {}
local inCombat = false

_G.InCombatLockdown = function() return inCombat end
_G.CreateFrame = function()
  local frame = {}
  function frame:RegisterEvent(event) registeredEvents[event] = true end
  function frame:IsEventRegistered(event) return registeredEvents[event] == true end
  function frame:SetScript(script, callback)
    expect(script == "OnEvent", "unexpected event-frame script")
    eventHandler = callback
  end
  return frame
end

local function NewFrame()
  local frame = { alpha = 1 }
  function frame:SetAlpha(value) self.alpha = value end
  function frame:GetAlpha() return self.alpha end
  function frame:CreateAnimationGroup()
    local group = {}
    function group:CreateAnimation()
      local animation = {}
      function animation:SetSmoothing() end
      function animation:SetFromAlpha(value) self.from = value end
      function animation:SetToAlpha(value) self.to = value end
      function animation:SetDuration(value) self.duration = value end
      return animation
    end
    function group:SetScript(_, callback) self.finished = callback end
    function group:Stop() self.stopped = true end
    function group:Play()
      self.played = true
      if self.finished then self.finished(self) end
    end
    return group
  end
  return frame
end

local ns = { func = {} }
assert(loadfile("core/combat_fader.lua"))("Roth_UI", ns)
expect(type(ns.func.AttachCombatFader) == "function", "combat fader was not published")
expect(type(_G.rCombatFrameFader) == "function", "compatibility alias was not published")

local frame = NewFrame()
expect(ns.func.AttachCombatFader(frame, { alpha = 1, time = 0 }, { alpha = 0.2, time = 0 }) == true,
  "AttachCombatFader failed")
expect(frame.alpha == 0.2, "out-of-combat alpha was not applied")
expect(registeredEvents.PLAYER_REGEN_DISABLED and registeredEvents.PLAYER_REGEN_ENABLED,
  "combat events were not registered")

inCombat = true
eventHandler(nil, "PLAYER_REGEN_DISABLED")
expect(frame.alpha == 1, "combat alpha was not applied")

inCombat = false
eventHandler(nil, "PLAYER_REGEN_ENABLED")
expect(frame.alpha == 0.2, "post-combat alpha was not restored")

print("combat fader test: OK")
