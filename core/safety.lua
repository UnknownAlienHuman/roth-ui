-- Roth_UI shared safety helpers.
--
-- Centralizes Secret/Forbidden/serialization guards used across runtime,
-- settings, and SavedVariables logic.

local addonName, ns = ...

ns.safety = ns.safety or {}
local safety = ns.safety

local type = type
local pcall = pcall
local pairs = pairs
local next = next
local tostring = tostring
local unpack = unpack or table.unpack

local function GetDebugState()
  if ns and type(ns.GetRuntimeDebugState) == "function" then
    local state = ns.GetRuntimeDebugState()
    if type(state) == "table" then
      return state
    end
  end
  return nil
end

function safety.ReportGuardFailure(kind, detail)
  local debugState = GetDebugState()
  if not (type(debugState) == "table" and debugState.enabled == true) then
    return
  end

  local bucket = debugState.guardFailures
  if type(bucket) ~= "table" then
    bucket = {}
    debugState.guardFailures = bucket
  end

  local key = ("%s|%s"):format(tostring(kind or "guard"), tostring(detail or "unknown"))
  local count = (bucket[key] or 0) + 1
  bucket[key] = count
  if count > 5 then
    return
  end

  local msg = ("Roth_UI guard failure [%s] #%d: %s"):format(tostring(kind or "guard"), count, tostring(detail or "unknown"))
  if ns and type(ns.Log) == "function" then
    ns.Log(msg)
  end
  if type(_G.geterrorhandler) == "function" then
    _G.geterrorhandler()(msg)
  else
    print(msg)
  end
end

local function GetSecretFn()
  return _G.issecretvalue or _G.IsSecretValue
end

function safety.IsSecret(v)
  local fn = GetSecretFn()
  if type(fn) ~= "function" then
    return false
  end
  local ok, res = pcall(fn, v)
  return ok and res or false
end

function safety.IsForbiddenTable(t)
  if type(t) ~= "table" then
    return false
  end
  local ok = pcall(next, t)
  return not ok
end

function safety.IsSerializablePrimitive(v)
  local tv = type(v)
  return tv == "nil" or tv == "string" or tv == "number" or tv == "boolean"
end

function safety.SanitizeSerializableInPlace(t, opts, depth, seen)
  if type(t) ~= "table" then
    return false
  end
  if safety.IsSecret(t) or safety.IsForbiddenTable(t) then
    return false
  end

  opts = opts or {}
  depth = depth or 0
  if depth > (opts.maxDepth or 20) then
    return false
  end

  seen = seen or {}
  if seen[t] then
    return true
  end
  seen[t] = true

  local kill = {}
  for k, v in pairs(t) do
    local tk = type(k)
    if safety.IsSecret(k) or (tk ~= "string" and tk ~= "number") then
      kill[#kill + 1] = k
    else
      if safety.IsSecret(v) then
        kill[#kill + 1] = k
      else
        local tv = type(v)
        if tv == "table" then
          local ok = safety.SanitizeSerializableInPlace(v, opts, depth + 1, seen)
          if not ok then
            kill[#kill + 1] = k
          end
        elseif not safety.IsSerializablePrimitive(v) then
          kill[#kill + 1] = k
        end
      end
    end
  end

  for i = 1, #kill do
    t[kill[i]] = nil
  end
  return true
end

function safety.TryCall(fn, ...)
  if type(fn) ~= "function" then
    return false, nil
  end
  local results = { pcall(fn, ...) }
  if results[1] ~= true then
    safety.ReportGuardFailure("TryCall", results[2])
  end
  return unpack(results)
end

function safety.TryMethod(obj, methodName, ...)
  if type(methodName) ~= "string" then
    return false, nil
  end
  local fn = obj and obj[methodName]
  if type(fn) ~= "function" then
    return false, nil
  end
  local results = { pcall(fn, obj, ...) }
  if results[1] ~= true then
    safety.ReportGuardFailure(("TryMethod:%s"):format(methodName), results[2])
  end
  return unpack(results)
end

function safety.CopySerializable(src, stack, memo, depth)
  if safety.IsSecret(src) then
    return nil
  end

  local tv = type(src)
  if tv ~= "table" then
    if safety.IsSerializablePrimitive(src) then
      return src
    end
    return nil
  end

  if safety.IsForbiddenTable(src) then
    return nil
  end

  stack = stack or {}
  memo = memo or {}
  depth = depth or 0
  if depth > 64 then
    return nil
  end
  if memo[src] then
    return memo[src]
  end
  if stack[src] then
    return nil
  end
  stack[src] = true

  local dst = {}
  memo[src] = dst
  for k, v in pairs(src) do
    local tk = type(k)
    if (tk == "string" or tk == "number") and not safety.IsSecret(k) then
      local cv = safety.CopySerializable(v, stack, memo, depth + 1)
      if cv ~= nil then
        dst[k] = cv
      end
    end
  end

  stack[src] = nil
  return dst
end
