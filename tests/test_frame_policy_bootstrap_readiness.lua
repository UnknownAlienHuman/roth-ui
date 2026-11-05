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

local function NewScheduler()
  local pending = {}
  return {
    RunNextFrame = function(key, callback)
      expect(key == "frame-policy-bootstrap:apply", "unexpected bootstrap scheduler key")
      pending[key] = callback
      return true
    end,
    Count = function()
      local count = 0
      for _ in pairs(pending) do count = count + 1 end
      return count
    end,
    Drain = function()
      local work = pending
      pending = {}
      for _, callback in pairs(work) do callback() end
    end,
  }
end

local frames = {}
local scheduler = NewScheduler()
_G.CreateFrame = function() return NewFrame(frames) end
_G.EventUtil = nil
_G.C_AddOns = {
  IsAddOnLoaded = function(addonName)
    if addonName == "Blizzard_UnitFrame" then
      return true, false
    end
    return false, false
  end,
}

local calls = 0
local ns = {
  safety = { TryCall = function(callback, ...) return pcall(callback, ...) end },
  defer = scheduler,
  func = {
    ApplyGlobalFonts = function() end,
    ApplyGroupFramePolicy = function()
      calls = calls + 1
      local fallback = frames[2]
      expect(fallback.scripts.OnEvent == nil,
        "final fallback listener was not detached before policy callback")
    end,
  },
}
assert(loadfile("core/frame_policy_bootstrap.lua"))("Roth_UI", ns)
expect(calls == 0, "loading-inclusive IsAddOnLoaded result was treated as completed")
expect(#frames == 2, "fallback readiness path did not create one bounded listener")
local fallback = frames[2]
expect(fallback.events.ADDON_LOADED == true, "fallback listener was not registered")
fallback.scripts.OnEvent(fallback, "ADDON_LOADED", "Blizzard_UnitFrame")
expect(calls == 0 and scheduler.Count() == 1 and fallback.events.ADDON_LOADED == true,
  "first completed watched addon did not retain and coalesce the remaining watch")
fallback.scripts.OnEvent(fallback, "ADDON_LOADED", "Blizzard_CompactRaidFrames")
expect(fallback.events.ADDON_LOADED == nil and fallback.scripts.OnEvent == nil,
  "fallback listener was not released after both addons completed")
expect(scheduler.Count() == 1, "completed watched addons created duplicate scheduled work")
scheduler.Drain()
expect(calls == 1, "completed watched addons did not produce one policy pass")

frames = {}
local callbacks = {}
scheduler = NewScheduler()
_G.CreateFrame = function() return NewFrame(frames) end
_G.C_AddOns = nil
_G.EventUtil = {
  ContinueOnAddOnLoaded = function(addonName, callback)
    callbacks[addonName] = callback
  end,
}
calls = 0
ns = {
  safety = { TryCall = function(callback, ...) return pcall(callback, ...) end },
  defer = scheduler,
  func = {
    ApplyGlobalFonts = function() end,
    ApplyGroupFramePolicy = function() calls = calls + 1 end,
  },
}
assert(loadfile("core/frame_policy_bootstrap.lua"))("Roth_UI", ns)
callbacks.Blizzard_UnitFrame()
callbacks.Blizzard_UnitFrame()
callbacks.Blizzard_CompactRaidFrames()
callbacks.Blizzard_CompactRaidFrames()
expect(scheduler.Count() == 1 and calls == 0,
  "one-shot addon readiness callbacks bypassed keyed coalescing")
scheduler.Drain()
expect(calls == 1, "one-shot addon readiness callbacks produced duplicate policy passes")

print("frame-policy completed-addon readiness/coalescing test: OK")
