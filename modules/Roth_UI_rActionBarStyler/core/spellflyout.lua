-- Spell flyout fader
local addon, ns = ...
local gcfg = ns.cfg
if not (gcfg and gcfg.embeds and gcfg.embeds.rActionBarStyler) then
  return
end

local flyout = _G.SpellFlyout
if not (flyout and flyout.HookScript) then
  return
end

local buttonList = {}

-- In 12.x flyout buttons are named SpellFlyoutPopupButtonN and are pooled lazily.
local function BuildFlyoutButtonList()
  wipe(buttonList)
  local index = 1
  while true do
    local button = _G["SpellFlyoutPopupButton" .. index]
    if not button then
      break
    end
    buttonList[#buttonList + 1] = button
    index = index + 1
  end
end

local function ResolveOwnerFrame(flyoutFrame)
  local parent = flyoutFrame and flyoutFrame.GetParent and flyoutFrame:GetParent()
  for _ = 1, 8 do
    if not parent then
      return nil
    end
    if parent.mouseover then
      return parent
    end
    parent = parent.GetParent and parent:GetParent() or nil
  end
  return nil
end

local function AddFlyoutFramesToFader(self)
  if type(_G.rSpellFlyoutFader) ~= "function" then
    return
  end

  local frame = ResolveOwnerFrame(self)
  if not (frame and frame.mouseover and frame.mouseover.enable) then
    return
  end
  if frame.__rABS_SpellFlyoutFaderAttached then
    return
  end

  BuildFlyoutButtonList()
  if #buttonList == 0 then
    return
  end

  frame.__rABS_SpellFlyoutFaderAttached = true
  _G.rSpellFlyoutFader(frame, buttonList, frame.mouseover.fadeIn, frame.mouseover.fadeOut)
end

if not flyout.__rABS_SpellFlyoutHooked then
  flyout.__rABS_SpellFlyoutHooked = true
  flyout:HookScript("OnShow", AddFlyoutFramesToFader)
end
