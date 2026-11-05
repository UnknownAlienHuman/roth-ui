-- Minimal reversible policy for Blizzard-owned frames.
--
-- Roth UI never reparents protected frames, unregisters Blizzard events,
-- mutates Blizzard globals, changes addon enable state, or writes Blizzard
-- CVars. The policy applies ordinary visual/input state outside combat and owns
-- the single coalescing PLAYER_REGEN_ENABLED queue used by runtime services.

local _, ns = ...

local safety = assert(ns and ns.safety, "Roth_UI: safety is required by frame_policy.lua")
local CanAccess = assert(safety.CanAccess, "Roth_UI: safety.CanAccess is required by frame_policy.lua")
local CanUseRegion = assert(safety.CanUseRegion, "Roth_UI: safety.CanUseRegion is required by frame_policy.lua")
local TryCall = assert(safety.TryCall, "Roth_UI: safety.TryCall is required by frame_policy.lua")
local TryMethod = assert(safety.TryMethod, "Roth_UI: safety.TryMethod is required by frame_policy.lua")
local InCombatLockdown = InCombatLockdown
local CreateFrame = CreateFrame
local pairs = pairs
local type = type
local setmetatable = setmetatable

local policy = ns.framePolicy or {}
ns.framePolicy = policy

-- State exists only while a foreign frame is suppressed or while a failed
-- transition still owns one ordinary property that must be restored.
local frameState = setmetatable({}, { __mode = "k" })
local deferredObjectKeys = setmetatable({}, { __mode = "k" })
local nextDeferredObjectKey = 0
local pending = {}
local regenFrame

local function IsForbidden(frame)
  return frame ~= nil and not CanUseRegion(frame)
end

local function CaptureFrameState(frame)
  if not CanUseRegion(frame) then return nil end

  local state = frameState[frame]
  if state then
    return state
  end

  local gotAlpha, alpha = TryMethod(frame, "GetAlpha")
  local gotMouse, enabled = TryMethod(frame, "IsMouseEnabled")
  if gotAlpha ~= true or not CanAccess(alpha) or type(alpha) ~= "number"
      or gotMouse ~= true or not CanAccess(enabled) or type(enabled) ~= "boolean" then
    return nil
  end
  state = {
    alpha = alpha,
    mouse = enabled,
    suppressed = false,
  }
  frameState[frame] = state
  return state
end

local function RestoreProperty(frame, getter, setter, original, applied)
  if applied == nil then return true, nil end

  local ok, current = TryMethod(frame, getter)
  if ok ~= true or not CanAccess(current) or type(current) ~= type(applied) then
    return false, applied
  end
  if current ~= applied then
    -- Another owner changed this property after Roth wrote it.
    return true, nil
  end
  if TryMethod(frame, setter, original) ~= true then
    return false, applied
  end
  return true, nil
end

local function RestoreTrackedState(frame, state)
  local alphaResolved, appliedAlpha = RestoreProperty(
    frame, "GetAlpha", "SetAlpha", state.alpha, state.appliedAlpha)
  local mouseResolved, appliedMouse = RestoreProperty(
    frame, "IsMouseEnabled", "EnableMouse", state.mouse, state.appliedMouse)
  state.appliedAlpha = appliedAlpha
  state.appliedMouse = appliedMouse
  state.suppressed = false

  if alphaResolved and mouseResolved then
    frameState[frame] = nil
    return true
  end
  return false
end

local function ApplyProperty(frame, getter, setter, original, desired)
  if original == desired then
    return true, nil
  end

  if TryMethod(frame, setter, desired) == true then
    return true, desired
  end

  -- A setter may mutate before raising. Detect that ordinary state so the
  -- rollback path still owns and restores it.
  local ok, current = TryMethod(frame, getter)
  if ok == true and CanAccess(current) and type(current) == type(desired) and current == desired then
    return false, desired
  end
  return false, nil
end

local function ApplySuppressed(frame, suppressed)
  if not frame or IsForbidden(frame) then return false end

  local state
  if suppressed then
    state = CaptureFrameState(frame)
    if not state then return false end
  else
    state = frameState[frame]
    if not state then return true end
  end

  if not suppressed then
    return RestoreTrackedState(frame, state)
  end

  local alphaApplied
  local alphaOk
  alphaOk, alphaApplied = ApplyProperty(frame, "GetAlpha", "SetAlpha", state.alpha, 0)
  state.appliedAlpha = alphaApplied
  if not alphaOk then
    RestoreTrackedState(frame, state)
    return false
  end

  local mouseApplied
  local mouseOk
  mouseOk, mouseApplied = ApplyProperty(frame, "IsMouseEnabled", "EnableMouse", state.mouse, false)
  state.appliedMouse = mouseApplied
  if not mouseOk then
    RestoreTrackedState(frame, state)
    return false
  end

  state.suppressed = true
  return true
end

local function FlushPending(self)
  if InCombatLockdown and InCombatLockdown() then return false end
  if self then self:UnregisterEvent("PLAYER_REGEN_ENABLED") end
  local work = pending
  pending = {}
  for _, callback in pairs(work) do
    TryCall(callback)
  end
  return true
end

local function EnsureRegenFrame()
  if regenFrame then return regenFrame end
  regenFrame = CreateFrame("Frame")
  regenFrame:SetScript("OnEvent", FlushPending)
  return regenFrame
end

local function DeferUntilOutOfCombat(key, callback)
  if not CanAccess(key) or type(key) ~= "string" or key == ""
      or not CanAccess(callback) or type(callback) ~= "function" then
    return false
  end
  if not (InCombatLockdown and InCombatLockdown()) then return false end

  pending[key] = callback
  EnsureRegenFrame():RegisterEvent("PLAYER_REGEN_ENABLED")
  return true
end

local function DeferForObject(scope, object, callback)
  local objectType = type(object)
  if not CanAccess(scope) or type(scope) ~= "string" or scope == ""
      or not CanAccess(object) or (objectType ~= "table" and objectType ~= "userdata")
      or not CanAccess(callback) or type(callback) ~= "function" then
    return false
  end
  if not (InCombatLockdown and InCombatLockdown()) then
    return false
  end

  local key = deferredObjectKeys[object]
  if not key then
    nextDeferredObjectKey = nextDeferredObjectKey + 1
    key = nextDeferredObjectKey
    deferredObjectKeys[object] = key
  end

  return DeferUntilOutOfCombat(scope .. ":" .. key, callback)
end

local function IsRothEnabled(value)
  if not CanAccess(value) then return false end
  if value == nil then return true end
  if type(value) == "boolean" then return value end
  if type(value) == "number" then return value ~= 0 end
  if type(value) == "string" then
    local normalized = value:lower()
    if normalized == "false" or normalized == "0" or normalized == "blizzard" or normalized == "off" then return false end
    if normalized == "true" or normalized == "1" or normalized == "roth" or normalized == "on" then return true end
  end
  return true
end

local function SetSuppressed(frame, suppressed)
  -- Validate the foreign object and requested state before branching, deriving
  -- queue identity or retaining either value in a deferred closure.
  if not CanAccess(suppressed) or type(suppressed) ~= "boolean"
      or not frame or IsForbidden(frame) then
    return false
  end

  if DeferForObject("frame-suppression", frame, function()
    ApplySuppressed(frame, suppressed)
  end) then
    return false
  end
  return ApplySuppressed(frame, suppressed)
end

policy.IsForbidden = IsForbidden
policy.IsRothEnabled = IsRothEnabled
policy.SetSuppressed = SetSuppressed
policy.DeferUntilOutOfCombat = DeferUntilOutOfCombat
policy.DeferForObject = DeferForObject
policy.FlushPending = function() return FlushPending(regenFrame) end
policy.GetSuppressionState = function(frame)
  if not CanAccess(frame) then return false end
  local state = frame and frameState[frame]
  return state and state.suppressed == true or false
end
policy.GetPendingCount = function()
  local count = 0
  for _ in pairs(pending) do count = count + 1 end
  return count
end

ns.IsRothEnabled = IsRothEnabled
