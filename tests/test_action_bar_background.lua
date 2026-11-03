local function expect(condition, message)
  if not condition then error(message, 2) end
end

local inCombat = false
_G.InCombatLockdown = function() return inCombat end
_G.UnitHasVehicleUI = function() return false end
_G.C_ActionBar = {}
_G.UIParent = { name = "UIParent" }
function _G.UIParent:GetName() return self.name end
_G.Enum = { EditModeActionBarSystemIndices = { MainBar = 1 } }
_G.hooksecurefunc = nil
_G.MainActionBar = nil
_G.C_Timer = nil
_G.NUM_ACTIONBAR_BUTTONS = 0

local function makeRegion()
  local region = { points = {} }
  function region:ClearAllPoints() self.points = {} end
  function region:SetPoint(...) self.points[#self.points + 1] = { ... } end
  function region:SetAllPoints(target) self.allPoints = target end
  function region:SetTexture(texture) self.texture = texture end
  function region:SetAlpha(alpha) self.alpha = alpha end
  function region:Show() self.shown = true end
  function region:Hide() self.shown = false end
  function region:IsShown() return self.shown == true end
  return region
end

local created = {}
local function makeFrame(name, parent)
  local frame = makeRegion()
  frame.name, frame.parent = name, parent
  frame.width, frame.height, frame.scale = 0, 0, 1
  frame.shown = true
  frame.events, frame.scripts = {}, {}
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:SetScript(script, callback) self.scripts[script] = callback end
  function frame:GetName() return self.name end
  function frame:CreateTexture() self.texture = makeRegion(); return self.texture end
  function frame:SetFrameStrata(value) self.strata = value end
  function frame:SetFrameLevel(value) self.level = value end
  function frame:SetSize(width, height) self.width, self.height = width, height end
  function frame:GetSize() return self.width, self.height end
  function frame:SetScale(value) self.scale = value end
  function frame:GetScale() return self.scale end
  function frame:GetPoint() local p = self.points[1]; if p then return unpack(p) end end
  created[#created + 1] = frame
  return frame
end

local function makeMoverBar(name)
  local frame = makeRegion()
  frame.name, frame.width, frame.height, frame.scale = name, 100, 10, 1
  frame.__rothActive = true
  function frame:GetName() return self.name end
  function frame:SetSize(width, height) self.width, self.height = width, height end
  function frame:GetSize() return self.width, self.height end
  function frame:SetScale(value) self.scale = value end
  function frame:GetScale() return self.scale end
  return frame
end

local expBar = makeMoverBar("Roth_UIExpBar")
local repBar = makeMoverBar("Roth_UIRepBar")

_G.CreateFrame = function(_, name, parent) return makeFrame(name, parent) end

local controller
local saved = { point = nil, scale = nil, size = nil }
local savedBars = {}
local appliedLayoutCount = 0
local appliedBarLayoutCount = 0
local policyQueue, policyDrainCount = {}, 0
local ns = {
  cfg = {
    bars = {},
    units = { player = {
      expbar = { width = 365, height = 10 },
      repbar = { width = 365, height = 10 },
      art = { actionbarbackground = {
      show = true, scale = 1.25,
      pos = { a1 = "CENTER", af = "UIParent", a2 = "CENTER", x = 12, y = 34 },
    } } } },
  },
  func = { IsSecretValue = function() return false end },
  frameRegistry = {
    ResolveFrame = function(_, category, name)
      if category ~= "bars" then return nil end
      if name == "Roth_UIExpBar" then return expBar end
      if name == "Roth_UIRepBar" then return repBar end
    end,
  },
  safety = {
    CanAccess = function() return true end,
    CanUseRegion = function(value) return type(value) == "table" end,
    TryGet = function(value, key) return true, value and value[key] end,
    TryMethod = function(value, key, ...) if value and type(value[key]) == "function" then return true, value[key](value, ...) end; return false end,
  },
  framePolicy = {
    DeferUntilOutOfCombat = function(key, callback) policyQueue[key] = callback end,
  },
}

-- These mocks preserve the real ordering contract: configured layout is in
-- place before mover initialization; existing saved overrides are reapplied
-- after each later config layout refresh.
ns.func.applyDragFunctionality = function(frame)
  expect(frame.width == 788 and frame.height == 220, "mover initialized before configured artwork size")
  expect(frame.scale == 1.25, "mover initialized before configured scale")
  expect(frame.points[1][1] == "CENTER" and frame.points[1][4] == 12 and frame.points[1][5] == 34,
    "mover initialized before configured anchor")
  frame.defaultPosition = { a1 = "CENTER", af = "UIParent", a2 = "CENTER", x = 12, y = 34 }
  frame.defaultScale = 1.25
  frame.defaultSize = { w = 788, h = 220 }
  frame.dragframe = {}
  if saved.point then frame:ClearAllPoints(); frame:SetPoint(saved.point.a1, _G[saved.point.af], saved.point.a2, saved.point.x, saved.point.y) end
  if saved.size then frame:SetSize(saved.size.w, saved.size.h) end
  if saved.scale then frame:SetScale(saved.scale) end
end
ns.ApplySavedMoverLayout = function(frame)
  if frame == expBar or frame == repBar then
    appliedBarLayoutCount = appliedBarLayoutCount + 1
    local layout = savedBars[frame.name]
    if layout then
      if layout.size then frame:SetSize(layout.size.w, layout.size.h) end
      if layout.point then frame:ClearAllPoints(); frame:SetPoint(layout.point.a1, _G[layout.point.af], layout.point.a2, layout.point.x, layout.point.y) end
      if layout.scale then frame:SetScale(layout.scale) end
    end
    return
  end
  appliedLayoutCount = appliedLayoutCount + 1
  if saved.size then frame:SetSize(saved.size.w, saved.size.h) end
  if saved.point then frame:ClearAllPoints(); frame:SetPoint(saved.point.a1, _G[saved.point.af], saved.point.a2, saved.point.x, saved.point.y) end
  if saved.scale then frame:SetScale(saved.scale) end
end
ns.func.ResetMoverLayout = function(frame)
  local pos = frame.defaultPosition
  frame:ClearAllPoints()
  frame:SetPoint(pos.a1, _G[pos.af], pos.a2, pos.x, pos.y)
  frame:SetScale(frame.defaultScale)
  frame:SetSize(frame.defaultSize.w, frame.defaultSize.h)
end

assert(loadfile("core/action_bar_background.lua"))("Roth_UI", ns)
controller = created[1]
expect(controller ~= nil and controller.scripts.OnEvent, "event controller was not created")
expect(ns.ActionBarBackground ~= nil, "enabled artwork frame was not created")
local artwork = ns.ActionBarBackground
expect(artwork.width == 788 and artwork.height == 220 and artwork.scale == 1.25,
  "configured artwork dimensions or scale were not applied")
expect(artwork.points[1][1] == "CENTER" and artwork.points[1][4] == 12 and artwork.points[1][5] == 34,
  "configured artwork position was not applied")
expect(artwork.defaultPosition.x == 12 and artwork.defaultScale == 1.25
    and artwork.defaultSize.w == 788,
  "configured geometry was not captured as mover reset defaults")
expect(expBar.defaultPosition and expBar.defaultPosition.a1 == "BOTTOM"
    and expBar.defaultPosition.af == UIParent and expBar.defaultPosition.y == 126.25
    and expBar.defaultSize.w == 486.25 and expBar.defaultSize.h == 12.5,
  "experience bar mover defaults did not capture artwork-aligned geometry")
expect(repBar.defaultPosition and repBar.defaultPosition.y == 138.75
    and repBar.defaultSize.w == 500,
  "reputation bar mover defaults did not capture artwork-aligned geometry")

savedBars["Roth_UIExpBar"] = {
  point = { a1 = "TOP", af = "UIParent", a2 = "BOTTOM", x = 35, y = 55 },
  scale = 1.4, size = { w = 500, h = 22 },
}
ns.RefreshActionBarArtwork()
expect(expBar.points[1][1] == "TOP" and expBar.points[1][4] == 35 and expBar.points[1][5] == 55
    and expBar.width == 500 and expBar.height == 22 and expBar.scale == 1.4,
  "saved experience-bar mover overrides did not survive action-art refresh")
expect(expBar.defaultPosition.y == 126.25 and expBar.defaultSize.w == 486.25,
  "saved experience-bar layout overwrote its reset defaults")

local afterInitialEvents = appliedLayoutCount
controller.scripts.OnEvent(controller, "PLAYER_ENTERING_WORLD", true, false)
expect(appliedLayoutCount == afterInitialEvents + 1,
  "PLAYER_ENTERING_WORLD booleans were incorrectly treated as a unit token")
local afterWorld = appliedLayoutCount
controller.scripts.OnEvent(controller, "UNIT_ENTERED_VEHICLE", "party1")
expect(appliedLayoutCount == afterWorld, "non-player vehicle event triggered an artwork refresh")
controller.scripts.OnEvent(controller, "UNIT_ENTERED_VEHICLE", "player")
expect(appliedLayoutCount == afterWorld + 1, "player vehicle event did not refresh artwork")

saved.point = { a1 = "TOP", af = "UIParent", a2 = "BOTTOM", x = 80, y = 90 }
saved.scale, saved.size = 1.7, { w = 900, h = 260 }
ns.RefreshActionBarArtwork()
expect(artwork.points[1][1] == "TOP" and artwork.points[1][4] == 80 and artwork.points[1][5] == 90,
  "saved mover point did not survive artwork refresh")
expect(artwork.scale == 1.7 and artwork.width == 900 and artwork.height == 260,
  "saved mover scale/size did not survive artwork refresh")
expect(appliedLayoutCount >= 1, "saved mover layout was not reapplied after config geometry")

-- Settings can change the configured default after the frame already exists.
ns.cfg.units.player.art.actionbarbackground.pos = {
  a1 = "BOTTOM", af = "UIParent", a2 = "BOTTOM", x = -15, y = 25,
}
ns.cfg.units.player.art.actionbarbackground.scale = 0.9
ns.RefreshActionBarArtwork()
expect(artwork.defaultPosition.a1 == "BOTTOM" and artwork.defaultPosition.x == -15
    and artwork.defaultScale == 0.9,
  "changed configured defaults were not recorded for mover reset")
expect(artwork.points[1][1] == "TOP" and artwork.scale == 1.7,
  "config refresh replaced an active saved mover override")

local savedAtStart = saved
saved = { point = nil, scale = nil, size = nil }
ns.func.ResetMoverLayout(artwork)
expect(artwork.points[1][1] == "BOTTOM" and artwork.points[1][4] == -15 and artwork.points[1][5] == 25,
  "reset did not restore the latest configured position")
expect(artwork.scale == 0.9 and artwork.width == 788 and artwork.height == 220,
  "reset did not restore configured scale and size")
saved = savedAtStart

local beforeCreateDisabled = #created
ns.cfg.units.player.art.actionbarbackground.show = false
ns.RefreshActionBarArtwork()
expect(#created == beforeCreateDisabled, "disabling existing artwork created a spurious frame")
expect(artwork.shown == false, "disabled artwork was not hidden")

local beforeCombat = #created
inCombat = true
ns.RefreshActionBarArtwork()
expect(#created == beforeCombat, "combat refresh performed structural frame work")
expect(policyQueue["action-bar-background"] ~= nil, "combat refresh was not deferred to shared policy")
inCombat = false
policyQueue["action-bar-background"]()
policyQueue["action-bar-background"] = nil
policyDrainCount = policyDrainCount + 1
expect(policyDrainCount == 1, "shared deferred callback did not run once")

expect(controller.events.PLAYER_REGEN_ENABLED == nil,
  "action-bar owner registered its own permanent regen-enabled event")
for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" }) do
  expect(controller.events[event] == true, "missing event registration: " .. event)
end

local disabledStart = #created
local disabledNs = {
  cfg = { bars = {}, units = { player = { art = { actionbarbackground = { show = false } } } } },
  func = { IsSecretValue = function() return false end },
  frameRegistry = { ResolveFrame = function() return nil end },
  safety = {
    CanAccess = function() return true end,
    CanUseRegion = function(value) return type(value) == "table" end,
    TryGet = function(value, key) return true, value and value[key] end,
    TryMethod = function(value, key, ...) if value and type(value[key]) == "function" then return true, value[key](value, ...) end; return false end,
  },
  framePolicy = { DeferUntilOutOfCombat = function(key, callback) policyQueue[key] = callback end },
}
assert(loadfile("core/action_bar_background.lua"))("Roth_UI", disabledNs)
expect(#created == disabledStart + 1, "disabled artwork created more than its event controller")
expect(disabledNs.ActionBarBackground == nil, "disabled artwork published or created a background frame")

print("action-bar artwork lifecycle/mover test: OK")
