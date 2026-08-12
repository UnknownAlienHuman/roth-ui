local addonName, ns = ...

local controller = ns.OrbTextController or {}
ns.OrbTextController = controller

local type = type
local string_lower = string.lower

local VALID_MODES = {
  current = true,
  max = true,
  percent = true,
}

local DEFAULT_LAYOUT = {
  top = "current",
  bottom = "percent",
}

local MODE_OPTIONS = {
  { label = "Current Value", value = "current" },
  { label = "Maximum Value", value = "max" },
  { label = "Percent", value = "percent" },
}

local LEGACY_MODE_ALIASES = {
  current = "current",
  cur = "current",
  curs = "current",
  cmax = "current",
  cmaxs = "current",
  max = "max",
  maxs = "max",
  percent = "percent",
  per = "percent",
  perp = "percent",
  topdef = "__top_default__",
  topdefhp = "__top_default__",
  topdefpp = "__top_default__",
  botdef = "__bottom_default__",
  botdefhp = "__bottom_default__",
  botdefpp = "__bottom_default__",
  null = "__default__",
}

local MODE_TO_TAG_BASE = {
  current = "cur",
  max = "max",
  percent = "perp",
}

local function NormalizeToken(rawMode)
  if type(rawMode) ~= "string" then
    return nil
  end

  local token = rawMode:gsub("^%s+", ""):gsub("%s+$", "")
  if token == "" then
    return nil
  end

  local wrapped = token:match("^%[(.-)%]$")
  if wrapped then
    token = wrapped
  end
  if token:sub(-1) == "%" then
    token = token:sub(1, -2)
  end

  token = string_lower(token)
  token = token:gsub("^diablo:", "")
  return LEGACY_MODE_ALIASES[token] or token
end

local function NormalizeNodeMode(node)
  if type(node) == "table" then
    return node.mode or node.tag
  end
  return node
end

function controller.GetDefaultMode(which)
  return DEFAULT_LAYOUT[which] or DEFAULT_LAYOUT.top
end

function controller.GetValueModeOptions()
  local copy = {}
  for i = 1, #MODE_OPTIONS do
    copy[i] = {
      label = MODE_OPTIONS[i].label,
      value = MODE_OPTIONS[i].value,
    }
  end
  return copy
end

function controller.NormalizeMode(which, rawMode, fallbackMode)
  local token = NormalizeToken(rawMode)
  if token == "__top_default__" then
    return controller.GetDefaultMode("top")
  end
  if token == "__bottom_default__" then
    return controller.GetDefaultMode("bottom")
  end
  if VALID_MODES[token] then
    return token
  end

  local fallbackToken = NormalizeToken(fallbackMode)
  if fallbackToken == "__top_default__" then
    return controller.GetDefaultMode("top")
  end
  if fallbackToken == "__bottom_default__" then
    return controller.GetDefaultMode("bottom")
  end
  if VALID_MODES[fallbackToken] then
    return fallbackToken
  end

  return controller.GetDefaultMode(which)
end

function controller.GetValueMode(valueCfg, which, fallbackMode)
  local rawMode = type(valueCfg) == "table" and NormalizeNodeMode(valueCfg[which]) or nil
  return controller.NormalizeMode(which, rawMode, fallbackMode)
end

function controller.NormalizeValueConfig(cfg, defaultCfg)
  if type(cfg) ~= "table" then
    return
  end

  local value = cfg.value
  if type(value) ~= "table" then
    value = {}
    cfg.value = value
  end

  if value.bot ~= nil then
    if value.bottom == nil then
      value.bottom = value.bot
    end
    value.bot = nil
  end

  if type(value.top) ~= "table" then
    value.top = { mode = value.top }
  end
  if type(value.bottom) ~= "table" then
    value.bottom = { mode = value.bottom }
  end

  if value.top.mode == nil then
    value.top.mode = value.top.tag
  end
  if value.bottom.mode == nil then
    value.bottom.mode = value.bottom.tag
  end

  local defaultsValue = type(defaultCfg) == "table" and defaultCfg.value or nil
  value.top.mode = controller.NormalizeMode("top", value.top.mode, controller.GetValueMode(defaultsValue, "top"))
  value.bottom.mode = controller.NormalizeMode("bottom", value.bottom.mode, controller.GetValueMode(defaultsValue, "bottom"))
  value.top.tag = nil
  value.bottom.tag = nil
end

function controller.ResolveTagBase(mode)
  mode = controller.NormalizeMode("top", mode)
  return MODE_TO_TAG_BASE[mode]
end

function controller.ResolveOufTag(orbType, mode)
  local base = controller.ResolveTagBase(mode)
  if not base then
    return nil
  end

  if orbType == "HEALTH" then
    return base .. "hp"
  end
  if orbType == "POWER" then
    return base .. "pp"
  end

  return base
end
