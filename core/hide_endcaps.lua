-- Hide Blizzard MainMenuBar endcaps/gryphons.
--
-- Retail 11.x+ introduced multiple bar implementations (MainMenuBar, MainActionBar,
-- overrides) and the endcaps are created/updated late. This file hides them
-- unconditionally so Diablo orbs/art are never covered.

local addonName, ns = ...

local defer = ns and ns.defer

local function HideMainBarEndcaps()
  local function hide(f)
    if not f then return end
    if f.Hide then f:Hide() end
    if f.SetAlpha then f:SetAlpha(0) end
    if f.SetShown then f:SetShown(false) end
  end

  local function tryHide(container)
    if not container then return end
    hide(container.LeftEndCap)
    hide(container.RightEndCap)
    if container.EndCaps then
      hide(container.EndCaps.LeftEndCap)
      hide(container.EndCaps.RightEndCap)
    end
  end

  tryHide(_G.MainMenuBarArtFrame)
  tryHide(_G.MainMenuBarArtFrameBackground)
  tryHide(_G.MainMenuBar)
  tryHide(_G.MainActionBar)
  tryHide(_G.ActionBarFrame)

  hide(_G.GryphonLeft)
  hide(_G.GryphonRight)
end

local function StartHideSweep()
  local delays = { 0.2, 1.0, 2.0, 5.0 }
  if defer and type(defer.RunSeries) == "function" then
    defer.RunSeries("hide_endcaps:sweep", HideMainBarEndcaps, delays, false)
  else
    HideMainBarEndcaps()
  end
end

local function Kick()
  HideMainBarEndcaps()
  StartHideSweep()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
f:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
f:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
f:SetScript("OnEvent", Kick)

-- Defensive: Blizzard updates endcaps on state changes.
-- Retail 12.x uses MainActionBarMixin:UpdateEndCaps; keep the legacy fallback too.
if _G.MainActionBarMixin and type(_G.MainActionBarMixin.UpdateEndCaps) == "function" then
  hooksecurefunc(_G.MainActionBarMixin, "UpdateEndCaps", Kick)
elseif type(_G.MainMenuBarArtFrame_UpdateEndCaps) == "function" then
  hooksecurefunc("MainMenuBarArtFrame_UpdateEndCaps", Kick)
end
