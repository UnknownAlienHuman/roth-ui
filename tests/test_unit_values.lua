local function expect(condition, message)
  if not condition then error(message, 2) end
end

-- Lua 5.1 sentinels verify routing only. They cannot reproduce WoW's native
-- Secret Value enforcement or prove that FontString sinks are allowed in-game.
local inaccessible = {}
local secretText = {}
local secretPercent = {}
local connected = true
local dead = false
local healthPercent
local powerPercent

_G.issecretvalue = function(value)
  return value == secretText or value == secretPercent
end
_G.canaccessvalue = function(value)
  return value ~= inaccessible
end
_G.UnitIsTapDenied = function() return false end
_G.UnitIsDeadOrGhost = function() return dead end
_G.UnitIsConnected = function() return connected end
_G.UnitIsPlayer = function() return false end
_G.UnitReaction = function() return 5 end
_G.UnitClass = function() return "Warrior", "WARRIOR" end
_G.UnitGUID = function() return nil end
_G.UnitPowerType = function() return 0, "MANA" end
_G.UnitHealthPercent = function() return healthPercent end
_G.UnitPowerPercent = function() return powerPercent end
_G.PLAYER_OFFLINE = "OFFLINE"
_G.DEAD = "DEAD"
_G.RAID_CLASS_COLORS = {}
_G.FACTION_BAR_COLORS = { [5] = { r = 1, g = 1, b = 1 } }
_G.PowerBarColor = { MANA = { r = 0, g = 0, b = 1 } }

local formatCalls = 0
local ns = {
  func = {
    IsSecretValue = function(value) return _G.issecretvalue(value) end,
    numFormat = function(value)
      formatCalls = formatCalls + 1
      expect(type(value) == "number", "non-number reached the numeric formatter")
      return tostring(value)
    end,
  },
  cfg = {
    colorswitcher = {
      classcolored = false,
      bright = { r = 1, g = 0, b = 0, a = 1 },
      dark = { r = 0, g = 0, b = 0, a = 0.1 },
      useBrightForeground = true,
    },
  },
  safety = {},
}
assert(loadfile("core/safety.lua"))("Roth_UI", ns)
assert(loadfile("core/unit_value_runtime.lua"))("Roth_UI", ns)

local function NewTextSink()
  local sink = { writes = {}, formatted = {} }
  function sink:SetText(value) self.writes[#self.writes + 1] = value end
  function sink:SetFormattedText(format, value)
    self.formatted[#self.formatted + 1] = { format = format, value = value }
  end
  return sink
end

local function NewBar(valueMode)
  return {
    valueTextMode = valueMode or "curmax",
    valueText = NewTextSink(),
    perText = NewTextSink(),
    SetStatusBarColor = function() end,
  }
end

local inaccessibleSink = NewTextSink()
ns.func.SafeSetText(inaccessibleSink, inaccessible)
expect(#inaccessibleSink.writes == 1 and inaccessibleSink.writes[1] == "",
  "inaccessible non-secret text was not cleared")

local offlineBar = NewBar("curmax")
connected = false
dead = false
healthPercent = 45
ns.func.updateHealth(offlineBar, "target", 45, nil, 100)
expect(offlineBar.valueText.writes[#offlineBar.valueText.writes] == "OFFLINE",
  "disconnected unit did not show the offline label")

local deadBar = NewBar("curmax")
connected = true
dead = true
healthPercent = 0
ns.func.updateHealth(deadBar, "target", 0, nil, 100)
expect(deadBar.valueText.writes[#deadBar.valueText.writes] == "DEAD",
  "dead unit did not show the dead label")

dead = false
local healthBar = NewBar("curmax")
healthPercent = 25
ns.func.updateHealth(healthBar, "target", 25, nil, 100)
expect(healthBar.valueText.writes[#healthBar.valueText.writes] == "25 / 100",
  "ordinary health current/max values did not format")

local powerBar = NewBar("curmax")
powerPercent = 40
ns.func.updatePower(powerBar, "target", 40, nil, 100)
expect(powerBar.valueText.writes[#powerBar.valueText.writes] == "40 / 100",
  "ordinary power current/max values did not format")

local inaccessibleHealthBar = NewBar("curmax")
healthPercent = inaccessible
local beforeFormats = formatCalls
ns.func.updateHealth(inaccessibleHealthBar, "target", inaccessible, nil, 100)
expect(formatCalls == beforeFormats, "inaccessible health value reached Lua formatting")
expect(inaccessibleHealthBar.valueText.writes[#inaccessibleHealthBar.valueText.writes] == "",
  "inaccessible health text was not cleared")

local inaccessiblePowerBar = NewBar("curmax")
powerPercent = inaccessible
beforeFormats = formatCalls
ns.func.updatePower(inaccessiblePowerBar, "target", inaccessible, nil, 100)
expect(formatCalls == beforeFormats, "inaccessible power value reached Lua formatting")
expect(inaccessiblePowerBar.valueText.writes[#inaccessiblePowerBar.valueText.writes] == "",
  "inaccessible power text was not cleared")

local secretTextBar = NewBar("curmax")
healthPercent = nil
ns.func.updateHealth(secretTextBar, "target", secretText, nil, 100)
expect(secretTextBar.valueText.writes[#secretTextBar.valueText.writes] == secretText,
  "secret current value did not reach the native SetText sink")

local secretPercentBar = NewBar("percent")
healthPercent = secretPercent
ns.func.updateHealth(secretPercentBar, "target", 5, nil, 10)
local formatted = secretPercentBar.valueText.formatted[#secretPercentBar.valueText.formatted]
expect(formatted and formatted.format == "%.0f%%" and formatted.value == secretPercent,
  "secret percent did not reach the native SetFormattedText sink")

expect(ns.func.CoerceAccessibleNumber("not numeric") == nil,
  "failed ordinary numeric conversion did not return nil")
local ok, convertedSecret = pcall(ns.func.CoerceAccessibleNumber, secretText)
expect(ok and convertedSecret == nil, "secret numeric conversion was attempted or returned a Lua value")

print("unit value access-boundary and display test: OK")
