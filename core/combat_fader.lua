local addonName, ns = ...

local func = assert(ns and ns.func, "Roth_UI: ns.func is required by combat_fader.lua")
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local pairs = pairs
local setmetatable = setmetatable
local tonumber = tonumber
local CanAccessValue = (ns.safety and ns.safety.CanAccess) or func.CanAccessValue or function(value)
  return not func.IsSecretValue(value)
end

-- All fader metadata is owned here. Resource bars are addon-owned frames, but
-- keeping state in a weak table avoids exporting private fields onto widgets and
-- makes the ownership boundary explicit.
local states = setmetatable({}, { __mode = "k" })
local eventFrame = CreateFrame("Frame")

local function Number(value, fallback)
  if not CanAccessValue(value) then return fallback end
  local numeric = tonumber(value)
  if numeric == nil then return fallback end
  return numeric
end

local function EnsureAnimation(frame, state)
  if state.animation then return state.animation end

  local group = frame:CreateAnimationGroup()
  local animation = group:CreateAnimation("Alpha")
  animation:SetSmoothing("OUT")
  group:SetScript("OnFinished", function()
    if states[frame] ~= state then return end
    frame:SetAlpha(state.targetAlpha or 1)
  end)

  state.group = group
  state.animation = animation
  return animation
end

local function Apply(frame, enteringCombat)
  local state = states[frame]
  if not state then return end

  local spec = enteringCombat and state.fadeIn or state.fadeOut
  local target = Number(spec and spec.alpha, enteringCombat and 1 or 0.2)
  local duration = Number(spec and spec.time, 0)
  local group = state.group

  if duration <= 0 then
    if group then group:Stop() end
    state.targetAlpha = target
    frame:SetAlpha(target)
    return
  end

  local animation = EnsureAnimation(frame, state)
  group = state.group
  group:Stop()
  state.targetAlpha = target
  local currentAlpha = frame:GetAlpha()
  if not CanAccessValue(currentAlpha) or type(currentAlpha) ~= "number" then currentAlpha = 1 end
  animation:SetFromAlpha(currentAlpha)
  animation:SetToAlpha(target)
  animation:SetDuration(duration)
  group:Play()
end

local function RefreshAll(enteringCombat)
  for frame in pairs(states) do
    Apply(frame, enteringCombat)
  end
end

eventFrame:SetScript("OnEvent", function(_, event)
  RefreshAll(event == "PLAYER_REGEN_DISABLED")
end)

function func.AttachCombatFader(frame, fadeIn, fadeOut)
  if not frame then return false end

  local state = states[frame]
  if not state then
    state = {}
    states[frame] = state
  end
  state.fadeIn = fadeIn or {}
  state.fadeOut = fadeOut or {}

  if not eventFrame:IsEventRegistered("PLAYER_REGEN_DISABLED") then
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
  end

  Apply(frame, InCombatLockdown and InCombatLockdown() == true)
  return true
end

function func.DetachCombatFader(frame)
  local state = frame and states[frame]
  if not state then return false end
  if state.group then state.group:Stop() end
  states[frame] = nil

  if next(states) == nil then
    eventFrame:UnregisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
  end
  return true
end
