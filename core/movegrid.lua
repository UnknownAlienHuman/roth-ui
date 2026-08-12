--[[
  Roth UI - Move Grid Overlay

  Shows a lightweight, semi-transparent grid while frames are unlocked.
  Intended for precise alignment without Blizzard Edit Mode.

  API:
    ns.ShowMoveGrid()
    ns.HideMoveGrid()

  Notes:
  - Grid is created lazily.
  - Rebuilt when UIParent size changes.
  - Hidden by default.
--]]

local addon, ns = ...

ns = ns or {}

local gridFrame
local vLines = {}
local hLines = {}

local GRID_STEP = 32
local GRID_MAJOR_STEP = 128
local MINOR_ALPHA = 0.06
local MAJOR_ALPHA = 0.12
local CENTER_ALPHA = 0.20

local function AcquireLine(lines, idx)
  local t = lines[idx]
  if t then
    t:Show()
    return t
  end
  t = gridFrame:CreateTexture(nil, "BACKGROUND")
  t:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  lines[idx] = t
  return t
end

local function HideExtra(lines, from)
  for i = from, #lines do
    if lines[i] then lines[i]:Hide() end
  end
end

local function BuildGrid()
  if not (gridFrame and UIParent) then return end
  gridFrame:ClearAllPoints()
  gridFrame:SetAllPoints(UIParent)

  local w = UIParent:GetWidth() or 0
  local h = UIParent:GetHeight() or 0
  if w <= 0 or h <= 0 then return end

  local cx = w / 2
  local cy = h / 2

  local vCount = 0
  local maxX = math.floor(w / GRID_STEP)
  for i = 0, maxX do
    local x = i * GRID_STEP
    vCount = vCount + 1
    local l = AcquireLine(vLines, vCount)
    l:ClearAllPoints()
    l:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", x, 0)
    l:SetPoint("BOTTOMLEFT", gridFrame, "BOTTOMLEFT", x, 0)
    l:SetWidth(1)

    local alpha = MINOR_ALPHA
    if math.abs(x - cx) < 1 then
      alpha = CENTER_ALPHA
    elseif (x % GRID_MAJOR_STEP) == 0 then
      alpha = MAJOR_ALPHA
    end
    l:SetVertexColor(1, 1, 1, alpha)
  end
  HideExtra(vLines, vCount + 1)

  local hCount = 0
  local maxY = math.floor(h / GRID_STEP)
  for i = 0, maxY do
    local y = i * GRID_STEP
    hCount = hCount + 1
    local l = AcquireLine(hLines, hCount)
    l:ClearAllPoints()
    l:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", 0, -y)
    l:SetPoint("TOPRIGHT", gridFrame, "TOPRIGHT", 0, -y)
    l:SetHeight(1)

    local alpha = MINOR_ALPHA
    if math.abs(y - cy) < 1 then
      alpha = CENTER_ALPHA
    elseif (y % GRID_MAJOR_STEP) == 0 then
      alpha = MAJOR_ALPHA
    end
    l:SetVertexColor(1, 1, 1, alpha)
  end
  HideExtra(hLines, hCount + 1)
end

local function EnsureGrid()
  if gridFrame then return end

  gridFrame = CreateFrame("Frame", "Roth_UIMoveGrid", UIParent)
  gridFrame:SetFrameStrata("DIALOG")
  gridFrame:SetAllPoints(UIParent)
  gridFrame:Hide()

  local ev = CreateFrame("Frame")
  ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
  ev:RegisterEvent("UI_SCALE_CHANGED")
  ev:SetScript("OnEvent", function()
    if gridFrame and gridFrame:IsShown() then
      BuildGrid()
    end
  end)

  BuildGrid()
end

function ns.ShowMoveGrid()
  if InCombatLockdown and InCombatLockdown() then return end
  EnsureGrid()
  BuildGrid()
  if gridFrame then gridFrame:Show() end
end

function ns.HideMoveGrid()
  if gridFrame then gridFrame:Hide() end
end
