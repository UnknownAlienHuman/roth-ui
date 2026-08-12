-- rLib: core
-- zork, 2016

-----------------------------
-- Variables
-----------------------------

local A, L = ...
L.addonName = A

-----------------------------
-- rLib Global
-----------------------------

-- Keep a single shared global table used by legacy modules.
local existing = _G.rLib
rLib = existing or {}
_G.rLib = rLib
rLib.addonName = rLib.addonName or A

-----------------------------
-- Functions
-----------------------------

--L:GetPoint
function L:GetPoint(frame)
  if not frame then return end
  local point = {}
  point.a1, point.af, point.a2, point.x, point.y = frame:GetPoint()
  if point.af and point.af:GetName() then
    point.af = point.af:GetName()
  end
  return point
end

--L:GetSize
function L:GetSize(frame)
  if not frame then return end
  local size = {}
  size.w, size.h = frame:GetWidth(), frame:GetHeight()
  return size
end

--L:ResetPoint
function L:ResetPoint(frame)
  if not frame then return end
  if not frame.defaultPoint then return end
  if InCombatLockdown() then return end
  local point = frame.defaultPoint
  frame:ClearAllPoints()
  if point.af and point.a2 then
    frame:SetPoint(point.a1 or "CENTER", point.af, point.a2, point.x or 0, point.y or 0)
  elseif point.af then
    frame:SetPoint(point.a1 or "CENTER", point.af, point.x or 0, point.y or 0)
  else
    frame:SetPoint(point.a1 or "CENTER", point.x or 0, point.y or 0)
  end
end

--L:ResetSize
function L:ResetSize(frame)
  if not frame then return end
  if not frame.defaultSize then return end
  if InCombatLockdown() then return end
  frame:SetSize(frame.defaultSize.w, frame.defaultSize.h)
end

--L:UnlockFrame
function L:UnlockFrame(frame)
  if not frame then return end
  if not frame.dragFrame then return end
  frame.dragFrame:Show()
end

--L:LockFrame
function L:LockFrame(frame)
  if not frame then return end
  if not frame.dragFrame then return end
  frame.dragFrame:Hide()
end

--L:UnlockFrames
function L:UnlockFrames(frames, str)
  if not frames then return end
  for idx, frame in next, frames do
    self:UnlockFrame(frame)
  end
  if rLib and rLib.ShowGrid then rLib:ShowGrid() end
  print(str)
end

--L:LockFrames
function L:LockFrames(frames, str)
  if not frames then return end
  for idx, frame in next, frames do
    self:LockFrame(frame)
  end
  if rLib and rLib.HideGrid then rLib:HideGrid() end
  if rLib and rLib.HideGuides then rLib:HideGuides() end
  print(str)
end

--L:ResetFrames
function L:ResetFrames(frames, str)
  if not frames then return end
  if InCombatLockdown() then
    print("|c00FF0000ERROR:|r " .. str .. " not allowed while in combat!")
    return
  end
  local callbacks = rLib and rLib.moverCallbacks
  local resetMoverLayout = callbacks and callbacks.ResetLayout
  for idx, frame in next, frames do
    if type(resetMoverLayout) == "function" then
      resetMoverLayout(frame)
    else
      self:ResetPoint(frame)
      self:ResetSize(frame)
    end
  end
  print(str)
end
