local function expect(condition, message)
  if not condition then error(message, 2) end
end

local function copyStrict(value, seen)
  local kind = type(value)
  if kind == "number" then
    if value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
  end
  if kind == "string" or kind == "boolean" then return value end
  if kind ~= "table" then return nil end
  seen = seen or {}
  if seen[value] then return nil end
  seen[value] = true
  local result = {}
  for key, child in pairs(value) do
    local copiedKey = copyStrict(key, seen)
    local copiedValue = copyStrict(child, seen)
    if copiedKey == nil or copiedValue == nil then return nil end
    result[copiedKey] = copiedValue
  end
  return result
end

local function accountRoot(marker, version)
  return {
    schema = { version = version or 1 },
    account = { settings = { marker = marker }, templates = {} },
  }
end

local function charRoot(marker, version)
  return {
    schema = { version = version or 1 },
    orbs = { marker = marker },
  }
end

local inCombat = false
_G.InCombatLockdown = function() return inCombat end
local reloadMode = "success"
local reloadCalls = 0
_G.ReloadUI = function()
  reloadCalls = reloadCalls + 1
  if reloadMode == "error" then error("reload unavailable") end
  if reloadMode == "false" then return false end
end

local eventFrame
_G.CreateFrame = function()
  local frame = { events = {} }
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:UnregisterEvent(event) self.events[event] = nil end
  function frame:SetScript(_, callback) self.onEvent = callback end
  eventFrame = frame
  return frame
end

local canonical = {}
local expectedAccountRoot
local expectedCharRoot
local function refreshViews()
  canonical.settings = canonical.accountRoot and canonical.accountRoot.account.settings or nil
  canonical.templates = canonical.accountRoot and canonical.accountRoot.account.templates or nil
  canonical.orbChar = canonical.charRoot and canonical.charRoot.orbs or nil
end
local function setBaseline(marker)
  canonical.accountRoot = accountRoot(marker)
  canonical.charRoot = charRoot(marker .. "-char")
  expectedAccountRoot = canonical.accountRoot
  expectedCharRoot = canonical.charRoot
  refreshViews()
end
setBaseline("old")

local replaceMode = "success"
local resetMode = "success"
local reconcileMode = "accept"
local reconcileCalls = 0
local sanitizeCalls = 0
local replaceCalls = 0
local resetCalls = 0
local visuals = 0

local function install(payload)
  if payload.accountRoot ~= nil then canonical.accountRoot = copyStrict(payload.accountRoot) end
  if payload.charRoot ~= nil then canonical.charRoot = copyStrict(payload.charRoot) end
  refreshViews()
end

local ns = {
  safety = {
    CanAccess = function() return true end,
    CopySerializableStrict = copyStrict,
    TryCall = function(fn, ...)
      local ok, result = pcall(fn, ...)
      return ok, result
    end,
  },
  store = {},
  persistenceRuntime = {},
  persistence = {},
  configPersistence = { ReconcileConfigStore = function() end },
  GetPersistenceSchemaNodeKeys = function() return { "config", "orbChar", "orbGlobal" } end,
  RefreshOrbsVisual = function() visuals = visuals + 1 end,
}

ns.store.GetCanonicalStores = function() refreshViews(); return canonical end
ns.store.GetPersistenceDescriptors = function() return {} end
ns.store.GetConfigRoot = function() refreshViews(); return canonical.settings end
ns.store.GetPersistenceStores = function() refreshViews(); return {} end
ns.store.CommitRoots = function(payload)
  replaceCalls = replaceCalls + 1
  if replaceMode == "partial_false" then
    replaceMode = "success"
    if payload.accountRoot ~= nil then canonical.accountRoot = copyStrict(payload.accountRoot) end
    refreshViews()
    return false
  end
  if replaceMode == "partial_error" then
    replaceMode = "success"
    if payload.charRoot ~= nil then canonical.charRoot = copyStrict(payload.charRoot) end
    refreshViews()
    error("replacement failed after mutation")
  end
  install(payload)
  return true
end
ns.store.ResetRoots = function()
  resetCalls = resetCalls + 1
  if resetMode == "partial_false" then
    resetMode = "success"
    canonical.accountRoot = nil
    refreshViews()
    return false
  end
  if resetMode == "partial_error" then
    resetMode = "success"
    canonical.charRoot = nil
    refreshViews()
    error("reset failed after mutation")
  end
  canonical.accountRoot = nil
  canonical.charRoot = nil
  refreshViews()
  return true
end
ns.store.RestoreRoots = function(snapshot)
  if type(snapshot) ~= "table" or type(snapshot.accountRoot) ~= "table"
      or type(snapshot.charRoot) ~= "table" then
    return false
  end
  canonical.accountRoot = snapshot.accountRoot
  canonical.charRoot = snapshot.charRoot
  refreshViews()
  return true
end
ns.store.ReconcileStores = function()
  reconcileCalls = reconcileCalls + 1
  if reconcileMode == "reject_once" then
    reconcileMode = "accept"
    return { driftAccepted = false }
  end
  if reconcileMode == "error_once" then
    reconcileMode = "accept"
    error("reconcile failed")
  end
  return { driftAccepted = true }
end
ns.store.SanitizeStores = function(opts)
  sanitizeCalls = sanitizeCalls + 1
  if opts then expect(opts.logoutEvent == true, "sanitize lost logout context") end
  return true
end

for _, name in ipairs({ "GetDebugState", "GetLog", "ClearLog", "GetPersistenceState", "GetSVDoctorState" }) do
  ns.persistenceRuntime[name] = function() return {} end
end

assert(loadfile("core/persistence_control_plane.lua"))("Roth_UI", ns)
local persistence = ns.persistence

expect(ns.store.CommitRoots == nil and ns.store.ResetRoots == nil and ns.store.RestoreRoots == nil,
  "raw store mutators remained reachable after control-plane initialization")
expect(ns.store.GetCanonicalStores == nil and ns.store.GetPersistenceStores == nil
    and ns.store.GetDomainRoot == nil and ns.store.SetDomainRoot == nil
    and ns.store.GetConfigRoot == nil and ns.GetPersistenceStores == nil,
  "raw live-root access remained reachable after control-plane initialization")
expect(ns.configPersistence.ReconcileConfigStore == nil,
  "raw config reconcile writer remained reachable after registry capture")
expect(persistence.ResetRoots == nil and persistence.ReplaceRoots == nil and persistence.GetStores == nil,
  "raw persistence root access escaped the transaction owner")
expect(type(persistence.ApplyTransferRootsAndReload) == "function",
  "transactional import/reload entry point is missing")
expect(eventFrame.events.ADDON_LOADED == nil,
  "LoadSavedVariablesFirst control plane retained a redundant ADDON_LOADED listener")
expect(eventFrame.events.PLAYER_LOGIN == true and eventFrame.events.PLAYER_LOGOUT == true,
  "persistence lifecycle listeners were not registered")

local function assertBaseline(marker, context)
  expect(canonical.accountRoot == expectedAccountRoot,
    context .. ": account root identity was not restored")
  expect(canonical.charRoot == expectedCharRoot,
    context .. ": character root identity was not restored")
  expect(canonical.accountRoot.account.settings.marker == marker,
    context .. ": account root value was not restored")
  expect(canonical.charRoot.orbs.marker == marker .. "-char",
    context .. ": character root value was not restored")
end

local function staged(marker)
  return { accountRoot = accountRoot(marker), charRoot = charRoot(marker .. "-char") }
end

-- Export is detached and validates account+character as one tree.
local exported, exportError = persistence.GetTransferRoots("full")
expect(type(exported) == "table" and exportError == nil, "detached export roots were not returned")
exported.accountRoot.account.settings.marker = "detached"
exported.charRoot.orbs.marker = "detached-char"
assertBaseline("old", "detached export")
expect(sanitizeCalls == 0, "export mutated live persistence through sanitation")
expect(persistence.GetTransferRoots("invalid") == nil, "unknown transfer mode was accepted")

local crossRootAlias = { value = true }
canonical.accountRoot.account.settings.crossRootAlias = crossRootAlias
canonical.charRoot.orbs.crossRootAlias = crossRootAlias
expect(persistence.GetTransferRoots("full") == nil,
  "full export accepted an alias shared across account and character roots")
canonical.accountRoot.account.settings.crossRootAlias = nil
canonical.charRoot.orbs.crossRootAlias = nil

-- Validation rejects unsupported roots, aliases, malformed shapes and future schemas before commit.
local beforeReplace = replaceCalls
expect(persistence.ApplyTransferRootsAndReload({ unexpected = {} }) == false,
  "unsupported transfer root was accepted")
local shared = { value = true }
expect(persistence.ApplyTransferRootsAndReload({
  accountRoot = { account = { settings = { first = shared, second = shared }, templates = {} } },
}) == false, "aliased transfer graph crossed the strict staging boundary")
expect(persistence.ApplyTransferRootsAndReload({ accountRoot = accountRoot("future", 2) }) == false,
  "future root schema was accepted")
expect(persistence.ApplyTransferRootsAndReload({
  accountRoot = { schema = { version = 1 }, account = { settings = {} } },
}) == false, "malformed account root was accepted")
expect(replaceCalls == beforeReplace, "invalid transfer reached canonical replacement")
assertBaseline("old", "validation refusal")

-- A valid transaction commits both roots and includes ReloadUI in the boundary.
reloadMode = "success"
expect(persistence.ApplyTransferRootsAndReload(staged("new")) == true,
  "accepted detached transfer did not commit")
expect(canonical.accountRoot.account.settings.marker == "new"
    and canonical.charRoot.orbs.marker == "new-char",
  "accepted transfer roots were not installed")

-- Partial writers, schema rejection and reload failure all restore exact old roots.
for _, mode in ipairs({ "partial_false", "partial_error" }) do
  setBaseline("replace-" .. mode)
  replaceMode = mode
  reloadMode = "success"
  local beforeReload = reloadCalls
  expect(persistence.ApplyTransferRootsAndReload(staged("candidate")) == false,
    mode .. " replacement reported success")
  assertBaseline("replace-" .. mode, mode .. " replacement")
  expect(reloadCalls == beforeReload, mode .. " replacement reached reload")
end

for _, mode in ipairs({ "reject_once", "error_once" }) do
  setBaseline("reconcile-" .. mode)
  reconcileMode = mode
  reloadMode = "success"
  expect(persistence.ApplyTransferRootsAndReload(staged("candidate")) == false,
    mode .. " reconcile reported success")
  assertBaseline("reconcile-" .. mode, mode .. " reconcile")
end

for _, mode in ipairs({ "false", "error" }) do
  setBaseline("reload-" .. mode)
  reloadMode = mode
  expect(persistence.ApplyTransferRootsAndReload(staged("candidate")) == false,
    mode .. " reload reported success")
  assertBaseline("reload-" .. mode, mode .. " reload")
end

inCombat = true
setBaseline("combat")
expect(persistence.ApplyTransferRootsAndReload(staged("candidate")) == false,
  "combat transfer reached canonical mutation")
expect(persistence.ResetAndReload() == false, "combat reset reached canonical mutation")
assertBaseline("combat", "combat refusal")
inCombat = false

-- Reset uses the same rollback and identity-preservation contract.
for _, mode in ipairs({ "partial_false", "partial_error" }) do
  setBaseline("reset-" .. mode)
  resetMode = mode
  reloadMode = "success"
  local beforeReload = reloadCalls
  expect(persistence.ResetAndReload() == false, mode .. " reset reported success")
  assertBaseline("reset-" .. mode, mode .. " reset")
  expect(reloadCalls == beforeReload, mode .. " reset reached reload")
end
for _, mode in ipairs({ "false", "error" }) do
  setBaseline("reset-reload-" .. mode)
  resetMode = "success"
  reloadMode = mode
  expect(persistence.ResetAndReload() == false, mode .. " reset reload reported success")
  assertBaseline("reset-reload-" .. mode, mode .. " reset reload")
end

-- Malformed legacy graphs must not block recovery transactions. Exact root
-- references are sufficient for rollback even when a strict fallback copy is
-- impossible because the existing roots share a descendant.
setBaseline("legacy-alias")
local legacyAlias = { legacy = true }
canonical.accountRoot.account.settings.shared = legacyAlias
canonical.charRoot.orbs.shared = legacyAlias
expectedAccountRoot = canonical.accountRoot
expectedCharRoot = canonical.charRoot
reloadMode = "false"
expect(persistence.ResetAndReload() == false,
  "malformed legacy roots prevented reset rollback")
assertBaseline("legacy-alias", "legacy alias reset rollback")
expect(canonical.accountRoot.account.settings.shared == legacyAlias
    and canonical.charRoot.orbs.shared == legacyAlias,
  "legacy alias rollback did not restore exact root references")
canonical.accountRoot.account.settings.shared = nil
canonical.charRoot.orbs.shared = nil

setBaseline("reset-valid")
resetMode = "success"
reloadMode = "success"
expect(persistence.ResetAndReload() == true, "valid reset/reload path failed")
expect(canonical.accountRoot == nil and canonical.charRoot == nil,
  "successful reset retained canonical roots before reload")

-- Restore roots for lifecycle checks.
setBaseline("lifecycle")
eventFrame.onEvent(eventFrame, "PLAYER_LOGIN")
expect(eventFrame.events.PLAYER_LOGIN == nil and reconcileCalls >= 1 and visuals == 1,
  "PLAYER_LOGIN did not reconcile once and release its listener")
eventFrame.onEvent(eventFrame, "PLAYER_LOGOUT")
expect(sanitizeCalls == 1, "PLAYER_LOGOUT did not sanitize persistence")
expect(replaceCalls > 0 and resetCalls > 0, "transaction test did not exercise root owners")

print("persistence control-plane transaction test: OK")
