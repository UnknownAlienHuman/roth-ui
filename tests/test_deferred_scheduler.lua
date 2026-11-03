local ns = {}
local timers = {}
C_Timer = { After = function(delay, callback)
  assert(delay == 0, "next-frame work must not be retried later")
  timers[#timers + 1] = callback
end }
assert(loadfile("core/deferred_scheduler.lua"))("Roth_UI", ns)

local calls = 0
for index = 1, 100 do
  local value = index
  ns.defer.RunNextFrame("layout", function() calls = value end, false)
end
assert(#timers == 1, "rapid changes scheduled duplicate timers")
assert(calls == 0, "deferred callback ran synchronously")
timers[1]()
assert(calls == 100, "coalesced work did not use the latest callback")

ns.defer.RunNextFrame("layout", function()
  calls = calls + 1
  ns.defer.RunNextFrame("layout", function() calls = calls + 10 end, false)
end, false)
assert(#timers == 2, "drained key could not be reused")
timers[2]()
assert(calls == 101 and #timers == 3, "reentrant work was lost")
timers[3]()
assert(calls == 111, "reentrant callback did not run")

C_Timer = nil
ns.defer.RunNextFrame("fallback", function() calls = calls + 1 end, false)
assert(calls == 112, "missing timer service silently dropped work")
assert(ns.defer.RunNextFrame("", function() error("must not run") end) == false)
print("deferred scheduler test: OK")
