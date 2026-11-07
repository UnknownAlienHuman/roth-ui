local function fail(message)
  error(message, 2)
end

local function expect(condition, message)
  if not condition then fail(message) end
end

local inCombat = false
_G.InCombatLockdown = function() return inCombat end
_G.RegisterStateDriver = function() fail("parallel state-driver fallback was used") end
_G.UnregisterStateDriver = function() fail("parallel state-driver fallback was used") end

local blocked = {}
local secret = {}
local ns = {
  safety = {
    CanAccess = function(value) return value ~= blocked end,
    IsSecret = function(value) return value == secret end,
    CanUseRegion = function(value)
      return type(value) == "table" and value.allowed ~= false
    end,
    TryMethod = function(value, key, ...)
      if type(value) ~= "table" or type(value[key]) ~= "function" then
        return false
      end
      local ok, result = pcall(value[key], value, ...)
      return ok, result
    end,
  },
}

assert(loadfile("core/group_header_visibility.lua"))("Roth_UI", ns)
local service = assert(ns.GroupHeaderVisibility)
expect(type(service.Apply) == "function", "visibility owner was not published")
expect(type(service.ApplyDesired) == "function", "desired visibility API is missing")
expect(service.SetDesired == nil and service.GetDesired == nil
    and service.Park == nil and service.Forget == nil and service.states == nil,
  "visibility owner published retired bookkeeping or compatibility APIs")

local calls = {}
local header = { allowed = true }
function header:SetVisibility(value)
  calls[#calls + 1] = value
end

expect(service.Apply(header, "custom [group] show; hide") == true, "oUF visibility method failed")
expect(calls[1] == "custom [group] show; hide", "custom condition was changed before oUF")
expect(service.Apply(header, "custom [group] show; hide") == true, "idempotent apply failed")
expect(#calls == 1, "identical visibility was registered twice")

expect(service.Hide(header) == true and calls[2] == "custom hide",
  "hide state did not use the exact oUF custom path")
expect(service.ApplyDesired(header) == true and calls[3] == "custom [group] show; hide",
  "desired visibility was not restored after hide")
expect(service.Show(header) == true and calls[4] == "custom show",
  "show state did not use the exact oUF custom path")
expect(service.ApplyDesired(header) == true and calls[5] == "custom [group] show; hide",
  "desired visibility was not restored after show")

inCombat = true
expect(service.Show(header) == false, "visibility mutation was allowed in combat")
expect(#calls == 5, "combat attempt reached the protected header")
inCombat = false

header.allowed = false
expect(service.Apply(header, "show") == false, "inaccessible header was accepted")
expect(#calls == 5, "inaccessible header reached SetVisibility")
header.allowed = true

expect(service.Apply(header, blocked) == false, "inaccessible visibility was evaluated")
expect(service.Apply(header, secret) == false, "secret visibility was evaluated")
expect(service.Apply(header, "   ") == false, "empty visibility was accepted")
expect(#calls == 5, "rejected visibility reached SetVisibility")

local missingMethod = { allowed = true }
expect(service.Apply(missingMethod, "show") == false,
  "header without the required oUF SetVisibility contract was accepted")

print("group header visibility owner test: OK")
