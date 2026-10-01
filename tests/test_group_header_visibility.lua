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
expect(type(service.Park) == "function", "safe compatibility Park entry point is missing")

local calls = {}
local header = {}
function header:SetVisibility(value)
  calls[#calls + 1] = value
end

expect(service.Apply(header, "custom [group] show; hide") == true, "oUF visibility method failed")
expect(calls[1] == "custom [group] show; hide", "custom condition was changed before oUF")
expect(service.Apply(header, "custom [group] show; hide") == true, "idempotent apply failed")
expect(#calls == 1, "identical visibility was registered twice")

expect(service.Hide(header) == true and calls[2] == "hide", "hide state was not applied")
expect(service.Show(header) == true and calls[3] == "show", "show state was not applied")
expect(service.Park(header, "unused") == true and calls[4] == "hide", "Park must degrade to hide")
expect(header.parent == nil, "Park reparented a secure header")

inCombat = true
expect(service.Show(header) == false, "visibility mutation was allowed in combat")
expect(#calls == 4, "combat attempt reached the protected header")
inCombat = false

local fallback = {}
expect(service.Apply(fallback, "custom [party] show; hide") == true, "state-driver fallback failed")
expect(#fallbackCalls == 2, "fallback did not replace exactly one driver")
expect(fallbackCalls[1][1] == "unregister" and fallbackCalls[1][3] == "visibility",
  "fallback did not clear the previous visibility driver")
expect(fallbackCalls[2][1] == "register" and fallbackCalls[2][3] == "visibility",
  "fallback did not register the visibility driver")
expect(fallbackCalls[2][4] == "[party] show; hide", "fallback did not normalize custom prefix")

service.Forget(header)
expect(ns.GroupHeaderVisibility.states[header] == nil, "weak metadata was not cleared")

print("group header visibility test: OK")
