local addonName, ns = ...

local registry = ns.BarRuntimeRegistry or {}
ns.BarRuntimeRegistry = registry

registry.frames = registry.frames or {}
registry.descriptors = registry.descriptors or {}
registry.listeners = registry.listeners or {}
registry.mouseoverRefreshers = registry.mouseoverRefreshers or {}

local type = type
local pairs = pairs
local RegisterStateDriver = RegisterStateDriver
local min = math.min
local max = math.max

local DEFAULT_DESCRIPTORS = {
  bar1 = {
    frameName = "rAbs_MainMenuBar",
    role = "main",
    visibilityDriver = "[petbattle][overridebar][vehicleui][possessbar,@vehicle,exists] hide; show",
  },
  bar2 = {
    frameName = "rABS_MultiBarBottomLeft",
    role = "aux",
    visibilityDriver = "[petbattle][overridebar][vehicleui][possessbar,@vehicle,exists] hide; show",
  },
  bar3 = {
    frameName = "rABS_MultiBarBottomRight",
    role = "aux",
    visibilityDriver = "[petbattle][overridebar][vehicleui][possessbar,@vehicle,exists] hide; show",
  },
  bar4 = {
    frameName = "rABS_MultiBarRight",
    visibilityDriver = "[petbattle][overridebar][vehicleui][possessbar,@vehicle,exists] hide; show",
  },
  bar5 = {
    frameName = "rABS_MultiBarLeft",
    visibilityDriver = "[petbattle][overridebar][vehicleui][possessbar,@vehicle,exists] hide; show",
  },
  extrabar = { frameName = "rABS_ExtraBar" },
  bags = {
    frameName = "rABS_BagFrame",
    dockSlot = "bags",
    visibilityDriver = "[petbattle] hide; show",
  },
  petbar = {
    frameName = "rABS_PetBar",
    visibilityDriver = "[petbattle][overridebar][vehicleui][possessbar,@vehicle,exists] hide; [@pet,exists,nomounted] show; hide",
  },
  stancebar = {
    frameName = "rABS_StanceBar",
    dockSlot = "stancebar",
    visibilityDriver = "[petbattle] hide; show",
  },
  micromenu = {
    frameName = "rABS_MicroMenu",
    dockSlot = "micromenu",
    visibilityDriver = "[petbattle] hide; show",
  },
  overridebar = { frameName = "OverrideActionBar" },
  leave_vehicle = {
    frameName = "rABS_LeaveVehicle",
    visibilityDriver = "[petbattle] hide; show",
  },
  leave_vehicle_button = {
    frameName = "rABS_LeaveVehicleButton",
    visibilityDriver = "[petbattle] hide; [overridebar][vehicleui][possessbar][@vehicle,exists][canexitvehicle] show; hide",
  },
}

local DEFAULT_OWNERSHIP = {
  shell = "core_action_bar_wrappers",
  layout = "core_action_bar_wrappers",
  visibility = "bar_runtime_registry",
  artwork = "core_action_bar_background",
  dock = "core_action_bar_dock",
  specials = "owner_follow_runtime",
}

registry.ownership = registry.ownership or {}
for field, value in pairs(DEFAULT_OWNERSHIP) do
  if registry.ownership[field] == nil then
    registry.ownership[field] = value
  end
end
ns.actionBarOwnership = registry.ownership

local function NormalizeMethodArgs(selfOrFirst, first, second, third)
  if type(selfOrFirst) == "table" then
    return first, second, third
  end
  return selfOrFirst, first, second
end

local function ResolveVisualHeight(frame)
  local heightResolver = frame and frame.__dockGetVisualHeight
  if type(heightResolver) == "function" then
    local height = heightResolver(frame)
    if type(height) == "number" and height > 0 then
      return height
    end
  end
  if not (frame and frame.GetHeight) then
    return 0
  end
  local height = frame:GetHeight()
  if type(height) ~= "number" or height <= 0 then
    return 0
  end
  local scale = frame.GetScale and frame:GetScale() or 1
  if type(scale) ~= "number" or scale <= 0 then
    scale = 1
  end
  return height * scale
end

local function ResolveFrameBounds(frame)
  if not (frame and frame.IsShown and frame:IsShown() and frame.GetLeft and frame.GetRight) then
    return nil
  end

  local left = frame:GetLeft()
  local right = frame:GetRight()
  if type(left) ~= "number" or type(right) ~= "number" or right <= left then
    return nil
  end

  return left, right
end

local function ResolveVisibilityFrame(descriptor, frame)
  local visibilityFrame = type(descriptor) == "table" and descriptor.visibilityFrame or nil
  if visibilityFrame then
    return visibilityFrame
  end

  return frame
end

local function EnsureDescriptor(key)
  if type(key) ~= "string" or key == "" then
    return nil
  end

  local descriptor = registry.descriptors[key]
  if type(descriptor) ~= "table" then
    descriptor = {}
    registry.descriptors[key] = descriptor
  end

  if descriptor.frameName == nil and type(descriptor.legacyFrameName) == "string" and descriptor.legacyFrameName ~= "" then
    descriptor.frameName = descriptor.legacyFrameName
  end
  descriptor.legacyFrameName = nil

  local defaults = DEFAULT_DESCRIPTORS[key]
  if type(defaults) == "table" then
    for field, value in pairs(defaults) do
      if descriptor[field] == nil then
        descriptor[field] = value
      end
    end
  end

  return descriptor
end

local function MergeDescriptor(descriptor, update)
  if type(descriptor) ~= "table" or type(update) ~= "table" then
    return descriptor
  end

  for field, value in pairs(update) do
    if value ~= nil then
      descriptor[field] = value
    end
  end

  return descriptor
end

function registry.RegisterFrame(selfOrKey, keyOrFrame, frameOrOpts, maybeOpts)
  local key, frame, opts = NormalizeMethodArgs(selfOrKey, keyOrFrame, frameOrOpts, maybeOpts)
  if type(key) ~= "string" or key == "" or not frame then
    return false
  end

  local descriptor = EnsureDescriptor(key)
  MergeDescriptor(descriptor, opts)
  registry.frames[key] = frame
  if descriptor and type(frame.GetName) == "function" then
    descriptor.runtimeFrameName = frame:GetName()
  end
  if type(registry.NotifyChanged) == "function" then
    registry.NotifyChanged(key, "register")
  end
  return true
end

function registry.GetFrame(selfOrKey, maybeKey)
  local key = NormalizeMethodArgs(selfOrKey, maybeKey)
  if type(key) ~= "string" or key == "" then
    return nil
  end
  return registry.frames[key]
end

function registry.GetDescriptor(selfOrKey, maybeKey)
  local key = NormalizeMethodArgs(selfOrKey, maybeKey)
  return EnsureDescriptor(key)
end

function registry.GetOwnershipMatrix(selfOrNil)
  return registry.ownership
end

function registry.ResolveFrame(selfOrKey, maybeKey)
  local key = NormalizeMethodArgs(selfOrKey, maybeKey)
  if type(key) ~= "string" or key == "" then
    return nil
  end

  local frame = registry.frames[key]
  if frame then
    return frame
  end

  local descriptor = EnsureDescriptor(key)
  if type(descriptor) ~= "table" then
    return nil
  end

  local runtimeFrameName = descriptor.runtimeFrameName
  if type(runtimeFrameName) == "string" and runtimeFrameName ~= "" then
    frame = _G[runtimeFrameName]
    if frame then
      return frame
    end
  end

  local frameName = descriptor.frameName
  if type(frameName) == "string" and frameName ~= "" then
    return _G[frameName]
  end

  return nil
end

function registry.ForEachShellFrame(selfOrCallback, maybeCallback)
  local callback = type(selfOrCallback) == "table" and maybeCallback or selfOrCallback
  if type(callback) ~= "function" then
    return
  end

  registry.ForEachDescriptor(function(key, descriptor, frame)
    local role = type(descriptor) == "table" and descriptor.role or nil
    if role ~= "main" and role ~= "aux" then
      return
    end
    callback(key, descriptor, frame or registry.ResolveFrame(key))
  end)
end

function registry.ResolveMainFrame(selfOrNil)
  local frame = registry.ResolveFrame("bar1")
  if frame then
    return frame
  end
  return _G.MainActionBar or _G.MainMenuBar
end

function registry.GetBottomClusterLayout(selfOrNil)
  local anchor = registry.ResolveMainFrame()
  local left, right = ResolveFrameBounds(anchor)
  local rowHeight = ResolveVisualHeight(anchor)
  if not left or rowHeight <= 0 then
    return nil
  end

  registry.ForEachShellFrame(function(_, descriptor, frame)
    if descriptor and descriptor.role == "aux" then
      local visibilityFrame = ResolveVisibilityFrame(descriptor, frame)
      local frameLeft, frameRight = ResolveFrameBounds(visibilityFrame)
      if frameLeft and frameRight then
        left = min(left, frameLeft)
        right = max(right, frameRight)
      end
    end
  end)

  local width = right - left
  if type(width) ~= "number" or width <= 0 then
    return nil
  end

  return left, width, rowHeight
end

function registry.GetVisibleAuxRowCount(selfOrNil)
  local count = 0
  registry.ForEachShellFrame(function(_, descriptor, frame)
    local visibilityFrame = ResolveVisibilityFrame(descriptor, frame)
    if descriptor and descriptor.role == "aux" and visibilityFrame and visibilityFrame.IsShown and visibilityFrame:IsShown() then
      count = count + 1
    end
  end)
  return count
end

function registry.GetArtworkTier(selfOrNil)
  local extraRows = registry.GetVisibleAuxRowCount()
  if extraRows >= 2 then
    return 3
  end
  if extraRows == 1 then
    return 2
  end
  return 1
end

function registry.ResolveDockMember(selfOrSlot, maybeSlot)
  local slot = NormalizeMethodArgs(selfOrSlot, maybeSlot)
  if type(slot) ~= "string" or slot == "" then
    return nil
  end

  local resolvedFrame
  registry.ForEachDescriptor(function(key, descriptor, frame)
    if resolvedFrame or not descriptor or descriptor.dockSlot ~= slot then
      return
    end

    frame = frame or registry.ResolveFrame(key)
    if frame then
      resolvedFrame = frame
    end
  end)

  return resolvedFrame
end

function registry.ForEachDescriptor(selfOrCallback, maybeCallback)
  local callback = type(selfOrCallback) == "table" and maybeCallback or selfOrCallback
  if type(callback) ~= "function" then
    return
  end

  for key, descriptor in pairs(registry.descriptors) do
    callback(key, descriptor, registry.frames[key])
  end
end

function registry.RegisterListener(selfOrKey, keyOrCallback, maybeCallback)
  local key, callback = NormalizeMethodArgs(selfOrKey, keyOrCallback, maybeCallback)
  if type(key) ~= "string" or key == "" or type(callback) ~= "function" then
    return false
  end

  registry.listeners[key] = callback
  return true
end

function registry.NotifyChanged(selfOrKey, maybeKey, maybeReason)
  local key, reason = NormalizeMethodArgs(selfOrKey, maybeKey, maybeReason)
  local descriptor = type(key) == "string" and EnsureDescriptor(key) or nil
  local frame = type(key) == "string" and registry.ResolveFrame(key) or nil

  for _, callback in pairs(registry.listeners) do
    if type(callback) == "function" then
      callback(key, descriptor, frame, reason)
    end
  end
end

function registry.RegisterMouseoverRefresher(selfOrKey, keyOrCallback, maybeCallback)
  local key, callback = NormalizeMethodArgs(selfOrKey, keyOrCallback, maybeCallback)
  if type(key) ~= "string" or key == "" or type(callback) ~= "function" then
    return false
  end

  registry.mouseoverRefreshers[key] = callback
  return true
end

function registry.RefreshMouseover(selfOrKey, maybeKey)
  local key = NormalizeMethodArgs(selfOrKey, maybeKey)
  if type(key) ~= "string" or key == "" then
    return false
  end

  local refresher = registry.mouseoverRefreshers[key]
  if type(refresher) ~= "function" then
    return false
  end

  refresher()
  return true
end

function registry.GetVisibilityDriver(selfOrKey, maybeKey)
  local key = NormalizeMethodArgs(selfOrKey, maybeKey)
  local descriptor = EnsureDescriptor(key)
  return type(descriptor) == "table" and descriptor.visibilityDriver or nil
end

local function GetEffectiveVisibilityDriver(descriptor)
  if type(descriptor) ~= "table" then
    return nil
  end

  if descriptor.proxyVisible == false then
    return "hide"
  end

  local driver = descriptor.visibilityDriver
  if type(driver) == "string" and driver ~= "" then
    return driver
  end

  return nil
end

function registry.ApplyVisibilityDriver(selfOrKey, keyOrTarget, maybeTarget)
  local key, target = NormalizeMethodArgs(selfOrKey, keyOrTarget, maybeTarget)
  local descriptor = EnsureDescriptor(key)
  local driver = GetEffectiveVisibilityDriver(descriptor)
  if type(driver) ~= "string" or driver == "" then
    return false
  end

  local frame = target
  if not frame and type(key) == "string" then
    frame = registry.ResolveFrame(key)
  end

  if not frame or type(RegisterStateDriver) ~= "function" then
    return false
  end

  if descriptor then
    descriptor.visibilityFrame = frame
  end

  RegisterStateDriver(frame, "visibility", driver)
  return true
end

function registry.SetProxyVisibility(selfOrKey, keyOrVisible, maybeVisible)
  local key, visible = NormalizeMethodArgs(selfOrKey, keyOrVisible, maybeVisible)
  if type(key) ~= "string" or key == "" then
    return false
  end

  local descriptor = EnsureDescriptor(key)
  if type(descriptor) ~= "table" then
    return false
  end

  descriptor.proxyVisible = visible ~= false

  local frame = descriptor.visibilityFrame
  if not frame then
    frame = registry.ResolveFrame(key)
  end

  local hasVisibilityDriver = type(descriptor.visibilityDriver) == "string" and descriptor.visibilityDriver ~= ""
  if hasVisibilityDriver and frame and type(RegisterStateDriver) == "function" then
    return registry.ApplyVisibilityDriver(key, frame)
  end

  if frame and type(frame.SetShown) == "function" then
    frame:SetShown(descriptor.proxyVisible == true)
    return true
  end

  return false
end

for key in pairs(DEFAULT_DESCRIPTORS) do
  EnsureDescriptor(key)
end
