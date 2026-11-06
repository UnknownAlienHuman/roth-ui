local function expect(condition, message)
  if not condition then error(message, 2) end
end

local restricted = setmetatable({}, {
  __tostring = function() error("restricted diagnostic value was stringified") end,
})

-- Logger is an ordinary-only transport. Restricted values become a fixed token.
do
  local log = {}
  local ns = {
    safety = {
      CanAccess = function(value) return value ~= restricted end,
      IsSecret = function() return false end,
    },
    GetRuntimeLog = function() return log end,
  }
  assert(loadfile("core/logger.lua"))("Roth_UI", ns)
  local ok, message = pcall(ns.Log, "ordinary", restricted)
  expect(ok, "logger consumed a restricted argument: " .. tostring(message))
  expect(#log == 1 and log[1]:find("ordinary <restricted>", 1, true),
    "logger did not replace the restricted argument with a fixed ordinary token")
end

-- SVDoctor must survive the exact invalid key/value shapes it is meant to report.
do
  local restrictedKey = restricted
  local restrictedValue = {}
  local store = {
    [restrictedKey] = "bad key",
    restrictedValue = restrictedValue,
    ordinaryBadValue = function() end,
  }
  local state = {}
  local ns = {
    safety = {
      CanAccess = function(value)
        return value ~= restrictedKey and value ~= restrictedValue
      end,
      IsSecret = function() return false end,
      IsForbiddenTable = function(value)
        return value == restrictedValue
      end,
    },
    persistence = {
      GetScanStores = function() return { nodes = { config = store } } end,
      GetStorageLabels = function() return { nodes = { config = "config" } } end,
      GetDoctorState = function() return state end,
      GetConfigRoot = function() return store end,
    },
    GetPersistenceSchemaNodeKeys = function() return { "config" } end,
    persistenceReport = {
      BuildSchemaReport = function() return { driftCount = 0 } end,
    },
  }
  assert(loadfile("core/sv_doctor.lua"))("Roth_UI", ns)
  local ok, issues = pcall(ns.persistenceDoctor.Scan, false)
  expect(ok, "SVDoctor crashed on a restricted key: " .. tostring(issues))
  expect(type(issues) == "table" and #issues == 3,
    "SVDoctor did not report all restricted/non-serializable entries")
  local sawRestrictedKey, sawRestrictedValue = false, false
  for i = 1, #issues do
    local issue = issues[i]
    if issue.path == "config.<restricted-key>" and issue.vtype == "restricted" then
      sawRestrictedKey = true
    end
    if issue.path == "config.restrictedValue" and issue.vtype == "restricted" then
      sawRestrictedValue = true
    end
  end
  expect(sawRestrictedKey and sawRestrictedValue,
    "SVDoctor retained or misclassified restricted diagnostic data")
end

print("diagnostic ordinary-transport access-boundary test: OK")
