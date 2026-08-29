-- Roth_UI - lightweight session logger
--
-- Stores up to MAX lines in addon runtime memory.
-- This keeps debugging noise out of persisted SavedVariables.
--
local addonName = ...
local ns = assert(_G.Roth_UI, "Roth_UI_Options: Roth_UI namespace is required")

local MAX = 200

local function _GetLogTable()
  if ns and type(ns.GetRuntimeLog) == "function" then
    return ns.GetRuntimeLog()
  end

  local runtimeState = ns and type(ns.GetRuntimeState) == "function" and ns.GetRuntimeState() or ns or {}
  runtimeState._fallbackLog = runtimeState._fallbackLog or {}
  return runtimeState._fallbackLog
end

local function _Push(line)
  local log = _GetLogTable()
  log[#log + 1] = line
  if #log > MAX then
    -- trim from the start (cheap at this size)
    table.remove(log, 1)
  end
end

function ns.Log(fmt, ...)
  if not fmt then return end
  local msg
  if select('#', ...) > 0 then
    local parts = { tostring(fmt) }
    for i = 1, select('#', ...) do
      parts[#parts + 1] = tostring(select(i, ...))
    end
    msg = table.concat(parts, " ")
  else
    msg = tostring(fmt)
  end

  local ts = (date and date('%H:%M:%S')) or ''
  _Push(string.format('[%s] %s', ts, msg))
end

function ns.LogDump(lastN)
  local log = _GetLogTable()
  local n = tonumber(lastN) or 80
  if n < 1 then n = 1 end
  if n > 200 then n = 200 end

  print(('Roth_UI: Log last %d of %d'):format(n, #log))
  local start = #log - n + 1
  if start < 1 then start = 1 end
  for i = start, #log do
    print(log[i])
  end
end
