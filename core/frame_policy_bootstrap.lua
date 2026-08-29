local addonName, ns = ...

local func = assert(ns and ns.func, "Roth_UI: ns.func is required by frame_policy_bootstrap.lua")

local function ApplyPolicies()
  if type(func.ApplyGroupFramePolicy) == "function" then func:ApplyGroupFramePolicy() end
  if type(func.ApplyUnitFramePolicy) == "function" then func:ApplyUnitFramePolicy() end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, loadedAddon)
  if event == "PLAYER_LOGIN" then
    if type(func.ApplyGlobalFonts) == "function" then func:ApplyGlobalFonts() end
    ApplyPolicies()
    return
  end
  if loadedAddon == "Blizzard_UnitFrame" or loadedAddon == "Blizzard_CompactRaidFrames" then
    ApplyPolicies()
  end
end)
