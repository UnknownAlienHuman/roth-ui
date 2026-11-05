local function fail(message)
  error(message, 2)
end

local function expect(condition, message)
  if not condition then fail(message) end
end

_G.issecretvalue = function() return false end
local denied = setmetatable({}, { __mode = "k" })
_G.canaccessvalue = function(value) return denied[value] ~= true end
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
expect(policy.SetSuppressed(region, "yes") == false,
  "non-boolean suppression state was accepted")
expect(region.mutations == 0, "invalid suppression state mutated a foreign frame")
expect(policy.SetSuppressed(region, false) == true, "unsuppressed no-op failed")
expect(region.mutations == 0, "unsuppressed no-op mutated a Blizzard frame")

expect(policy.SetSuppressed(region, true) == true, "ordinary suppression failed")
expect(region.alpha == 0 and region.mouse == false, "suppression state was not applied")
expect(policy.GetSuppressionState(region) == true, "suppression state was not recorded")
expect(policy.SetSuppressed(region, false) == true, "ordinary restore failed")
expect(region.alpha == 0.75 and region.mouse == true, "captured frame state was not restored")
expect(policy.GetSuppressionState(region) == false, "restored state was not cleared")

local outsideAlpha = NewRegion()
expect(policy.SetSuppressed(outsideAlpha, true) == true, "alpha ownership setup failed")
outsideAlpha.alpha = 0.35
expect(policy.SetSuppressed(outsideAlpha, false) == true, "external alpha change blocked restore")
expect(outsideAlpha.alpha == 0.35 and outsideAlpha.mouse == true,
  "restore overwrote an alpha change made by another owner")

local outsideMouse = NewRegion()
expect(policy.SetSuppressed(outsideMouse, true) == true, "mouse ownership setup failed")
outsideMouse.mouse = true
expect(policy.SetSuppressed(outsideMouse, false) == true, "external mouse change blocked restore")
expect(outsideMouse.alpha == 0.75 and outsideMouse.mouse == true,
  "restore overwrote a mouse change made by another owner")

region.alpha = 0.45
region.mouse = false
expect(policy.SetSuppressed(region, true) == true, "second suppression failed")
expect(region.alpha == 0 and region.mouse == false, "second suppression was not applied")
expect(policy.SetSuppressed(region, false) == true, "second restore failed")
expect(region.alpha == 0.45 and region.mouse == false,
  "second restore replayed a stale suppression snapshot")

local partial = NewRegion()
local mouseSetter = partial.EnableMouse
partial.EnableMouse = function() error("temporary setter failure") end
expect(policy.SetSuppressed(partial, true) == false, "partial failure was reported as success")
expect(partial.alpha == 0.75 and partial.mouse == true,
  "partial suppression failure did not roll back ordinary frame state")
expect(policy.GetSuppressionState(partial) == false,
  "partial suppression failure published a suppressed state")
partial.EnableMouse = mouseSetter
expect(policy.SetSuppressed(partial, true) == true, "later explicit suppression failed")
expect(policy.SetSuppressed(partial, false) == true, "partial cycle did not restore")
expect(partial.alpha == 0.75 and partial.mouse == true, "partial retry lost the original snapshot")

local mutateThenFail = NewRegion()
local originalMouseSetter = mutateThenFail.EnableMouse
mutateThenFail.EnableMouse = function(self, value)
  originalMouseSetter(self, value)
  error("failed after mutation")
end
expect(policy.SetSuppressed(mutateThenFail, true) == false,
  "mutating setter failure was reported as success")
expect(mutateThenFail.alpha == 0.75 and mutateThenFail.mouse == true,
  "mutating setter failure escaped transactional rollback")

local partialRestore = NewRegion()
expect(policy.SetSuppressed(partialRestore, true) == true, "partial restore setup failed")
local restoreMouseSetter = partialRestore.EnableMouse
partialRestore.EnableMouse = function() error("temporary restore failure") end
expect(policy.SetSuppressed(partialRestore, false) == false, "partial restore failure was reported as success")
expect(partialRestore.alpha == 0.75 and partialRestore.mouse == false,
  "partial restore did not isolate the failed property")
partialRestore.EnableMouse = restoreMouseSetter
local alphaMutations = partialRestore.mutations
expect(policy.SetSuppressed(partialRestore, false) == true, "partial restore retry failed")
expect(partialRestore.alpha == 0.75 and partialRestore.mouse == true,
  "partial restore retry lost the original snapshot")
expect(partialRestore.mutations == alphaMutations + 1,
  "partial restore retry mutated an already-restored property")

local unreadable = NewRegion()
unreadable.GetAlpha = function() error("alpha unavailable") end
expect(policy.SetSuppressed(unreadable, true) == false, "unknown original state was guessed")
expect(unreadable.mutations == 0, "suppression mutated a frame without a restorable snapshot")

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
expect(region.alpha == 0.45 and region.mouse == false, "latest deferred state did not win")

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

-- Object-scoped work must use weak identity, not tostring(ScriptObject).
local tostringCalls = 0
local identityRegion = NewRegion()
setmetatable(identityRegion, {
  __tostring = function()
    tostringCalls = tostringCalls + 1
    error("foreign object must not be stringified")
  end,
})
inCombat = true
local objectCallback = 0
expect(policy.DeferForObject("test-owner", identityRegion, function() objectCallback = 1 end) == true,
  "object-scoped work was not deferred")
expect(policy.DeferForObject("test-owner", identityRegion, function() objectCallback = 2 end) == true,
  "object-scoped replacement was not deferred")
expect(policy.GetPendingCount() == 1, "object-scoped work was not coalesced")
inCombat = false
regenFrame.scripts.OnEvent(regenFrame, "PLAYER_REGEN_ENABLED")
expect(objectCallback == 2, "latest object-scoped callback did not win")
expect(tostringCalls == 0, "object-scoped deferral stringified a ScriptObject")
expect(policy.DeferForObject("test-owner", "not-an-object", function() end) == false,
  "object-scoped deferral accepted a primitive identity")
expect(policy.DeferForObject("test-owner", identityRegion, function() end) == false,
  "object-scoped deferral allocated work outside combat")

local restrictedProvider = {}
denied[restrictedProvider] = true
expect(ns.IsRothEnabled(restrictedProvider) == false,
  "provider normalization branched on an inaccessible value")
expect(policy.GetSuppressionState(restrictedProvider) == false,
  "suppression state indexed an inaccessible object")

local inaccessible = NewRegion()
function inaccessible:HasAccessConstraints() return true end
function inaccessible:CanBeAccessedInContext() return false end
expect(policy.SetSuppressed(inaccessible, true) == false, "inaccessible region was mutated")
expect(inaccessible.mutations == 0, "inaccessible region received visual/input mutations")

expect(ns.IsRothEnabled("blizzard") == false, "provider normalization rejected Blizzard mode")
expect(ns.IsRothEnabled("roth") == true, "provider normalization rejected Roth mode")

print("frame policy test: OK")
