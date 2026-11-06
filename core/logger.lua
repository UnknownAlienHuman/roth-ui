-- Roth_UI - lightweight session logger
--
-- Stores up to MAX lines in addon runtime memory.
-- This keeps debugging noise out of persisted SavedVariables.
--
local _, private = ...
local ns = assert(private or _G.Roth_UI, "Roth_UI: main namespace is required")

local safety = assert(ns and ns.safety, "Roth_UI: ns.safety is required by logger.lua")
local CanAccess = assert(safety.CanAccess, "Roth_UI: safety.CanAccess is required by logger.lua")
local IsSecret = assert(safety.IsSecret, "Roth_UI: safety.IsSecret is required by logger.lua")

local MAX = 200

local function SafeLogToken(value)
  if not CanAccess(value) or IsSecret(value) then
    return "<restricted>"
  end
  local valueType = type(value)
  if valueType == "nil" then return "nil" end
  if valueType == "string" or valueType == "number" or valueType == "boolean" then
    return tostring(value)
  end
  return "<" .. valueType .. ">"
end

local function IsOrdinaryTable(value)
  return CanAccess(value) and not IsSecret(value) and type(value) == "table"
end

local function _GetLogTable()
  if ns and type(ns.GetRuntimeLog) == "function" then
    local log = ns.GetRuntimeLog()
    if IsOrdinaryTable(log) then
      return log
    end
  end

  local runtimeState = ns and type(ns.GetRuntimeState) == "function" and ns.GetRuntimeState() or ns
  if not IsOrdinaryTable(runtimeState) then
    error("Roth_UI: an ordinary runtime log owner is required", 2)
  end
  local log = runtimeState._fallbackLog
  if not IsOrdinaryTable(log) then
    log = {}
    runtimeState._fallbackLog = log
  end
  return log
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
  if CanAccess(fmt) and not IsSecret(fmt) and fmt == nil then return end
  local msg
  if select('#', ...) > 0 then
    local parts = { SafeLogToken(fmt) }
    for i = 1, select('#', ...) do
      parts[#parts + 1] = SafeLogToken(select(i, ...))
    end
    msg = table.concat(parts, " ")
  else
    msg = SafeLogToken(fmt)
  end

  local ts = (date and date('%H:%M:%S')) or ''
  _Push(string.format('[%s] %s', ts, msg))
end

function ns.LogDump(lastN)
  local log = _GetLogTable()
  local n
  if CanAccess(lastN) and not IsSecret(lastN) then
    n = tonumber(lastN)
  end
  n = n or 80
  if n < 1 then n = 1 end
  if n > 200 then n = 200 end

  print(('Roth_UI: Log last %d of %d'):format(n, #log))
  local start = #log - n + 1
  if start < 1 then start = 1 end
  for i = start, #log do
    print(log[i])
  end
end
