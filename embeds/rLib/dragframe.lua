-- rLib: dragframe
-- zork, 2016; snap/grid integration 2025

-----------------------------
-- Variables
-----------------------------

local A, L = ...
local MOVER_SCALE_MIN = 0.5
local MOVER_SCALE_MAX = 2.5
local MOVER_SCALE_STEP = 0.02
local MOVER_SCALE_FINE_STEP = 0.01
local NUDGE_STEP = 1
local NUDGE_STEP_LARGE = 10

local function TryTooltipCallback(fn, ...)
  local root = _G.Roth_UI
  local safety = root and root.safety
  local tryCall = safety and safety.TryCall
  if type(tryCall) ~= "function" then
    return false, nil
  end
  return tryCall(fn, ...)
end

local function Clamp(v, minV, maxV)
  if v < minV then return minV end
  if v > maxV then return maxV end
  return v
end

local function InsertUnique(list, entry)
  if type(list) ~= "table" or entry == nil then
    return false
  end

  for i = 1, #list do
    if list[i] == entry then
      return false
    end
  end

  list[#list + 1] = entry
  return true
end

-----------------------------
-- Cursor helper
-----------------------------

local function GetCursorUI()
  local x, y = GetCursorPosition()
  local s = UIParent:GetEffectiveScale()
  if type(s) ~= "number" or s <= 0 then s = 1 end
  return (x or 0) / s, (y or 0) / s
end

local function GetMoverCallbacks()
  local callbacks = _G.rLib and _G.rLib.moverCallbacks
  if type(callbacks) ~= "table" then
    return nil
  end
  return callbacks
end

local function SaveAddonMoverLayout(frame, opts)
  local callbacks = GetMoverCallbacks()
  local fn = callbacks and callbacks.SaveLayout
  if type(fn) == "function" then
    fn(frame, opts)
  end
end

local function ClearAddonMoverLayout(frame, opts)
  local callbacks = GetMoverCallbacks()
  local fn = callbacks and callbacks.ClearLayout
  if type(fn) == "function" then
    fn(frame, opts)
  end
end

local function ApplyAddonMoverLayout(frame, opts)
  local callbacks = GetMoverCallbacks()
  local fn = callbacks and callbacks.ApplySavedLayout
  if type(fn) == "function" then
    fn(frame, opts)
  end
end

-----------------------------
-- Functions
-----------------------------

local function OnDragStart(self, button)
  if not IsShiftKeyDown() then return end
  local frame = self:GetParent()
  if not frame then return end

  if button == "RightButton" then
    -- Resize uses native StartSizing (no snap needed)
    frame:StartSizing()
    return
  end

  if button ~= "LeftButton" then return end
  if InCombatLockdown and InCombatLockdown() then return end

  -- Snap-aware drag: compute initial state, use OnUpdate
  -- Ensure CENTER/UIParent anchor for predictable math
  local cx, cy = frame:GetCenter()
  local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
  if not (cx and cy and pw and ph and pw > 0 and ph > 0) then
    frame:StartMoving()
    return
  end

  local x = cx - (pw * 0.5)
  local y = cy - (ph * 0.5)

  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", x, y)

  local curX, curY = GetCursorUI()
  self._dragging = true
  self._startCursorX = curX
  self._startCursorY = curY
  self._startX = x
  self._startY = y

  -- Build snap targets once at drag start
  local frameList = self._frameList
  if rLib and rLib.BuildSnapTargets then
    self._snapXT, self._snapYT = rLib:BuildSnapTargets(frameList, frame)
  else
    self._snapXT, self._snapYT = nil, nil
  end

  self:SetScript("OnUpdate", function(s)
    if not s._dragging then return end
    local ccx, ccy = GetCursorUI()
    local dx = ccx - s._startCursorX
    local dy = ccy - s._startCursorY
    local nx = s._startX + dx
    local ny = s._startY + dy

    local fr = s:GetParent()
    if not fr then return end
    local fw = fr:GetWidth() or 1
    local fh = fr:GetHeight() or 1

    -- Apply snap
    if rLib and rLib.SnapOffsets and s._snapXT and s._snapYT then
      nx, ny = rLib:SnapOffsets(nx, ny, fw, fh, s._snapXT, s._snapYT)
    end

    fr:ClearAllPoints()
    fr:SetPoint("CENTER", UIParent, "CENTER", nx, ny)
  end)
end

local function OnDragStop(self)
  local frame = self:GetParent()
  if self._dragging then
    self._dragging = false
    self:SetScript("OnUpdate", nil)
    self._snapXT = nil
    self._snapYT = nil
    if rLib and rLib.HideGuides then
      rLib:HideGuides()
    end
  else
    if frame then
      frame:StopMovingOrSizing()
    end
  end

  if frame then
    SaveAddonMoverLayout(frame, {
      point = true,
      scale = false,
      size = frame.__resizable == true,
    })
  end
end

local function OnEnter(self)
  if InCombatLockdown and InCombatLockdown() then return end
  local t = ns and ns.Tooltip
  if t and type(t.OnMoverEnter) == "function" then
    local ok, handled = TryTooltipCallback(t.OnMoverEnter, t, self, self:GetParent())
    if ok and handled then
      self.__tooltipHandled = true
      return
    end
  end
  if not GameTooltip then return end
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine(self:GetParent():GetName(), 0, 1, 0.5, 1, 1, 1)
  GameTooltip:AddLine("SHIFT+LeftDrag to move (snap to grid).", 1, 1, 1, 1, 1, 1)
  if self:GetParent().__resizable then
    GameTooltip:AddLine("SHIFT+RightDrag to resize.", 1, 1, 1, 1, 1, 1)
  end
  GameTooltip:AddLine("MouseWheel to scale.", 0.8, 0.95, 1, 1, 1, 1)
  GameTooltip:AddLine("SHIFT+MouseWheel for fine scale.", 0.8, 0.95, 1, 1, 1, 1)
  if self:GetParent().__resizable then
    GameTooltip:AddLine("CTRL+ALT+MouseWheel to resize.", 0.8, 0.95, 1, 1, 1, 1)
  end
  GameTooltip:AddLine("Arrow keys to nudge (SHIFT: 10px).", 0.6, 0.9, 1, 1, 1, 1)
  GameTooltip:AddLine("SHIFT+RightClick to reset scale.", 0.8, 0.95, 1, 1, 1, 1)
  GameTooltip:Show()
  self.__tooltipHandled = true

  -- Enable keyboard for arrow nudge
  self:EnableKeyboard(true)
  if self.SetPropagateKeyboardInput then
    self:SetPropagateKeyboardInput(true)
  end
end

local function OnLeave(self)
  -- Disable keyboard when mouse leaves
  self:EnableKeyboard(false)

  local t = ns and ns.Tooltip
  if t and type(t.OnMoverLeave) == "function" then
    TryTooltipCallback(t.OnMoverLeave, t, self)
    self.__tooltipHandled = nil
    return
  end
  if self.__tooltipHandled and GameTooltip then GameTooltip:Hide() end
  self.__tooltipHandled = nil
end

local function OnKeyDown(self, key)
  local isArrow = (key == "LEFT" or key == "RIGHT" or key == "UP" or key == "DOWN")
  if not isArrow then
    if self.SetPropagateKeyboardInput then
      self:SetPropagateKeyboardInput(true)
    end
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    if self.SetPropagateKeyboardInput then
      self:SetPropagateKeyboardInput(true)
    end
    return
  end

  -- Consume the key
  if self.SetPropagateKeyboardInput then
    self:SetPropagateKeyboardInput(false)
  end

  local frame = self:GetParent()
  if not frame then return end

  local step = IsShiftKeyDown() and NUDGE_STEP_LARGE or NUDGE_STEP

  -- Get current center-relative position
  local cx, cy = frame:GetCenter()
  local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
  if not (cx and cy and pw and ph and pw > 0 and ph > 0) then return end

  local x = cx - (pw * 0.5)
  local y = cy - (ph * 0.5)

  if key == "LEFT" then x = x - step end
  if key == "RIGHT" then x = x + step end
  if key == "UP" then y = y + step end
  if key == "DOWN" then y = y - step end

  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
  SaveAddonMoverLayout(frame, { point = true, scale = false, size = false })
end

local function OnShow(self)
  local frame = self:GetParent()
  if frame.fader then
    L:StartFadeIn(frame)
  end
end

local function OnHide(self)
  local frame = self:GetParent()
  if frame.fader then
    L:StartFadeOut(frame)
  end
  -- Clean up drag state if hidden mid-drag
  if self._dragging then
    self._dragging = false
    self:SetScript("OnUpdate", nil)
    if rLib and rLib.HideGuides then rLib:HideGuides() end
  end
  self:EnableKeyboard(false)
end

local function OnMouseWheel(self, delta)
  if InCombatLockdown and InCombatLockdown() then return end
  local frame = self:GetParent()
  if not frame then return end

  local ctrlDown = (_G.IsControlKeyDown and IsControlKeyDown()) or false
  local altDown = (_G.IsAltKeyDown and IsAltKeyDown()) or false
  if ctrlDown and altDown and frame.__resizable and frame.GetSize and frame.SetSize then
    local step = IsShiftKeyDown() and 4 or 10
    local sign = (tonumber(delta) or 0) >= 0 and 1 or -1
    local w, h = frame:GetSize()
    w = tonumber(w) or 1
    h = tonumber(h) or 1
    if w < 1 then w = 1 end
    local ratio = h / w
    local nextW = Clamp(w + (sign * step), 24, 4096)
    local nextH = Clamp(nextW * ratio, 24, 4096)
    frame:SetSize(nextW, nextH)
    SaveAddonMoverLayout(frame, { point = false, scale = false, size = true })
    return
  end

  if not (frame.GetScale and frame.SetScale) then return end

  local step = IsShiftKeyDown() and MOVER_SCALE_FINE_STEP or MOVER_SCALE_STEP
  local sign = (tonumber(delta) or 0) >= 0 and 1 or -1
  local cur = tonumber(frame:GetScale()) or 1
  local nextScale = Clamp(cur + (sign * step), MOVER_SCALE_MIN, MOVER_SCALE_MAX)
  if nextScale == cur then return end

  frame:SetScale(nextScale)
  SaveAddonMoverLayout(frame, { point = false, scale = true, size = false })
end

local function OnMouseUp(self, button)
  if button ~= "RightButton" then return end
  if not IsShiftKeyDown() then return end
  if InCombatLockdown and InCombatLockdown() then return end
  local frame = self:GetParent()
  if not (frame and frame.SetScale) then return end
  local defaultScale = tonumber(frame.defaultScale) or 1
  frame:SetScale(defaultScale)
  ClearAddonMoverLayout(frame, { point = false, scale = true, size = false })
end

--rLib:CreateDragFrame
function rLib:CreateDragFrame(frame, frames, inset, clamp)
  if not frame or not frames then return end
  --save the default position for later
  frame.defaultPoint = L:GetPoint(frame)
  frame.defaultScale = frame.defaultScale or frame:GetScale()
  InsertUnique(frames, frame) --add frame object to the list
  --anchor a dragable frame on frame
  local df = CreateFrame("Frame", nil, frame)
  df:SetAllPoints(frame)
  df:SetFrameStrata("HIGH")
  df:SetHitRectInsets(inset or 0, inset or 0, inset or 0, inset or 0)
  df:EnableMouse(true)
  df:EnableMouseWheel(true)
  df:RegisterForDrag("LeftButton")
  df:SetScript("OnDragStart", OnDragStart)
  df:SetScript("OnDragStop", OnDragStop)
  df:SetScript("OnEnter", OnEnter)
  df:SetScript("OnLeave", OnLeave)
  df:SetScript("OnShow", OnShow)
  df:SetScript("OnHide", OnHide)
  df:SetScript("OnMouseWheel", OnMouseWheel)
  df:SetScript("OnMouseUp", OnMouseUp)
  df:SetScript("OnKeyDown", OnKeyDown)
  df:Hide()
  -- Store reference to frame list for snap targets
  df._frameList = frames
  --overlay texture
  local t = df:CreateTexture(nil, "OVERLAY", nil, 6)
  t:SetAllPoints(df)
  t:SetColorTexture(0, 1, 1)
  t:SetVertexColor(0, 1, 0)
  t:SetAlpha(0.3)
  df.texture = t
  --frame stuff
  frame.dragFrame = df
  frame.dragframe = df
  frame:SetClampedToScreen(clamp or false)
  frame:SetMovable(true)
  if frame.SetUserPlaced then
    frame:SetUserPlaced(false)
  end
  ApplyAddonMoverLayout(frame, { point = true, scale = true, size = false })

  local callbacks = GetMoverCallbacks()
  local registerMoverFrame = callbacks and callbacks.RegisterFrame
  if type(registerMoverFrame) == "function" then
    registerMoverFrame(frame)
  end
end

--rLib:CreateDragResizeFrame
function rLib:CreateDragResizeFrame(frame, frames, inset, clamp)
  if not frame or not frames then return end
  rLib:CreateDragFrame(frame, frames, inset, clamp)
  frame.defaultSize = L:GetSize(frame)
  frame:SetResizable(true)
  frame.__resizable = true
  frame.dragFrame:RegisterForDrag("LeftButton", "RightButton")
  ApplyAddonMoverLayout(frame, { point = false, scale = false, size = true })
end
