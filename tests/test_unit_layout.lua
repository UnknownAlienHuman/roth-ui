local function fail(message)
  error(message, 2)
end

local function expect(condition, message)
  if not condition then fail(message) end
end

local function same(actual, expected, message)
  expect(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function newRegion(kind, parent)
  local region = { kind = kind, parent = parent, points = {}, textures = {}, children = {} }
  function region:SetPoint(...)
    self.points[#self.points + 1] = { ... }
  end
  function region:ClearAllPoints() self.points = {} end
  function region:SetAllPoints(target) self.allPoints = target or self.parent end
  function region:SetTexture(texture) self.texture = texture end
  function region:SetVertexColor(...) self.vertexColor = { ... } end
  function region:SetFrameStrata(value) self.frameStrata = value end
  function region:SetFrameLevel(value) self.frameLevel = value end
  function region:SetSize(width, height) self.width, self.height = width, height end
  function region:SetScale(value) self.scale = value end
  function region:SetStatusBarTexture(texture) self.statusBarTexture = texture end
  function region:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
  function region:SetValue(value) self.value = value end
  function region:SetOrientation(value) self.orientation = value end
  function region:SetJustifyH(value) self.justifyH = value end
  function region:SetScript(name, callback) self.scripts = self.scripts or {}; self.scripts[name] = callback end
  function region:HookScript(name, callback) self.hooks = self.hooks or {}; self.hooks[name] = callback end
  function region:RegisterForClicks(...) self.clicks = { ... } end
  function region:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
  function region:UnregisterEvent(event) if self.events then self.events[event] = nil end end
  function region:SetHitRectInsets(...) self.hitInsets = { ... } end
  function region:EnableMouse(value) self.mouseEnabled = value end
  function region:SetShown(value) self.shown = value end
  function region:Show() self.shown = true end
  function region:Hide() self.shown = false end
  function region:Tag(fontString, tag) fontString.tag = tag end
  function region:CreateTexture(name, layer, template, sublevel)
    local texture = newRegion("Texture", self)
    texture.name, texture.layer, texture.sublevel = name, layer, sublevel
    self.textures[#self.textures + 1] = texture
    self.children[#self.children + 1] = texture
    return texture
  end
  function region:CreateFontString()
    local fontString = newRegion("FontString", self)
    self.children[#self.children + 1] = fontString
    return fontString
  end
  return region
end

_G.CreateFrame = function(kind, name, parent)
  local frame = newRegion(kind, parent)
  frame.name = name
  return frame
end
_G.UnitFrame_OnEnter = function() end
_G.UnitFrame_OnLeave = function() end
local inCombat = false
_G.InCombatLockdown = function() return inCombat end
_G.MAX_BOSS_FRAMES = 1
_G.format = string.format
_G.floor = math.floor
_G.mod = math.mod
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end end
_G.tinsert = table.insert
_G.tremove = table.remove

local cfg = {
  font = "test-font",
  units = {},
  playerclass = "PRIEST",
}
local unitFrames = {}
local styleCallbacks = {}
local deferredWork = {}
local oUF = {
  colors = {},
  Tags = { Methods = {} },
}
function oUF:RegisterStyle(name, callback) styleCallbacks[name] = callback end
function oUF:SetActiveStyle(name) self.activeStyle = name end
function oUF:Spawn(unit, name)
  local frame = newRegion("Frame", _G.UIParent)
  frame.name, frame.unit = name, unit
  styleCallbacks[self.activeStyle](frame)
  unitFrames[unit] = frame
  return frame
end
function oUF:SpawnHeader(name)
  local header = newRegion("Frame", _G.UIParent)
  header.name = name
  styleCallbacks[self.activeStyle](header)
  return header
end

local ns = {
  cfg = cfg,
  unit = {},
  oUF = oUF,
  safety = { IsSecret = function() return false end },
  IsRothEnabled = function(value) return value ~= false end,
  GetUnitConfig = function(name) return cfg.units[name] end,
  frameRegistry = { Register = function() end },
  GroupHeaderVisibility = {
    Apply = function() end,
    ApplyDesired = function() end,
    Hide = function() end,
  },
  framePolicy = {
    DeferUntilOutOfCombat = function(key, callback)
      if not inCombat then return false end
      deferredWork[key] = callback
      return true
    end,
    DeferForObject = function(scope, object, callback)
      if not inCombat then return false end
      deferredWork[scope .. ":" .. tostring(object)] = callback
      return true
    end,
  },
}
local function noop() end
local func = {
  ResolveStatusBarSmoothing = function(value) return value == false and "immediate" or "smooth" end,
  ResolveHealthValueMode = function() return "cur" end,
  createFontString = function(parent, font, size, flags)
    local value = newRegion("FontString", parent)
    value.font, value.fontSize, value.fontFlags = font, size, flags
    return value
  end,
  applyDragFunctionality = noop,
  updateHealth = noop,
  updatePower = noop,
  ShouldShowPortrait = function(frame) return frame.cfg.portrait.show == true end,
  createPortrait = function(frame)
    frame.PortraitHolder = newRegion("Frame", frame)
    frame.Portrait = newRegion("Texture", frame.PortraitHolder)
  end,
  createCastbar = function(frame) frame.Castbar = newRegion("StatusBar", frame) end,
  QueueStandardAuras = noop,
  QueueHealerAuraWatch = noop,
  QueueRaidAuras = noop,
  QueueTargetAuras = noop,
  createDebuffGlow = noop,
  ConfigureGroupRange = noop,
  createIcon = function(parent)
    return newRegion("Texture", parent)
  end,
  healPrediction = noop,
  totalAbsorb = noop,
  checkThreat = noop,
  createAlternativePowerBar = noop,
  createStandAlonePortrait = noop,
}
ns.func = func

assert(loadfile("units/mini_target_scaffold.lua"))("Roth_UI", ns)
local sharedBuilder = func.buildMiniTargetScaffold
expect(type(sharedBuilder) == "function", "shared mini layout builder did not load")

local function makeConfig(name)
  local config = {
    show = true,
    width = 120,
    height = 64,
    scale = 1,
    pos = { a1 = "CENTER", af = _G.UIParent, a2 = "CENTER", x = 0, y = 0 },
    health = { texture = name .. "-health", smooth = true },
    power = { texture = name .. "-power", smooth = false },
    portrait = { show = name == "pet" or name == "focus" or name == "pettarget", use3D = false, width = 128 },
    castbar = { show = name == "pet" or name == "focus", hideDefault = false },
    auras = { showBuffs = true },
    altpower = { show = false },
    special = { chains = false },
    misc = { NameFontSize = 11, classFontSize = 10 },
    healthValueMode = "cur",
    health = { texture = name .. "-health", smooth = true, fontSize = 11, point = "RIGHT", x = -2, y = 0 },
    healper = { fontSize = 11, point = "CENTER", x = 0, y = 0 },
    power = { texture = name .. "-power", smooth = false, fontSize = 9, point = "RIGHT", x = -2, y = 0 },
    powper = { fontSize = 9, point = "CENTER", x = 0, y = 0 },
  }
  return config
end

for _, name in ipairs({ "pet", "targettarget", "pettarget", "focustarget", "focus", "boss" }) do
  cfg.units[name] = makeConfig(name)
end
cfg.units.boss.castbar.show = false
cfg.units.targettarget.portrait.show = false
cfg.units.pettarget.portrait.show = true
cfg.units.party = makeConfig("party")
cfg.units.party.vertical = false
cfg.units.party.portrait.show = true
cfg.units.party.attributes = {
  showPlayer = true,
  showSolo = true,
  showRaid = true,
  HorizontalPoint = "TOPLEFT",
  VerticalPoint = "TOPLEFT",
  visibility = "show",
}
cfg.units.party.width, cfg.units.party.height = 120, 64
cfg.units.party.vertwidth, cfg.units.party.vertheight = 64, 120

for _, module in ipairs({ "units/pet.lua", "units/targettarget.lua", "units/pettarget.lua", "units/focustarget.lua", "units/focus.lua", "units/boss.lua" }) do
  assert(loadfile(module))("Roth_UI", ns)
end

local expectedUnits = { "pet", "targettarget", "pettarget", "focustarget", "focus", "boss1" }
for _, unit in ipairs(expectedUnits) do
  local frame = unitFrames[unit]
  expect(frame ~= nil, unit .. " frame was not spawned")
  expect(frame.Health and frame.Power, unit .. " did not receive shared health and power elements")
  same(frame.Health.statusBarTexture, frame.cfg.health.texture, unit .. " health texture")
  same(frame.Power.statusBarTexture, frame.cfg.power.texture, unit .. " power texture")
  same(frame.Health.PostUpdate, func.updateHealth, unit .. " health PostUpdate")
  same(frame.Power.PostUpdate, func.updatePower, unit .. " power PostUpdate")
  expect(frame.Name and frame.Name.tag == "[roth:namecolor][name<$|r]", unit .. " name tag missing")
end

local targetTarget = unitFrames.targettarget
same(targetTarget.textures[1].layer, "BORDER", "targettarget artwork draw layer")
same(targetTarget.textures[1].sublevel, -8, "targettarget artwork sublevel")
same(targetTarget.textures[1].texture, "Interface\\AddOns\\Roth_UI\\media\\targettarget",
  "targettarget artwork texture")
same(targetTarget.Health.points[1][1], "TOP", "targettarget health top anchor")
same(targetTarget.Health.points[1][5], -29, "targettarget health top offset")
same(targetTarget.Health.glow.points[1][5], -33, "targettarget glow top offset")
same(targetTarget.Health.highlight.allPoints, targetTarget.Health.glow, "targettarget highlight relative frame")
same(targetTarget.Name.fontSize, 11, "targettarget name font size")
same(targetTarget.Health.valueText.fontSize, 8, "targettarget health font size")
same(targetTarget.Health.valueText.justifyH, "RIGHT", "targettarget health alignment")
same(targetTarget.Power.parent, targetTarget.Health, "targettarget power parent")
same(targetTarget.Power.points[1][5], -12, "targettarget power top offset")
same(targetTarget.Health.frameStrata, "BACKGROUND", "targettarget health strata")

local petTarget = unitFrames.pettarget
same(petTarget.Power.parent, petTarget, "pettarget power parent")
same(petTarget.Power.points[1][5], -38.5, "pettarget power top offset")
same(unitFrames.pet.Health.frameStrata, "LOW", "pet health strata")
same(unitFrames.pet.Power.smoothing, "immediate", "pet power smoothing")
expect(petTarget.PortraitHolder ~= nil, "pettarget optional portrait was not retained")
expect(unitFrames.pet.Castbar ~= nil, "pet castbar callback was not retained")
expect(unitFrames.focus.Castbar ~= nil, "focus castbar callback was not retained")
expect(unitFrames.boss1.Castbar == nil, "boss castbar should stay disabled by its config")

-- Party portrait geometry deferred from combat must use the shared policy queue,
-- with no per-portrait PLAYER_REGEN_ENABLED event owner.
assert(loadfile("units/party.lua"))("Roth_UI", ns)
local partyStyle = assert(styleCallbacks["diablo:party"], "party style was not registered")
local combatPartyChild = newRegion("Frame", _G.UIParent)
inCombat = true
partyStyle(combatPartyChild)
expect(combatPartyChild.PortraitHolder ~= nil, "party portrait setup did not run")
expect(not (combatPartyChild.PortraitHolder.events and combatPartyChild.PortraitHolder.events.PLAYER_REGEN_ENABLED),
  "party portrait registered a private regen event")
local partyDeferred
for key, callback in pairs(deferredWork) do
  if key:find("party%-portrait%-hitrect:") then partyDeferred = callback end
end
expect(type(partyDeferred) == "function", "party portrait hit rect did not use the shared policy queue")
inCombat = false
partyDeferred()
same(combatPartyChild.hitInsets[3], 0, "party portrait deferred top hit inset")
same(combatPartyChild.hitInsets[4], 0, "party portrait deferred bottom hit inset")

-- Target visual regression: the empty health track retains its configured
-- texture, and the target-only glow covers the target frame.
local targetCfg = makeConfig("target")
targetCfg.portrait.show = false
targetCfg.castbar.show = false
cfg.units.target = targetCfg
func.createIcon = function(parent) return newRegion("Texture", parent) end
local targetFrame
function oUF:Spawn(unit, name)
  local frame = newRegion("Frame", _G.UIParent)
  frame.name, frame.unit = name, unit
  styleCallbacks[self.activeStyle](frame)
  targetFrame = frame
  unitFrames[unit] = frame
  return frame
end
assert(loadfile("units/target.lua"))("Roth_UI", ns)
same(targetFrame.Health.bg.texture, targetCfg.health.texture, "target health background texture")
same(targetFrame.Health.glow.allPoints, targetFrame, "target health glow anchor")

-- oUF Health:ForceUpdate dispatches the element update path and PostUpdate.
-- The runtime must use that callback once, without manually invoking it again.
local refreshCallback
local healthFill = { ForceUpdate = function() refreshCallback() end, PostUpdate = function() fail("orb PostUpdate duplicated after ForceUpdate") end }
ns.HealthOrb = { fill = healthFill }
ns.store = { GetOrbConfig = function() return nil end }
assert(loadfile("core/orb_runtime.lua"))("Roth_UI", ns)
-- Resolve the internal frame through the public refresh entrypoint's test hook.
-- ForceOrbValueRefresh only needs the fill and must not call the callback twice.
local postUpdates = 0
refreshCallback = function() postUpdates = postUpdates + 1 end
ns.ForceOrbValueRefresh("HEALTH")
same(postUpdates, 1, "orb ForceUpdate callback count")

print("unit shared layout and runtime regressions: OK")
