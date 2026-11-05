local function fail(message)
  error(message, 2)
end

local function expect(condition, message)
  if not condition then fail(message) end
end

local function NewEnvironment(useEventUtil, fontThrows, immediateLoaded)
  local frames = {}
  local callbacks = {}
  local scheduled = {}
  local policyCalls = 0
  local unitPolicyCalls = 0
  local fontCalls = 0

  _G.CreateFrame = function()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(script, callback) self.scripts[script] = callback end
    frames[#frames + 1] = frame
    return frame
  end

  if useEventUtil then
    _G.EventUtil = {
      ContinueOnAddOnLoaded = function(addonName, callback)
        callbacks[addonName] = callback
        if immediateLoaded then callback() end
      end,
    }
    _G.C_AddOns = nil
  else
    _G.EventUtil = nil
    _G.C_AddOns = {
      IsAddOnLoaded = function(addonName)
        if addonName == "Blizzard_UnitFrame" then
          return true, false
        end
        if addonName == "Blizzard_CompactRaidFrames" then
          return true, true
        end
        return false, false
      end,
    }
  end

  local ns = {
    safety = {
      TryCall = function(callback, ...)
        return pcall(callback, ...)
      end,
    },
    defer = {
      RunNextFrame = function(key, callback)
        expect(key == "frame-policy-bootstrap:apply", "bootstrap used an unexpected scheduler key")
        scheduled[key] = callback
        return true
      end,
    },
    func = {
      ApplyGroupFramePolicy = function()
        policyCalls = policyCalls + 1
      end,
      ApplyUnitFramePolicy = function()
        unitPolicyCalls = unitPolicyCalls + 1
      end,
      ApplyGlobalFonts = function()
        fontCalls = fontCalls + 1
        if fontThrows then error("font failure") end
      end,
    },
  }

  assert(loadfile("core/frame_policy_bootstrap.lua"))("Roth_UI", ns)

  local function PendingCount()
    local count = 0
    for _ in pairs(scheduled) do count = count + 1 end
    return count
  end

  local function Drain()
    local work = scheduled
    scheduled = {}
    for _, callback in pairs(work) do callback() end
  end

  return {
    frames = frames,
    callbacks = callbacks,
    pendingCount = PendingCount,
    drain = Drain,
    policyCalls = function() return policyCalls end,
    unitPolicyCalls = function() return unitPolicyCalls end,
    fontCalls = function() return fontCalls end,
  }
end

local eventUtilEnv = NewEnvironment(true, true)
expect(#eventUtilEnv.frames == 1, "EventUtil path created a broad ADDON_LOADED frame")
expect(type(eventUtilEnv.callbacks.Blizzard_UnitFrame) == "function",
  "UnitFrame load callback was not registered")
expect(type(eventUtilEnv.callbacks.Blizzard_CompactRaidFrames) == "function",
  "CompactRaidFrames load callback was not registered")

local loginFrame = eventUtilEnv.frames[1]
expect(loginFrame.events.PLAYER_LOGIN == true, "login event was not registered")
loginFrame.scripts.OnEvent(loginFrame, "PLAYER_LOGIN")
expect(loginFrame.events.PLAYER_LOGIN == nil, "login event remained registered")
expect(loginFrame.scripts.OnEvent == nil, "login script remained installed")
expect(eventUtilEnv.fontCalls() == 1, "login font owner did not run exactly once")
expect(eventUtilEnv.policyCalls() == 0 and eventUtilEnv.pendingCount() == 1,
  "login work bypassed the coalesced policy scheduler")

eventUtilEnv.callbacks.Blizzard_UnitFrame()
eventUtilEnv.callbacks.Blizzard_CompactRaidFrames()
eventUtilEnv.callbacks.Blizzard_UnitFrame()
expect(eventUtilEnv.pendingCount() == 1, "named addon callbacks were not coalesced")
eventUtilEnv.drain()
expect(eventUtilEnv.policyCalls() == 1, "coalesced policy work did not run exactly once")
expect(eventUtilEnv.unitPolicyCalls() == 0, "retired unit-frame policy route was invoked")

local immediateEnv = NewEnvironment(true, false, true)
expect(#immediateEnv.frames == 1, "immediate EventUtil path created a fallback frame")
expect(immediateEnv.policyCalls() == 0 and immediateEnv.pendingCount() == 1,
  "immediate completed-load callbacks bypassed next-frame coalescing")
immediateEnv.drain()
expect(immediateEnv.policyCalls() == 1 and immediateEnv.unitPolicyCalls() == 0,
  "immediate completed-load callbacks did not produce one canonical policy pass")

local fallbackEnv = NewEnvironment(false, false)
expect(#fallbackEnv.frames == 2, "fallback path did not create exactly login and addon frames")
expect(fallbackEnv.policyCalls() == 0 and fallbackEnv.pendingCount() == 1,
  "completed fallback addon did not queue one policy invalidation")
local fallbackLogin = fallbackEnv.frames[1]
local fallbackFrame = fallbackEnv.frames[2]
expect(fallbackFrame.events.ADDON_LOADED == true,
  "loading-inclusive IsAddOnLoaded return incorrectly resolved the fallback listener")

fallbackLogin.scripts.OnEvent(fallbackLogin, "PLAYER_LOGIN")
fallbackFrame.scripts.OnEvent(fallbackFrame, "ADDON_LOADED", "Unrelated_Addon")
expect(fallbackEnv.pendingCount() == 1, "equivalent fallback invalidations did not coalesce")
expect(fallbackFrame.events.ADDON_LOADED == true, "unrelated addon removed fallback listener")

fallbackFrame.scripts.OnEvent(fallbackFrame, "ADDON_LOADED", "Blizzard_UnitFrame")
expect(fallbackFrame.events.ADDON_LOADED == nil, "fallback listener remained after completed targets")
expect(fallbackFrame.scripts.OnEvent == nil, "fallback script remained after completed targets")
expect(fallbackEnv.pendingCount() == 1, "target fallback addon created duplicate policy work")
fallbackEnv.drain()
expect(fallbackEnv.fontCalls() == 1 and fallbackEnv.policyCalls() == 1,
  "fallback readiness did not produce one font and one policy pass")
expect(fallbackEnv.unitPolicyCalls() == 0, "fallback invoked the retired unit-frame policy route")

print("frame policy bootstrap readiness/coalescing test: OK")
