-- Secure oUF group-header visibility owner.
--
-- oUF owns the protected header and exposes SetVisibility. Roth keeps only the
-- desired/applied ordinary policy in a private weak table and never installs a
-- parallel state driver or publishes the bookkeeping table.

local _, ns = ...

local safety = assert(ns and ns.safety, "Roth_UI: ns.safety is required by group_header_visibility.lua")
local CanAccess = assert(safety.CanAccess, "Roth_UI: safety.CanAccess is required by group_header_visibility.lua")
local IsSecret = assert(safety.IsSecret, "Roth_UI: safety.IsSecret is required by group_header_visibility.lua")
local CanUseRegion = assert(safety.CanUseRegion, "Roth_UI: safety.CanUseRegion is required by group_header_visibility.lua")
local TryMethod = assert(safety.TryMethod, "Roth_UI: safety.TryMethod is required by group_header_visibility.lua")
local InCombatLockdown = InCombatLockdown
local type = type
local setmetatable = setmetatable

local service = ns.GroupHeaderVisibility or {}
ns.GroupHeaderVisibility = service

local states = setmetatable({}, { __mode = "k" })

local function ResolveVisibility(visibility)
  if not CanAccess(visibility) or IsSecret(visibility) or type(visibility) ~= "string" then
    return nil
  end
  local value = visibility:match("^%s*(.-)%s*$")
  if value == "" then
    return nil
  end

  -- oUF only recognizes named shorthands such as party/raid/solo. Passing the
  -- literal word "show" through its shorthand path resolves to "hide". Force
  -- exact unconditional states through the documented custom-condition path.
  if value == "show" or value == "hide" then
    return "custom " .. value
  end
  return value
end

local function GetState(frame)
  local state = states[frame]
  if not state then
    state = {}
    states[frame] = state
  end
  return state
end

local function ApplyResolved(frame, value)
  if not value or not CanUseRegion(frame) then
    return false
  end
  if InCombatLockdown and InCombatLockdown() then
    return false
  end

  local state = GetState(frame)
  if state.applied == value then
    return true
  end

  if TryMethod(frame, "SetVisibility", value) ~= true then
    return false
  end

  state.applied = value
  return true
end

function service.Apply(frame, visibility)
  local value = ResolveVisibility(visibility)
  if not value or not CanUseRegion(frame) then
    return false
  end
  GetState(frame).desired = value
  return ApplyResolved(frame, value)
end

function service.ApplyDesired(frame, fallback)
  if not CanUseRegion(frame) then
    return false
  end
  local state = states[frame]
  local value = state and state.desired or ResolveVisibility(fallback)
  return ApplyResolved(frame, value)
end

function service.Hide(frame)
  return ApplyResolved(frame, "custom hide")
end

function service.Show(frame)
  return ApplyResolved(frame, "custom show")
end
