-- Operation-specific forbidden-aspect guards.
--
-- A script object may be accessible while a particular operation remains
-- forbidden. Keep these checks separate from the generic region-access gate.

local addonName, ns = ...

local safety = assert(ns and ns.safety, "Roth_UI: safety is required by safety_aspects.lua")
local CanAccess = assert(safety.CanAccess, "Roth_UI: safety.CanAccess is required by safety_aspects.lua")
local CanUseRegion = assert(safety.CanUseRegion, "Roth_UI: safety.CanUseRegion is required by safety_aspects.lua")
local TryGet = assert(safety.TryGet, "Roth_UI: safety.TryGet is required by safety_aspects.lua")
local ReportGuardFailure = assert(safety.ReportGuardFailure, "Roth_UI: safety.ReportGuardFailure is required by safety_aspects.lua")
local pcall = pcall
local type = type

function safety.HasForbiddenAspect(region, aspect)
  if not CanAccess(region) or region == nil or aspect == nil or not CanAccess(aspect) then
    return true
  end

  local got, method = TryGet(region, "HasAnyForbiddenAspects")
  if got ~= true or type(method) ~= "function" then
    return false
  end

  local ok, value = pcall(method, region, aspect)
  if ok ~= true then
    ReportGuardFailure("HasAnyForbiddenAspects", value)
    return true
  end
  if not CanAccess(value) then
    return true
  end
  return value == true
end

function safety.CanUseRegionFor(region, aspect)
  if not CanUseRegion(region) then
    return false
  end
  if aspect ~= nil and safety.HasForbiddenAspect(region, aspect) then
    return false
  end
  return true
end
