local function expect(condition, message)
  if not condition then error(message, 2) end
end

local inCombat, shiftDown, ctrlDown, altDown = false, false, false, false
_G.InCombatLockdown = function() return inCombat end
_G.IsShiftKeyDown = function() return shiftDown end
_G.IsControlKeyDown = function() return ctrlDown end
_G.IsAltKeyDown = function() return altDown end
_G.GameTooltip = nil
_G.floor = math.floor
_G.LibStub = nil -- the runtime must work without the dormant rLib bridge

local store = {}
local function keyPath(path)
  return table.concat(path, ".")
end
local function getPath(path)
  return store[keyPath(path)]
end
local function setPath(path, value)
  store[keyPath(path)] = value
end

local canonical = {}
local frameRegistry = {
  RegisterFrame = function(_, category, frame)
    canonical[category] = canonical[category] or {}
    for _, entry in ipairs(canonical[category]) do if entry == frame then return end end
    canonical[category][#canonical[category] + 1] = frame
  end,
  GetCategory = function(_, frame)
    for category, list in pairs(canonical) do
      for _, entry in ipairs(list) do if entry == frame then return category end end
    end
  end,
  GetList = function(category) return canonical[category] end,
  ForEachFrame = function(selection, callback)
    for category, list in pairs(canonical) do
      if selection == nil or selection == "all" or selection == category then
        for _, frame in ipairs(list) do callback(frame, category) end
      end
    end
  end,
}

local created = {}
local function makeFrame(name, parent)
  local frame = {
    name = name,
    parent = parent,
    scripts = {},
    width = 120,
    height = 40,
    scale = 1,
    points = {},
    movable = false,
    mouse = false,
    mouseWheel = false,
    shown = true,
  }
  function frame:GetName() return self.name end
  function frame:GetParent() return self.parent end
  function frame:SetAllPoints(target) self.allPoints = target end
  function frame:SetFrameStrata(value) self.strata = value end
  function frame:SetScript(name, callback) self.scripts[name] = callback end
  function frame:CreateTexture()
    return {
      SetAllPoints = function(_, target) end,
      SetColorTexture = function(_, ...) self.tint = { ... } end,
      SetPoint = function() end,
      SetHeight = function(_, value) end,
      SetWidth = function(_, value) end,
    }
  end
  function frame:CreateFontString()
    return {
      SetFont = function() end,
      SetPoint = function() end,
      SetWordWrap = function() end,
      SetTextColor = function() end,
      SetText = function() end,
    }
  end
  function frame:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
  function frame:Show() self.shown = true end
  function frame:EnableMouse(value) self.mouse = value end
  function frame:EnableMouseWheel(value) self.mouseWheel = value end
  function frame:RegisterForDrag(...) self.dragButtons = { ... } end
  function frame:SetClampedToScreen(value) self.clamped = value end
  function frame:SetMovable(value) self.movable = value end
  function frame:IsMovable() return self.movable end
  function frame:IsResizable() return self.resizable or false end
  function frame:SetUserPlaced(value) self.userPlaced = value end
  function frame:GetPoint() local p = self.points[1]; if p then return unpack(p) end end
  function frame:ClearAllPoints() self.points = {} end
  function frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
  function frame:GetSize() return self.width, self.height end
  function frame:SetSize(width, height) self.width, self.height = width, height end
  function frame:GetScale() return self.scale end
  function frame:SetScale(value) self.scale = value end
  function frame:StartMoving() self.startedMoving = true end
  function frame:StopMovingOrSizing() self.stoppedMoving = true end
  function frame:IsMouseOver() return false end
  created[#created + 1] = frame
  return frame
end
_G.CreateFrame = function(_, name, parent) return makeFrame(name, parent) end

local ns = {
  cfg = { framesLocked = true },
  func = { IsSecretValue = function() return false end },
  store = { GetConfigValue = function(path) return getPath(path) end, SetConfigValue = function(path, value) setPath(path, value) end },
  frameRegistry = frameRegistry,
  framePolicy = { DeferUntilOutOfCombat = function() return false end },
}
assert(loadfile("core/mover_runtime.lua"))("Roth_UI", ns)

local function createMovable(name, category)
  local frame = makeFrame(name, _G.UIParent)
  frame:SetPoint("CENTER", _G.UIParent, "CENTER", 5, 6)
  frame:SetSize(120, 40)
  frame:SetScale(1)
  ns.RegisterMoverFrame(frame, category)
  ns.func.applyDragFunctionality(frame)
  expect(frame.dragframe ~= nil, "mover handle was not created for " .. name)
  expect(frameRegistry:GetCategory(frame) == category, "mover was not registered in expected category")
  return frame
end

_G.UIParent = makeFrame("UIParent")
local frame = createMovable("Roth_TestMover", "units")
local handle = frame.dragframe
expect(handle.shown == false and handle.mouse == false and handle.mouseWheel == false,
  "locked mode left the mover interactive")
expect(frame.defaultPosition.x == 5 and frame.defaultPosition.y == 6
    and frame.defaultScale == 1 and frame.defaultSize.w == 120,
  "mover defaults were not captured")

expect(ns.func.SetMoverUnlocked(frame, true) == true, "unlock failed")
expect(handle.shown and handle.mouse and handle.mouseWheel, "unlocked handle is not interactive")
expect(handle.dragButtons and handle.dragButtons[1] == "LeftButton", "left-button drag was not registered")

shiftDown = false
handle.scripts.OnDragStart(handle)
expect(not frame.startedMoving, "drag moved frame without Shift")
shiftDown = true
handle.scripts.OnDragStart(handle)
expect(frame.startedMoving, "Shift+drag did not start moving")
frame:ClearAllPoints()
frame:SetPoint("TOP", _G.UIParent, "BOTTOM", 31, 42)
handle.scripts.OnDragStop(handle)
expect(frame.stoppedMoving, "drag stop did not stop movement")
local savedPoint = getPath({ "movers", "point", "Roth_TestMover" })
expect(savedPoint and savedPoint.a1 == "TOP" and savedPoint.x == 31 and savedPoint.y == 42,
  "drag stop did not persist the point")

shiftDown = false
handle.scripts.OnMouseWheel(handle, 1)
expect(math.abs(frame.scale - 1.03) < 0.00001 and math.abs(getPath({ "movers", "scale", "Roth_TestMover" }) - 1.03) < 0.00001,
  "mouse wheel scale change did not persist: " .. tostring(frame.scale) .. ", " .. tostring(getPath({ "movers", "scale", "Roth_TestMover" })))
shiftDown = true
handle.scripts.OnMouseWheel(handle, 1)
expect(math.abs(frame.scale - 1.04) < 0.00001, "Shift+wheel fine scale step was incorrect")
shiftDown = false
ctrlDown, altDown = true, true
handle.scripts.OnMouseWheel(handle, 1)
expect(frame.width == 130 and math.abs(frame.height - (40 / 120 * 130)) < 0.001,
  "Ctrl+Alt+wheel did not resize while preserving aspect")
local savedSize = getPath({ "movers", "size", "Roth_TestMover" })
expect(savedSize and savedSize.w == 130 and savedSize.h == 43,
  "resized dimensions were not persisted")
ctrlDown, altDown = false, false

shiftDown = true
handle.scripts.OnMouseUp(handle, "RightButton")
expect(frame.scale == 1 and getPath({ "movers", "scale", "Roth_TestMover" }) == nil,
  "Shift+right-click did not reset and clear saved scale")
shiftDown = false

expect(ns.func.ResetMoverLayout(frame) == nil, "reset unexpectedly returned a failure")
local point = frame.points[1]
expect(point[1] == "CENTER" and point[4] == 5 and point[5] == 6,
  "full reset did not restore default point")
expect(frame.width == 120 and frame.height == 40 and frame.scale == 1,
  "full reset did not restore default dimensions and scale")
expect(getPath({ "movers", "point", "Roth_TestMover" }) == nil
    and getPath({ "movers", "size", "Roth_TestMover" }) == nil
    and getPath({ "movers", "scale", "Roth_TestMover" }) == nil,
  "full reset did not clear persisted geometry")

shiftDown = true
handle.scripts.OnDragStart(handle)
frame:ClearAllPoints()
frame:SetPoint("BOTTOM", _G.UIParent, "TOP", -9, 14)
frame.stoppedMoving = nil
handle:Hide()
expect(frame.stoppedMoving == true, "hiding an active drag handle did not stop frame movement")
local pointOnHide = getPath({ "movers", "point", "Roth_TestMover" })
expect(pointOnHide and pointOnHide.a1 == "BOTTOM" and pointOnHide.x == -9 and pointOnHide.y == 14,
  "drag-handle hide did not persist the last frame position")
shiftDown = false

expect(ns.func.SetMoverUnlocked(frame, false) == true, "lock failed")
expect(not handle.shown and not handle.mouse and not handle.mouseWheel,
  "locked handle remained interactive")

-- A power/alternate-power frame uses the same mover registration path and is
-- discoverable by the shared runtime iteration API.
local altPower = makeFrame("Roth_AltPower", _G.UIParent)
altPower:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
ns.func.applyDragFunctionality(altPower, "orb")
expect(frameRegistry:GetCategory(altPower) == "orbs",
  "orb hint was not registered through the shared mover")
ns.RegisterMoverFrame(altPower, "orbs")
local visitedAltPower = false
ns.ForEachMoverFrame("orbs", function(candidate, category)
  if candidate == altPower then visitedAltPower = category == "orbs" end
end)
expect(visitedAltPower, "shared mover iteration did not include the alternate-power frame")

local beforeCombatFrames = #created
expect(ns.func.SetMoverUnlocked(frame, true) == true, "pre-combat unlock failed")
inCombat = true
local combatFrame = makeFrame("Roth_CombatMover", _G.UIParent)
ns.func.applyDragFunctionality(combatFrame)
expect(combatFrame.dragframe == nil and #created == beforeCombatFrames + 1,
  "combat initialization created a drag overlay")
expect(ns.func.SetMoverUnlocked(frame, true) == false, "combat unlock was not blocked")
expect(ns.func.ResetMoverLayout(frame) == false, "combat reset was not blocked")
local priorScale = frame.scale
handle.scripts.OnMouseWheel(handle, 1)
expect(frame.scale == priorScale, "combat mouse handler mutated mover scale")
inCombat = false

print("mover runtime interaction/persistence test: OK")
