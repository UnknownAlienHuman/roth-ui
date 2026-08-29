-- Minimal reversible policy for Blizzard-owned unit frames.
--
-- Roth UI never reparents protected frames, unregisters their events, mutates
-- Blizzard globals, changes addon enable state, or writes Blizzard CVars. The
-- policy only applies ordinary visual/input state outside combat and restores
-- the state captured before Roth UI first touched each frame.

local addonName, ns = ...

local safety = assert(ns and ns.safety, "Roth_UI: safety is required by frame_policy.lua")
local IsSecret = assert(safety.IsSecret, "Roth_UI: safety.IsSecret is required by frame_policy.lua")
local InCombatLockdown = InCombatLockdown

local policy = ns.framePolicy or {}
ns.framePolicy = policy

local frameState = setmetatable({}, { __mode = "k" })
local pending = {}
local regenFrame

local function IsForbidden(frame)
  if not frame then return false end
  if safety.IsForbiddenTable and safety.IsForbiddenTable(frame) then return true end
  if type(frame.IsForbidden) == "function" then
    local forbidden = frame:IsForbidden()
    return not IsSecret(forbidden) and forbidden == true
  end
  return false
end

local function CaptureFrameState(frame)
  local state = frameState[frame]
  if state then return state end

  state = { alpha = 1, mouse = true }
  if type(frame.GetAlpha) == "function" then
    local alpha = frame:GetAlpha()
    if not IsSecret(alpha) and type(alpha) == "number" then state.alpha = alpha end
  end
  if type(frame.IsMouseEnabled) == "function" then
    local enabled = frame:IsMouseEnabled()
    if not IsSecret(enabled) and type(enabled) == "boolean" then state.mouse = enabled end
  end
  frameState[frame] = state
  return state
end

local function ApplySuppressed(frame, suppressed)
  if not frame or IsForbidden(frame) then return false end
  local state = CaptureFrameState(frame)
  if type(frame.SetAlpha) == "function" then
    frame:SetAlpha(suppressed and 0 or state.alpha)
  end
  if type(frame.EnableMouse) == "function" then
    frame:EnableMouse(suppressed and false or state.mouse)
  end
  state.suppressed = suppressed and true or false
  return true
end

local function FlushPending()
  if InCombatLockdown and InCombatLockdown() then return end
  for key, callback in pairs(pending) do
    pending[key] = nil
    callback()
  end
end

local function DeferUntilOutOfCombat(key, callback)
  if type(key) ~= "string" or key == "" or type(callback) ~= "function" then return false end
  if not (InCombatLockdown and InCombatLockdown()) then return false end

  pending[key] = callback
  if not regenFrame then
    regenFrame = CreateFrame("Frame")
    regenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    regenFrame:SetScript("OnEvent", FlushPending)
  end
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
policy.FlushPending = FlushPending
policy.GetSuppressionState = function(frame)
  local state = frame and frameState[frame]
  return state and state.suppressed == true or false
end

ns.IsRothEnabled = IsRothEnabled
