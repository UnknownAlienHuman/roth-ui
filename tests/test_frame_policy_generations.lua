local function expect(value, message)
  if not value then error(message, 2) end
end

_G.issecretvalue = function() return false end
_G.canaccessvalue = function() return true end
_G.canaccessallvalues = function() return true end
local inCombat = false
_G.InCombatLockdown = function() return inCombat end
local events = {}
_G.CreateFrame = function()
  local frame = {}
  function frame:RegisterEvent(event) events[event] = true end
  function frame:UnregisterEvent(event) events[event] = nil end
  function frame:SetScript() end
  return frame
end
local ns = {}
assert(loadfile("core/safety.lua"))("Roth_UI", ns)
assert(loadfile("core/frame_policy.lua"))("Roth_UI", ns)
local policy = ns.framePolicy
local failures = {}
local function check(name, fn)
  inCombat = false
  policy.FlushPending()
  local ok, message = pcall(fn)
  if not ok then failures[#failures + 1] = name .. ": " .. message end
end

check("newer immediate keyed request", function()
  local state = "old"
  inCombat = true
  expect(policy.DeferUntilOutOfCombat("latest", function() state = "stale" end), "not queued")
  inCombat = false
  expect(not policy.DeferUntilOutOfCombat("latest", function() state = "unused" end), "immediate request queued")
  state = "new"
  policy.FlushPending()
  expect(state == "new", "stale callback overwrote newer immediate work")
  expect(not events.PLAYER_REGEN_ENABLED, "empty queue retained event")
end)

check("newer immediate object request", function()
  local object, state = {}, "old"
  inCombat = true
  expect(policy.DeferForObject("object", object, function() state = "stale" end), "not queued")
  inCombat = false
  expect(not policy.DeferForObject("object", object, function() end), "immediate object request queued")
  state = "new"
  policy.FlushPending()
  expect(state == "new", "object queue retained obsolete work")
end)

check("replacement inside active drain", function()
  local stale = 0
  local function first(other)
    if stale ~= 0 then stale = stale + 1; return end
    stale = 1
    policy.DeferUntilOutOfCombat(other, function() end)
  end
  inCombat = true
  policy.DeferUntilOutOfCombat("left", function() first("right") end)
  policy.DeferUntilOutOfCombat("right", function() first("left") end)
  inCombat = false
  policy.FlushPending()
  expect(stale == 1, "replaced callback still executed from detached batch")
end)

check("combat resumes inside drain", function()
  local calls, protectedCalls = 0, 0
  local function callback()
    calls = calls + 1
    if inCombat then protectedCalls = protectedCalls + 1 end
    inCombat = true
  end
  inCombat = true
  policy.DeferUntilOutOfCombat("one", callback)
  policy.DeferUntilOutOfCombat("two", callback)
  inCombat = false
  policy.FlushPending()
  expect(calls == 1 and protectedCalls == 0, "drain ran work after combat resumed")
  expect(policy.GetPendingCount() == 1 and events.PLAYER_REGEN_ENABLED, "unrun work was lost")
  inCombat = false
  policy.FlushPending()
  expect(calls == 2 and protectedCalls == 0, "deferred remainder did not recover")
end)

check("callback reentry and failures", function()
  local calls = 0
  inCombat = true
  policy.DeferUntilOutOfCombat("error", function() error("expected callback failure") end)
  policy.DeferUntilOutOfCombat("reentry", function()
    calls = calls + 1
    policy.FlushPending()
  end)
  inCombat = false
  policy.FlushPending()
  expect(calls == 1 and policy.GetPendingCount() == 0, "reentry lost or repeated work")
end)
expect(#failures == 0, table.concat(failures, "\n"))
print("combat queue latest-request and generation tests: OK")
