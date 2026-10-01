-- Bounded bootstrap for reversible Blizzard-frame policies.
--
-- Login work is one-shot. Late Blizzard frame addons are watched through
-- EventUtil when available; the fallback ADDON_LOADED listener tracks only the
-- named addons and unregisters after both have resolved.

local addonName, ns = ...

local func = assert(ns and ns.func, "Roth_UI: ns.func is required by frame_policy_bootstrap.lua")
local CreateFrame = CreateFrame
local next = next
local type = type

local function ApplyPolicies()
  if type(func.ApplyGroupFramePolicy) == "function" then func:ApplyGroupFramePolicy() end
  if type(func.ApplyUnitFramePolicy) == "function" then func:ApplyUnitFramePolicy() end
end

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  self:SetScript("OnEvent", nil)
  if type(func.ApplyGlobalFonts) == "function" then func:ApplyGlobalFonts() end
  ApplyPolicies()
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
    ApplyPolicies()
    if next(watchedAddons) == nil then
      self:UnregisterEvent("ADDON_LOADED")
      self:SetScript("OnEvent", nil)
    end
  end)
  return fallbackFrame
end

local function WatchBlizzardAddon(addonNameToWatch)
  if EventUtil and type(EventUtil.ContinueOnAddOnLoaded) == "function" then
    EventUtil.ContinueOnAddOnLoaded(addonNameToWatch, ApplyPolicies)
    watchedAddons[addonNameToWatch] = nil
    return
  end

  if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function"
      and C_AddOns.IsAddOnLoaded(addonNameToWatch) == true then
    watchedAddons[addonNameToWatch] = nil
    ApplyPolicies()
    return
  end

  EnsureFallbackFrame()
end

WatchBlizzardAddon("Blizzard_UnitFrame")
WatchBlizzardAddon("Blizzard_CompactRaidFrames")
