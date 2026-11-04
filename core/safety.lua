-- Roth_UI shared safety helpers.
--
-- Centralizes Secret/Forbidden/access/serialization guards used across runtime,
-- settings, and SavedVariables logic.

local _, ns = ...

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
  if valueType == "number" then
    return value == value and value ~= math.huge and value ~= -math.huge
  end
  return valueType == "nil" or valueType == "string" or valueType == "boolean"
end

function safety.SanitizeSerializableInPlace(value, opts)
  opts = opts or {}
  local maxDepth = opts.maxDepth or 20
  local states = {}
  local removals = {}

  local function Scan(tableValue, depth)
    if not safety.CanAccess(tableValue) or type(tableValue) ~= "table"
        or safety.IsSecret(tableValue) or safety.IsForbiddenTable(tableValue)
        or depth > maxDepth then
      return false
    end

    local state = states[tableValue]
    if state == "visiting" or state == "failed" then
      return false
    end
    if state == "complete" then
      return true
    end

    states[tableValue] = "visiting"
    for key, child in pairs(tableValue) do
      if not safety.CanAccess(key) or safety.IsSecret(key) then
        -- An inaccessible key cannot safely be used for a second lookup or
        -- deletion. The parent may drop this subtree; already scanned children
        -- can also be reachable through another valid branch, so retain their
        -- queued cleanup. Nothing is changed if the root scan fails.
        states[tableValue] = "failed"
        return false
      end

      local keyType = type(key)
      if keyType ~= "string" and keyType ~= "number" then
        removals[#removals + 1] = { owner = tableValue, key = key }
      elseif keyType == "number" and not safety.IsSerializablePrimitive(key) then
        removals[#removals + 1] = { owner = tableValue, key = key }
      elseif not safety.CanAccess(child) or safety.IsSecret(child) then
        removals[#removals + 1] = { owner = tableValue, key = key }
      elseif type(child) == "table" then
        if not Scan(child, depth + 1) then
          removals[#removals + 1] = { owner = tableValue, key = key }
        end
      elseif not safety.IsSerializablePrimitive(child) then
        removals[#removals + 1] = { owner = tableValue, key = key }
      end
    end

    states[tableValue] = "complete"
    return true
  end

  if not Scan(value, 0) then
    return false
  end

  for index = 1, #removals do
    local removal = removals[index]
    removal.owner[removal.key] = nil
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
  -- These script-object queries are part of the Retail contract. If a lookup
  -- or call fails, permission is unknown and the object must not be used.
  if ok ~= true or not safety.CanAccess(constrained) or type(constrained) ~= "boolean" then
    return false
  end
  if constrained == true then
    local accessible, allowed = safety.TryMethod(region, "CanBeAccessedInContext")
    if accessible ~= true or not safety.CanAccess(allowed) or type(allowed) ~= "boolean" or allowed ~= true then
      return false
    end
  end

  local hasForbidden, forbidden = safety.TryMethod(region, "IsForbidden")
  if hasForbidden ~= true or not safety.CanAccess(forbidden)
      or type(forbidden) ~= "boolean" or forbidden == true then
    return false
  end
  return true
end

local function ConsumeStrictStringBudget(budget, value)
  if not budget or type(value) ~= "string" then
    return true
  end
  budget.stringBytes = budget.stringBytes + #value
  return budget.stringBytes <= budget.maxStringBytes
end

local function CopySerializable(source, stack, memo, depth, strict, budget)
  if not safety.CanAccess(source) or safety.IsSecret(source) then
    return nil
  end

  local valueType = type(source)
  if valueType ~= "table" then
    if safety.IsSerializablePrimitive(source)
        and (not strict or ConsumeStrictStringBudget(budget, source)) then
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
  if depth > (budget and budget.maxDepth or 64) then
    return nil
  end
  if strict and budget then
    budget.tables = budget.tables + 1
    if budget.tables > budget.maxTables then
      return nil
    end
  end
  if stack[source] then
    -- SavedVariables cannot safely persist cyclic tables. Reject the branch
    -- instead of recreating a cycle through the memo table.
    return nil
  end
  if memo[source] then
    -- A canonical import/export document is a tree. Shared-reference graphs
    -- are rejected in strict mode because object identity is not part of the
    -- portable schema and can hide cycles or alias unrelated roots.
    if strict then
      return nil
    end
    return memo[source]
  end
  stack[source] = true

  local destination = {}
  memo[source] = destination
  for key, child in pairs(source) do
    if strict and budget then
      budget.entries = budget.entries + 1
      if budget.entries > budget.maxEntries then
        stack[source] = nil
        memo[source] = nil
        return nil
      end
    end
    if not safety.CanAccess(key) then
      stack[source] = nil
      memo[source] = nil
      return nil
    end

    if safety.IsSecret(key) then
      if strict then
        stack[source] = nil
        memo[source] = nil
        return nil
      end
    else
      local keyType = type(key)
      if (keyType == "string" or keyType == "number")
          and (not strict or safety.IsSerializablePrimitive(key))
          and (not strict or ConsumeStrictStringBudget(budget, key)) then
        local copy = CopySerializable(child, stack, memo, depth + 1, strict, budget)
        if copy ~= nil then
          destination[key] = copy
        elseif strict then
          stack[source] = nil
          memo[source] = nil
          return nil
        end
      elseif strict then
        stack[source] = nil
        memo[source] = nil
        return nil
      end
    end
  end

  stack[source] = nil
  return destination
end

function safety.CopySerializable(source, stack, memo, depth)
  return CopySerializable(source, stack, memo, depth, false, nil)
end

local function PositiveIntegerOption(opts, key, fallback)
  local value = type(opts) == "table" and opts[key] or nil
  if type(value) ~= "number" or value ~= value or value < 1 or value % 1 ~= 0 then
    return fallback
  end
  return value
end

-- Validate and copy a complete, bounded serializable tree. Unlike
-- CopySerializable's migration-oriented sanitizer, this rejects the entire
-- input when any nested value is secret, inaccessible, unsupported, cyclic,
-- aliased, too deep, or exceeds the table/entry/string budgets. A depth limit
-- alone is not a size bound.
function safety.CopySerializableStrict(source, opts)
  local budget = {
    maxDepth = PositiveIntegerOption(opts, "maxDepth", 64),
    maxTables = PositiveIntegerOption(opts, "maxTables", 8192),
    maxEntries = PositiveIntegerOption(opts, "maxEntries", 65536),
    maxStringBytes = PositiveIntegerOption(opts, "maxStringBytes", 4 * 1024 * 1024),
    tables = 0,
    entries = 0,
    stringBytes = 0,
  }
  return CopySerializable(source, nil, nil, 0, true, budget)
end
