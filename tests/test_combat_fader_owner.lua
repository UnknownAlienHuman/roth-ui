local function expect(condition, message)
  if not condition then error(message, 2) end
end

local eventFrame
_G.InCombatLockdown = function() return false end
_G.CreateFrame = function()
  local frame = { events = {} }
  function frame:SetScript(_, callback) self.onEvent = callback end
  function frame:IsEventRegistered(event) return self.events[event] == true end
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:UnregisterEvent(event) self.events[event] = nil end
  eventFrame = frame
  return frame
end

local ns = {
  func = { IsSecretValue = function() return false end },
  safety = { CanAccess = function() return true end },
}
assert(loadfile("core/combat_fader.lua"))("Roth_UI", ns)
expect(type(ns.func.AttachCombatFader) == "function", "combat fader owner was not published")
expect(_G.rCombatFrameFader == nil, "combat fader leaked the retired global alias")

local frame = { alpha = 1 }
function frame:SetAlpha(value) self.alpha = value end
function frame:GetAlpha() return self.alpha end
function frame:CreateAnimationGroup()
  local group = {}
  function group:CreateAnimation()
    return {
      SetSmoothing = function() end,
      SetFromAlpha = function() end,
      SetToAlpha = function() end,
      SetDuration = function() end,
    }
  end
  function group:SetScript(_, callback) self.finished = callback end
  function group:Stop() end
  function group:Play() if self.finished then self.finished() end end
  return group
end

expect(ns.func.AttachCombatFader(frame, { alpha = 1, time = 0 }, { alpha = 0.2, time = 0 }) == true,
  "direct combat-fader owner rejected an ordinary frame")
expect(frame.alpha == 0.2, "direct combat-fader owner did not apply out-of-combat alpha")
expect(eventFrame.events.PLAYER_REGEN_DISABLED and eventFrame.events.PLAYER_REGEN_ENABLED,
  "combat-fader owner did not retain its bounded events")

print("combat fader direct-owner test: OK")
