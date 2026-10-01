local function fail(message)
  error(message, 2)
end

local function expect(condition, message)
  if not condition then fail(message) end
end

_G.issecretvalue = function() return false end
_G.canaccessvalue = function() return true end
_G.canaccessallvalues = function() return true end

local inCombat = false
_G.InCombatLockdown = function() return inCombat end

local eventFrames = {}
_G.CreateFrame = function()
  local frame = { events = {}, scripts = {} }
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:UnregisterEvent(event) self.events[event] = nil end
  function frame:SetScript(script, callback) self.scripts[script] = callback end
  eventFrames[#eventFrames + 1] = frame
  return frame
end

local ns = {}
assert(loadfile("core/safety.lua"))("Roth_UI", ns)
assert(loadfile("core/frame_policy.lua"))("Roth_UI", ns)
local policy = assert(ns.framePolicy)

local function NewRegion()
  local region = { alpha = 0.75, mouse = true, mutations = 0 }
  function region:HasAccessConstraints() return false end
  function region:IsForbidden() return false end
  function region:GetAlpha() return self.alpha end
  function region:IsMouseEnabled() return self.mouse end
  function region:SetAlpha(value) self.alpha = value; self.mutations = self.mutations + 1 end
  function region:EnableMouse(value) self.mouse = value; self.mutations = self.mutations + 1 end
  return region
end

local region = NewRegion()
expect(policy.SetSuppressed(region, true) == true, "ordinary suppression failed")
expect(region.alpha == 0 and region.mouse == false, "suppression state was not applied")
expect(policy.GetSuppressionState(region) == true, "suppression state was not recorded")
expect(policy.SetSuppressed(region, false) == true, "ordinary restore failed")
expect(region.alpha == 0.75 and region.mouse == true, "captured frame state was not restored")
expect(policy.GetSuppressionState(region) == false, "restored state was not recorded")

inCombat = true
expect(policy.SetSuppressed(region, true) == false, "combat suppression was not deferred")
expect(policy.SetSuppressed(region, false) == false, "latest combat state was not coalesced")
expect(policy.GetPendingCount() == 1, "same-frame combat work was not coalesced")
expect(#eventFrames == 1, "deferral created more than one event frame")
local regenFrame = eventFrames[1]
expect(regenFrame.events.PLAYER_REGEN_ENABLED == true, "regen event was not registered")

inCombat = false
regenFrame.scripts.OnEvent(regenFrame, "PLAYER_REGEN_ENABLED")
expect(policy.GetPendingCount() == 0, "pending queue did not drain")
expect(regenFrame.events.PLAYER_REGEN_ENABLED == nil, "regen event remained permanently registered")
expect(region.alpha == 0.75 and region.mouse == true, "latest deferred state did not win")

local callbackValue = 0
inCombat = true
expect(policy.DeferUntilOutOfCombat("shared", function() callbackValue = 1 end) == true,
  "first keyed callback was not deferred")
expect(policy.DeferUntilOutOfCombat("shared", function() callbackValue = 2 end) == true,
  "replacement keyed callback was not deferred")
expect(policy.GetPendingCount() == 1, "keyed callbacks were not coalesced")
expect(regenFrame.events.PLAYER_REGEN_ENABLED == true, "regen event did not re-register")
inCombat = false
regenFrame.scripts.OnEvent(regenFrame, "PLAYER_REGEN_ENABLED")
expect(callbackValue == 2, "latest keyed callback did not run")
expect(regenFrame.events.PLAYER_REGEN_ENABLED == nil, "regen event remained after second drain")

local inaccessible = NewRegion()
function inaccessible:HasAccessConstraints() return true end
function inaccessible:CanBeAccessedInContext() return false end
expect(policy.SetSuppressed(inaccessible, true) == false, "inaccessible region was mutated")
expect(inaccessible.mutations == 0, "inaccessible region received visual/input mutations")

expect(ns.IsRothEnabled("blizzard") == false, "provider normalization rejected Blizzard mode")
expect(ns.IsRothEnabled("roth") == true, "provider normalization rejected Roth mode")

print("frame policy test: OK")
