
  --get the addon namespace
  local addon, ns = ...

  local IsAddOnLoaded = C_AddOns.IsAddOnLoaded


  --get oUF namespace (just in case needed)
  local oUF = ns.oUF or oUF

  --get the config
  local cfg = ns.cfg
  local storeApi = ns and ns.store
  local orbText = assert(ns and ns.OrbTextController, "Roth_UI: ns.OrbTextController is required by tags.lua")
  --get the functions
  local func = ns.func

  local type = type
  local pairs = pairs
  local select = select
  local tostring = tostring
  local tonumber = tonumber
  local format = format
  local floor = floor
  local UnitHealth = UnitHealth
  local UnitHealthMax = UnitHealthMax
  local UnitPower = UnitPower
  local UnitPowerMax = UnitPowerMax
  local UnitPowerType = UnitPowerType
  local UnitIsDeadOrGhost = UnitIsDeadOrGhost
  local UnitIsConnected = UnitIsConnected
  local UnitName = UnitName
  local UnitIsPlayer = UnitIsPlayer
  local UnitReaction = UnitReaction
  local safety = assert(ns and ns.safety, "Roth_UI: ns.safety is required by tags.lua")
  local colorHexCache = {}

  local function ResolveOrbConfig(orbType)
    if type(storeApi) == "table" and type(storeApi.GetOrbConfig) == "function" then
      local config = storeApi.GetOrbConfig(orbType)
      if type(config) == "table" then
        return config
      end
    end
    return nil
  end

  local function GetColorHex(color)
    local key = color or "ffffff"
    local cached = colorHexCache[key]
    if not cached then
      cached = "|cff" .. key
      colorHexCache[key] = cached
    end
    return cached
  end

	  -- Midnight/12.x: Unit* APIs may return "secret" values (protected in combat).
	  -- Never do boolean checks / comparisons / arithmetic on secrets.
	  local IsSecretValue = (func and func.IsSecretValue) or assert(safety.IsSecret, "Roth_UI: safety.IsSecret is required by tags.lua")

	  local function SafeDead(unit)
	    local dead = UnitIsDeadOrGhost(unit)
	    if IsSecretValue(dead) then return false end
	    return dead
	  end

	  local function SafeConnected(unit)
	    local connected = UnitIsConnected(unit)
	    if IsSecretValue(connected) then return true end
	    return connected
	  end

	  -- Override a few core oUF tags that are frequently used throughout Roth_UI.
	  -- (oUF's default implementations commonly do math on Unit* return values.)
	do
		local Methods = oUF.Tags.Methods
		if Methods then
			-- Prefer safe percent APIs (Midnight/12.x) when available.
			local UnitHealthPercent = _G.UnitHealthPercent
			local UnitPowerPercent = _G.UnitPowerPercent
			local function RoundPct(p)
				if type(p) ~= 'number' then return nil end
				if p <= 1 then p = p * 100 end
				return floor(p + 0.5)
			end

			Methods['curhp'] = function(unit)
				local v = UnitHealth(unit)
				-- Never return Secret Values to the oUF tag engine (it may compare/cache values).
				if IsSecretValue(v) then return '' end
				return v or 0
			end
			Methods['maxhp'] = function(unit)
				local v = UnitHealthMax(unit)
				if IsSecretValue(v) then return '' end
				return v or 0
			end
			Methods['perhp'] = function(unit)
				if UnitHealthPercent then
					local p = UnitHealthPercent(unit)
					if not IsSecretValue(p) then
										local rp = RoundPct(p)
						if rp then return rp end
					end
				end
				local cur = UnitHealth(unit)
				local max = UnitHealthMax(unit)
				if IsSecretValue(cur) or IsSecretValue(max) or not max or max == 0 then return '' end
				return floor(cur / max * 100)
			end
			Methods['curpp'] = function(unit)
				local v = UnitPower(unit)
				if IsSecretValue(v) then return '' end
				return v or 0
			end
			Methods['maxpp'] = function(unit)
				local v = UnitPowerMax(unit)
				if IsSecretValue(v) then return '' end
				return v or 0
			end
			Methods['perpp'] = function(unit)
				if UnitPowerPercent then
					local p = UnitPowerPercent(unit)
					if not IsSecretValue(p) then
										local rp = RoundPct(p)
						if rp then return rp end
					end
				end
				local cur = UnitPower(unit)
				local max = UnitPowerMax(unit)
				if IsSecretValue(cur) or IsSecretValue(max) or not max or max == 0 then return '' end
				return floor(cur / max * 100)
			end
		end
	end

  ---------------------------------------------
  -- TAGS
  ---------------------------------------------

  --rgb to hex func
  local function RGBPercToHex(r, g, b)
    r = r <= 1 and r >= 0 and r or 1
    g = g <= 1 and g >= 0 and g or 1
    b = b <= 1 and b >= 0 and b or 1
    return format("%02x%02x%02x", r*255, g*255, b*255)
  end

  --reuse constant colors to avoid per-tag allocations
  local COLOR_WHITE = { r = 1, g = 1, b = 1 }
  local COLOR_DEAD_OFFLINE = { r = 0.5, g = 0.5, b = 0.5 }
  local SharedGetClassColorForUnit = func and func.GetClassColorForUnit
  local function GetClassColorForUnit(unit)
    if type(SharedGetClassColorForUnit) == "function" then
      return SharedGetClassColorForUnit(unit)
    end
    return nil
  end

  ---------------------------------------------

  --color tag
  oUF.Tags.Methods["diablo:color"] = function(unit)
    local color

    -- Treat secret booleans as "unknown" and avoid boolean tests on them.
    local dead = UnitIsDeadOrGhost(unit)
    if IsSecretValue(dead) then dead = false end

    local connected = UnitIsConnected(unit)
    if IsSecretValue(connected) then connected = true end

    if dead or not connected then
      color = COLOR_DEAD_OFFLINE
    else
      -- Tap denied: avoid UnitIsUnit (can return secret), and avoid boolean tests on secret.
      if unit == "target" or unit == "targettarget" then
        local tap = UnitIsTapDenied(unit)
        if not IsSecretValue(tap) and tap then
          color = COLOR_DEAD_OFFLINE
        end
      end

      if not color then
        local isPlayer = UnitIsPlayer(unit)
        if not IsSecretValue(isPlayer) and isPlayer then
          color = GetClassColorForUnit(unit)
        end
      end

      if not color then
        local reaction = UnitReaction(unit, "player")
        if reaction and not IsSecretValue(reaction) then
          color = FACTION_BAR_COLORS[reaction]
        end
      end
    end

    if color then
      return RGBPercToHex(color.r or 1, color.g or 1, color.b or 1)
    end
    return "ffffff"
  end

  ---------------------------------------------

  --colorsimple tag
  oUF.Tags.Methods["diablo:colorsimple"] = function(unit)
    local color = COLOR_WHITE
    if SafeDead(unit) or not SafeConnected(unit) then
      color = COLOR_DEAD_OFFLINE
    end
    if color then
      return RGBPercToHex(color.r,color.g,color.b)
    else
      return "ffffff"
    end
  end

  ---------------------------------------------

  --name tag
oUF.Tags.Methods["diablo:name"] = function(unit)
    local color = oUF.Tags.Methods["diablo:color"](unit)
    local name
    if IsAddOnLoaded("Totalrp3") and TRP3_API and TRP3_API.utils and TRP3_API.utils.str and TRP3_API.chat then
      local unitID = TRP3_API.utils.str.getUnitID(unit)
      name = unitID and TRP3_API.chat.getFullnameForUnitUsingChatMethod(unitID) or nil
    end
    if not name then
      name = UnitName(unit) or ""
    end
    local prefix = GetColorHex(color)
    if _G.C_StringUtil and _G.C_StringUtil.WrapString then
      return _G.C_StringUtil.WrapString(name, prefix, "|r")
    end
    if IsSecretValue(name) then
      return ""
    end
    return format("%s%s|r", prefix, name)
end
  oUF.Tags.Events["diablo:name"] = "UNIT_NAME_UPDATE UNIT_FLAGS UNIT_CONNECTION UNIT_FACTION PLAYER_TARGET_CHANGED"

  ---------------------------------------------
  
  --status tag
  oUF.Tags.Methods["diablo:status"] = function(unit, rolf)
    local color = oUF.Tags.Methods["diablo:colorsimple"](unit)
    local status
	if SafeDead(unit) then
		status = "Dead"
	elseif not SafeConnected(unit) then
		status = "Offline"
	end
    return format("%s%s|r", GetColorHex(color), status or "")
  end
  oUF.Tags.Events["diablo:status"] = "UNIT_FLAGS UNIT_CONNECTION"

  ---------------------------------------------

  --hp value
    oUF.Tags.Methods["diablo:hpval"] = function(unit)
    local color = oUF.Tags.Methods["diablo:colorsimple"](unit)
    local hpval
    if SafeDead(unit) then
      hpval = "Dead"
    elseif not SafeConnected(unit) then
      hpval = "Offline"
    else
      local cur = UnitHealth(unit)
      if IsSecretValue(cur) then
        hpval = ""
      else
        hpval = func.numFormat(cur or 0)
      end
    end
    return format("%s%s|r", GetColorHex(color), hpval or "")
  end
  oUF.Tags.Events["diablo:hpval"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  ---------------------------------------------

  --power value
  oUF.Tags.Methods["diablo:ppval"] = function(unit)
    local cur = UnitPower(unit)
    if IsSecretValue(cur) then
      return ""
    end
    local ppval = func.numFormat(cur or 0)
    return ppval or ""
  end
  oUF.Tags.Events["diablo:ppval"] = "UNIT_POWER_UPDATE UNIT_MAXPOWER"

  ---------------------------------------------

  --health current value (PostUpdate parity: DEAD/OFFLINE/current)
  oUF.Tags.Methods["diablo:hpcur"] = function(unit)
    if SafeDead(unit) then
      return DEAD or "DEAD"
    end
    if not SafeConnected(unit) then
      return PLAYER_OFFLINE or "OFFLINE"
    end
    local cur = oUF.Tags.Methods["curhp"](unit)
    if cur == nil or cur == "" then
      return ""
    end
    return func.numFormat(cur) or ""
  end
  oUF.Tags.Events["diablo:hpcur"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  ---------------------------------------------

  --health percent (PostUpdate parity: blank when dead/offline)
  oUF.Tags.Methods["diablo:hppct"] = function(unit)
    if SafeDead(unit) or (not SafeConnected(unit)) then
      return ""
    end
    local per = oUF.Tags.Methods["perhp"](unit)
    if per == nil or per == "" then
      return ""
    end
    local n = tonumber(per)
    if type(n) == "number" then
      return floor(n) .. "%"
    end
    return tostring(per)
  end
  oUF.Tags.Events["diablo:hppct"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  ---------------------------------------------

  --power current value
  oUF.Tags.Methods["diablo:ppcur"] = function(unit)
    local cur = oUF.Tags.Methods["curpp"](unit)
    if cur == nil or cur == "" then
      return ""
    end
    return func.numFormat(cur) or ""
  end
  oUF.Tags.Events["diablo:ppcur"] = "UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_CONNECTION"

  ---------------------------------------------

  --power percent
  oUF.Tags.Methods["diablo:pppct"] = function(unit)
    local per = oUF.Tags.Methods["perpp"](unit)
    if per == nil or per == "" then
      return ""
    end
    local n = tonumber(per)
    if type(n) == "number" then
      return floor(n) .. "%"
    end
    return tostring(per)
  end
  oUF.Tags.Events["diablo:pppct"] = "UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_CONNECTION"

  ---------------------------------------------

  oUF.Tags.Methods["diablo:misshp"] = function(unit)
    local color = oUF.Tags.Methods["diablo:colorsimple"](unit)
    local hpval
    if SafeDead(unit) then
      hpval = "Dead"
    elseif not SafeConnected(unit) then
      hpval = "Offline"
    else
	      local max, min = UnitHealthMax(unit), UnitHealth(unit)
	      if IsSecretValue(max) or IsSecretValue(min) then
	        hpval = ""
	      else
	        local missing = (max or 0) - (min or 0)
	        if missing > 0 then
	          hpval = "-"..func.numFormat(missing)
	        end
	      end
    end
    return format("%s%s|r", GetColorHex(color), hpval or "")
  end
  oUF.Tags.Events["diablo:misshp"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  ---------------------------------------------

  oUF.Tags.Methods["diablo:raidhp"] = function(unit, rolf)
    local color = oUF.Tags.Methods["diablo:color"](unit)
    local hpval
    if SafeDead(unit) then
      --hpval = "Dead"
      hpval = UnitName(rolf or unit)
    elseif not SafeConnected(unit) then
      hpval = UnitName(rolf or unit)
      --hpval = "Offline"
    else
	      local max, min = UnitHealthMax(unit), UnitHealth(unit)
	      if IsSecretValue(max) or IsSecretValue(min) then
	        hpval = UnitName(rolf or unit)
	      else
	        local missing = (max or 0) - (min or 0)
	        if missing > 0 then
	          hpval = "-"..func.numFormat(missing)
        --rewrite color to white
        color = "ffffff"
	        else
	          hpval = UnitName(rolf or unit)
	        end
	      end
    end
    return format("%s%s|r", GetColorHex(color), hpval or "")
  end
  oUF.Tags.Events["diablo:raidhp"] = "UNIT_NAME_UPDATE UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  ---------------------------------------------

  oUF.Tags.Methods["diablo:altbosspower"] = function(unit)
    local cur = UnitPower(unit, ALTERNATE_POWER_INDEX)
    local max = UnitPowerMax(unit, ALTERNATE_POWER_INDEX)
    local color = "0099ff"

    if IsSecretValue(cur) or IsSecretValue(max) then
      return nil
    end

    if cur == nil then cur = 0 end

    local dead = UnitIsDeadOrGhost(unit)
    if IsSecretValue(dead) then dead = false end
    if max and max > 0 and not dead then
      return format("%s%s%%|cff666666 / |r", GetColorHex(color), floor(cur/max*100))
    end
  end
  oUF.Tags.Events["diablo:altbosspower"] = "UNIT_POWER_UPDATE"

  ---------------------------------------------

  oUF.Tags.Methods["diablo:altpower"] = function(unit)
    local cur = UnitPower(unit, ALTERNATE_POWER_INDEX)
    local max = UnitPowerMax(unit, ALTERNATE_POWER_INDEX)

    if IsSecretValue(cur) or IsSecretValue(max) then
      return nil
    end

    if cur == nil or max == nil then
      return nil
    end

    if cur > 0 and max > 0 then
      return floor(cur).." / "..floor(max)
    end
  end
  oUF.Tags.Events["diablo:altpower"] = "UNIT_POWER_UPDATE"

  ---------------------------------------------

  --boss health value
  oUF.Tags.Methods["diablo:bosshp"] = function(unit)
    local val = oUF.Tags.Methods["perhp"](unit)
    return val or ""
  end
  oUF.Tags.Events["diablo:bosshp"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_TARGETABLE_CHANGED"
  
  --boss power value
  oUF.Tags.Methods["diablo:bosspp"] = function(unit)
    local dead = UnitIsDeadOrGhost(unit)
    if IsSecretValue(dead) then dead = false end
    if dead then return "" end

    local str = ""

    -- Power percentage (safe tag; returns "" if power values are secret)
    local per = oUF.Tags.Methods["perpp"](unit)
    if per ~= "" then
      str = str..per.."%"
    end

    -- Alternate power percentage (guard against secret values)
    local ap_cur = UnitPower(unit, ALTERNATE_POWER_INDEX)
    local ap_max = UnitPowerMax(unit, ALTERNATE_POWER_INDEX)
    local color = "0099ff"

    if IsSecretValue(ap_cur) or IsSecretValue(ap_max) then
      return str
    end

    if ap_max and ap_max > 0 then
      if ap_cur == nil then ap_cur = 0 end
      local ap_pct = floor(ap_cur/ap_max*100)
      if str ~= "" then
        str = format("%s (%s%s%%|r)", str, GetColorHex(color), ap_pct)
      else
        str = format("%s%s%%|r", GetColorHex(color), ap_pct)
      end
    end

    return str
  end
  oUF.Tags.Events["diablo:bosspp"] = "UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_TARGETABLE_CHANGED"

  ---------------------------------------------

  --topdefhp - the top healthorb value
  oUF.Tags.Methods["topdefhp"] = function(unit)
    local val = oUF.Tags.Methods["perhp"](unit)
    return val or ""
  end
  oUF.Tags.Events["topdefhp"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"


  ---------------------------------------------

  --botdefhp - the bottom healthorb value
  oUF.Tags.Methods["botdefhp"] = function(unit)
    local dead = UnitIsDeadOrGhost(unit)
    if IsSecretValue(dead) then dead = false end
    local connected = UnitIsConnected(unit)
    if IsSecretValue(connected) then connected = true end
    if dead then
      return  "Dead"
    elseif not connected then
      return "Offline"
    end
    local val = oUF.Tags.Methods["curhp"](unit)
    val = func.numFormat(val)
    return val or ""
  end
  oUF.Tags.Events["botdefhp"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  ---------------------------------------------

  --topdefpp - the top powerorb value
  oUF.Tags.Methods["topdefpp"] = function(unit)
    --we change power display based on power type
    --for mana users the top display is power percentage for all others it is current power value
    local powertype = select(2, UnitPowerType(unit))
    if IsSecretValue(powertype) then return "" end
    local val
    if powertype ~= "MANA" then
      val = oUF.Tags.Methods["curpp"](unit)
      val = func.numFormat(val)
    else
      val = oUF.Tags.Methods["perpp"](unit)
    end
    return val or ""
  end
  oUF.Tags.Events["topdefpp"] = "UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_CONNECTION"

  ---------------------------------------------

  --botdefpp - the bottom powerorb value
  oUF.Tags.Methods["botdefpp"] = function(unit)
    --we change power display based on power type
    --for non-mana users the bottom display is power percentage for mana users it is current power value
    local powertype = select(2, UnitPowerType(unit))
    if IsSecretValue(powertype) then return "" end
    local val
    if powertype ~= "MANA" then
      val = oUF.Tags.Methods["perpp"](unit)
    else
      val = oUF.Tags.Methods["curpp"](unit)
      val = func.numFormat(val)
    end
    return val or ""
  end
  oUF.Tags.Events["botdefpp"] = "UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_CONNECTION"

  ---------------------------------------------

  --curshp - curhp short
  oUF.Tags.Methods["curshp"] = function(unit)
    local val = oUF.Tags.Methods["curhp"](unit)
    val = func.numFormat(val)
    return val or ""
  end
  oUF.Tags.Events["curshp"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  ---------------------------------------------

  --maxshp - maxhp short
  oUF.Tags.Methods["maxshp"] = function(unit)
    local val = oUF.Tags.Methods["maxhp"](unit)
    val = func.numFormat(val)
    return val or ""
  end
  oUF.Tags.Events["maxshp"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  ---------------------------------------------

  local function IsTagValueMissing(v)
    return v == nil or v == ""
  end

  local function FormatTagValueShort(v)
    if IsTagValueMissing(v) then
      return ""
    end
    if type(v) == "number" then
      return func.numFormat(v)
    end
    local n = tonumber(v)
    if type(n) == "number" then
      return func.numFormat(n)
    end
    return tostring(v)
  end

  --cmaxhp - curhp / maxhp
  oUF.Tags.Methods["cmaxhp"] = function(unit)
    local cur = oUF.Tags.Methods["curhp"](unit)
    local max = oUF.Tags.Methods["maxhp"](unit)
    if IsTagValueMissing(cur) or IsTagValueMissing(max) then
      return ""
    end
    return FormatTagValueShort(cur).."/"..FormatTagValueShort(max)
  end
  oUF.Tags.Events["cmaxhp"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  ---------------------------------------------

  --cmaxshp - curhp / maxhp short
  oUF.Tags.Methods["cmaxshp"] = function(unit)
    local cur = oUF.Tags.Methods["curhp"](unit)
    local max = oUF.Tags.Methods["maxhp"](unit)
    if IsTagValueMissing(cur) or IsTagValueMissing(max) then
      return ""
    end
    local curText = func.numFormat(cur)
    local maxText = func.numFormat(max)
    if IsTagValueMissing(curText) or IsTagValueMissing(maxText) then
      return ""
    end
    return tostring(curText).."/"..tostring(maxText)
  end
  oUF.Tags.Events["cmaxshp"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  ---------------------------------------------

  --curspp - curpp short
  oUF.Tags.Methods["curspp"] = function(unit)
    local val = oUF.Tags.Methods["curpp"](unit)
    val = func.numFormat(val)
    return val or ""
  end
  oUF.Tags.Events["curspp"] = "UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_CONNECTION"

  ---------------------------------------------

  --maxspp - maxpp short
  oUF.Tags.Methods["maxspp"] = function(unit)
    local val = oUF.Tags.Methods["maxpp"](unit)
    val = func.numFormat(val)
    return val or ""
  end
  oUF.Tags.Events["maxspp"] = "UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_CONNECTION"

  ---------------------------------------------

  --cmaxpp - curpp / maxpp (secret-safe)
  oUF.Tags.Methods["cmaxpp"] = function(unit)
    local cur = oUF.Tags.Methods["curpp"](unit)
    local max = oUF.Tags.Methods["maxpp"](unit)
    if IsTagValueMissing(cur) or IsTagValueMissing(max) then
      return ""
    end
    return FormatTagValueShort(cur).."/"..FormatTagValueShort(max)
  end
  oUF.Tags.Events["cmaxpp"] = "UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_CONNECTION"


  ---------------------------------------------

  --cmaxspp - curpp / maxpp short (secret-safe)
  oUF.Tags.Methods["cmaxspp"] = function(unit)
    local cur = oUF.Tags.Methods["curpp"](unit)
    local max = oUF.Tags.Methods["maxpp"](unit)
    if IsTagValueMissing(cur) or IsTagValueMissing(max) then
      return ""
    end
    local curText = func.numFormat(cur)
    local maxText = func.numFormat(max)
    if IsTagValueMissing(curText) or IsTagValueMissing(maxText) then
      return ""
    end
    return tostring(curText).."/"..tostring(maxText)
  end
  oUF.Tags.Events["cmaxspp"] = "UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_CONNECTION"


  ---------------------------------------------

  --perphp - hp percent (Midnight safe, no string concatenation)
oUF.Tags.Methods["perphp"] = function(unit)
    local dead = UnitIsDeadOrGhost(unit)
    if IsSecretValue(dead) then dead = false end
    local connected = UnitIsConnected(unit)
    if IsSecretValue(connected) then connected = true end
    if dead then return "Dead" end
    if not connected then return "Offline" end
    local per = oUF.Tags.Methods["perhp"](unit)
    return per or ""
  end
  oUF.Tags.Events["perphp"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"


  ---------------------------------------------

  --perppp - pp percent (Midnight safe, no string concatenation)
oUF.Tags.Methods["perppp"] = function(unit)
    local per = oUF.Tags.Methods["perpp"](unit)
    return per or ""
  end
  oUF.Tags.Events["perppp"] = "UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_CONNECTION"


  ---------------------------------------------

  local orbTagCache = {
    healthTop = {},
    healthBottom = {},
    powerTop = {},
    powerBottom = {},
  }

  local function ResolveOrbTag(cache, orbType, valueCfg, which)
    local mode = orbText.GetValueMode(valueCfg, which)
    local tag = orbText.ResolveOufTag(orbType, mode)
    if not tag then
      cache.tag = nil
      cache.method = nil
      return nil
    end
    if cache.tag ~= tag then
      cache.tag = tag
      cache.method = oUF.Tags.Methods[tag]
    end
    return cache.method
  end

  --HealthOrbTop
  oUF.Tags.Methods["diablo:HealthOrbTop"] = function(unit)
    local cfg = ResolveOrbConfig("HEALTH")
    local fn = ResolveOrbTag(orbTagCache.healthTop, "HEALTH", cfg and cfg.value, "top")
    return fn and fn(unit) or ""
  end
  --oUF.Tags.Events["diablo:HealthOrbTop"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  ---------------------------------------------

  --HealthOrbBottom
  oUF.Tags.Methods["diablo:HealthOrbBottom"] = function(unit)
    local cfg = ResolveOrbConfig("HEALTH")
    local fn = ResolveOrbTag(orbTagCache.healthBottom, "HEALTH", cfg and cfg.value, "bottom")
    return fn and fn(unit) or ""
  end
  --oUF.Tags.Events["diablo:HealthOrbBottom"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  ---------------------------------------------

  --PowerOrbTop
  oUF.Tags.Methods["diablo:PowerOrbTop"] = function(unit)
    local cfg = ResolveOrbConfig("POWER")
    local fn = ResolveOrbTag(orbTagCache.powerTop, "POWER", cfg and cfg.value, "top")
    return fn and fn(unit) or ""
  end
  --oUF.Tags.Events["diablo:PowerOrbTop"] = "UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_CONNECTION"


  ---------------------------------------------

  --PowerOrbBottom
  oUF.Tags.Methods["diablo:PowerOrbBottom"] = function(unit)
    local cfg = ResolveOrbConfig("POWER")
    local fn = ResolveOrbTag(orbTagCache.powerBottom, "POWER", cfg and cfg.value, "bottom")
    return fn and fn(unit) or ""
  end
  --oUF.Tags.Events["diablo:PowerOrbBottom"] = "UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_CONNECTION"

  ---------------------------------------------
