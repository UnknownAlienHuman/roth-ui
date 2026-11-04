-- One bounded next-frame scheduler for all addon-owned layout and refresh work.
local _, ns = ...
local TryCall = assert(ns and ns.safety and ns.safety.TryCall,
  "Roth_UI: safety.TryCall is required by deferred_scheduler.lua")
local scheduler = {}
ns.defer = scheduler

local pending = {}
local order = {}
local scheduled = false

local function Drain()
  scheduled = false

  -- Swap generations before invoking callbacks. Work queued by a callback is
  -- scheduled for the next frame rather than mutating the active iteration.
  local work = pending
  local workOrder = order
  pending = {}
  order = {}

  for index = 1, #workOrder do
    local callback = work[workOrder[index]]
    if callback then
      TryCall(callback)
    end
  end
end

local function ScheduleDrain()
  if scheduled then return end
  scheduled = true

  if C_Timer and type(C_Timer.After) == "function" then
    C_Timer.After(0, Drain)
  else
    Drain()
  end
end

function scheduler.RunNextFrame(key, callback)
  if type(key) ~= "string" or key == "" or type(callback) ~= "function" then
    return false
  end

  if pending[key] == nil then
    order[#order + 1] = key
  end
  pending[key] = callback
  ScheduleDrain()
  return true
end
