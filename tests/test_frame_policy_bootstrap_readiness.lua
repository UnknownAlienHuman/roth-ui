local function expect(condition, message)
  if not condition then error(message, 2) end
end

local function NewFrame(frames)
  local frame = { events = {}, scripts = {} }
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:UnregisterEvent(event) self.events[event] = nil end
  function frame:SetScript(script, callback) self.scripts[script] = callback end
  frames[#frames + 1] = frame
  return frame
end

local frames = {}
_G.CreateFrame = function() return NewFrame(frames) end
_G.EventUtil = nil
_G.C_AddOns = {
  IsAddOnLoaded = function(addonName)
    if addonName == "Blizzard_UnitFrame" then
      return true, false -- loading, but not finished
    end
    return false, false
  end,
}

local calls = 0
local ns = {
  func = {
    ApplyGroupFramePolicy = function()
      calls = calls + 1
      local fallback = frames[2]
      if calls == 2 then
        expect(fallback.scripts.OnEvent == nil,
          "final fallback listener was not detached before policy callback")
      end
    end,
  },
}
assert(loadfile("core/frame_policy_bootstrap.lua"))("Roth_UI", ns)
expect(calls == 0, "loading-inclusive IsAddOnLoaded result was treated as completed")
expect(#frames == 2, "fallback readiness path did not create one bounded listener")
local fallback = frames[2]
expect(fallback.events.ADDON_LOADED == true, "fallback listener was not registered")
fallback.scripts.OnEvent(fallback, "ADDON_LOADED", "Blizzard_UnitFrame")
expect(calls == 1 and fallback.events.ADDON_LOADED == true,
  "first completed watched addon did not retain the remaining watch")
fallback.scripts.OnEvent(fallback, "ADDON_LOADED", "Blizzard_CompactRaidFrames")
expect(calls == 2, "second completed watched addon did not apply policy")
expect(fallback.events.ADDON_LOADED == nil and fallback.scripts.OnEvent == nil,
  "fallback listener was not released after both addons completed")

frames = {}
local callbacks = {}
_G.CreateFrame = function() return NewFrame(frames) end
_G.C_AddOns = nil
_G.EventUtil = {
  ContinueOnAddOnLoaded = function(addonName, callback)
    callbacks[addonName] = callback
  end,
}
calls = 0
ns = { func = { ApplyGroupFramePolicy = function() calls = calls + 1 end } }
assert(loadfile("core/frame_policy_bootstrap.lua"))("Roth_UI", ns)
callbacks.Blizzard_UnitFrame()
callbacks.Blizzard_UnitFrame()
callbacks.Blizzard_CompactRaidFrames()
callbacks.Blizzard_CompactRaidFrames()
expect(calls == 2, "one-shot addon readiness callbacks applied policy more than once")

print("frame-policy completed-addon readiness test: OK")
