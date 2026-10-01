-- Secure oUF group-header visibility owner.
--
-- oUF creates protected SecureGroupHeaderTemplate frames and retains them in
-- its header registry. Roth UI therefore never reparents or respawns an active
-- header to apply settings. Visibility is updated out of combat through oUF's
-- public header method when available; ordinary bookkeeping stays in a weak
-- addon-owned table rather than on the protected frame.

local addon, ns = ...

local safety = assert(ns and ns.safety, "Roth_UI: ns.safety is required by group_header_visibility.lua")
local TryCall = assert(safety.TryCall, "Roth_UI: safety.TryCall is required by group_header_visibility.lua")
local InCombatLockdown = InCombatLockdown
local RegisterStateDriver = RegisterStateDriver
local UnregisterStateDriver = UnregisterStateDriver
local type = type
local setmetatable = setmetatable

local service = ns.GroupHeaderVisibility or {}
ns.GroupHeaderVisibility = service

local states = service.states or setmetatable({}, { __mode = "k" })
service.states = states

local function ResolveVisibility(visibility)
  if type(visibility) ~= "string" then
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

local function ResolveFallbackCondition(visibility)
  local custom = visibility:match("^custom%s+(.+)$")
  return custom or visibility
end

local function GetState(frame)
  local state = states[frame]
  if not state then
    state = {}
    states[frame] = state
  end
  return state
end

function service.Apply(frame, visibility)
  if not frame then
    return false
  end

  local value = ResolveVisibility(visibility)
  if not value then
    return false
  end
  if InCombatLockdown and InCombatLockdown() then
    return false
  end

  local state = GetState(frame)
  if state.applied == value then
    return true
  end

  local ok
  if type(frame.SetVisibility) == "function" then
    ok = TryCall(frame.SetVisibility, frame, value)
  else
    if type(RegisterStateDriver) ~= "function" then
      return false
    end
    if type(UnregisterStateDriver) == "function" then
      TryCall(UnregisterStateDriver, frame, "visibility")
    end
    ok = TryCall(RegisterStateDriver, frame, "visibility", ResolveFallbackCondition(value))
  end

  if ok == true then
    state.applied = value
    return true
  end
  return false
end

function service.Hide(frame)
  return service.Apply(frame, "hide")
end

function service.Show(frame)
  return service.Apply(frame, "show")
end

-- Historical rebuild code called Park before spawning another secure header.
-- Secure headers cannot be destroyed and oUF retains them, so reparenting is
-- prohibited. Keep this compatibility entry point as hide-only fail-safe.
function service.Park(frame)
  return service.Hide(frame)
end

function service.Forget(frame)
  if frame then
    states[frame] = nil
  end
end
