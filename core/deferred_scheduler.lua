local addonName, ns = ...

local scheduler = ns.defer or {}
ns.defer = scheduler

scheduler.tokens = scheduler.tokens or {}

function scheduler.RunSeries(key, fn, delays, immediate)
  if type(key) ~= "string" or key == "" or type(fn) ~= "function" then
    return
  end

  local token = (scheduler.tokens[key] or 0) + 1
  scheduler.tokens[key] = token

  local function Run()
    if scheduler.tokens[key] ~= token then
      return
    end
    fn()
  end

  if immediate ~= false then
    Run()
  end

  if _G.C_Timer and C_Timer.After and type(delays) == "table" then
    for i = 1, #delays do
      local delay = tonumber(delays[i])
      if delay and delay >= 0 then
        C_Timer.After(delay, Run)
      end
    end
  end
end

function scheduler.RunNextFrame(key, fn, immediate)
  scheduler.RunSeries(key, fn, { 0 }, immediate)
end

function scheduler.RunWithRetry(key, fn, immediate)
  scheduler.RunSeries(key, fn, { 0, 0.2 }, immediate)
end
