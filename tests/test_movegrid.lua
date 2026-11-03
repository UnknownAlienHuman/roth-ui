local function expect(condition, message)
  if not condition then error(message, 2) end
end

local inCombat = false
_G.InCombatLockdown = function() return inCombat end
_G.UIParent = { width = 256, height = 128 }
function _G.UIParent:GetWidth() return self.width end
function _G.UIParent:GetHeight() return self.height end
local timers = {}
_G.C_Timer = { After = function(delay, callback)
  expect(delay == 0, "grid coalescing used a delayed retry")
  timers[#timers + 1] = callback
end }

local frames = {}
local textureCount, layoutCalls = 0, 0
_G.CreateFrame = function(_, name, parent)
  local frame = { name = name, parent = parent, events = {}, scripts = {}, shown = true }
  function frame:SetFrameStrata(value) self.strata = value end
  function frame:SetAllPoints(target) self.allPoints = target end
  function frame:ClearAllPoints() end
  function frame:SetPoint(...) layoutCalls = layoutCalls + 1; self.points = self.points or {}; self.points[#self.points + 1] = { ... } end
  function frame:SetWidth(value) self.width = value end
  function frame:SetHeight(value) self.height = value end
  function frame:Show() self.shown = true end
  function frame:Hide() self.shown = false end
  function frame:IsShown() return self.shown end
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:UnregisterEvent(event) self.events[event] = nil end
  function frame:SetScript(script, callback) self.scripts[script] = callback end
  function frame:CreateTexture()
    textureCount = textureCount + 1
    local texture = { points = {} }
    function texture:SetTexture(value) self.texture = value end
    function texture:ClearAllPoints() self.points = {} end
    function texture:SetPoint(...) layoutCalls = layoutCalls + 1; self.points[#self.points + 1] = { ... } end
    function texture:SetWidth(value) self.width = value end
    function texture:SetHeight(value) self.height = value end
    function texture:SetVertexColor(...) self.color = { ... } end
    function texture:Show() self.shown = true end
    function texture:Hide() self.shown = false end
    return texture
  end
  frames[#frames + 1] = frame
  return frame
end

local ns = {}
assert(loadfile("core/deferred_scheduler.lua"))("Roth_UI", ns)
assert(loadfile("core/movegrid.lua"))("Roth_UI", ns)
expect(#frames == 0, "move grid was not lazy")

ns.ShowMoveGrid()
local grid, eventFrame = frames[1], frames[2]
expect(#frames == 2 and grid:IsShown(), "first show did not create and reveal the grid")
expect(textureCount == 14, "initial 256x128 grid did not create the expected pooled lines")
expect(eventFrame.events.DISPLAY_SIZE_CHANGED and eventFrame.events.UI_SCALE_CHANGED,
  "visible grid did not subscribe to geometry changes")

local initialLayouts = layoutCalls
ns.ShowMoveGrid()
expect(layoutCalls == initialLayouts, "repeated unlock rebuilt an already visible grid")
expect(textureCount == 14, "repeated show allocated duplicate grid lines")

_G.UIParent.width, _G.UIParent.height = 320, 160
eventFrame.scripts.OnEvent(eventFrame, "DISPLAY_SIZE_CHANGED")
eventFrame.scripts.OnEvent(eventFrame, "UI_SCALE_CHANGED")
expect(layoutCalls == initialLayouts and #timers == 1,
  "visible grid layout invalidations were not coalesced to one next-frame pass")
timers[1]()
expect(layoutCalls > initialLayouts, "visible grid ignored a display-size change")
local afterResize = layoutCalls

ns.HideMoveGrid()
expect(not grid:IsShown(), "hide did not hide the grid")
expect(eventFrame.events.DISPLAY_SIZE_CHANGED == nil and eventFrame.events.UI_SCALE_CHANGED == nil,
  "hidden grid retained idle geometry event subscriptions")
_G.UIParent.width, _G.UIParent.height = 384, 192
eventFrame.scripts.OnEvent(eventFrame, "UI_SCALE_CHANGED")
expect(layoutCalls == afterResize, "hidden grid rebuilt on a geometry notification")

ns.ShowMoveGrid()
expect(grid:IsShown() and eventFrame.events.DISPLAY_SIZE_CHANGED and eventFrame.events.UI_SCALE_CHANGED,
  "show did not rebuild and resubscribe after hiding")
expect(layoutCalls > afterResize, "reopened grid did not use current UIParent dimensions")

ns.HideMoveGrid()
inCombat = true
local layoutsBeforeCombatShow = layoutCalls
ns.ShowMoveGrid()
expect(not grid:IsShown() and layoutCalls == layoutsBeforeCombatShow,
  "combat unlock showed or rebuilt the grid")

print("move grid visible-lifecycle test: OK")
