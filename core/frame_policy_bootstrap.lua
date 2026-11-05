-- Bounded bootstrap for reversible Blizzard-frame policies.
--
-- Login work is one-shot. Late Blizzard frame addons are watched through
-- EventUtil when available; the fallback ADDON_LOADED listener tracks only the
-- named addons and unregisters after both have completed loading.

local _, ns = ...

local func = assert(ns and ns.func, "Roth_UI: ns.func is required by frame_policy_bootstrap.lua")
local TryCall = assert(ns.safety and ns.safety.TryCall,
  "Roth_UI: safety.TryCall is required by frame_policy_bootstrap.lua")
local RunNextFrame = assert(ns.defer and ns.defer.RunNextFrame,
  "Roth_UI: defer.RunNextFrame is required by frame_policy_bootstrap.lua")
local ApplyGroupFramePolicy = assert(func.ApplyGroupFramePolicy,
  "Roth_UI: func.ApplyGroupFramePolicy is required by frame_policy_bootstrap.lua")
local ApplyGlobalFonts = assert(func.ApplyGlobalFonts,
  "Roth_UI: func.ApplyGlobalFonts is required by frame_policy_bootstrap.lua")
local CreateFrame = CreateFrame
local next = next
local type = type

local APPLY_KEY = "frame-policy-bootstrap:apply"

local function ApplyPolicies()
  ApplyGroupFramePolicy(func)
end

local function QueueApplyPolicies()
  return RunNextFrame(APPLY_KEY, ApplyPolicies)
end

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  self:SetScript("OnEvent", nil)

  -- Font and frame policy are independent owners. A font failure must not
  -- prevent the bounded frame-policy invalidation from being scheduled.
  TryCall(ApplyGlobalFonts)
  QueueApplyPolicies()
end)

local watchedAddons = {
  Blizzard_UnitFrame = true,
  Blizzard_CompactRaidFrames = true,
}
local fallbackFrame

local function EnsureFallbackFrame()
  if fallbackFrame then return fallbackFrame end
  fallbackFrame = CreateFrame("Frame")
  fallbackFrame:RegisterEvent("ADDON_LOADED")
  fallbackFrame:SetScript("OnEvent", function(self, _, loadedAddon)
    if not watchedAddons[loadedAddon] then return end
    watchedAddons[loadedAddon] = nil

    -- Detach the one-shot owner before feature work. The shared next-frame
    -- scheduler may execute synchronously in a reduced test environment.
    if next(watchedAddons) == nil then
      self:UnregisterEvent("ADDON_LOADED")
      self:SetScript("OnEvent", nil)
    end
    QueueApplyPolicies()
  end)
  return fallbackFrame
end

local function FinishWatchedAddon(addonNameToWatch)
  if not watchedAddons[addonNameToWatch] then return end
  watchedAddons[addonNameToWatch] = nil
  QueueApplyPolicies()
end

local function WatchBlizzardAddon(addonNameToWatch)
  if EventUtil and type(EventUtil.ContinueOnAddOnLoaded) == "function" then
    EventUtil.ContinueOnAddOnLoaded(addonNameToWatch, function()
      FinishWatchedAddon(addonNameToWatch)
    end)
    return
  end

  if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
    local _, isLoaded = C_AddOns.IsAddOnLoaded(addonNameToWatch)
    if isLoaded == true then
      FinishWatchedAddon(addonNameToWatch)
      return
    end
  end

  EnsureFallbackFrame()
end

WatchBlizzardAddon("Blizzard_UnitFrame")
WatchBlizzardAddon("Blizzard_CompactRaidFrames")
