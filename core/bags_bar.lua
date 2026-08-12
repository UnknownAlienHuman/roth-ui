-----------------------------
-- Bags Bar
-----------------------------

local addon, ns = ...
local gcfg = ns.cfg
if not (gcfg and gcfg.bars and gcfg.bars.bags) then return end

local cfg = gcfg.bars.bags
local barRegistry = assert(ns and ns.BarRuntimeRegistry, "Roth_UI.bags_bar: ns.BarRuntimeRegistry is required")

if not gcfg.embeds.rActionBarStyler then return end
if not cfg.enable then return end
if ns and ns.disableProtectedActionBarOwnership then
  if _G.BagsBar then
    barRegistry:RegisterFrame("bags", _G.BagsBar, { dockSlot = "bags" })
  end
  return
end

local initialized = false
local DEFAULT_POS = { x = 180, y = 97 }

local function ResolveBagPosition(pos)
  pos = type(pos) == "table" and pos or DEFAULT_POS
  return {
    x = tonumber(pos.x) or DEFAULT_POS.x,
    y = tonumber(pos.y) or DEFAULT_POS.y,
  }
end

local function TryInitializeBagBar()
  if initialized then return true end
  if not _G.BagsBar or not _G.MainMenuBarBackpackButton then return false end
  initialized = true

  local desiredScale = cfg.scale or 0.6
  local sync = CreateFrame("Frame")
  local frame = CreateFrame("Frame", "rABS_BagFrame", UIParent, "SecureHandlerStateTemplate")
  barRegistry:RegisterFrame("bags", frame, { dockSlot = "bags" })
  frame:SetSize(40, 40)

  local pos = ResolveBagPosition(cfg.pos)
  frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOM", pos.x, pos.y)
  frame:SetScale(desiredScale)

  _G.BagsBar:SetParent(frame)
  _G.BagsBar:ClearAllPoints()
  _G.BagsBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  _G.BagsBar:SetScale(1)
  frame.__dockGetVisualWidth = function(self)
    local width = (_G.BagsBar and _G.BagsBar.GetWidth and _G.BagsBar:GetWidth()) or self:GetWidth() or 0
    local scale = self.GetScale and self:GetScale() or 1
    if type(scale) ~= "number" or scale <= 0 then
      scale = 1
    end
    return width * scale
  end

  local pendingLayout = false

  local function SyncSize()
    frame:SetSize(_G.BagsBar:GetWidth(), _G.BagsBar:GetHeight())
    barRegistry.NotifyChanged("bags", "layout")
  end

  local function ApplyBagLayout(target)
    target = target or _G.BagsBar
    if not target then
      return
    end
    SyncSize()
    target:ClearAllPoints()
    target:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    pendingLayout = false
    sync:UnregisterEvent("PLAYER_REGEN_ENABLED")
  end

  local function RequestBagLayout(target)
    if InCombatLockdown and InCombatLockdown() then
      pendingLayout = true
      sync:RegisterEvent("PLAYER_REGEN_ENABLED")
      return
    end
    ApplyBagLayout(target)
  end

  if type(_G.BagsBar.Layout) == "function" then
    hooksecurefunc(_G.BagsBar, "Layout", function(self)
      RequestBagLayout(self)
    end)
    _G.BagsBar:Layout()
  else
    RequestBagLayout(_G.BagsBar)
  end

  sync:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" and not pendingLayout then
      self:UnregisterEvent("PLAYER_REGEN_ENABLED")
      return
    end
    RequestBagLayout(_G.BagsBar)
  end)

  if not cfg.show then
    frame:SetParent(ns.pastebin)
    _G.BagsBar:SetParent(ns.pastebin)
    return true
  end

  barRegistry:ApplyVisibilityDriver("bags", frame)

  if cfg.userplaced and cfg.userplaced.enable and ns.func and ns.func.applyDragFunctionality then
    ns.func.applyDragFunctionality(frame)
    if frame.dragframe then
      frame.dragframe:SetFrameStrata("DIALOG")
      frame.dragframe:SetFrameLevel(30)
    end
  end

  barRegistry.NotifyChanged("bags", "layout")
  return true
end

if not TryInitializeBagBar() then
  local bootstrap = CreateFrame("Frame")
  bootstrap:RegisterEvent("PLAYER_LOGIN")
  bootstrap:RegisterEvent("ADDON_LOADED")
  bootstrap:SetScript("OnEvent", function(self)
    if TryInitializeBagBar() then
      self:UnregisterAllEvents()
    end
  end)
end
