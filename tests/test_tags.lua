local function expect(ok, message)
  if not ok then error(message, 2) end
end

local inaccessible = {}
local inaccessibleColor = {}
local classColorCalls = 0
local ns = {
  safety = {},
  func = {
    IsSecretValue = function(v) return false end,
    GetClassColorForUnit = function()
      classColorCalls = classColorCalls + 1
      return { r = 1, g = 0, b = 0 }
    end,
  },
  oUF = { Tags = { Methods = {}, Events = {} } },
}
_G.issecretvalue = function() return false end
_G.canaccessvalue = function(v) return v ~= inaccessible and v ~= inaccessibleColor end
_G.UnitIsConnected = function() return inaccessible end
_G.UnitIsDeadOrGhost = function() return false end
_G.UnitIsTapDenied = function() return false end
_G.UnitReaction = function() return inaccessible end
_G.FACTION_BAR_COLORS = setmetatable({}, { __index = function() error("inaccessible reaction indexed color table") end })
assert(loadfile("core/safety.lua"))("Roth_UI", ns)
assert(loadfile("core/tags.lua"))("Roth_UI", ns)

local nameColor = ns.oUF.Tags.Methods["roth:namecolor"]
expect(nameColor("target") == "|cffff0000", "inaccessible reaction must fall back to the class color")
expect(classColorCalls == 1, "inaccessible reaction must not index its color table")
expect(nameColor(inaccessible) == "|cffffffff", "inaccessible unit token must return a safe fallback")
expect(classColorCalls == 1, "inaccessible unit token must not reach unit APIs or class lookup")

_G.UnitIsConnected = function() return false end
expect(nameColor("target") == "|cff808080", "ordinary disconnected status must retain unavailable styling")

print("tag access-boundary test: OK")
