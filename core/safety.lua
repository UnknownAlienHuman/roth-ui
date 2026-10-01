-- Roth_UI shared safety helpers.
--
-- Centralizes Secret/Forbidden/access/serialization guards used across runtime,
-- settings, and SavedVariables logic.

local addonName, ns = ...

ns.safety = ns.safety or {}
local safety = ns.safety

local type = type
local pcall = pcall
local pairs = pairs
local next = next
local select = select
local tostring = tostring

local IsSecretValue = _G.issecretvalue or _G.IsSecretValue
local CanAccessValue = _G.canaccessvalue
local CanAccessAllValues = _G.canaccessallvalues

assert(type(IsSecretValue) == "function", "Roth_UI: issecretvalue is required on Retail 12.1")

function safety.IsSecret(value)
  return IsSecretValue(value)
end

-- `issecretvalue` and `canaccessvalue` answer different questions. Every Lua
-- branch, comparison, conversion, table access and serialization path must use
-- the access gate before touching a value.
function safety.CanAccess(value)
  if type(CanAccessValue) == "function" then
    return CanAccessValue(value) == true
  end
  return not IsSecretValue(value)
end

function safety.CanAccessAll(...)
  if type(CanAccessAllValues) == "function" then
    return CanAccessAllValues(...) == true
  end

  for index = 1, select("#", ...) do
    if not safety.CanAccess(select(index, ...)) then
      return false
    end
  end
  return true
end

function safety.IsRestricted(value)
  return not safety.CanAccess(value)
end

local function SafeDebugToken(value, fallback)
  if safety.IsRestricted(value) then
    return fallback or "restricted"
  end
  local valueType = type(value)
  if valueType == "string" or valueType == "number" or valueType == "boolean" then
    return tostring(value)
  end
  return fallback or valueType
end

local function GetDebugState()
  if ns and type(ns.GetRuntimeDebugState) == "function" then
    local state = ns.GetRuntimeDebugState()
    if safety.CanAccess(state) and type(state) == "table" then
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

  local safeKind = SafeDebugToken(kind, "guard")
  local safeDetail = SafeDebugToken(detail, "restricted")
  local key = ("%s|%s"):format(safeKind, safeDetail)
  local count = (bucket[key] or 0) + 1
  bucket[key] = count
  if count > 5 then
    return
  end

  local msg = ("Roth_UI guard failure [%s] #%d: %s"):format(safeKind, count, safeDetail)
  if ns and type(ns.Log) == "function" then
    ns.Log(msg)
  end
  if type(_G.geterrorhandler) == "function" then
    _G.geterrorhandler()(msg)
  else
    print(msg)
  end
end

function safety.IsForbiddenTable(value)
  if not safety.CanAccess(value) then
    return true
  end
  if type(value) ~= "table" then
    return false
  end
  local ok = pcall(next, value)
  return not ok
end

function safety.IsSerializablePrimitive(value)
  if not safety.CanAccess(value) then
    return false
  end
  local valueType = type(value)
  return valueType == "nil"
    or valueType == "string"
    or valueType == "number"
    or valueType == "boolean"
end

function safety.SanitizeSerializableInPlace(value, opts, depth, seen)
  if not safety.CanAccess(value) or type(value) ~= "table" then
    return false
  end
  if safety.IsSecret(value) or safety.IsForbiddenTable(value) then
    return false
  end

  opts = opts or {}
  depth = depth or 0
  if depth > (opts.maxDepth or 20) then
    return false
  end

  seen = seen or {}
  if seen[value] then
    return true
  end
  seen[value] = true

  local kill = {}
  for key, child in pairs(value) do
    if not safety.CanAccess(key) then
      -- An inaccessible key cannot safely be used for a second lookup/removal.
      -- Abort the entire sanitization rather than turning iteration into an
      -- oracle for restricted table state.
      return false
    end

    local keyType = type(key)
    if safety.IsSecret(key) or (keyType ~= "string" and keyType ~= "number") then
      kill[#kill + 1] = key
    elseif not safety.CanAccess(child) or safety.IsSecret(child) then
      kill[#kill + 1] = key
    else
      local childType = type(child)
      if childType == "table" then
        local ok = safety.SanitizeSerializableInPlace(child, opts, depth + 1, seen)
        if not ok then
          kill[#kill + 1] = key
        end
      elseif not safety.IsSerializablePrimitive(child) then
        kill[#kill + 1] = key
      end
    end
  end

  for index = 1, #kill do
    value[kill[index]] = nil
  end
  return true
end

function safety.TryCall(fn, ...)
  if not safety.CanAccess(fn) or type(fn) ~= "function" then
    return false, nil
  end

  -- Do not pack arbitrary return values into a Lua table. A successful API call
  -- may legally return a restricted value; inserting that value into a table can
  -- make subsequent iteration/serialization of the table forbidden. Roth callers
  -- consume at most the first payload value, so preserve that value directly.
  local ok, value = pcall(fn, ...)
  if ok ~= true then
    safety.ReportGuardFailure("TryCall", value)
    return false, nil
  end
  return true, value
end

function safety.TryGet(obj, key)
  if not safety.CanAccess(obj) or not safety.CanAccess(key) then
    return false, nil
  end
  local ok, value = pcall(function() return obj[key] end)
  if ok ~= true then
    safety.ReportGuardFailure("TryGet", value)
    return false, nil
  end
  return true, value
end

function safety.TryMethod(obj, methodName, ...)
  if not safety.CanAccess(methodName) or type(methodName) ~= "string" then
    return false, nil
  end
  local got, fn = safety.TryGet(obj, methodName)
  if got ~= true or not safety.CanAccess(fn) or type(fn) ~= "function" then
    return false, nil
  end

  local ok, value = pcall(fn, obj, ...)
  if ok ~= true then
    safety.ReportGuardFailure(("TryMethod:%s"):format(methodName), value)
    return false, nil
  end
  return true, value
end

function safety.CanUseRegion(region)
  if not safety.CanAccess(region) or region == nil then
    return false
  end

  local ok, constrained = safety.TryMethod(region, "HasAccessConstraints")
  if ok == true then
    -- A restricted access-state result cannot be used as a branch condition.
    -- Fail closed rather than treating an unreadable region as ordinary.
    if not safety.CanAccess(constrained) then
      return false
    end
    if constrained == true then
      local accessible, allowed = safety.TryMethod(region, "CanBeAccessedInContext")
      if accessible ~= true or not safety.CanAccess(allowed) or allowed ~= true then
        return false
      end
    end
  end

  local hasForbidden, forbidden = safety.TryMethod(region, "IsForbidden")
  if hasForbidden == true then
    if not safety.CanAccess(forbidden) then
      return false
    end
    if forbidden == true then
      return false
    end
  end
  return true
end

function safety.CopySerializable(source, stack, memo, depth)
  if not safety.CanAccess(source) or safety.IsSecret(source) then
    return nil
  end

  local valueType = type(source)
  if valueType ~= "table" then
    if safety.IsSerializablePrimitive(source) then
      return source
    end
    return nil
  end

  if safety.IsForbiddenTable(source) then
    return nil
  end

  stack = stack or {}
  memo = memo or {}
  depth = depth or 0
  if depth > 64 then
    return nil
  end
  if stack[source] then
    -- SavedVariables cannot safely persist cyclic tables. Reject the branch
    -- instead of recreating a cycle through the memo table.
    return nil
  end
  if memo[source] then
    return memo[source]
  end
  stack[source] = true

  local destination = {}
  memo[source] = destination
  for key, child in pairs(source) do
    if not safety.CanAccess(key) then
      stack[source] = nil
      return nil
    end

    local keyType = type(key)
    if (keyType == "string" or keyType == "number") and not safety.IsSecret(key) then
      local copy = safety.CopySerializable(child, stack, memo, depth + 1)
      if copy ~= nil then
        destination[key] = copy
      end
    end
  end

  stack[source] = nil
  return destination
end
