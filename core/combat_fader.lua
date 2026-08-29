local addonName, ns = ...

local func = assert(ns and ns.func, "Roth_UI: ns.func is required by combat_fader.lua")
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local pairs = pairs
local setmetatable = setmetatable
local tonumber = tonumber

local registered = setmetatable({}, { __mode = "k" })
local eventFrame = CreateFrame("Frame")

local function Number(value, fallback)
  value = tonumber(value)
  if not value then return fallback end
  return value
end

local function EnsureAnimation(frame)
  local animation = frame.__rothCombatFadeAnimation
  if animation then return animation end

  local group = frame:CreateAnimationGroup()
  animation = group:CreateAnimation("Alpha")
  animation:SetSmoothing("OUT")
  group:SetScript("OnFinished", function(owner)
    local targetFrame = owner.__rothOwner
    if targetFrame then targetFrame:SetAlpha(owner.__rothTargetAlpha or 1) end
  end)
  group.__rothOwner = frame
  frame.__rothCombatFadeGroup = group
  frame.__rothCombatFadeAnimation = animation
  return animation
end

local function Apply(frame, enteringCombat)
  local config = registered[frame]
  if not config then return end

  local spec = enteringCombat and config.fadeIn or config.fadeOut
  local target = Number(spec and spec.alpha, enteringCombat and 1 or 0.2)
  local duration = Number(spec and spec.time, 0)
  local group = frame.__rothCombatFadeGroup

  if duration <= 0 then
    if group then group:Stop() end
    frame:SetAlpha(target)
    return
  end

  local animation = EnsureAnimation(frame)
  group = frame.__rothCombatFadeGroup
  group:Stop()
  group.__rothTargetAlpha = target
  animation:SetFromAlpha(frame:GetAlpha())
  animation:SetToAlpha(target)
  animation:SetDuration(duration)
  group:Play()
end

local function RefreshAll(enteringCombat)
  for frame in pairs(registered) do
    Apply(frame, enteringCombat)
  end
end

eventFrame:SetScript("OnEvent", function(_, event)
  RefreshAll(event == "PLAYER_REGEN_DISABLED")
end)

function func.AttachCombatFader(frame, fadeIn, fadeOut)
  if not frame then return false end
  registered[frame] = { fadeIn = fadeIn or {}, fadeOut = fadeOut or {} }
  if not eventFrame:IsEventRegistered("PLAYER_REGEN_DISABLED") then
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
  end
  Apply(frame, InCombatLockdown and InCombatLockdown() == true)
  return true
end

-- Existing class-bar builders call this name. It is now backed by one owner.
_G.rCombatFrameFader = func.AttachCombatFader
