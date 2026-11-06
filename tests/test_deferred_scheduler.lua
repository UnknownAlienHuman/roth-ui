local function expect(condition, message)
  if not condition then error(message, 2) end
end

local timers = {}
_G.C_Timer = {
  After = function(delay, callback)
    expect(delay == 0, "scheduler used a non-zero delay")
    timers[#timers + 1] = callback
  end,
}

local failures = 0
local ns = {
  safety = {
    TryCall = function(callback, ...)
      local ok, value = pcall(callback, ...)
      if not ok then failures = failures + 1 end
      return ok, value
    end,
  },
}
assert(loadfile("core/deferred_scheduler.lua"))("Roth_UI", ns)
local scheduler = assert(ns.defer)

expect(scheduler.RunNextFrame(nil, function() end) == false, "scheduler accepted a missing key")
expect(scheduler.RunNextFrame("key", nil) == false, "scheduler accepted a missing callback")

local calls = {}
expect(scheduler.RunNextFrame("shared", function() calls[#calls + 1] = "old" end) == true,
  "first same-key callback was rejected")
expect(scheduler.RunNextFrame("other", function() calls[#calls + 1] = "other" end) == true,
  "independent callback was rejected")
expect(scheduler.RunNextFrame("shared", function() calls[#calls + 1] = "new" end) == true,
  "replacement same-key callback was rejected")
expect(scheduler.RunNextFrame("failure", function() error("expected") end) == true,
  "failing callback was not queued")
expect(scheduler.RunNextFrame("after-failure", function() calls[#calls + 1] = "after" end) == true,
  "post-failure callback was not queued")
expect(#timers == 1, "one scheduler generation allocated more than one timer")

timers[1]()
expect(table.concat(calls, ",") == "new,other,after",
  "coalescing/order or failure isolation changed: " .. table.concat(calls, ","))
expect(failures == 1, "failing callback escaped the shared safety sink")

local generations = 0
expect(scheduler.RunNextFrame("reschedule", function()
  generations = generations + 1
  scheduler.RunNextFrame("reschedule", function() generations = generations + 10 end)
end) == true, "reschedule setup failed")
expect(scheduler.RunNextFrame("same-generation", function() generations = generations + 100 end) == true,
  "same-generation setup failed")
expect(#timers == 2, "second generation did not use one timer")
timers[2]()
expect(generations == 101 and #timers == 3,
  "reentrant work was not isolated to the next generation")
timers[3]()
expect(generations == 111, "reentrant callback did not execute exactly once")

_G.C_Timer = nil
local missingTimerNs = {
  safety = { TryCall = function(callback, ...) return pcall(callback, ...) end },
}
local ok, message = pcall(assert(loadfile("core/deferred_scheduler.lua")), "Roth_UI", missingTimerNs)
expect(ok == false and tostring(message):find("C_Timer.After is required", 1, true),
  "missing timer owner silently changed next-frame work into synchronous recursion")

print("deferred scheduler generation/coalescing test: OK")
