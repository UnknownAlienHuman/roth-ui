local function fail(message)
  error(message, 2)
end

local function expect(condition, message)
  if not condition then fail(message) end
end

local inCombat = false
_G.InCombatLockdown = function() return inCombat end

local fallbackCalls = {}
_G.UnregisterStateDriver = function(frame, state)
  fallbackCalls[#fallbackCalls + 1] = { "unregister", frame, state }
end
_G.RegisterStateDriver = function(frame, state, condition)
  fallbackCalls[#fallbackCalls + 1] = { "register", frame, state, condition }
end

local ns = {
  safety = {
    TryCall = function(fn, ...)
      local ok, value = pcall(fn, ...)
      return ok, value
    end,
  },
}

assert(loadfile("core/group_header_visibility.lua"))("Roth_UI", ns)
local service = assert(ns.GroupHeaderVisibility)
expect(type(service.Apply) == "function", "visibility owner was not published")
expect(type(service.ApplyDesired) == "function", "desired visibility API is missing")
expect(type(service.Park) == "function", "safe compatibility Park entry point is missing")

local calls = {}
local header = {}
function header:SetVisibility(value)
  calls[#calls + 1] = value
end

expect(service.Apply(header, "custom [group] show; hide") == true, "oUF visibility method failed")
expect(calls[1] == "custom [group] show; hide", "custom condition was changed before oUF")
expect(service.GetDesired(header) == "custom [group] show; hide", "desired visibility was not retained")
expect(service.Apply(header, "custom [group] show; hide") == true, "idempotent apply failed")
expect(#calls == 1, "identical visibility was registered twice")

expect(service.Hide(header) == true and calls[2] == "custom hide",
  "hide state did not use the exact oUF custom path")
expect(service.GetDesired(header) == "custom [group] show; hide",
  "temporary hide overwrote desired visibility")
expect(service.ApplyDesired(header) == true and calls[3] == "custom [group] show; hide",
  "desired visibility was not restored after hide")
expect(service.Show(header) == true and calls[4] == "custom show",
  "show state did not use the exact oUF custom path")
expect(service.GetDesired(header) == "custom [group] show; hide",
  "temporary show overwrote desired visibility")
expect(service.ApplyDesired(header) == true and calls[5] == "custom [group] show; hide",
  "desired visibility was not restored after show")
expect(service.Park(header, "unused") == true and calls[6] == "custom hide",
  "Park must degrade to exact hide")
expect(header.parent == nil, "Park reparented a secure header")

inCombat = true
expect(service.Show(header) == false, "visibility mutation was allowed in combat")
expect(#calls == 6, "combat attempt reached the protected header")
inCombat = false

local fallback = {}
expect(service.Apply(fallback, "show") == true, "unconditional fallback show failed")
expect(#fallbackCalls == 2, "fallback show did not replace exactly one driver")
expect(fallbackCalls[1][1] == "unregister" and fallbackCalls[1][3] == "visibility",
  "fallback did not clear the previous visibility driver")
expect(fallbackCalls[2][1] == "register" and fallbackCalls[2][3] == "visibility",
  "fallback did not register the visibility driver")
expect(fallbackCalls[2][4] == "show", "fallback unconditional show was not preserved")
expect(service.GetDesired(fallback) == "custom show", "fallback desired visibility was not normalized")

expect(service.Apply(fallback, "custom [party] show; hide") == true, "conditional fallback failed")
expect(#fallbackCalls == 4, "conditional fallback did not replace exactly one driver")
expect(fallbackCalls[4][4] == "[party] show; hide", "fallback did not normalize custom prefix")

service.Forget(header)
expect(ns.GroupHeaderVisibility.states[header] == nil, "weak metadata was not cleared")

print("group header visibility test: OK")
