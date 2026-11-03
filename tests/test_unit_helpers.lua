local function expect(condition, message)
  if not condition then error(message, 2) end
end

local blocked, secret = {}, {}
_G.issecretvalue = function(value) return value == secret end
_G.canaccessvalue = function(value) return value ~= blocked end
_G.canaccessallvalues = function(...)
  for i = 1, select("#", ...) do
    if select(i, ...) == blocked then return false end
  end
  return true
end

local function noop() end
local frameCount = 0
local function newRegion()
  local region = {}
  for _, method in ipairs({ "SetPoint", "SetSize", "SetStatusBarTexture", "SetAllPoints",
      "SetTexture", "SetColorTexture", "SetAlpha", "SetBlendMode", "SetVertexColor", "SetTextColor",
      "SetScale", "SetFont", "SetShadowColor", "SetJustifyH", "SetFrameStrata", "Hide" }) do
    region[method] = noop
  end
  region.CreateTexture = newRegion
  region.CreateFontString = newRegion
  function region:SetStatusBarColor(...) self.color = { ... } end
  function region:SetText(value) self.text, self.formatted = value, nil end
  function region:SetFormattedText(format, current, maximum)
    self.formatted = { format, current, maximum }
  end
  return region
end
_G.CreateFrame = function()
  frameCount = frameCount + 1
  return newRegion()
end
_G.LibStub = function() return { Register = noop } end
_G.UIParent = {}
local inCombat = false
_G.InCombatLockdown = function() return inCombat end
local initCallback, deferred
local ns = {
  cfg = { font = "font.ttf" },
  frameRegistry = { Register = noop },
  oUF = { RegisterInitCallback = function(_, callback) initCallback = callback end },
  framePolicy = { DeferUntilOutOfCombat = function(_, callback) deferred = callback return true end },
}
assert(loadfile("core/safety.lua"))("Roth_UI", ns)
assert(loadfile("core/lib.lua"))("Roth_UI", ns)
expect(frameCount == 0, "helper namespace allocated an unused native frame")
ns.func.applyDragFunctionality = noop
ns.func.RegisterMoverFrame = noop

local factoryCalls, enableCalls = 0, 0
local owner = { visible = true }
function owner:IsVisible() return self.visible end
function owner:HookScript(_, callback) self.onShow = callback end
function owner:IsElementEnabled() return false end
function owner:EnableElement(element)
  expect(element == "Portrait", "lazy lifecycle enabled the wrong element")
  enableCalls = enableCalls + 1
end
owner.__rothPortraitFactory = function()
  factoryCalls = factoryCalls + 1
  return {}
end
inCombat = true
initCallback(owner)
expect(factoryCalls == 0 and type(deferred) == "function", "portrait creation was not deferred in combat")
owner.visible = false
inCombat = false
deferred()
expect(factoryCalls == 0 and owner.Portrait == nil, "stale combat callback created a hidden portrait")
owner.visible = blocked
owner.onShow(owner)
expect(factoryCalls == 0, "inaccessible visibility created a portrait")
owner.visible = true
owner.onShow(owner)
owner.onShow(owner)
expect(factoryCalls == 1 and enableCalls == 1, "visible portrait was not created and enabled exactly once")

local threat, threatQueries = 2, 0
_G.UnitThreatSituation = function() threatQueries = threatQueries + 1 return threat end
_G.GetThreatStatusColor = function(value)
  expect(value == 2, "opaque threat reached the color API")
  return 1, 0.2, 0
end
local unit = {
  __unit = "focus",
  Border = { SetVertexColor = function(self, ...) self.color = { ... } end },
  PortraitBack = { SetVertexColor = function(self, ...) self.color = { ... } end },
}
ns.func.checkThreat(unit, "UNIT_THREAT_SITUATION_UPDATE", blocked)
ns.func.checkThreat(unit, "UNIT_THREAT_SITUATION_UPDATE", secret)
ns.func.checkThreat(unit, "UNIT_THREAT_SITUATION_UPDATE", "pet")
expect(threatQueries == 0, "unusable or unrelated unit reached the threat API")
ns.func.checkThreat(unit, "UNIT_THREAT_SITUATION_UPDATE", "focus")
expect(unit.Border.color[1] == 1, "ordinary threat color was not applied")
for _, value in ipairs({ blocked, secret }) do
  threat = value
  ns.func.checkThreat(unit, "UNIT_THREAT_SITUATION_UPDATE", "focus")
  expect(unit.Border.color[1] == 0.6 and unit.PortraitBack.color[4] == 0.9,
    "unavailable threat did not restore neutral styling")
end

local altOwner = { cfg = { altpower = {
  pos = { a1 = "CENTER", af = UIParent, a2 = "CENTER", x = 0, y = 0 },
  texture = "texture", color = { r = 1, g = 1, b = 1 }, scale = 1,
} } }
ns.func.createAlternativePowerBar(altOwner)
local alt = altOwner.AlternativePower
alt:PostUpdate("player", 20, 0, 100)
expect(alt.ValueText.formatted[2] == 20, "ordinary alternative power was not rendered")
alt:PostUpdate("player", secret, 0, secret)
expect(alt.ValueText.formatted[2] == secret, "opaque power did not go directly to the native text sink")
alt:PostUpdate("player", blocked, 0, 100)
expect(alt.ValueText.text == "" and alt.ValueText.formatted == nil,
  "inaccessible nonsecret power was forwarded to a text sink")
alt:PostUpdate("player", 20, 0, 0)
expect(alt.ValueText.text == "", "empty alternative power maximum left stale text")

local castOwner = { __style = "player", cfg = { castbar = {
  mini = true, texture = "texture", color = {
    bar = { r = 0.2, g = 0.4, b = 0.6, a = 0.8 },
    bg = { r = 0, g = 0, b = 0, a = 1 },
  },
} } }
ns.func.createCastbar(castOwner)
local cast = castOwner.Castbar
cast:PostUpdateStage(1)
expect(cast.color[1] == 1 and cast.color[3] == 0, "first empower stage lost its style")
cast:PostUpdateStage(2)
expect(cast.color[1] == 0 and cast.color[3] == 1, "second empower stage lost its style")
for _, value in ipairs({ blocked, secret, 3 }) do
  cast:PostUpdateStage(value)
  expect(cast.color[1] == 0.2 and cast.color[4] == 0.8, "cast stage did not restore configured color")
end

print("unit helper lifecycle and value boundaries: OK")
