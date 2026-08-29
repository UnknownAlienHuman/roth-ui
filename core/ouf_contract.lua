-- Fail-fast contract for the external oUF runtime required by Roth UI.
--
-- No compatibility layer is retained for legacy oUF element/color/aura APIs.
-- Development builds with an unexpanded version token are accepted only when
-- the complete capability surface used by Roth UI is present.

local addonName, ns = ...

local oUF = assert(ns and ns.oUF, "Roth_UI: oUF is required by ouf_contract.lua")
local C_AddOns = C_AddOns
local CanAccess = assert(ns.safety and ns.safety.CanAccess, "Roth_UI: safety.CanAccess is required by ouf_contract.lua")
local type = type
local tonumber = tonumber

local MIN_MAJOR, MIN_MINOR, MIN_PATCH = 14, 0, 2

local REQUIRED_METHODS = {
  "AddElement",
  "AddMetaElement",
  "RegisterInitCallback",
  "RegisterStyle",
  "SetActiveStyle",
  "Spawn",
}

local function ParseVersion(value)
  if not CanAccess(value) or type(value) ~= "string" then return nil end
  local major, minor, patch = value:match("(%d+)%.(%d+)%.(%d+)")
  major, minor, patch = tonumber(major), tonumber(minor), tonumber(patch)
  if not (major and minor and patch) then return nil end
  return major, minor, patch
end

local function IsOlder(major, minor, patch)
  if major ~= MIN_MAJOR then return major < MIN_MAJOR end
  if minor ~= MIN_MINOR then return minor < MIN_MINOR end
  return patch < MIN_PATCH
end

for index = 1, #REQUIRED_METHODS do
  local methodName = REQUIRED_METHODS[index]
  assert(type(oUF[methodName]) == "function", "Roth_UI: incompatible oUF; missing " .. methodName)
end

assert(type(AnchorUtil) == "table"
    and type(AnchorUtil.FlowLayoutAxis) == "table"
    and AnchorUtil.FlowLayoutAxis.Horizontal ~= nil
    and AnchorUtil.FlowLayoutAxis.Vertical ~= nil,
  "Roth_UI: Retail 12.1 flow-layout API is unavailable")
assert(type(AuraContainerSortMethod) == "table"
    and type(AuraContainerSortDirection) == "table",
  "Roth_UI: Retail 12.1 managed-aura enums are unavailable")
assert(type(Enum) == "table"
    and type(Enum.StatusBarInterpolation) == "table"
    and Enum.StatusBarInterpolation.Immediate ~= nil,
  "Roth_UI: native status-bar interpolation API is unavailable")

local version
if type(C_AddOns) == "table" and type(C_AddOns.GetAddOnMetadata) == "function" then
  version = C_AddOns.GetAddOnMetadata("oUF", "Version")
end
local major, minor, patch = ParseVersion(version)
if major and IsOlder(major, minor, patch) then
  error(("Roth_UI: oUF %d.%d.%d is too old; version 14.0.2 or newer is required")
    :format(major, minor, patch), 0)
end

ns.oUFContract = {
  minimumVersion = "14.0.2",
  detectedVersion = version,
  managedAuras = true, -- verified when the first oUF frame is initialized
  nativeInterpolation = true,
}
