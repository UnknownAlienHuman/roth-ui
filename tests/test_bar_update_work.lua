local function expect(condition, message)
  if not condition then error(message, 2) end
end

local vehicleUI = false
local accessDenied = {}
local secretValues = {}
_G.UnitHasVehicleUI = function() return vehicleUI end
local expCurrent, expMaximum, expRested = 123, 456, 80
_G.UnitXP = function() return expCurrent end
_G.UnitXPMax = function() return expMaximum end
_G.GetXPExhaustion = function() return expRested end
_G.GameTooltip = {
  lines = {},
  SetOwner = function() end,
  ClearLines = function(self) self.lines = {} end,
  AddLine = function(self, value) self.lines[#self.lines + 1] = value end,
  Show = function() end,
  Hide = function() end,
}

local function newTexture()
  local texture = { shown = true }
  function texture:SetTexture(value) self.texture = value end
  function texture:SetTexCoord(...) self.texCoord = { ... } end
  function texture:SetSize(width, height) self.width, self.height = width, height end
  function texture:SetPoint(...) self.point = { ... } end
  function texture:SetAllPoints(target) self.allPoints = target end
  function texture:SetVertexColor(...) self.color = { ... } end
  function texture:SetBlendMode(value) self.blend = value end
  function texture:SetAlpha(value) self.alpha = value end
  function texture:Hide() self.shown = false end
  function texture:Show() self.shown = true end
  return texture
end

local function newFrame(kind, name, parent)
  local frame = {
    kind = kind, name = name, parent = parent, shown = true,
    width = 0, height = 0, scale = 1, shownCalls = 0,
  }
  function frame:SetPoint(...) self.point = { ... } end
  function frame:SetAllPoints(target) self.allPoints = target end
  function frame:SetSize(width, height) self.width, self.height = width, height end
  function frame:SetWidth(width) self.width = width end
  function frame:SetHeight(height) self.height = height end
  function frame:SetScale(value) self.scale = value end
  function frame:SetFrameStrata(value) self.strata = value end
  function frame:SetFrameLevel(value) self.level = value end
  function frame:EnableMouse(value) self.mouseEnabled = value end
  function frame:SetScript(name, callback) self.scripts = self.scripts or {}; self.scripts[name] = callback end
  function frame:SetShown(value) self.shownCalls = self.shownCalls + 1; self.shown = value end
  function frame:Show() self.shown = true end
  function frame:Hide() self.shown = false end
  function frame:CreateTexture(name, layer, template, sublevel)
    local texture = newTexture()
    texture.layer, texture.sublevel = layer, sublevel
    self.textures = self.textures or {}
    self.textures[#self.textures + 1] = texture
    return texture
  end
  function frame:SetStatusBarTexture(texture) self.statusTexture = texture end
  function frame:SetMinMaxValues(minimum, maximum) self.range = { minimum, maximum } end
  function frame:SetValue(value) self.value = value end
  function frame:SetStatusBarColor(...) self.statusColor = { ... } end
  function frame:SetOrientation(value) self.orientation = value end
  function frame:SetAlpha(value) self.alpha = value end
  return frame
end
_G.CreateFrame = newFrame

local ns = {
  cfg = {},
  cfgDefaults = { units = { player = { expbar = {}, repbar = {} } } },
  func = {
    IsSecretValue = function() return false end,
    applyDragFunctionality = function() end,
  },
  safety = {
    IsSecret = function(value) return secretValues[value] == true end,
    CanAccess = function(value) return not accessDenied[value] end,
  },
}
assert(loadfile("core/bars.lua"))("Roth_UI", ns)
expect(type(ns.bars) == "table" and ns.bars.kind == nil,
  "bar constructors allocated a native frame for their namespace")

local unit = {
  cfg = {
    expbar = {
      pos = { a1 = "CENTER", af = _G.UIParent, a2 = "CENTER", x = 0, y = 0 },
      width = 365, height = 4, scale = 1, texture = "xp", show = true,
      color = { r = 1, g = 1, b = 1 }, rested = { color = { r = 0, g = 0.5, b = 1 } },
    },
    repbar = { height = 4 },
    combobar = {
      pos = { a1 = "CENTER", af = _G.UIParent, a2 = "CENTER", x = 0, y = 0 },
      scale = 1,
      color = { r = 1, g = 0.2, b = 0.1 },
      combat = { enable = false },
    },
    runes = {
      pos = { a1 = "CENTER", af = _G.UIParent, a2 = "CENTER", x = 0, y = 0 },
      scale = 1,
      combat = { enable = false },
    },
  },
}
ns.bars.createExpBar(unit)
local expTooltip = unit.Experience
accessDenied[expCurrent] = true
accessDenied[expMaximum] = true
accessDenied[expRested] = true
expTooltip.scripts.OnEnter(expTooltip)
expect(#GameTooltip.lines == 1 and GameTooltip.lines[1] == "Experience",
  "inaccessible-but-not-secret XP values were converted or rendered in the tooltip")
accessDenied[expCurrent], accessDenied[expMaximum], accessDenied[expRested] = nil, nil, nil
local secretXP, secretMaxXP, secretRested = "123", "456", "80"
secretValues[secretXP], secretValues[secretMaxXP], secretValues[secretRested] = true, true, true
_G.UnitXP = function() return secretXP end
_G.UnitXPMax = function() return secretMaxXP end
_G.GetXPExhaustion = function() return secretRested end
expTooltip.scripts.OnEnter(expTooltip)
expect(#GameTooltip.lines == 1 and GameTooltip.lines[1] == "Experience",
  "accessible-but-secret XP values were converted or rendered in the tooltip")
secretValues[secretXP], secretValues[secretMaxXP], secretValues[secretRested] = nil, nil, nil
_G.UnitXP = function() return expCurrent end
_G.UnitXPMax = function() return expMaximum end
_G.GetXPExhaustion = function() return expRested end

local function addConfig(key, x)
  unit.cfg[key] = {
    pos = { a1 = "TOP", af = _G.UIParent, a2 = "BOTTOM", x = x, y = -12 },
    scale = 1.25,
    color = { r = 0.2, g = 0.4, b = 0.6 },
    combat = { enable = false },
  }
end
addConfig("harmony", 11)
addConfig("holypower", 22)
addConfig("soulshards", 33)
addConfig("arcbar", 44)

ns.bars.createComboBar(unit)
local classPower = unit.ClassPower
local combo = unit.ComboBar
expect(combo.width == 768, "combo bar initial geometry changed")
classPower.PostUpdate(classPower, 0, 5, true, false, "COMBO_POINTS")
local setterCalls = 0
for index = 1, #unit.ComboPoints do
  local orb = unit.ComboPoints[index]
  setterCalls = setterCalls + orb.shownCalls
  expect(orb.shown == (index <= 5), "initial class-power visibility was not applied")
end
expect(setterCalls == 10, "first class-power update did not initialize each orb once")

classPower.PostUpdate(classPower, 1, 5, true, false, "COMBO_POINTS")
local repeatedCalls = 0
for index = 1, #unit.ComboPoints do repeatedCalls = repeatedCalls + unit.ComboPoints[index].shownCalls end
expect(repeatedCalls == setterCalls, "ordinary value update repeated unchanged orb visibility setters")

classPower.PostUpdate(classPower, 1, 6, true, true, "COMBO_POINTS")
local changedCalls = 0
for index = 1, #unit.ComboPoints do
  local orb = unit.ComboPoints[index]
  changedCalls = changedCalls + orb.shownCalls
  expect(orb.shown == (index <= 6), "changed class-power maximum did not update orb visibility")
end
expect(changedCalls == repeatedCalls + 10, "maximum change did not perform one bounded visibility pass")
expect(combo.width == 512, "maximum change did not resize the class-power bar")

accessDenied[6] = true
classPower.PostUpdate(classPower, 1, 6, true, true, "COMBO_POINTS")
expect(combo.width == 768, "inaccessible maximum did not fall back to the configured orb count")
accessDenied[6] = nil
secretValues[6] = true
classPower.PostUpdate(classPower, 1, 6, true, true, "COMBO_POINTS")
expect(combo.width == 768, "accessible-but-secret maximum was used for class-power layout")
secretValues[6] = nil
accessDenied[true] = true
classPower.PostUpdate(classPower, 1, 7, true, true, "COMBO_POINTS")
expect(combo.width == 768, "inaccessible hasMaxChanged flag was used for layout")
accessDenied[true] = nil

ns.bars.createRuneBar(unit)
local runes = unit.Runes
local runeBar = unit.RuneBar
runes.PostUpdate(runes)
expect(runeBar.shown and runeBar.shownCalls == 1, "first rune update did not set vehicle visibility")
runes.PostUpdate(runes)
expect(runeBar.shownCalls == 1, "steady-state rune update repeated the same visibility setter")
accessDenied[true] = true
vehicleUI = true
runes.PostUpdate(runes)
expect(runeBar.shownCalls == 1 and runeBar.shown,
  "inaccessible vehicle state was compared or used to change rune visibility")
accessDenied[true] = nil
vehicleUI = true
runes.PostUpdate(runes)
expect(not runeBar.shown and runeBar.shownCalls == 2, "vehicle transition did not hide rune bar")
runes.PostUpdate(runes)
expect(runeBar.shownCalls == 2, "steady vehicle state repeated the visibility setter")

local builders = {
  { method = "createHarmonyPowerBar", key = "harmony", bar = "HarmonyPowerBar", orbs = "Harmony", count = 6, scale = 0.85, visible = true, edgeOrbs = 2 },
  { method = "createHolyPowerBar", key = "holypower", bar = "HolyPowerBar", orbs = "HolyPower", count = 5, scale = 0.85, visible = false, edgeOrbs = 2 },
  { method = "createSoulShardPowerBar", key = "soulshards", bar = "SoulShardPowerBar", orbs = "SoulShards", count = 5, scale = 0.95, visible = false, edgeOrbs = 1 },
  { method = "createArcBar", key = "arcbar", bar = "ArcBar", orbs = "ACharges", count = 4, scale = 0.95, visible = false, edgeOrbs = 1 },
}
for _, expected in ipairs(builders) do
  ns.bars[expected.method](unit)
  local bar, orbs, config = unit[expected.bar], unit[expected.orbs], unit.cfg[expected.key]
  expect(bar.width == 64 * (expected.count + 2) and bar.height == 64, expected.key .. " bar size changed")
  expect(bar.point[1] == "TOP" and bar.point[2] == _G.UIParent and bar.point[4] == config.pos.x and bar.point[5] == -12,
    expected.key .. " configured anchor changed")
  expect(bar.scale == 1.25, expected.key .. " configured scale changed")
  expect(bar.shown == expected.visible, expected.key .. " initial visibility changed")
  expect(bar.orbSize == 64 and bar.edgeOrbs == expected.edgeOrbs, expected.key .. " native class-power sizing fields changed")
  expect(bar.leftEdge.texture == "Interface\\AddOns\\Roth_UI\\media\\combo_left", expected.key .. " left edge texture changed")
  expect(bar.leftEdge.layer == "BACKGROUND" and bar.leftEdge.sublevel == -8, expected.key .. " left edge draw layer changed")
  expect(bar.rightEdge.point[1] == "RIGHT", expected.key .. " right edge anchor changed")
  expect(#orbs == expected.count, expected.key .. " pip count changed")
  expect(unit.ClassPower and unit.ClassPower.__bar == bar, expected.key .. " did not attach the native ClassPower element")
  for index, orb in ipairs(orbs) do
    expect(orb.width == 64 and orb.height == 64 and orb.point[1] == "LEFT" and orb.point[2] == index * 64,
      expected.key .. " pip position changed at index " .. index)
    expect(orb.bg.width == 64 * expected.scale and orb.fill.width == 64 * expected.scale,
      expected.key .. " pip background or fill size changed")
    expect(orb.fill.range[1] == 0 and orb.fill.range[2] == 1 and orb.fill.value == 0,
      expected.key .. " fill range initialization changed")
    expect(orb.border.layer == "BACKGROUND" and orb.border.sublevel == -5,
      expected.key .. " pip border draw layer changed")
  end
end
expect(unit.SoulShards[1].bg.texture:match("combo_gem_bg$"), "soul-shard gem background changed")
expect(unit.SoulShards[1].fill.statusTexture.texture:match("combo_gem_fill1$"), "soul-shard fill texture changed")
expect(unit.SoulShards[1].glow.texture:match("combo_gem_glow$"), "soul-shard glow texture changed")
expect(unit.ACharges[1].fill.statusTexture.texture == [[Interface\PLAYERFRAME\MageArcaneCharges]], "arcane fill texture changed")
expect(table.concat(unit.ACharges[1].fill.statusTexture.texCoord, ",") == "0.25,0.375,0.5,0.75", "arcane fill texture coordinates changed")
expect(unit.ACharges[1].glow == nil and unit.ArcBar.colorize == false, "arcane charges gained class-power glow/colorization")
expect(not unit.RuneBar.shown and unit.RuneBar.width == 512 and unit.RuneBar.color == nil, "rune bar native fields changed")
expect(unit.RuneOrbs[1].bg.width == 108.8 and unit.RuneOrbs[1].border.width == 108.8,
  "rune oversized background/decorations changed")
expect(unit.RuneOrbs[1].fill.orientation == "VERTICAL" and unit.RuneOrbs[1].glow.shown == false,
  "rune fill orientation or initial glow visibility changed")
secretValues[true] = true
runes.PostUpdate(runes)
expect(runeBar.shown and runeBar.shownCalls == 3,
  "accessible-but-secret vehicle state hid the rune bar")
secretValues[true] = nil

print("resource-bar update work test: OK")
