local function fail(message)
  error(message, 2)
end

local function expect(condition, message)
  if not condition then fail(message) end
end

local function NewEnvironment(useEventUtil)
  local frames = {}
  local callbacks = {}
  local policyCalls = 0
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
      end,
    }
    _G.C_AddOns = nil
  else
    _G.EventUtil = nil
    _G.C_AddOns = {
      IsAddOnLoaded = function(addonName)
        return addonName == "Blizzard_UnitFrame"
      end,
    }
  end

  local ns = {
    func = {
      ApplyGroupFramePolicy = function() policyCalls = policyCalls + 1 end,
      ApplyGlobalFonts = function() fontCalls = fontCalls + 1 end,
    },
  }

  assert(loadfile("core/frame_policy_bootstrap.lua"))("Roth_UI", ns)
  return {
    frames = frames,
    callbacks = callbacks,
    policyCalls = function() return policyCalls end,
    fontCalls = function() return fontCalls end,
  }
end

local eventUtilEnv = NewEnvironment(true)
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
expect(eventUtilEnv.fontCalls() == 1 and eventUtilEnv.policyCalls() == 1,
  "login work did not run exactly once")

eventUtilEnv.callbacks.Blizzard_UnitFrame()
eventUtilEnv.callbacks.Blizzard_CompactRaidFrames()
expect(eventUtilEnv.policyCalls() == 3, "named addon callbacks did not reapply policy")

local fallbackEnv = NewEnvironment(false)
expect(#fallbackEnv.frames == 2, "fallback path did not create exactly login and addon frames")
expect(fallbackEnv.policyCalls() == 1, "already-loaded Blizzard addon was not handled immediately")
local fallbackFrame = fallbackEnv.frames[2]
expect(fallbackFrame.events.ADDON_LOADED == true, "fallback ADDON_LOADED event was not registered")
fallbackFrame.scripts.OnEvent(fallbackFrame, "ADDON_LOADED", "Unrelated_Addon")
expect(fallbackEnv.policyCalls() == 1, "unrelated addon triggered policy")
expect(fallbackFrame.events.ADDON_LOADED == true, "unrelated addon removed fallback listener")
fallbackFrame.scripts.OnEvent(fallbackFrame, "ADDON_LOADED", "Blizzard_CompactRaidFrames")
expect(fallbackEnv.policyCalls() == 2, "target fallback addon did not apply policy")
expect(fallbackFrame.events.ADDON_LOADED == nil, "fallback listener remained after targets resolved")
expect(fallbackFrame.scripts.OnEvent == nil, "fallback script remained after targets resolved")

print("frame policy bootstrap test: OK")
