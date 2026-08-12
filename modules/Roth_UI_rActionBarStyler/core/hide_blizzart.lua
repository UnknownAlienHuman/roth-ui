
  -----------------------------
  -- INIT
  -----------------------------

  --get the addon namespace
  local addon, ns = ...
  local gcfg = ns.cfg
  if not (gcfg and gcfg.bars) then return end
  local mainBar = _G.MainActionBar or _G.MainMenuBar

  -----------------------------
  -- HIDE FRAMES
  -----------------------------
if not gcfg.embeds.rActionBarStyler then return end
  --hide blizzard
  local pastebin = CreateFrame("Frame")
  pastebin:Hide()
  ns.pastebin = pastebin
  --hide main menu bar frames

  --hide override actionbar frames
  if gcfg.bars.overridebar.enable then
    if OverrideActionBarExpBar then OverrideActionBarExpBar:SetAlpha(0) end
    if OverrideActionBarHealthBar then OverrideActionBarHealthBar:SetAlpha(0) end
    if OverrideActionBarPowerBar then OverrideActionBarPowerBar:SetAlpha(0) end
    if OverrideActionBarPitchFrame then OverrideActionBarPitchFrame:SetAlpha(0) end --maybe we can use that frame later for pitchig and such
  end

  if MainStatusTrackingBarContainer then MainStatusTrackingBarContainer:Hide() end
  if SecondaryStatusTrackingBarContainer then SecondaryStatusTrackingBarContainer:Hide() end
  if StatusTrackingBarManager then StatusTrackingBarManager:Hide() end
  -----------------------------
  -- HIDE TEXTURES
  -----------------------------

  --remove some the default background textures
  --StanceBarLeft:SetAlpha(0)
  --StanceBarMiddle:SetAlpha(0)
  --StanceBarRight:SetAlpha(0)
  --SlidingActionBarTexture0:SetAlpha(0)
  --SlidingActionBarTexture1:SetAlpha(0)
  --PossessBackground1:SetAlpha(0)
  --PossessBackground2:SetAlpha(0)

  if gcfg.bars.bar1.enable then
    if mainBar and mainBar.EndCaps then mainBar.EndCaps:SetAlpha(0) end

  end

  --remove OverrideBar textures
  if gcfg.bars.overridebar.enable then
    local textureList =  {
      "_BG",
      "EndCapL",
      "EndCapR",
      "_Border",
      "Divider1",
      "Divider2",
      "Divider3",
      "ExitBG",
      "MicroBGL",
      "MicroBGR",
      "_MicroBGMid",
      "ButtonBGL",
      "ButtonBGR",
      "_ButtonBGMid",
    }

    for _,tex in ipairs(textureList) do
      if OverrideActionBar and OverrideActionBar[tex] then OverrideActionBar[tex]:SetAlpha(0) end
    end
  end
