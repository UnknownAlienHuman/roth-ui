-----------------------------
-- Shared bottom dock
-----------------------------

local addon, ns = ...

local dock = ns.ActionBarDock or {}
ns.ActionBarDock = dock

local shell = ns.ActionBarShell or {}
ns.ActionBarShell = shell
local barRuntimeRegistry = assert(ns and ns.BarRuntimeRegistry, "Roth_UI_rActionBarStyler.dock: ns.BarRuntimeRegistry is required")
local ResolveMainRuntimeFrame = assert(barRuntimeRegistry.ResolveMainFrame, "Roth_UI_rActionBarStyler.dock: ResolveMainFrame is required")
local GetBottomClusterLayout = assert(barRuntimeRegistry.GetBottomClusterLayout, "Roth_UI_rActionBarStyler.dock: GetBottomClusterLayout is required")
local GetVisibleAuxRowCount = assert(barRuntimeRegistry.GetVisibleAuxRowCount, "Roth_UI_rActionBarStyler.dock: GetVisibleAuxRowCount is required")
local GetArtworkTier = assert(barRuntimeRegistry.GetArtworkTier, "Roth_UI_rActionBarStyler.dock: GetArtworkTier is required")
local GetOwnershipMatrix = assert(barRuntimeRegistry.GetOwnershipMatrix, "Roth_UI_rActionBarStyler.dock: GetOwnershipMatrix is required")
local NotifyBarRuntimeChanged = assert(barRuntimeRegistry.NotifyChanged, "Roth_UI_rActionBarStyler.dock: NotifyChanged is required")
local RegisterBarRuntimeListener = assert(barRuntimeRegistry.RegisterListener, "Roth_UI_rActionBarStyler.dock: RegisterListener is required")
local ResolveDockRuntimeMember = assert(barRuntimeRegistry.ResolveDockMember, "Roth_UI_rActionBarStyler.dock: ResolveDockMember is required")

local DOCK_GAP = 2

local max = math.max
local floor = math.floor
local min = math.min
local dockFrame

local function ResolveVisualWidth(frame)
  local widthResolver = frame and frame.__dockGetVisualWidth
  if type(widthResolver) == "function" then
    local width = widthResolver(frame)
    if type(width) == "number" and width > 0 then
      return width
    end
  end
  if not (frame and frame.GetWidth) then
    return 0
  end
  local width = frame:GetWidth()
  if type(width) ~= "number" or width <= 0 then
    return 0
  end
  local scale = frame.GetScale and frame:GetScale() or 1
  if type(scale) ~= "number" or scale <= 0 then
    scale = 1
  end
  return width * scale
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

function shell.ResolveMainFrame()
  return ResolveMainRuntimeFrame()
end

function shell.GetBottomClusterLayout()
  return GetBottomClusterLayout()
end

function shell.GetVisibleAuxRowCount()
  return GetVisibleAuxRowCount()
end

function shell.GetArtworkTier()
  return GetArtworkTier()
end

function shell.GetOwnershipMatrix()
  return GetOwnershipMatrix()
end

function shell.NotifyChanged()
  NotifyBarRuntimeChanged(nil, "shell")
end

function shell.RegisterListener(key, callback)
  return RegisterBarRuntimeListener(key, callback)
end

local function ResolveDockAnchor()
  local bars = ns and ns.cfg and ns.cfg.bars
  local microPos = bars and bars.micromenu and bars.micromenu.pos
  local bagsPos = bars and bars.bags and bars.bags.pos
  local stancePos = bars and bars.stancebar and bars.stancebar.pos

  local leftX = type(microPos) == "table" and tonumber(microPos.x) or nil
  local rightX = type(bagsPos) == "table" and tonumber(bagsPos.x) or nil
  local centerX = type(stancePos) == "table" and tonumber(stancePos.x) or nil
  local x = centerX
  if type(x) ~= "number" then
    if leftX and rightX then
      x = (leftX + rightX) / 2
    elseif leftX then
      x = leftX
    elseif rightX then
      x = rightX
    else
      x = 0
    end
  end

  local centerY = type(stancePos) == "table" and tonumber(stancePos.y) or nil
  local y = centerY
  if type(y) ~= "number" then
    y = 97
    if type(microPos) == "table" and type(tonumber(microPos.y)) == "number" then
      y = tonumber(microPos.y)
    end
    if type(bagsPos) == "table" and type(tonumber(bagsPos.y)) == "number" then
      y = math.max(y, tonumber(bagsPos.y))
    end
  end

  return x, y
end

local function ResolveActionShellLayout()
  return GetBottomClusterLayout()
end

local function EnsureDockFrame()
  if dockFrame then
    return dockFrame
  end

  dockFrame = CreateFrame("Frame", "Roth_UIBottomDock", UIParent)
  dockFrame:SetSize(1, 1)
  dockFrame:SetFrameStrata("LOW")
  dockFrame.ignoreFramePositionManager = true
  dockFrame.leftPane = CreateFrame("Frame", nil, dockFrame)
  dockFrame.rightPane = CreateFrame("Frame", nil, dockFrame)
  dockFrame.stancePane = CreateFrame("Frame", nil, dockFrame.rightPane)
  dockFrame.bagsPane = CreateFrame("Frame", nil, dockFrame.rightPane)
  dock.frame = dockFrame
  return dockFrame
end

local function ResolveDockMember(slot)
  return ResolveDockRuntimeMember(slot)
end

function dock.Refresh()
  local frame = EnsureDockFrame()
  local micro = ResolveDockMember("micromenu")
  local stance = ResolveDockMember("stancebar")
  local bags = ResolveDockMember("bags")

  if not (micro or stance or bags) then
    return
  end

  local shellLeft, shellWidth, shellHeight = ResolveActionShellLayout()
  local anchorX, anchorY = ResolveDockAnchor()
  if shellLeft and shellWidth and shellHeight then
    frame:SetSize(shellWidth, shellHeight)
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", shellLeft, anchorY)
  else
    local fallbackWidth = 0
    local fallbackHeight = 32
    for _, member in ipairs({ micro, stance, bags }) do
      local width = ResolveVisualWidth(member)
      local height = ResolveVisualHeight(member)
      if width > 0 and height > 0 then
        fallbackWidth = fallbackWidth + width
        fallbackHeight = max(fallbackHeight, height)
      end
    end
    fallbackWidth = max(fallbackWidth + DOCK_GAP * 2, 1)
    frame:SetSize(fallbackWidth, fallbackHeight)
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOM", UIParent, "BOTTOM", anchorX, anchorY)
  end

  local dockWidth = ResolveVisualWidth(frame)
  local dockHeight = ResolveVisualHeight(frame)
  local leftPaneWidth = floor(dockWidth / 2)
  local rightPaneWidth = max(dockWidth - leftPaneWidth, 0)
  local bagsPaneWidth = 0

  if bags then
    bagsPaneWidth = min(ResolveVisualWidth(bags), rightPaneWidth)
  end
  local stanceGap = (stance and bags and bagsPaneWidth > 0) and DOCK_GAP or 0
  local stancePaneWidth = max(rightPaneWidth - bagsPaneWidth - stanceGap, 0)

  frame.leftPane:ClearAllPoints()
  frame.leftPane:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  frame.leftPane:SetSize(leftPaneWidth, dockHeight)

  frame.rightPane:ClearAllPoints()
  frame.rightPane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  frame.rightPane:SetSize(rightPaneWidth, dockHeight)

  frame.bagsPane:ClearAllPoints()
  frame.bagsPane:SetPoint("BOTTOMRIGHT", frame.rightPane, "BOTTOMRIGHT", 0, 0)
  frame.bagsPane:SetSize(bagsPaneWidth, dockHeight)

  frame.stancePane:ClearAllPoints()
  frame.stancePane:SetPoint("BOTTOMLEFT", frame.rightPane, "BOTTOMLEFT", 0, 0)
  if bagsPaneWidth > 0 then
    frame.stancePane:SetPoint("TOPRIGHT", frame.bagsPane, "TOPLEFT", -stanceGap, 0)
  else
    frame.stancePane:SetPoint("TOPRIGHT", frame.rightPane, "TOPRIGHT", 0, 0)
  end

  if micro and type(micro.__dockApplyLayout) == "function" then
    micro:__dockApplyLayout(leftPaneWidth, dockHeight)
  end

  if micro then
    micro:ClearAllPoints()
    micro:SetPoint("BOTTOMLEFT", frame.leftPane, "BOTTOMLEFT", 0, 0)
  end

  if bags then
    bags:ClearAllPoints()
    bags:SetPoint("BOTTOMRIGHT", frame.bagsPane, "BOTTOMRIGHT", 0, 0)
  end

  if stance then
    stance:ClearAllPoints()
    stance:SetPoint("BOTTOMLEFT", frame.stancePane, "BOTTOMLEFT", 0, 0)
  end
end

RegisterBarRuntimeListener("dock_refresh", function()
  dock.Refresh()
end)

dock.Refresh()
