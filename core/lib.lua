--get the addon namespace
local addon, ns = ...

--get oUF namespace (just in case needed)
local oUF = ns.oUF or _G["oUF"]
local LSM = LibStub("LibSharedMedia-3.0")
local frameRegistry = assert(ns and ns.frameRegistry, "Roth_UI: frameRegistry is required by lib.lua")

--get the config
local cfg = ns.cfg
local mediapath = ns.mediapath or "Interface\\AddOns\\Roth_UI\\media\\"
local type = type
local pairs = pairs
local ipairs = ipairs
local next = next
local select = select
local tostring = tostring
local tonumber = tonumber

local format = format
local floor = floor
local mod = mod
local wipe = wipe
local tinsert = table.insert or tinsert
local tremove = table.remove or tremove
local pcall = pcall
local InCombatLockdown = InCombatLockdown
local CreateFrame = CreateFrame
local GetTime = GetTime
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsConnected = UnitIsConnected
local UnitInRange = UnitInRange
local UnitClass = UnitClass
local UnitName = UnitName
local UnitGUID = UnitGUID
local UnitIsPlayer = UnitIsPlayer
local UnitReaction = UnitReaction
local GetPlayerInfoByGUID = GetPlayerInfoByGUID

--object container
local func = CreateFrame("Frame")
ns.func = func
RothUI = {}

---------------------------------------------
-- MAINLINE HELPERS
---------------------------------------------

local safety = ns and ns.safety
ns.IsAddOnLoadedCompat = C_AddOns.IsAddOnLoaded
local DebuffTypeColor = _G["DebuffTypeColor"]
local CreateSecondsFormatter = _G["CreateSecondsFormatter"]

if _G and not _G.IsAddOnLoadedCompat then
  _G.IsAddOnLoadedCompat = ns.IsAddOnLoadedCompat
end

-- Centralized Secret Value handling (WoW 12.x/Midnight).
-- Hot paths should call the native predicate directly; safety.IsSecret keeps
-- pcall guards for non-hot serialization/sanitization code.
local _nativeIsSecret = _G["issecretvalue"] or _G["IsSecretValue"]
local _issecretvalue = (type(_nativeIsSecret) == "function" and _nativeIsSecret) or (safety and safety.IsSecret)
func.IsSecretValue = function(v)
  return _issecretvalue and _issecretvalue(v) or false
end
local IsSecretValue = func.IsSecretValue

func.SafeUnitHealth = function(unit)
  local v = UnitHealth(unit)
  if func.IsSecretValue(v) then return nil end
  return v
end

func.SafeUnitHealthMax = function(unit)
  local v = UnitHealthMax(unit)
  if func.IsSecretValue(v) then return nil end
  return v
end

func.SafeUnitPower = function(unit, powerType)
  local pType = powerType or UnitPowerType(unit)
  if func.IsSecretValue(pType) then return nil end
  local v = UnitPower(unit, pType)
  if func.IsSecretValue(v) then return nil end
  return v
end

func.SafeUnitPowerMax = function(unit, powerType)
  local pType = powerType or UnitPowerType(unit)
  if func.IsSecretValue(pType) then return nil end
  local v = UnitPowerMax(unit, pType)
  if func.IsSecretValue(v) then return nil end
  return v
end

---------------------------------------------
-- VARIABLES
---------------------------------------------

---------------------------------------------
-- FUNCTIONS
---------------------------------------------

-- Numeric formatting runtime moved to core/unit_misc_runtime.lua.

local VALID_HEALTH_VALUE_MODES = {
  cur = true,
  max = true,
  curmax = true,
  percent = true,
  curpercent = true,
}

local function ResolveUnitStyle(frame)
  if type(frame) ~= "table" then
    return nil
  end

  local style = frame.__style
  if type(style) == "string" and style ~= "" then
    return style
  end

  local unitCfg = frame.cfg
  style = unitCfg and unitCfg.style
  if type(style) == "string" and style ~= "" then
    return style
  end

  return nil
end

func.GetUnitStyle = ResolveUnitStyle

func.GetUnitRenderWidth = function(frame)
  local width = tonumber(frame and frame.__renderWidth)
  if width and width > 0 then
    return width
  end

  local unitCfg = frame and frame.cfg
  width = tonumber(unitCfg and unitCfg.width)
  if width and width > 0 then
    return width
  end

  return 0
end

func.GetUnitRenderHeight = function(frame)
  local height = tonumber(frame and frame.__renderHeight)
  if height and height > 0 then
    return height
  end

  local unitCfg = frame and frame.cfg
  height = tonumber(unitCfg and unitCfg.height)
  if height and height > 0 then
    return height
  end

  return 0
end

func.ShouldShowPortrait = function(frame)
  local style = ResolveUnitStyle(frame)
  if style == "party" then
    return true
  end

  local portrait = frame and frame.cfg and frame.cfg.portrait
  return type(portrait) == "table" and portrait.show == true
end

func.ResolveHealthValueMode = function()
  local mode = ns.cfg and ns.cfg.healthValueMode or nil
  if type(mode) == "string" and VALID_HEALTH_VALUE_MODES[mode] then
    return mode
  end
  return "cur"
end

local function RefreshUnitHealthBar(frame)
  if not (type(frame) == "table" and frame.Health) then
    return
  end

  frame.Health.valueTextMode = func.ResolveHealthValueMode()

  if type(frame.Health.ForceUpdate) == "function" then
    frame.Health:ForceUpdate()
    return
  end

  local unitId = frame.unit
  local postUpdate = frame.Health.PostUpdate
  if type(unitId) ~= "string" or unitId == "" or type(postUpdate) ~= "function" then
    return
  end

  postUpdate(frame.Health, unitId, UnitHealth(unitId), UnitHealthMax(unitId))
end

function ns.RefreshUnitHealthValueText(unitKey)
  local unitFrames = ns and ns.unit
  if type(unitFrames) ~= "table" then
    return
  end

  if unitKey == "party" then
    local header = ns.partyHeader
    if not (header and header.GetChildren) then
      return
    end
    local children = { header:GetChildren() }
    for i = 1, #children do
      RefreshUnitHealthBar(children[i])
    end
    return
  end

  if unitKey == "boss" then
    local bosses = unitFrames.boss
    if type(bosses) ~= "table" then
      return
    end
    for i = 1, #bosses do
      RefreshUnitHealthBar(bosses[i])
    end
    return
  end

  if unitKey == "raid" then
    local raidGroups = ns.raidGroups
    if type(raidGroups) ~= "table" then
      return
    end
    for _, header in pairs(raidGroups) do
      if header and header.GetChildren then
        local children = { header:GetChildren() }
        for i = 1, #children do
          RefreshUnitHealthBar(children[i])
        end
      end
    end
    return
  end

  RefreshUnitHealthBar(unitFrames[unitKey])
end

-- Обновить health text mode на всех юнит-фреймах (глобальная настройка)
function ns.RefreshAllHealthValueText()
  local SMALL_UNITS = { "target", "focus", "pet", "targettarget", "pettarget", "focustarget" }
  for _, key in ipairs(SMALL_UNITS) do
    ns.RefreshUnitHealthValueText(key)
  end
  ns.RefreshUnitHealthValueText("party")
  ns.RefreshUnitHealthValueText("boss")
  ns.RefreshUnitHealthValueText("raid")
end

--format time func
func.GetFormattedTime = function(time)
  local hr, m, s, text
  if time <= 0 then
    text = ""
  elseif (time < 3600 and time > 60) then
    hr = floor(time / 3600)
    m = floor(mod(time, 3600) / 60 + 1)
    text = format("%dm", m)
  elseif time < 60 then
    m = floor(time / 60)
    s = mod(time, 60)
    text = (m == 0 and format("%ds", s))
  else
    hr = floor(time / 3600 + 1)
    text = format("%dh", hr)
  end
  return text
end

local auraDurationFormatter = CreateSecondsFormatter and CreateSecondsFormatter() or nil

local function TryFormatAuraDuration(value)
  if auraDurationFormatter and auraDurationFormatter.Format then
    local text = auraDurationFormatter:Format(value)
    if text and text ~= "" and text ~= "0" and text ~= "0s" and text ~= "0.0" and text ~= "0.0s" then
      return text
    end
  end
  return nil
end

local function FormatAuraDurationValue(value)
  if value == nil then
    return ""
  end

  local formatted = TryFormatAuraDuration(value)
  if formatted then
    return formatted
  end

  if type(value) == "table" or type(value) == "userdata" then
    if type(value.GetRemainingDuration) == "function" then
      return FormatAuraDurationValue(value:GetRemainingDuration())
    end
    if type(value.GetValue) == "function" then
      return FormatAuraDurationValue(value:GetValue())
    end
    return ""
  end

  if IsSecretValue(value) or type(value) ~= "number" or value <= 0 then
    return ""
  end

  if value >= 60 then
    return func.GetFormattedTime(value)
  end

  if value >= 10 then
    return format("%.0f", value)
  end

  return format("%.1f", value)
end

local function EnsureAuraButtonLayout(element, button)
  if not (element and button and button.Icon and button.Count and button.Cooldown) then
    return
  end

  local size = element.size or button:GetWidth() or 20
  if button.__rothAuraStyledSize == size then
    return
  end
  button.__rothAuraStyledSize = size

  button.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

  button.Cooldown:ClearAllPoints()
  button.Cooldown:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
  button.Cooldown:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
  if button.Cooldown.SetReverse then
    button.Cooldown:SetReverse(true)
  end
  if button.Cooldown.SetDrawEdge then
    button.Cooldown:SetDrawEdge(false)
  end
  if button.Cooldown.SetHideCountdownNumbers then
    button.Cooldown:SetHideCountdownNumbers(true)
  end

  if not button.countFrame then
    button.countFrame = CreateFrame("Frame", nil, button)
    button.countFrame:SetAllPoints()
    button.countFrame:SetFrameStrata("MEDIUM")
    button.countFrame:SetFrameLevel(button.Cooldown:GetFrameLevel() + 2)
    button.Count:SetParent(button.countFrame)
  end

  button.Count:ClearAllPoints()
  button.Count:SetPoint("TOPRIGHT", button.countFrame, "TOPRIGHT", 4, 4)
  button.Count:SetTextColor(0.9, 0.9, 0.9)
  if func.RegisterFontString then
    func.RegisterFontString(button.Count, size / 1.8, "THINOUTLINE")
  else
    button.Count:SetFont(cfg.font, size / 1.8, "THINOUTLINE")
  end

  if not button.Border then
    local border = button:CreateTexture(nil, "OVERLAY", nil, 4)
    border:SetAllPoints()
    border:SetTexture(mediapath .. "icon_border")
    button.Border = border
    button.border = border
  end
  button.Border:SetVertexColor(0, 0, 0, 0.85)

  if not button.Gloss then
    local gloss = button:CreateTexture(nil, "ARTWORK", nil, -1)
    gloss:SetPoint("TOPLEFT", button.Icon, "TOPLEFT", -1, 1)
    gloss:SetPoint("BOTTOMRIGHT", button.Icon, "BOTTOMRIGHT", 1, -1)
    gloss:SetTexture(mediapath .. "gloss2")
    gloss:SetVertexColor(0.4, 0.35, 0.35, 1)
    button.Gloss = gloss
  end

  if not button.BackdropGlow then
    local back = button:CreateTexture(nil, "BACKGROUND", nil, 0)
    back:SetTexture(mediapath .. "simplesquare_glow")
    back:SetVertexColor(0, 0, 0, 1)
    button.BackdropGlow = back
  end
  button.BackdropGlow:ClearAllPoints()
  button.BackdropGlow:SetPoint("TOPLEFT", button.Icon, "TOPLEFT", -0.18 * size, 0.18 * size)
  button.BackdropGlow:SetPoint("BOTTOMRIGHT", button.Icon, "BOTTOMRIGHT", 0.18 * size, -0.18 * size)

  local duration = button.DurationText
  if not duration then
    local durationSize = math.max(7, math.floor(size * 0.28) - 2)
    duration = func.createFontString(button, cfg.font, durationSize, "THINOUTLINE")
    duration:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -1, 1)
    duration:SetJustifyH("LEFT")
    duration:SetJustifyV("BOTTOM")
    button.DurationText = duration
    button.duration = duration
  else
    local durationSize = math.max(7, math.floor(size * 0.28) - 2)
    if func.RegisterFontString then
      func.RegisterFontString(duration, durationSize, "THINOUTLINE")
    else
      duration:SetFont(cfg.font, durationSize, "THINOUTLINE")
    end
  end
end

local function ResolveAuraRemaining(button)
  if not button then
    return nil
  end

  local durationObject = button.__rothDurationObject
  if durationObject ~= nil then
    if type(durationObject.GetRemainingDuration) == "function" then
      return durationObject:GetRemainingDuration()
    end
    if type(durationObject.GetValue) == "function" then
      return durationObject:GetValue()
    end
    return durationObject
  end

  local expirationTime = button.__rothExpirationTime
  if type(expirationTime) == "number" then
    local remaining = expirationTime - GetTime()
    if remaining < 0 then
      remaining = 0
    end
    return remaining
  end

  return nil
end

local function UpdateAuraDurationText(button)
  local duration = button and button.DurationText
  if not duration then
    return
  end

  local text = FormatAuraDurationValue(ResolveAuraRemaining(button))
  if button.__rothDurationText ~= text then
    button.__rothDurationText = text
    duration:SetText(text)
  end
end

local function AuraDurationOnUpdate(button, elapsed)
  button.__rothDurationElapsed = (button.__rothDurationElapsed or 0) + (elapsed or 0)
  if button.__rothDurationElapsed < 0.1 then
    return
  end

  button.__rothDurationElapsed = 0
  UpdateAuraDurationText(button)

  if (button.__rothDurationText == nil or button.__rothDurationText == "")
      and button.__rothDurationObject == nil
      and button.__rothExpirationTime == nil then
    button:SetScript("OnUpdate", nil)
  end
end

local function ClearAuraDurationState(button)
  if not button then
    return
  end

  button.__rothDurationObject = nil
  button.__rothExpirationTime = nil
  button.__rothDurationElapsed = nil
  button.__rothDurationText = nil
  button:SetScript("OnUpdate", nil)
  if button.DurationText then
    button.DurationText:SetText("")
  end
end

local function SetAuraDurationState(element, button, unit, data)
  if not button then
    return
  end

  if not (element and element.__rothShowTimers == true and type(unit) == "string" and type(data) == "table") then
    ClearAuraDurationState(button)
    return
  end

  local auraInstanceID = data.auraInstanceID
  local durationObject
  if C_UnitAuras and C_UnitAuras.GetAuraDuration and auraInstanceID ~= nil and not IsSecretValue(auraInstanceID) then
    durationObject = C_UnitAuras.GetAuraDuration(unit, auraInstanceID)
  end

  local expirationTime = data.expirationTime
  if type(expirationTime) ~= "number" or IsSecretValue(expirationTime) or expirationTime <= 0 then
    expirationTime = nil
  end

  button.__rothDurationObject = durationObject
  button.__rothExpirationTime = expirationTime
  button.__rothDurationElapsed = 0
  UpdateAuraDurationText(button)

  if button.__rothDurationText and button.__rothDurationText ~= "" then
    button:SetScript("OnUpdate", AuraDurationOnUpdate)
  else
    button:SetScript("OnUpdate", nil)
  end
end

local function ApplyAuraBorder(button, element, data)
  if not (button and button.Border) then
    return
  end

  local r, g, b, a = 0, 0, 0, 0.85
  local isHarmfulAura = data and data.isHarmfulAura
  local harmfulAuraKnown = isHarmfulAura ~= nil and not IsSecretValue(isHarmfulAura)
  local isHarmful = harmfulAuraKnown and isHarmfulAura == true
  local isHelpful = harmfulAuraKnown and isHarmfulAura == false

  if data and isHarmful and element and element.showDebuffType then
    local dispelName = data.dispelName
    if type(dispelName) == "string" then
      local dispelColor = DebuffTypeColor and DebuffTypeColor[dispelName]
      if dispelColor then
        r, g, b = dispelColor.r or 1, dispelColor.g or 1, dispelColor.b or 1
      end
    end
  elseif data and isHelpful and element and element.showStealableBuffs then
    local isStealable = data.isStealable
    if isStealable ~= nil and not IsSecretValue(isStealable) and isStealable == true then
      r, g, b = 0.2, 0.75, 1
    end
  end

  button.Border:SetVertexColor(r, g, b, a)
end

local function PostCreateNativeAuraButton(element, button)
  EnsureAuraButtonLayout(element, button)
end

local function PostUpdateNativeAuraButton(element, button, unit, data)
  EnsureAuraButtonLayout(element, button)
  ApplyAuraBorder(button, element, data)
  SetAuraDurationState(element, button, unit, data)
end

local function SetupNativeAuraFrame(frame, showTimers)
  if not frame then
    return frame
  end

  frame.growthX = frame["growth-x"] or frame.growthX or "RIGHT"
  frame.growthY = frame["growth-y"] or frame.growthY or "DOWN"
  frame.PostCreateButton = PostCreateNativeAuraButton
  frame.PostUpdateButton = PostUpdateNativeAuraButton
  frame.__rothNativeAuras = true
  frame.__rothShowTimers = showTimers == true
  return frame
end

func.SetupNativeAuraFrame = SetupNativeAuraFrame

--backdrop func
func.createBackdrop = function(f)
  if not f then return end
  if not f.SetBackdrop and BackdropTemplateMixin and Mixin then
    Mixin(f, BackdropTemplateMixin)
  end
  if not f.SetBackdrop then return end
  f:SetBackdrop(cfg.backdrop)
  f:SetBackdropColor(0, 0, 0, 0.7)
  f:SetBackdropBorderColor(0, 0, 0, 1)
end

--create debuff func
func.createDebuffs = function(self)
  local style = ResolveUnitStyle(self)
  if self.cfg.vertical then
    local f = CreateFrame("Frame", nil, self)
    f.size = self.cfg.auras.size
    if style == "targettarget" then
      f.num = 8
    else
      f.num = cfg.units.party.auras.number
    end
    f:SetHeight((f.size + 5) * (f.num / 4))
    f:SetWidth((f.size + 5) * 4)
    if style == "targettarget" then
      f:SetPoint("BOTTOM", self, "RIGHT", 0, 0)
    elseif style == "party" then
      f:SetPoint("BOTTOM", self.Health, "RIGHT", 22, -19)
    else
      f:SetPoint("TOP", self, "RIGHT", 50, -5)
    end
    f.initialAnchor = "TOPLEFT"
    f["growth-x"] = "RIGHT"
    f["growth-y"] = "DOWN"
    f.spacing = 5
    f.showDebuffType = self.cfg.auras.showDebuffType
    f.onlyShowPlayer = self.cfg.auras.onlyShowPlayerDebuffs
    self.Debuffs = SetupNativeAuraFrame(f, style == "focus" or style == "targettarget")
  else
    local f = CreateFrame("Frame", nil, self)
    f.size = self.cfg.auras.size
    if style == "targettarget" then
      f.num = 8
    else
      f.num = cfg.units.party.auras.number
    end
    f:SetHeight((f.size + 5) * (f.num / 9))
    f:SetWidth((f.size + 5) * 4)
    if style == "targettarget" then
      f:SetPoint("BOTTOM", self, "RIGHT", -90, -40)
    else
      f:SetPoint("TOP", self, "RIGHT", -60, -67)
    end
    f.initialAnchor = "TOPLEFT"
    f["growth-x"] = "RIGHT"
    f["growth-y"] = "DOWN"
    f.spacing = 5
    f.showDebuffType = self.cfg.auras.showDebuffType
    f.onlyShowPlayer = self.cfg.auras.onlyShowPlayerDebuffs
    self.Debuffs = SetupNativeAuraFrame(f, style == "focus" or style == "targettarget")
  end
end

--create buff func
func.createBuffs = function(self)
  local style = ResolveUnitStyle(self)
  if self.cfg.auras.hideBuffs == true then return end
  if self.cfg.vertical == false then
    local f = CreateFrame("Frame", nil, self)
    f.size = self.cfg.auras.size
    if style == "targettarget" then
      f.num = 8
    else
      f.num = cfg.units.party.auras.number
    end
    f:SetHeight((f.size + 5) * (f.num / 9))
    f:SetWidth((f.size + 5) * 4)
    f:SetPoint("TOP", self, "RIGHT", -60, -27)
    f.initialAnchor = "TOPLEFT"
    f["growth-x"] = "RIGHT"
    f["growth-y"] = "DOWN"
    f.spacing = 5
    f.showBuffType = self.cfg.auras.showBuffType
    f.showStealableBuffs = self.cfg.auras.showStealableBuffs
    f.onlyShowPlayer = self.cfg.auras.onlyShowPlayerBuffs
    self.Buffs = SetupNativeAuraFrame(f, style == "focus" or style == "targettarget")
  else
    local f = CreateFrame("Frame", nil, self)
    f.size = self.cfg.auras.size
    if style == "targettarget" then
      f.num = 8
    else
      f.num = cfg.units.party.auras.number
    end
    f:SetHeight((f.size + 5) * (f.num / 9))
    f:SetWidth((f.size + 5) * 9)
    f:SetPoint("TOP", self, "RIGHT", 117.5, 30)
    f.initialAnchor = "TOPLEFT"
    f["growth-x"] = "RIGHT"
    f["growth-y"] = "UP"
    f.spacing = 5
    f.showBuffType = self.cfg.auras.showBuffType
    f.showStealableBuffs = self.cfg.auras.showStealableBuffs
    f.onlyShowPlayer = self.cfg.auras.onlyShowPlayerBuffs
    self.Buffs = SetupNativeAuraFrame(f, style == "focus" or style == "targettarget")
  end
end

-- Dispel/aura color runtime moved to core/unit_misc_runtime.lua.

--Desaturated and Button CD
func.postUpdateDebuff = function(element, unit, button, index, duration, expirationTime)
  if (UnitIsFriend("player", unit) or button.isPlayer) then
    button.icon:SetDesaturated(false)
    --button.cd:Show()
  else
    button.icon:SetDesaturated(true)
    --button.cd:Hide()
  end
  button.icon.duration = duration
  button.icon.timeLeft = expirationTime
  button.icon.first = true
end

--aura icon func
func.createAuraIcon = function(icons, button)
  --button:SetSize(icons.size,icons.size)
  --button.cd:SetReverse()
  local size = icons.size or button:GetWidth()
  button.Cooldown:SetFrameStrata("MEDIUM")
  button.Cooldown:SetPoint("TOPLEFT", 1, -1)
  button.Cooldown:SetPoint("BOTTOMRIGHT", -1, 1)
  button.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
  --count helper frame, this push the count fontstring over the cooldown spiral
  button.countFrame = CreateFrame("Frame", nil, button)
  button.countFrame:SetAllPoints()
  button.countFrame:SetFrameStrata("MEDIUM")
  button.countFrame:SetFrameLevel(button.Cooldown:GetFrameLevel() + 2)
  --button count
  button.Count:SetParent(button.countFrame)
  button.Count:ClearAllPoints()
  button.Count:SetPoint("TOPRIGHT", 4, 4)
  button.Count:SetTextColor(0.9, 0.9, 0.9)
  --fix fontsize to be based on button size
  button.Count:SetFont(cfg.font, size / 1.8, "THINOUTLINE")
  if func.RegisterFontString then
    func.RegisterFontString(button.Count, size / 1.8, "THINOUTLINE")
  end
  button.Overlay:SetTexture(mediapath .. "gloss2")
  button.Overlay:SetTexCoord(0, 1, 0, 1)
  button.Overlay:SetPoint("TOPLEFT", -1, 1)
  button.Overlay:SetPoint("BOTTOMRIGHT", 1, -1)
  button.Overlay:SetVertexColor(0.4, 0.35, 0.35, 1)
  button.Overlay:Show()
  button.Overlay.Hide = function() end
  local back = button:CreateTexture(nil, "BACKGROUND", nil, 0)
  back:SetPoint("TOPLEFT", button.Icon, "TOPLEFT", -0.18 * size, 0.18 * size)
  back:SetPoint("BOTTOMRIGHT", button.Icon, "BOTTOMRIGHT", 0.18 * size, -0.18 * size)
  back:SetTexture(mediapath .. "simplesquare_glow")
  back:SetVertexColor(0, 0, 0, 1)
end

--create AlternativePower
func.createAlternativePowerBar = function(self, name)
  local t, f
  local num = 4
  local w = 64 * num
  local h = 22

  local bar = CreateFrame("StatusBar", name, self)
  bar:SetPoint(self.cfg.altpower.pos.a1, self.cfg.altpower.pos.af, self.cfg.altpower.pos.a2, self.cfg.altpower.pos.x,
    self.cfg.altpower.pos.y)
  bar:SetSize(w, h)
  bar:SetStatusBarTexture(self.cfg.altpower.texture)
  bar:SetStatusBarColor(self.cfg.altpower.color.r, self.cfg.altpower.color.g, self.cfg.altpower.color.b)
  bar.colorTexture = true --color the altpower bar
  --bar:SetMinMaxValues(0,100)
  --bar:SetValue(70)

  t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetSize(64, 64)
  t:SetPoint("LEFT", -64, 0)
  t:SetTexture(mediapath .. "combo_left")
  bar.leftedge = t

  t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetSize(64, 64)
  t:SetPoint("RIGHT", 64, 0)
  t:SetTexture(mediapath .. "combo_right")
  bar.rightedge = t

  t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetSize(64 * num, 64)
  t:SetPoint("LEFT", 0, 0)
  t:SetTexture(mediapath .. "combo_back")
  bar.back = t

  local g = CreateFrame("Frame", nil, bar)
  g:SetAllPoints(bar)

  t = g:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetSize(64 * num, 64)
  t:SetPoint("LEFT", 0, 0)
  t:SetAlpha(0.7)
  t:SetBlendMode("BLEND")
  t:SetTexture(mediapath .. "combo_highlight2")

  f = func.createFontString(g, cfg.font, 24, "THINOUTLINE")
  f:SetPoint("CENTER", 0, 0)
  f:SetTextColor(0.8, 0.8, 0.8)
  self:Tag(f, "[diablo:altpower]")

  bar:SetScale(self.cfg.altpower.scale)
  bar:Hide()
  func.simpleDragFunc(bar)
  self.AlternativePower = bar
end

-- Runtime hot-path helpers moved to core/unit_value_runtime.lua.
-- Standard unit auras are framework-owned through native oUF Buffs/Debuffs.

--debuffglow
func.createDebuffGlow = function(self)
  local style = ResolveUnitStyle(self)
  local t = self:CreateTexture(nil, "BACKGROUND", nil, -5)
  if style == "target" then
    t:SetTexture(mediapath .. "target_debuffglow")
  else
    t:SetTexture(mediapath .. "targettarget_debuffglow")
  end
  if style == "party" then
    if cfg.units.party.vertical == true then
      t:SetPoint("TOP", 0, 29)
      t:SetPoint("LEFT", 0, 0)
      t:SetPoint("RIGHT", 0, 0)
      t:SetPoint("BOTTOM", 0, -10)
    else
      t:SetPoint("TOP", 0, 19)
      t:SetPoint("LEFT", 0, 0)
      t:SetPoint("RIGHT", 0, 0)
      t:SetPoint("BOTTOM", 0, -15)
    end
  elseif style == "target" then
    t:SetPoint("TOP", 0, 25)
    t:SetPoint("LEFT", -60, 0)
    t:SetPoint("RIGHT", 60, 0)
    t:SetPoint("BOTTOM", 0, -15)
  else
    t:SetAllPoints()
  end
  t:SetBlendMode("BLEND")
  t:SetVertexColor(0, 1, 1, 0) -- set alpha to 0 to hide the texture
  self.DebuffHighlight = t
  self.DebuffHighlightAlpha = 1
  self.DebuffHighlightFilter = false
end

--check threat
func.checkThreat = function(self, event, unit)
  if unit then
    if self.unit ~= unit then return end
    local threat = UnitThreatSituation(unit)
    if IsSecretValue(threat) then
      threat = nil
    end
    if (threat and threat > 0) then
      local r, g, b = GetThreatStatusColor(threat)
      if self.Border then
        self.Border:SetVertexColor(r, g, b)
        self.PortraitBack:SetVertexColor(r, g, b, 1)
      end
    else
      if self.Border then
        self.Border:SetVertexColor(0.6, 0.5, 0.5)
        self.PortraitBack:SetVertexColor(0.1, 0.1, 0.1, 0.9)
      end
    end
  end
end

--create portrait func
func.createPortrait = function(self)
  local back = CreateFrame("Frame", nil, self)
  local portraitWidth = func.GetUnitRenderWidth(self)
  back:SetSize(portraitWidth, portraitWidth)

  local style = ResolveUnitStyle(self)
  if style == "party" then
    if cfg.units.party.vertical == false then
      back:SetPoint("BOTTOM", self, "TOP", 0, -35)
    else
      back:SetPoint("BOTTOM", self, "LEFT", 10, -38)
    end
  else
    back:SetPoint("BOTTOM", self, "TOP", 0, -35)
  end
  self.PortraitHolder = back

  local t = back:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetAllPoints(back)
  t:SetTexture(mediapath .. "portrait_back")
  t:SetVertexColor(0.1, 0.1, 0.1, 0.9)
  self.PortraitBack = t

  if style == "party" then
    if self.cfg.portrait.use3D then
      self.Portrait = CreateFrame("PlayerModel", nil, back)
      self.Portrait:SetPoint("TOPLEFT", back, "TOPLEFT", 22, -20)
      self.Portrait:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -19, 21)

      local borderholder = CreateFrame("Frame", nil, self.Portrait)
      borderholder:SetAllPoints(back)
      self.BorderHolder = borderholder

      local border = borderholder:CreateTexture(nil, "BACKGROUND", nil, -6)
      border:SetAllPoints(borderholder)
      border:SetTexture(mediapath .. "portrait_border")
      border:SetVertexColor(0.6, 0.5, 0.5)
      --border:SetVertexColor(1,0,0,1) --threat test
      self.Border = border

      local gloss = borderholder:CreateTexture(nil, "BACKGROUND", nil, -5)
      gloss:SetAllPoints(borderholder)
      gloss:SetTexture(mediapath .. "portrait_gloss")
      gloss:SetVertexColor(0.9, 0.95, 1, 0.6)
    else
      self.Portrait = back:CreateTexture(nil, "BACKGROUND", nil, -7)
      self.Portrait:SetPoint("TOPLEFT", back, "TOPLEFT", 21, -21)
      self.Portrait:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -21, 21)
      self.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)

      local border = back:CreateTexture(nil, "BACKGROUND", nil, -6)
      border:SetAllPoints(back)
      border:SetTexture(mediapath .. "portrait_border")
      border:SetVertexColor(0.6, 0.5, 0.5)
      self.Border = border

      local gloss = back:CreateTexture(nil, "BACKGROUND", nil, -5)
      gloss:SetAllPoints(back)
      gloss:SetTexture(mediapath .. "portrait_gloss")
      gloss:SetVertexColor(0.9, 0.95, 1, 0.6)
    end
  else
    if self.cfg.portrait.use3D then
      self.Portrait = CreateFrame("PlayerModel", nil, back)
      self.Portrait:SetPoint("TOPLEFT", back, "TOPLEFT", 27, -27)
      self.Portrait:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -27, 27)

      local borderholder = CreateFrame("Frame", nil, self.Portrait)
      borderholder:SetAllPoints(back)
      self.BorderHolder = borderholder

      local border = borderholder:CreateTexture(nil, "BACKGROUND", nil, -6)
      border:SetAllPoints(borderholder)
      border:SetTexture(mediapath .. "portrait_border")
      border:SetVertexColor(0.6, 0.5, 0.5)
      --border:SetVertexColor(1,0,0,1) --threat test
      self.Border = border

      local gloss = borderholder:CreateTexture(nil, "BACKGROUND", nil, -5)
      gloss:SetAllPoints(borderholder)
      gloss:SetTexture(mediapath .. "portrait_gloss")
      gloss:SetVertexColor(0.9, 0.95, 1, 0.6)
    else
      self.Portrait = back:CreateTexture(nil, "BACKGROUND", nil, -7)
      self.Portrait:SetPoint("TOPLEFT", back, "TOPLEFT", 27, -27)
      self.Portrait:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -27, 27)
      self.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)

      local border = back:CreateTexture(nil, "BACKGROUND", nil, -6)
      border:SetAllPoints(back)
      border:SetTexture(mediapath .. "portrait_border")
      border:SetVertexColor(0.6, 0.5, 0.5)
      self.Border = border

      local gloss = back:CreateTexture(nil, "BACKGROUND", nil, -5)
      gloss:SetAllPoints(back)
      gloss:SetTexture(mediapath .. "portrait_gloss")
      gloss:SetVertexColor(0.9, 0.95, 1, 0.6)
    end
  end

  if self.cfg.vertical == true then
    self.Name:SetPoint("CENTER", 0, 0)
  else
    self.Name:SetPoint("BOTTOM", self, "TOP", 0, portraitWidth - 53)
  end
end

--create standalone portrait func
func.createStandAlonePortrait = function(self)
  local fname
  local style = ResolveUnitStyle(self)
  if style == "player" then
    fname = "Roth_UIPlayerPortrait"
  elseif style == "target" then
    fname = "Roth_UITargetPortrait"
  end

  local pcfg = self.cfg.portrait

  local back = CreateFrame("Frame", fname, self)
  back:SetSize(pcfg.size, pcfg.size)
  back:SetPoint(pcfg.pos.a1, pcfg.pos.af, pcfg.pos.a2, pcfg.pos.x, pcfg.pos.y)

  func.applyDragFunctionality(back)

  local t = back:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetAllPoints(back)
  t:SetTexture(mediapath .. "portrait_back")
  t:SetVertexColor(0.1, 0.1, 0.1, 0.9)

  if pcfg.use3D then
    self.Portrait = CreateFrame("PlayerModel", nil, back)
    self.Portrait:SetPoint("TOPLEFT", back, "TOPLEFT", pcfg.size * 27 / 128, -pcfg.size * 27 / 128)
    self.Portrait:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -pcfg.size * 27 / 128, pcfg.size * 27 / 128)

    local borderholder = CreateFrame("Frame", nil, self.Portrait)
    borderholder:SetAllPoints(back)

    local border = borderholder:CreateTexture(nil, "BACKGROUND", nil, -6)
    border:SetAllPoints(borderholder)
    border:SetTexture(mediapath .. "portrait_border")
    border:SetVertexColor(0.6, 0.5, 0.5)

    local gloss = borderholder:CreateTexture(nil, "BACKGROUND", nil, -5)
    gloss:SetAllPoints(borderholder)
    gloss:SetTexture(mediapath .. "portrait_gloss")
    gloss:SetVertexColor(0.9, 0.95, 1, 0.6)
  else
    self.Portrait = back:CreateTexture(nil, "BACKGROUND", nil, -7)
    self.Portrait:SetPoint("TOPLEFT", back, "TOPLEFT", pcfg.size * 27 / 128, -pcfg.size * 27 / 128)
    self.Portrait:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -pcfg.size * 27 / 128, pcfg.size * 27 / 128)
    self.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)

    local border = back:CreateTexture(nil, "BACKGROUND", nil, -6)
    border:SetAllPoints(back)
    border:SetTexture(mediapath .. "portrait_border")
    border:SetVertexColor(0.6, 0.5, 0.5)

    local gloss = back:CreateTexture(nil, "BACKGROUND", nil, -5)
    gloss:SetAllPoints(back)
    gloss:SetTexture(mediapath .. "portrait_gloss")
    gloss:SetVertexColor(0.9, 0.95, 1, 0.6)
  end
end
--create castbar func
local function ResolveAnchorFrame(af, ownerFrame)
  if type(af) == "string" then
    if af == "$parent" or af == "$self" or af == "self" then
      return ownerFrame
    end
    return _G[af]
  end
  return af
end

func.createCastbar = function(f)
  local style = ResolveUnitStyle(f)
  local cb = f.cfg and f.cfg.castbar or nil
  if not cb then return end
  if type(cb) ~= "table" then
    if ns and ns.Log then
      ns.Log("Castbar: skip style=%s (castbar type=%s)", tostring(style), type(cb))
    end
    return
  end

  local af = ResolveAnchorFrame(cb.pos and cb.pos.af, f) or UIParent
  local x = (cb.pos and cb.pos.x) or 0
  local y = (cb.pos and cb.pos.y) or 0
  local a1 = (cb.pos and cb.pos.a1) or "CENTER"
  local a2 = (cb.pos and cb.pos.a2) or a1

  local barW = tonumber(cb.width) or 265
  local barH = tonumber(cb.height) or 15
  local isMini = (cb.mini == true)

  if ns and ns.Log then
    ns.Log(
      "Castbar: create style=%s mini=%s w=%s h=%s anchor=%s",
      tostring(style),
      tostring(isMini),
      tostring(barW),
      tostring(barH),
      tostring(cb.pos and cb.pos.af)
    )
  end

  local frame = CreateFrame("Frame", "$parentCastBarDragFrame", f)
  frame:SetPoint(a1, af, a2, x + 8, y)
  frame:SetSize(barW, barH)

  frameRegistry.Register("bars", frame)

  local c = CreateFrame("StatusBar", "$parentCastbar", frame)
  c:SetSize(barW, barH)
  c:SetStatusBarTexture(cb.texture)
  c:SetScale(cb.scale or 1)
  c:SetPoint("CENTER", frame, 0, 0)
  c:SetFrameStrata("HIGH")
  c.castbarCfg = cb
  c:SetStatusBarColor(cb.color.bar.r, cb.color.bar.g, cb.color.bar.b, cb.color.bar.a)
  c.timeToHold = cb.timeToHold or 0.8
  c._dragFrame = frame

  if isMini then
    -- Minimal background (no large castbar art) for small unitframes.
    c.bg = c:CreateTexture(nil, "BACKGROUND", nil, -6)
    c.bg:SetAllPoints(c)
    c.bg:SetColorTexture(cb.color.bg.r, cb.color.bg.g, cb.color.bg.b, cb.color.bg.a)

    c._miniShade = c:CreateTexture(nil, "OVERLAY", nil, -5)
    c._miniShade:SetAllPoints(c)
    c._miniShade:SetColorTexture(0, 0, 0, 0.35)
  else
    c.background = c:CreateTexture(nil, "BACKGROUND", nil, -8)
    c.background:SetTexture(mediapath .. "castbar")
    c.background:SetPoint("TOP", 0, 24.9)
    c.background:SetPoint("LEFT", -170, 0)
    c.background:SetPoint("RIGHT", 170, 0)
    c.background:SetPoint("BOTTOM", 0, -24.2)

    c.bg = c:CreateTexture(nil, "BACKGROUND", nil, -6)
    c.bg:SetTexture(cb.texture)
    c.bg:SetAllPoints(c)
    c.bg:SetVertexColor(cb.color.bg.r, cb.color.bg.g, cb.color.bg.b, cb.color.bg.a)

    c.glow = c:CreateTexture(nil, "OVERLAY", nil, -4)
    c.glow:SetTexture(mediapath .. "castbar_glow")
    c.glow:SetPoint("TOP", 0, 26.5)
    c.glow:SetPoint("LEFT", -35, 0)
    c.glow:SetPoint("RIGHT", 35, 0)
    c.glow:SetPoint("BOTTOM", 0, -24.2)
    c.glow:SetVertexColor(0, 0, 0, 1)

    c.highlight = c:CreateTexture(nil, "OVERLAY", nil, -3)
    c.highlight:SetTexture(mediapath .. "castbar_highlight")
    c.highlight:SetPoint("TOP", 0, 26.5)
    c.highlight:SetPoint("LEFT", -35, 0)
    c.highlight:SetPoint("RIGHT", 35, 0)
    c.highlight:SetPoint("BOTTOM", 0, -24.2)
  end

  c.Text = func.createFontString(c, cfg.font, cb.TextSize or 11, "THINOUTLINE")
  c.Text:SetPoint("LEFT", 5, 0)
  c.Text:SetJustifyH("LEFT")

  c.Time = func.createFontString(c, cfg.font, cb.TextSize or 11, "THINOUTLINE")
  c.Time:SetPoint("RIGHT", -2, 0)
  c.Text:SetPoint("RIGHT", -50, 0)

  c.Spark = c:CreateTexture(nil, "OVERLAY", nil, -7)
  c.Spark:SetBlendMode("ADD")
  c.Spark:SetVertexColor(0.8, 0.6, 0, 1)

  if style == "target" then
    -- Blizzard-style shield for non-interruptible casts.
    c.Shield = c:CreateTexture(nil, "OVERLAY", nil, 3)
    c.Shield:SetTexture("Interface\\CastingBar\\UI-CastingBar-Shield")
    c.Shield:SetSize(26, 26)
    c.Shield:SetPoint("LEFT", c, "LEFT", -10, 0)
    c.Shield:SetBlendMode("BLEND")
    c.Shield:SetVertexColor(0.9, 0.9, 0.9, 1)
    c.Shield:Hide()
  end

  if style == "target" and ns.TargetCastbarRuntime and type(ns.TargetCastbarRuntime.ApplyInitialVisual) == "function" then
    ns.TargetCastbarRuntime.ApplyInitialVisual(c)
  end

  --safezone
  if style == "player" and cb.latency then
    c.SafeZone = c:CreateTexture(nil, "OVERLAY")
    c.SafeZone:SetTexture(cb.texture)
    c.SafeZone:SetVertexColor(0.6, 0, 0, 0.6)
    c.SafeZone:SetPoint("TOPRIGHT")
    c.SafeZone:SetPoint("BOTTOMRIGHT")
  end

  if style == "player" then
    c.PostUpdateStage = func.PostUpdateStage
    c.cfg = f.cfg
  end

  func.applyDragFunctionality(frame)

  f.Castbar = c
  c:Hide()
end

-- Standalone castbar polling (for units where UNIT_SPELLCAST events are unreliable).
-- Uses only non-secret numeric fields (start/end times) and never compares Secret Values.
func.EnableStandaloneCastbar = function(bar, unit)
  if not (bar and unit) then return end
  if bar.__standaloneEnabled then return end
  bar.__standaloneEnabled = true

  local pollFrame = bar._dragFrame or bar
  local accum = 0
  local active = false
  local castbarRuntime = ns and ns.TargetCastbarRuntime or nil

  local function SafeIsSecret(v)
    return IsSecretValue(v)
  end

  local function SafeNum(v)
    if type(v) == "number" and not SafeIsSecret(v) then
      return v
    end
    return nil
  end

  local function SafeTracked(v)
    local valueType = type(v)
    if (valueType == "number" or valueType == "string") and not SafeIsSecret(v) then
      return v
    end
    return nil
  end

  local function SafeBool(v)
    if type(v) == "boolean" and not SafeIsSecret(v) then
      return v
    end
    return nil
  end

  local function SafeSetText(fs, v)
    if not fs then return end
    if type(v) == "nil" or SafeIsSecret(v) then
      fs:SetText("")
      return
    end
    fs:SetText(tostring(v))
  end
  local function Query(unit)
    local name, text, texture, startTimeMS, endTimeMS, _, _, notInterruptible, spellID, castBarID = UnitCastingInfo(unit)
    if type(name) ~= "nil" then
      return name, text, texture, startTimeMS, endTimeMS, "cast", notInterruptible, spellID, castBarID
    end

    local isEmpowered
    name, text, texture, startTimeMS, endTimeMS, _, notInterruptible, spellID, isEmpowered, _, castBarID = UnitChannelInfo(unit)
    if type(name) == "nil" then
      return nil
    end

    local castKind = (SafeBool(isEmpowered) == true) and "empower" or "channel"
    return name, text, texture, startTimeMS, endTimeMS, castKind, notInterruptible, spellID, castBarID
  end

  local function Update()
    local name, displayText, texture, sMS, eMS, castKind, notInterruptible, spellID, castBarID = Query(unit)
    if type(name) == "nil" then
      if active then
        active = false
        bar.casting = nil
        bar.channeling = nil
        bar.empowering = nil
        bar.castID = nil
        bar.spellID = nil
        bar.notInterruptible = nil
        bar._lastCastRemaining = nil
        if castbarRuntime and type(castbarRuntime.ApplyInitialVisual) == "function" then
          castbarRuntime.ApplyInitialVisual(bar)
        end
        bar:Hide()
      end
      return
    end

    local isChannel = (castKind == "channel")
    local isEmpower = (castKind == "empower")
    active = true
    bar._rothUnit = unit
    bar.casting = (castKind == "cast" or isEmpower)
    bar.channeling = isChannel
    bar.empowering = isEmpower
    bar.castID = SafeTracked(castBarID)
    bar.spellID = SafeNum(spellID)
    bar.notInterruptible = SafeBool(notInterruptible)

    if type(texture) ~= "nil" and not SafeIsSecret(texture) and bar.Icon and bar.Icon.SetTexture then
      bar.Icon:SetTexture(texture)
    end

    SafeSetText(bar.Text, displayText or name)

    local s = SafeNum(sMS)
    local e = SafeNum(eMS)
    if not s or not e or e <= s then
      bar:SetMinMaxValues(0, 1)
      bar:SetValue(0)
      SafeSetText(bar.Time, "")
      if castbarRuntime and type(castbarRuntime.RefreshBar) == "function" then
        castbarRuntime.RefreshBar(bar)
      end
      bar:Show()
      return
    end

    local now = GetTime() * 1000
    local dur = (e - s) / 1000
    if dur <= 0 then dur = 0.01 end

    bar:SetMinMaxValues(0, dur)

    local val
    local remaining
    if isChannel then
      if bar.SetReverseFill then bar:SetReverseFill(true) end
      remaining = (e - now) / 1000
      if remaining < 0 then remaining = 0 end
      val = remaining
    else
      if bar.SetReverseFill then bar:SetReverseFill(false) end
      val = (now - s) / 1000
      if val < 0 then val = 0 end
      if val > dur then val = dur end
      remaining = dur - val
    end

    bar:SetValue(val)
    if bar.Time then
      local rounded = floor((remaining * 10) + 0.5) / 10
      if bar._lastCastRemaining ~= rounded then
        bar._lastCastRemaining = rounded
        SafeSetText(bar.Time, string.format("%.1f", rounded))
      end
    end

    if bar.Spark then
      local w = bar:GetWidth() or 0
      local pct = 0
      if dur > 0 then
        pct = (isChannel and ((dur - val) / dur) or (val / dur))
      end
      if pct < 0 then pct = 0 end
      if pct > 1 then pct = 1 end
      local sparkH = (bar:GetHeight() or 10) * 1.8
      if bar._lastSparkHeight ~= sparkH then
        bar._lastSparkHeight = sparkH
        bar.Spark:SetSize(10, sparkH)
      end
      local sparkX = w * pct
      if bar._lastSparkX ~= sparkX then
        bar._lastSparkX = sparkX
        bar.Spark:ClearAllPoints()
        bar.Spark:SetPoint("CENTER", bar, "LEFT", sparkX, 0)
      end
      if not bar.Spark:IsShown() then
        bar.Spark:Show()
      end
    end

    if castbarRuntime and type(castbarRuntime.RefreshBar) == "function" then
      castbarRuntime.RefreshBar(bar)
    end
    bar:Show()
  end

  local old = pollFrame:GetScript("OnUpdate")
  pollFrame:SetScript("OnUpdate", function(self, elapsed)
    if old then old(self, elapsed) end
    accum = accum + (elapsed or 0)
    local rate = active and 0.05 or 0.15
    if accum < rate then return end
    accum = 0
    Update()
  end)

  -- Initial state
  if castbarRuntime and type(castbarRuntime.ApplyInitialVisual) == "function" then
    castbarRuntime.ApplyInitialVisual(bar)
  end
  bar:Hide()
end

func.PostUpdateStage =
    function(self, stage)
      if (stage == 1) then
        self:SetStatusBarColor(1, 0, 0)
      elseif (stage == 2) then
        self:SetStatusBarColor(0, 0, 1)
      elseif (stage == 3) then
        self:SetStatusBarColor(self.cfg.castbar.color.bar.r, self.cfg.castbar.color.bar.g, self.cfg.castbar.color.bar.b,
          self.cfg.castbar.color.bar.a)
      end
    end

--fontstring func
local function ResolveFontPath(fontPath)
  if type(fontPath) ~= "string" or fontPath == "" then
    fontPath = (ns and ns.cfg and ns.cfg.font) or STANDARD_TEXT_FONT
  else
    -- If a LSM key (not a file path) is passed, try to resolve it
    if not fontPath:find("\\") and not fontPath:find("/") and not fontPath:lower():match("%.ttf$") and not fontPath:lower():match("%.otf$") then
      if LSM and type(LSM.Fetch) == "function" then
        local fetched = LSM:Fetch("font", fontPath)
        if type(fetched) == "string" and fetched ~= "" then
          fontPath = fetched
        end
      end
    end
  end
  return fontPath
end
func.ResolveFontPath = ResolveFontPath

local function RegisterFontString(fs, size, flags)
  if not fs then return end
  local reg = ns and ns._fontStrings
  if type(reg) ~= "table" then
    reg = setmetatable({}, { __mode = "k" })
    if ns then ns._fontStrings = reg end
  end
  reg[fs] = { size = size or 12, flags = flags or "" }
end

func.RegisterFontString = RegisterFontString

func.createFontString = function(f, font, size, outline, layer)
  local fs = f:CreateFontString(nil, layer or "OVERLAY")
  local fontPath = ResolveFontPath(font)
  fs:SetFont(fontPath, size or 12, outline)
  fs:SetShadowColor(0, 0, 0, 1)
  RegisterFontString(fs, size or 12, outline)
  return fs
end

-- Mover runtime moved to core/mover_runtime.lua.

--create icon func
func.createIcon = function(f, layer, size, anchorframe, anchorpoint1, anchorpoint2, posx, posy, sublevel)
  local icon = f:CreateTexture(nil, layer, nil, sublevel)
  icon:SetSize(size, size)
  icon:SetPoint(anchorpoint1, anchorframe, anchorpoint2, posx, posy)
  return icon
end

local function GetGroupRangeDriver(frame)
  local rangeCfg = frame and frame.cfg and frame.cfg.range
  local driver = type(rangeCfg) == "table" and rangeCfg.driver or nil
  if type(driver) ~= "string" then
    return "blizzard"
  end

  driver = driver:lower()
  if driver == "off" or driver == "disabled" or driver == "none" then
    return "off"
  end
  if driver == "ouf" then
    return "ouf"
  end
  return "blizzard"
end

local function GetGroupRangeOutsideAlpha(frame)
  local alphaCfg = frame and frame.cfg and frame.cfg.alpha
  local outsideAlpha = type(alphaCfg) == "table" and tonumber(alphaCfg.notinrange) or nil
  return outsideAlpha or 0.55
end

local function ApplyGroupRangeAlpha(frame, isOutside)
  if not (frame and frame.SetAlpha) then
    return
  end

  local alpha = isOutside and GetGroupRangeOutsideAlpha(frame) or 1
  frame:SetAlpha(alpha)
end

local function SyncBlizzardRangeDriver(driver)
  local frame = driver and driver.owner
  local unit = frame and (frame.unit or frame.displayedUnit)
  if not unit then
    return
  end

  if not UnitIsConnected(unit) then
    frame.__rothOutOfRange = false
    ApplyGroupRangeAlpha(frame, false)
    return
  end

  local inRange, checkedRange = UnitInRange(unit)
  local isOutside = checkedRange and (inRange == false)
  frame.__rothOutOfRange = isOutside and true or false
  ApplyGroupRangeAlpha(frame, isOutside)
end

local function UnregisterBlizzardRangeDriver(driver)
  if not driver then
    return
  end

  driver:UnregisterEvent("UNIT_IN_RANGE_UPDATE")
  driver:UnregisterEvent("UNIT_DISTANCE_CHECK_UPDATE")
  driver:UnregisterEvent("UNIT_CONNECTION")
  driver:UnregisterEvent("PARTY_MEMBER_ENABLE")
  driver:UnregisterEvent("PARTY_MEMBER_DISABLE")
  driver:UnregisterEvent("GROUP_ROSTER_UPDATE")
  driver:UnregisterEvent("PLAYER_ENTERING_WORLD")
  driver.registeredUnit = nil
end

local function RegisterBlizzardRangeDriver(driver)
  local frame = driver and driver.owner
  local unit = frame and (frame.unit or frame.displayedUnit)
  if not (frame and unit and frame.IsVisible and frame:IsVisible()) then
    return
  end

  if driver.registeredUnit == unit then
    SyncBlizzardRangeDriver(driver)
    return
  end

  UnregisterBlizzardRangeDriver(driver)
  driver:RegisterUnitEvent("UNIT_IN_RANGE_UPDATE", unit)
  driver:RegisterUnitEvent("UNIT_DISTANCE_CHECK_UPDATE", unit)
  driver:RegisterUnitEvent("UNIT_CONNECTION", unit)
  driver:RegisterEvent("PARTY_MEMBER_ENABLE")
  driver:RegisterEvent("PARTY_MEMBER_DISABLE")
  driver:RegisterEvent("GROUP_ROSTER_UPDATE")
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  driver.registeredUnit = unit
  SyncBlizzardRangeDriver(driver)
end

local function OnBlizzardRangeDriverEvent(self, event, ...)
  local frame = self.owner
  local unit = frame and (frame.unit or frame.displayedUnit)
  if not unit then
    return
  end

  if event == "UNIT_IN_RANGE_UPDATE" then
    local eventUnit, inRange = ...
    if eventUnit ~= unit then
      return
    end

    local isOutside = UnitIsConnected(unit) and (inRange == false)
    frame.__rothOutOfRange = isOutside and true or false
    ApplyGroupRangeAlpha(frame, isOutside)
    return
  end

  if event == "UNIT_DISTANCE_CHECK_UPDATE" then
    local eventUnit, inDistance = ...
    if eventUnit == unit then
      frame.__rothInDistance = inDistance == true
    end
    return
  end

  RegisterBlizzardRangeDriver(self)
end

local function EnsureBlizzardRangeDriver(frame)
  local driver = frame and frame.__rothBlizzardRangeDriver
  if driver then
    return driver
  end

  driver = CreateFrame("Frame", nil, frame)
  driver.owner = frame
  driver:SetScript("OnEvent", OnBlizzardRangeDriverEvent)

  -- Blizzard compact frames only listen for range events while visible because the
  -- engine does extra work for `UNIT_IN_RANGE_UPDATE`/`UNIT_DISTANCE_CHECK_UPDATE`.
  -- We keep that behavior here. `driver=blizzard` follows the Blizzard event path;
  -- `driver=ouf` delegates the same job to the oUF Range element for comparison.
  frame:HookScript("OnShow", function()
    RegisterBlizzardRangeDriver(driver)
  end)
  frame:HookScript("OnHide", function()
    UnregisterBlizzardRangeDriver(driver)
  end)

  frame.__rothBlizzardRangeDriver = driver
  return driver
end

func.ConfigureGroupRange = function(self)
  local style = ResolveUnitStyle(self)
  if style ~= "party" and style ~= "raid" then
    return
  end

  local driver = GetGroupRangeDriver(self)
  if driver == "off" then
    ApplyGroupRangeAlpha(self, false)
    return
  end

  if driver == "ouf" then
    self.Range = self.Range or {}
    self.Range.insideAlpha = 1
    self.Range.outsideAlpha = GetGroupRangeOutsideAlpha(self)
    return
  end

  RegisterBlizzardRangeDriver(EnsureBlizzardRangeDriver(self))
end

func.RefreshGroupRangeFrame = function(frame)
  if type(frame) ~= "table" then
    return
  end

  if type(frame.Range) == "table" then
    frame.Range.insideAlpha = 1
    frame.Range.outsideAlpha = GetGroupRangeOutsideAlpha(frame)
    if type(frame.ForceUpdate) == "function" then
      frame:ForceUpdate()
    end
  end

  local driver = frame.__rothBlizzardRangeDriver
  if driver then
    RegisterBlizzardRangeDriver(driver)
  end
end

function ns.RefreshGroupRangeRuntime()
  local seen = {}

  local function RefreshFrame(frame)
    if frame and not seen[frame] then
      seen[frame] = true
      func.RefreshGroupRangeFrame(frame)
    end
  end

  local partyHeader = ns and ns.partyHeader
  if partyHeader and partyHeader.GetChildren then
    for _, frame in ipairs({ partyHeader:GetChildren() }) do
      RefreshFrame(frame)
    end
  end

  local raidGroups = ns and ns.raidGroups
  if type(raidGroups) == "table" then
    for _, header in pairs(raidGroups) do
      if header and header.GetChildren then
        for _, frame in ipairs({ header:GetChildren() }) do
          RefreshFrame(frame)
        end
      end
    end
  end
end

-- Register incoming-heal bars on the Health element; oUF owns the calculator and updates.
func.healPrediction = function(self)
  if not self.cfg.healprediction or (self.cfg.healprediction and not self.cfg.healprediction.show) then return end
  local w = self.Health:GetWidth()
  if w == 0 then
    w = self:GetWidth() - 24.5 -
        24.5 --raids and party have no width on the health frame for whatever reason, thus use self and subtract the setpoint values
  end
  -- my heals
  local mhpb = CreateFrame("StatusBar", nil, self.Health)
  mhpb:SetFrameLevel(self.Health:GetFrameLevel())
  mhpb:SetPoint("TOPLEFT", self.Health, "TOPRIGHT", 0, 0)
  mhpb:SetPoint("BOTTOMLEFT", self.Health, "BOTTOMRIGHT", 0, 0)
  mhpb:SetWidth(w)
  mhpb:SetStatusBarTexture(self.cfg.healprediction.texture)
  mhpb:SetStatusBarColor(self.cfg.healprediction.color.myself.r, self.cfg.healprediction.color.myself.g,
    self.cfg.healprediction.color.myself.b, self.cfg.healprediction.color.myself.a)
  -- other heals
  local ohpb = CreateFrame("StatusBar", nil, self.Health)
  ohpb:SetFrameLevel(self.Health:GetFrameLevel())
  ohpb:SetPoint("TOPLEFT", mhpb:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
  ohpb:SetPoint("BOTTOMLEFT", mhpb:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
  ohpb:SetWidth(w)
  ohpb:SetStatusBarTexture(self.cfg.healprediction.texture)
  ohpb:SetStatusBarColor(self.cfg.healprediction.color.other.r, self.cfg.healprediction.color.other.g,
    self.cfg.healprediction.color.other.b, self.cfg.healprediction.color.other.a)
  -- Register on the Health element using the current oUF sub-widget contract.
  self.Health.HealingPlayer = mhpb
  self.Health.HealingOther = ohpb
  self.Health.incomingHealOverflow = self.cfg.healprediction.maxoverflow
end

--total absorb
func.totalAbsorb = function(self)
  if not self.cfg.totalabsorb or (self.cfg.totalabsorb and not self.cfg.totalabsorb.show) then return end

  local w = self.Health:GetWidth()

  if ResolveUnitStyle(self) == "party" then
    if cfg.units.party.vertical == false then
      if w == 0 then
        w = self:GetWidth() - 24.5 -
            24.5 --raids and party have no width on the health frame for whatever reason, thus use self and subtract the setpoint values
      end
    else
      if w == 0 then
        w = self:GetWidth() - 60 - 24.5
      end
    end
  else
    if w == 0 then
      w = self:GetWidth() - 24.5 -
          24.5 --raids and party have no width on the health frame for whatever reason, thus use self and subtract the setpoint values
    end
  end
  local absorbBar = CreateFrame("StatusBar", nil, self.Health)
  --new anchorpoint, absorb will now overlay the healthbar from right to left
  absorbBar:SetFrameLevel(self.Health:GetFrameLevel() + 1)
  absorbBar:SetPoint("TOPRIGHT", self.Health, 0, 0)
  absorbBar:SetPoint("BOTTOMRIGHT", self.Health, 0, 0)
  absorbBar:SetWidth(w)
  absorbBar:SetStatusBarTexture(self.cfg.totalabsorb.texture)
  absorbBar:SetStatusBarColor(self.cfg.totalabsorb.color.bar.r, self.cfg.totalabsorb.color.bar.g,
    self.cfg.totalabsorb.color.bar.b, self.cfg.totalabsorb.color.bar.a)
  absorbBar:SetReverseFill(true)
  -- Register on the Health element using the current oUF sub-widget contract.
  self.Health.DamageAbsorb = absorbBar
  -- Alias for smooth module and legacy call sites
  self.TotalAbsorb = absorbBar
end

--reset all settings
func.ResetAllSettings = function()
  local actions = ns and ns.settingsActions
  if type(actions) == "table" and type(actions.ResetAll) == "function" then
    return actions.ResetAll()
  end

  print("Roth_UI: settings reset is not available.")
  return false
end

--Register LSM media
LSM:Register("border", "RB border", "Interface\\AddOns\\Roth_UI\\media\\5.tga")
LSM:Register("statusbar", "Solid", "Interface\\AddOns\\Roth_UI\\media\\Solid.tga")
LSM:Register("statusbar", "Roth_Statusbar1", "Interface\\AddOns\\Roth_UI\\media\\statusbar")
LSM:Register("statusbar", "Roth_Statusbar2", "Interface\\AddOns\\Roth_UI\\media\\statusbar2")
LSM:Register("statusbar", "Roth_Statusbar3", "Interface\\AddOns\\Roth_UI\\media\\statusbar3")
LSM:Register("statusbar", "Roth_Statusbar4", "Interface\\AddOns\\Roth_UI\\media\\statusbar4")
LSM:Register("statusbar", "Roth_Statusbar5", "Interface\\AddOns\\Roth_UI\\media\\statusbar5")
LSM:Register("statusbar", "Roth_Statusbar6", "Interface\\AddOns\\Roth_UI\\media\\statusbar128")
LSM:Register("statusbar", "Roth_Statusbar7", "Interface\\AddOns\\Roth_UI\\media\\statusbar128_3")
LSM:Register("statusbar", "Roth_Statusbar8", "Interface\\AddOns\\Roth_UI\\media\\statusbar256")
LSM:Register("statusbar", "Roth_Statusbar9", "Interface\\AddOns\\Roth_UI\\media\\statusbar256_2")
LSM:Register("statusbar", "Roth_Statusbar10", "Interface\\AddOns\\Roth_UI\\media\\statusbar256_3")
LSM:Register("background", "Solid", "Interface\\AddOns\\Roth_UI\\media\\Solid.tga")
LSM:Register("font", "Cracked", "Interface\\AddOns\\Roth_UI\\media\\Cracked-Narrow.ttf")
LSM:Register("font", "Expressway", "Interface\\AddOns\\Roth_UI\\media\\Expressway.ttf")
LSM:Register("font", "Diablo Light", "Interface\\AddOns\\Roth_UI\\media\\Diablo-Light.ttf")
-- RothFont pack (integrated).
LSM:Register("font", "Roth Expressway", "Interface\\AddOns\\Roth_UI\\media\\Expressway.ttf")
LSM:Register("font", "Roth PT Sans Narrow", "Interface\\AddOns\\Roth_UI\\media\\PT_Sans_Narrow.ttf")
LSM:Register("font", "Roth Continuum", "Interface\\AddOns\\Roth_UI\\media\\Continuum_Medium.ttf")
LSM:Register("font", "Roth Cracked Narrow", "Interface\\AddOns\\Roth_UI\\media\\Cracked-Narrow.ttf")
LSM:Register("font", "Roth AssassinNation", "Interface\\AddOns\\Roth_UI\\media\\assassinnation.ttf")
LSM:Register("font", "Roth Devils Snare", "Interface\\AddOns\\Roth_UI\\media\\ufonts.com_devils-snare.ttf")
LSM:Register("font", "Roth Vielkalahizo", "Interface\\AddOns\\Roth_UI\\media\\vielkalahizo.ttf")
LSM:Register("font", "Roth Lycanthrope", "Interface\\AddOns\\Roth_UI\\media\\Lycanthrope.ttf")
LSM:Register("font", "Roth OldeEnglish", "Interface\\AddOns\\Roth_UI\\media\\OldeEnglish.ttf")
LSM:Register("font", "Roth Breakable", "Interface\\AddOns\\Roth_UI\\media\\Breakable_Regular.otf")
LSM:Register("font", "Roth Diablo Std", "Interface\\AddOns\\Roth_UI\\media\\Diablo Std Regular.otf")
LSM:Register("font", "Roth Enchanted Land", "Interface\\AddOns\\Roth_UI\\media\\Enchanted Land.otf")
