-- Minimal reversible policy for Blizzard-owned frames.
--
-- Roth UI never reparents protected frames, unregisters Blizzard events,
-- mutates Blizzard globals, changes addon enable state, or writes Blizzard
-- CVars. The policy applies ordinary visual/input state outside combat and owns
-- the single coalescing PLAYER_REGEN_ENABLED queue used by runtime services.

local addonName, ns = ...

local safety = assert(ns and ns.safety, "Roth_UI: safety is required by frame_policy.lua")
local CanAccess = assert(safety.CanAccess, "Roth_UI: safety.CanAccess is required by frame_policy.lua")
local CanUseRegion = assert(safety.CanUseRegion, "Roth_UI: safety.CanUseRegion is required by frame_policy.lua")
local TryCall = assert(safety.TryCall, "Roth_UI: safety.TryCall is required by frame_policy.lua")
local TryMethod = assert(safety.TryMethod, "Roth_UI: safety.TryMethod is required by frame_policy.lua")
local InCombatLockdown = InCombatLockdown
local CreateFrame = CreateFrame
local pairs = pairs
local type = type
local tostring = tostring
local setmetatable = setmetatable

local policy = ns.framePolicy or {}
ns.framePolicy = policy

local frameState = setmetatable({}, { __mode = "k" })
local pending = {}
local regenFrame

local function IsForbidden(frame)
  return frame ~= nil and not CanUseRegion(frame)
end

local function CaptureFrameState(frame)
  if not CanUseRegion(frame) then return nil end
  local state = frameState[frame]
  if state then return state end

  state = { alpha = 1, mouse = true }
  local gotAlpha, alpha = TryMethod(frame, "GetAlpha")
  if gotAlpha == true and CanAccess(alpha) and type(alpha) == "number" then
    state.alpha = alpha
  end
  local gotMouse, enabled = TryMethod(frame, "IsMouseEnabled")
  if gotMouse == true and CanAccess(enabled) and type(enabled) == "boolean" then
    state.mouse = enabled
  end
  frameState[frame] = state
  return state
end

local function ApplySuppressed(frame, suppressed)
  if not frame or IsForbidden(frame) then return false end
  local state = CaptureFrameState(frame)
  if not state then return false end

  local alphaTarget = suppressed and 0 or state.alpha
  local mouseTarget = state.mouse
  if suppressed then mouseTarget = false end
  local alphaApplied = TryMethod(frame, "SetAlpha", alphaTarget) == true
  local mouseApplied = TryMethod(frame, "EnableMouse", mouseTarget) == true
  if alphaApplied or mouseApplied then
    state.suppressed = suppressed and true or false
    return true
  end
  return false
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
  if type(key) ~= "string" or key == "" or type(callback) ~= "function" then return false end
  if not (InCombatLockdown and InCombatLockdown()) then return false end

  pending[key] = callback
  EnsureRegenFrame():RegisterEvent("PLAYER_REGEN_ENABLED")
  return true
end

local function IsRothEnabled(value)
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
  if DeferUntilOutOfCombat("frame:" .. tostring(frame), function()
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
policy.FlushPending = function() return FlushPending(regenFrame) end
policy.GetSuppressionState = function(frame)
  local state = frame and frameState[frame]
  return state and state.suppressed == true or false
end
policy.GetPendingCount = function()
  local count = 0
  for _ in pairs(pending) do count = count + 1 end
  return count
end

ns.IsRothEnabled = IsRothEnabled
