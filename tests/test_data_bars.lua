local function expect(condition, message)
  if not condition then error(message, 2) end
end

local currentXP, maximumXP, exhaustion = 120, 1000, 80
local playerLevel, maxPlayerLevel = 20, 80
local vehicleUI = false
local watchedFaction = {
  factionID = 11,
  name = "The Test faction",
  currentReactionThreshold = 0,
  nextReactionThreshold = 3000,
  currentStanding = 650,
  reaction = 5,
}

_G.UnitXP = function(unit) expect(unit == "player", "XP queried for unexpected unit"); return currentXP end
_G.UnitXPMax = function(unit) expect(unit == "player", "XP max queried for unexpected unit"); return maximumXP end
_G.GetXPExhaustion = function() return exhaustion end
_G.UnitLevel = function(unit) expect(unit == "player", "level queried for unexpected unit"); return playerLevel end
_G.IsXPUserDisabled = function() return false end
_G.GetMaxLevelForPlayerExpansion = function() return maxPlayerLevel end
_G.MAX_PLAYER_LEVEL = maxPlayerLevel
_G.UnitHasVehicleUI = function(unit) expect(unit == "player", "vehicle UI queried for unexpected unit"); return vehicleUI end
_G.MAX_REPUTATION_REACTION = 8
_G.FACTION_BAR_COLORS = { [5] = { r = 0.2, g = 0.6, b = 0.3 } }
_G.C_Reputation = {
  GetWatchedFactionData = function() return watchedFaction end,
  IsFactionParagonForCurrentPlayer = function() return false end,
  IsMajorFaction = function() return false end,
}
_G.C_GossipInfo = nil
_G.C_MajorFactions = nil

local elements = {}
local oUF = {
  AddElement = function(_, name, path, enable, disable)
    elements[name] = { path = path, enable = enable, disable = disable }
  end,
}
local queueCalls = 0
local ns = {
  oUF = oUF,
  cfg = { units = { player = { expbar = { show = true }, repbar = { show = true } } } },
  safety = { CanAccess = function(value) return true end },
  QueueActionBarArtworkRefresh = function() queueCalls = queueCalls + 1 end,
}

assert(loadfile("oUF/elements/experience.lua"))("Roth_UI", ns)
assert(loadfile("oUF/elements/reputation.lua"))("Roth_UI", ns)
expect(elements.Experience and elements.Reputation, "data bar elements were not registered through AddElement")

local function newStatusBar()
  local bar = { shown = false, values = {}, ranges = {}, colors = {} }
  function bar:IsObjectType(kind) return kind == "StatusBar" end
  function bar:GetStatusBarTexture() return true end
  function bar:SetStatusBarTexture(texture) self.texture = texture end
  function bar:SetFrameLevel(level) self.frameLevel = level end
  function bar:GetFrameLevel() return 2 end
  function bar:SetMinMaxValues(minimum, maximum) self.ranges[#self.ranges + 1] = { minimum, maximum } end
  function bar:SetValue(value) self.values[#self.values + 1] = value end
  function bar:SetStatusBarColor(...) self.colors[#self.colors + 1] = { ... } end
  function bar:Show() self.shown = true end
  function bar:Hide() self.shown = false end
  return bar
end

local owner = { __unit = "player", cfg = { expbar = { show = true }, repbar = { show = true } }, events = {} }
function owner:RegisterEvent(event, callback, unitless)
  local expectedUnitless = event ~= "UNIT_ENTERED_VEHICLE" and event ~= "UNIT_EXITED_VEHICLE"
  expect((unitless == true) == expectedUnitless,
    "oUF public RegisterEvent unitless flag is incorrect for " .. event)
  self.events[event] = self.events[event] or {}
  self.events[event][#self.events[event] + 1] = { callback = callback, unitless = unitless == true }
end
function owner:UnregisterEvent(event) self.events[event] = nil end

owner.Experience = newStatusBar()
owner.Experience.Rested = newStatusBar()
owner.Reputation = newStatusBar()
owner.Reputation.colorStanding = true
expect(elements.Experience.enable(owner, "player") == true, "experience element did not enable")
expect(elements.Reputation.enable(owner, "player") == true, "reputation element did not enable")

local function fire(event, ...)
  local registrations = owner.events[event]
  expect(registrations ~= nil, "event not registered: " .. event)
  for _, registration in ipairs(registrations) do
    registration.callback(owner, event, ...)
  end
end

-- Unitless world entry carries booleans, yet both elements must initialize.
fire("PLAYER_ENTERING_WORLD", true, false)
expect(owner.Experience.__rothActive == true and owner.Reputation.__rothActive == true,
  "unitless world-entry booleans prevented XP/reputation initialization: " .. tostring(owner.Experience.__rothActive) .. ", " .. tostring(owner.Reputation.__rothActive))
expect(owner.Experience.values[#owner.Experience.values] == currentXP,
  "world entry did not populate current XP")
expect(owner.Reputation.values[#owner.Reputation.values] == 650,
  "world entry did not populate watched faction progress")
expect(owner.events.PLAYER_ENTERING_WORLD[1].unitless == true
    and owner.events.PLAYER_ENTERING_WORLD[2].unitless == true,
  "world-entry event was not registered as unitless")

local beforeValues = #owner.Experience.values
local restedUpdates = #owner.Experience.Rested.values
currentXP = 240
fire("PLAYER_LEVEL_UP", 21)
expect(#owner.Experience.values == beforeValues + 1 and owner.Experience.values[#owner.Experience.values] == 240,
  "numeric level-up payload prevented XP refresh")
expect(owner.events.PLAYER_LEVEL_UP[1].unitless == true,
  "level-up event was not registered as unitless")
expect(#owner.Experience.Rested.values == restedUpdates + 1
    and owner.Experience.Rested.values[#owner.Experience.Rested.values] == 320,
  "rested progress was not updated exactly once by the registered experience element")

queueCalls = 0
local xpValueCount = #owner.Experience.values
restedUpdates = #owner.Experience.Rested.values
currentXP = 315
fire("PLAYER_XP_UPDATE", "player")
expect(#owner.Experience.values == xpValueCount + 1 and owner.Experience.values[#owner.Experience.values] == 315,
  "ordinary XP event did not update data")
expect(#owner.Experience.Rested.values == restedUpdates + 1
    and owner.Experience.Rested.values[#owner.Experience.Rested.values] == 395,
  "rested progress was duplicated or omitted on an XP event")
expect(queueCalls == 0, "ordinary XP value update relaid out action-bar artwork")

local repValueCount = #owner.Reputation.values
watchedFaction = {
  factionID = 11, name = "The Test faction", currentReactionThreshold = 0,
  nextReactionThreshold = 3000, currentStanding = 740, reaction = 5,
}
fire("UPDATE_FACTION")
expect(#owner.Reputation.values == repValueCount + 1 and owner.Reputation.values[#owner.Reputation.values] == 740,
  "ordinary faction progress event did not update data")
expect(queueCalls == 0, "ordinary faction value update relaid out action-bar artwork")

-- Unit-bearing events with an unrelated unit are ignored before reading data.
local beforeWrongUnitXP, beforeWrongUnitRep = #owner.Experience.values, #owner.Reputation.values
fire("PLAYER_XP_UPDATE", "party1")
fire("UNIT_ENTERED_VEHICLE", "party1")
expect(#owner.Experience.values == beforeWrongUnitXP and #owner.Reputation.values == beforeWrongUnitRep,
  "other-unit event changed player data bar values")

-- A visibility transition is the event that requests an artwork layout update.
queueCalls = 0
maxPlayerLevel = playerLevel
fire("PLAYER_LEVEL_UP", playerLevel)
expect(owner.Experience.__rothActive == false and queueCalls == 1,
  "XP visibility transition did not request exactly one artwork refresh")

queueCalls = 0
watchedFaction = nil
fire("UPDATE_FACTION")
expect(owner.Reputation.__rothActive == false and queueCalls == 1,
  "reputation visibility transition did not request exactly one artwork refresh")

print("data bar callbacks and artwork ownership test: OK")
