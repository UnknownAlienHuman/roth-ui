local addonName, ns = ...

-- Runtime orb text accepts only the current schema. Historical token migration
-- lives in orb_persistence_owner.lua and is never executed in the hot update path.
local controller = ns.OrbTextController or {}
ns.OrbTextController = controller

local type = type
local lower = string.lower

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

local function NormalizeCurrentToken(rawMode)
  if type(rawMode) ~= "string" then return nil end
  local token = lower(rawMode:gsub("^%s+", ""):gsub("%s+$", ""))
  return VALID_MODES[token] and token or nil
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
  return NormalizeCurrentToken(rawMode)
    or NormalizeCurrentToken(fallbackMode)
    or controller.GetDefaultMode(which)
end

function controller.GetValueMode(valueCfg, which, fallbackMode)
  local node = type(valueCfg) == "table" and valueCfg[which] or nil
  local rawMode = type(node) == "table" and node.mode or node
  return controller.NormalizeMode(which, rawMode, fallbackMode)
end

function controller.NormalizeValueConfig(cfg, defaultCfg)
  if type(cfg) ~= "table" then return end

  local value = cfg.value
  if type(value) ~= "table" then
    value = {}
    cfg.value = value
  end
  if type(value.top) ~= "table" then value.top = { mode = value.top } end
  if type(value.bottom) ~= "table" then value.bottom = { mode = value.bottom } end

  local defaultsValue = type(defaultCfg) == "table" and defaultCfg.value or nil
  value.top.mode = controller.NormalizeMode("top", value.top.mode, controller.GetValueMode(defaultsValue, "top"))
  value.bottom.mode = controller.NormalizeMode("bottom", value.bottom.mode, controller.GetValueMode(defaultsValue, "bottom"))
end
