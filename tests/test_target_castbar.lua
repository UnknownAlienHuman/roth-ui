local function fail(message)
  error(message, 2)
end

local function expect(condition, message)
  if not condition then fail(message) end
end

_G.CreateColor = function(r, g, b, a)
  return { r = r, g = g, b = b, a = a }
end

local function NewTexture()
  local texture = { shown = false }
  function texture:SetAllPoints() end
  function texture:SetTexture() end
  function texture:SetAlpha(value) self.alpha = value end
  function texture:SetSize() end
  function texture:SetPoint() end
  function texture:SetBlendMode() end
  function texture:Show() self.shown = true end
  function texture:SetVertexColorFromBoolean(value, trueColor, falseColor)
    self.booleanValue = value
    self.trueColor = trueColor
    self.falseColor = falseColor
  end
  function texture:SetAlphaFromBoolean(value, trueAlpha, falseAlpha)
    self.booleanValue = value
    self.trueAlpha = trueAlpha
    self.falseAlpha = falseAlpha
  end
  return texture
end

local bar = {
  castbarCfg = {
    texture = "test-texture",
    color = {
      semantic = {
        interruptibleCast = { r = 1, g = 0.5, b = 0, a = 1 },
        nonInterruptible = { r = 0.8, g = 0.8, b = 0.8, a = 1 },
        failedOrInterrupted = { r = 1, g = 0, b = 0, a = 1 },
      },
    },
  },
}
function bar:GetStatusBarTexture() return {} end
function bar:CreateTexture()
  local texture = NewTexture()
  self.createdTextures = self.createdTextures or {}
  self.createdTextures[#self.createdTextures + 1] = texture
  return texture
end
function bar:SetStatusBarColor(r, g, b, a)
  self.color = { r, g, b, a }
end
function bar:IsShown() return self.shown == true end

local nextFrame
local ns = {
  defer = {
    RunNextFrame = function(key, callback, replace)
      nextFrame = callback
    end,
  },
}

assert(loadfile("core/target_castbar.lua"))("Roth_UI", ns)
local runtime = assert(ns.TargetCastbarRuntime)
expect(runtime.Bind(bar, "target") == true, "Bind must succeed")
expect(type(bar.PostCastStart) == "function", "PostCastStart was not bound")
expect(type(bar.PostCastInterruptible) == "function", "PostCastInterruptible was not bound")

local secretMeta = {
  __tostring = function() fail("secret value was converted to text") end,
  __eq = function() fail("secret value was compared") end,
  __lt = function() fail("secret value was ordered") end,
  __le = function() fail("secret value was ordered") end,
}
local secretStart = setmetatable({}, secretMeta)
bar:PostCastStart("target", 12345, secretStart, "Spell", 1, false)
expect(rawequal(bar.__rothInterruptOverlay.booleanValue, secretStart), "PostCastStart did not forward secret boolean")
expect(rawequal(bar.Shield.booleanValue, secretStart), "shield did not receive secret boolean")
expect(bar.__rothInterruptOverlay.alpha == 1, "interrupt overlay must be active")

local secretChanged = setmetatable({}, secretMeta)
bar:PostCastInterruptible("target", 12345, secretChanged)
expect(rawequal(bar.__rothInterruptOverlay.booleanValue, secretChanged), "interruptibility event did not forward secret boolean")
expect(rawequal(bar.Shield.booleanValue, secretChanged), "shield did not receive changed secret boolean")

bar.shown = true
local forceUpdates = 0
function bar:ForceUpdate() forceUpdates = forceUpdates + 1 end
runtime.ScheduleActiveRefresh()
expect(type(nextFrame) == "function", "refresh was not coalesced")
nextFrame()
expect(forceUpdates == 1, "visible castbar must refresh through oUF ForceUpdate")

bar:PostCastFail("target", 12345)
expect(bar.__rothInterruptOverlay.alpha == 0, "failure must clear interrupt overlay")
expect(bar.Shield.alpha == 0, "failure must clear shield")

print("target castbar secret-sink test: OK")
