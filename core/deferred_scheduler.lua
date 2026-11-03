-- One next-frame callback per key. Replacement updates the work, not the timer.
local _, ns = ...
local scheduler = {}
ns.defer = scheduler

local pending = {}

function scheduler.RunNextFrame(key, callback, immediate)
  if type(key) ~= "string" or key == "" or type(callback) ~= "function" then
    return false
  end

  if immediate == true then callback() end
  local queued = pending[key] ~= nil
  pending[key] = callback
  if queued then return true end

  local function Run()
    local work = pending[key]
    pending[key] = nil
    if work then work() end
  end

  if C_Timer and type(C_Timer.After) == "function" then
    C_Timer.After(0, Run)
  else
    Run()
  end
  return true
end
