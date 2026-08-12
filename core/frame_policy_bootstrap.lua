local addonName, ns = ...

local func = assert(ns and ns.func, "Roth_UI: ns.func is required by frame_policy_bootstrap.lua")

local function ApplyUnitAndGroupPolicies()
  if type(func.ApplyGroupFramePolicy) == "function" then
    func:ApplyGroupFramePolicy()
  end
  if type(func.ApplyUnitFramePolicy) == "function" then
    func:ApplyUnitFramePolicy()
  end
end

do
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("PLAYER_LOGIN")
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  frame:RegisterEvent("ADDON_LOADED")
  frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
      if type(func.ApplyGlobalFonts) == "function" then
        func:ApplyGlobalFonts()
      end
      ApplyUnitAndGroupPolicies()
      return
    end

    if event == "ADDON_LOADED" then
      if (arg1 == "Blizzard_UnitFrame" or arg1 == "Blizzard_UIPanels_Game") and type(func.ApplyUnitFramePolicy) == "function" then
        func:ApplyUnitFramePolicy()
      end
      if arg1 == "Blizzard_CompactRaidFrames" and type(func.ApplyGroupFramePolicy) == "function" then
        func:ApplyGroupFramePolicy()
      end
      return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
      ApplyUnitAndGroupPolicies()
    end
  end)
end
