local addon, ns = ...

local safety = assert(ns and ns.safety, "Roth_UI_rActionBarStyler.multibar_visibility: ns.safety is required")
local TryCall = assert(safety.TryCall, "Roth_UI_rActionBarStyler.multibar_visibility: safety.TryCall is required")
local barRuntimeRegistry = assert(ns and ns.BarRuntimeRegistry, "Roth_UI_rActionBarStyler.multibar_visibility: ns.BarRuntimeRegistry is required")
local ResolveBarRuntimeFrame = assert(barRuntimeRegistry.ResolveFrame, "Roth_UI_rActionBarStyler.multibar_visibility: ResolveFrame is required")
local GetBarRuntimeDescriptor = assert(barRuntimeRegistry.GetDescriptor, "Roth_UI_rActionBarStyler.multibar_visibility: GetDescriptor is required")
local NotifyBarRuntimeChanged = assert(barRuntimeRegistry.NotifyChanged, "Roth_UI_rActionBarStyler.multibar_visibility: NotifyChanged is required")
local SetProxyVisibility = barRuntimeRegistry.SetProxyVisibility

local managedFrames = {}
local helper = CreateFrame("Frame")
local initialized = false
local pendingRefresh = false

local function IsProxyShown(proxyKey)
  if type(proxyKey) ~= "string" or proxyKey == "" then
    return true
  end

  local settings = _G.Settings
  if not (settings and type(settings.GetValue) == "function") then
    return true
  end

  local ok, value = TryCall(settings.GetValue, proxyKey)
  if not ok or value == nil then
    return true
  end

  return value == true
end

local function ShouldFrameBeShown(proxyKeys)
  if type(proxyKeys) ~= "table" or #proxyKeys == 0 then
    return true
  end

  for i = 1, #proxyKeys do
    if IsProxyShown(proxyKeys[i]) then
      return true
    end
  end

  return false
end

local function RefreshManagedFrames()
  if InCombatLockdown and InCombatLockdown() then
    pendingRefresh = true
    helper:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end

  pendingRefresh = false
  helper:UnregisterEvent("PLAYER_REGEN_ENABLED")

  for i = 1, #managedFrames do
    local entry = managedFrames[i]
    local frame = entry and entry.frame
    local shouldShow = ShouldFrameBeShown(entry and entry.proxyKeys)
    local applied = false
    if entry and type(entry.key) == "string" and type(SetProxyVisibility) == "function" then
      local ok, result = TryCall(SetProxyVisibility, entry.key, shouldShow)
      applied = ok and result == true
    end
    if not applied and frame and frame.SetShown then
      frame:SetShown(shouldShow)
    end
  end

  NotifyBarRuntimeChanged(nil, "visibility")
end

local function EnsureInitialized()
  if initialized then
    return
  end

  initialized = true
  helper:RegisterEvent("PLAYER_LOGIN")
  helper:RegisterEvent("PLAYER_ENTERING_WORLD")
  helper:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" and not pendingRefresh then
      helper:UnregisterEvent("PLAYER_REGEN_ENABLED")
      return
    end

    RefreshManagedFrames()
  end)

  if type(_G.hooksecurefunc) == "function" and type(_G.MultiActionBar_Update) == "function" then
    hooksecurefunc("MultiActionBar_Update", RefreshManagedFrames)
  end
end

local function ResolveManagedFrame(frameOrKey)
  if frameOrKey and frameOrKey.SetShown then
    return frameOrKey, nil, nil
  end

  if type(frameOrKey) ~= "string" or frameOrKey == "" then
    return nil, nil, nil
  end

  local frame = ResolveBarRuntimeFrame(frameOrKey)
  local descriptor = GetBarRuntimeDescriptor(frameOrKey)
  return frame, descriptor, frameOrKey
end

local function FindManagedFrameEntry(frame)
  if not frame then
    return nil
  end

  for i = 1, #managedFrames do
    local entry = managedFrames[i]
    if entry and entry.frame == frame then
      return entry
    end
  end

  return nil
end

function ns.RegisterManagedMultiBarFrame(frameOrKey, proxyKeys)
  local frame, descriptor, key = ResolveManagedFrame(frameOrKey)
  local activeProxyKeys = proxyKeys
  if type(activeProxyKeys) ~= "table" and type(descriptor) == "table" then
    activeProxyKeys = descriptor.proxyKeys
  end

  if not (frame and frame.SetShown) then
    return
  end

  local existing = FindManagedFrameEntry(frame)
  if existing then
    existing.proxyKeys = activeProxyKeys
    existing.key = key or existing.key
  else
    managedFrames[#managedFrames + 1] = {
      frame = frame,
      proxyKeys = activeProxyKeys,
      key = key,
    }
  end

  EnsureInitialized()
  RefreshManagedFrames()
end
