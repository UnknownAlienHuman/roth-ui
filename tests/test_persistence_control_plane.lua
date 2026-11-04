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

local canonical = {
  accountRoot = { schema = { version = 1 }, account = { settings = { marker = "old" }, templates = {} } },
  charRoot = { schema = { version = 1 }, orbs = { marker = "old-char" } },
}
local reconcileMode = "accept"
local reconcileCalls = 0
local sanitizeCalls = 0
local replaceCalls = 0
local resetCalls = 0

local function refreshViews()
  canonical.settings = canonical.accountRoot and canonical.accountRoot.account.settings or nil
  canonical.templates = canonical.accountRoot and canonical.accountRoot.account.templates or nil
  canonical.orbChar = canonical.charRoot and canonical.charRoot.orbs or nil
end
refreshViews()

local ns = {
  safety = {
    CopySerializableStrict = copyStrict,
    TryCall = function(fn, ...)
      local ok, result = pcall(fn, ...)
      return ok, result
    end,
  },
  store = {},
  persistenceRuntime = {},
  persistence = {},
  GetPersistenceSchemaNodeKeys = function() return { "config", "orbChar", "orbGlobal" } end,
}

ns.store.GetCanonicalStores = function() refreshViews(); return canonical end
ns.store.GetPersistenceDescriptors = function() return {} end
ns.store.GetConfigRoot = function() refreshViews(); return canonical.settings end
ns.store.GetPersistenceStores = function() refreshViews(); return {} end
ns.store.ReplaceRoots = function(payload)
  replaceCalls = replaceCalls + 1
  if payload.accountRoot ~= nil then canonical.accountRoot = copyStrict(payload.accountRoot) end
  if payload.charRoot ~= nil then canonical.charRoot = copyStrict(payload.charRoot) end
  refreshViews()
  return true
end
ns.store.ResetRoots = function()
  resetCalls = resetCalls + 1
  canonical.accountRoot = nil
  canonical.charRoot = nil
  refreshViews()
  return true
end
ns.store.ReconcileStores = function()
  reconcileCalls = reconcileCalls + 1
  if reconcileMode == "error" then error("reconcile failed") end
  return { driftAccepted = reconcileMode == "accept" }
end
ns.store.SanitizeStores = function()
  sanitizeCalls = sanitizeCalls + 1
end

for _, name in ipairs({ "GetDebugState", "GetLog", "ClearLog", "GetPersistenceState", "GetSVDoctorState" }) do
  ns.persistenceRuntime[name] = function() return {} end
end

assert(loadfile("core/persistence_control_plane.lua"))("Roth_UI", ns)
local persistence = ns.persistence

expect(eventFrame.events.ADDON_LOADED == nil,
  "LoadSavedVariablesFirst control plane retained a redundant ADDON_LOADED listener")
expect(eventFrame.events.PLAYER_LOGIN == true and eventFrame.events.PLAYER_LOGOUT == true,
  "persistence lifecycle listeners were not registered")

local exported, exportError = persistence.GetTransferRoots("full")
expect(type(exported) == "table" and exportError == nil, "detached export roots were not returned")
exported.accountRoot.account.settings.marker = "detached"
exported.charRoot.orbs.marker = "detached-char"
expect(canonical.accountRoot.account.settings.marker == "old"
    and canonical.charRoot.orbs.marker == "old-char",
  "export returned live mutable SavedVariables roots")
expect(sanitizeCalls == 0, "export mutated live persistence through sanitation")
expect(persistence.GetTransferRoots("invalid") == nil, "unknown transfer mode was accepted")

local crossRootAlias = { value = true }
canonical.accountRoot.account.settings.crossRootAlias = crossRootAlias
canonical.charRoot.orbs.crossRootAlias = crossRootAlias
expect(persistence.GetTransferRoots("full") == nil,
  "full export accepted an alias shared across account and character roots")
canonical.accountRoot.account.settings.crossRootAlias = nil
canonical.charRoot.orbs.crossRootAlias = nil
refreshViews()

local originalAccount = canonical.accountRoot
local invalidOk = persistence.ApplyTransferRoots({ unexpected = {} })
expect(invalidOk == false and canonical.accountRoot == originalAccount,
  "unsupported transfer root changed canonical persistence")

local shared = { value = true }
local sharedOk = persistence.ApplyTransferRoots({
  accountRoot = { account = { settings = { first = shared, second = shared }, templates = {} } },
})
expect(sharedOk == false and canonical.accountRoot == originalAccount,
  "aliased transfer graph crossed the strict staging boundary")

local acceptedPayload = {
  accountRoot = { schema = { version = 2 }, account = { settings = { marker = "new" }, templates = {} } },
  charRoot = { schema = { version = 2 }, orbs = { marker = "new-char" } },
}
expect(persistence.ApplyTransferRoots(acceptedPayload) == true,
  "accepted detached transfer did not commit")
expect(canonical.accountRoot.account.settings.marker == "new"
    and canonical.charRoot.orbs.marker == "new-char",
  "accepted transfer roots were not installed")

local committedSnapshot = { accountRoot = copyStrict(canonical.accountRoot), charRoot = copyStrict(canonical.charRoot) }
reconcileMode = "reject"
local rejected, rejectedReason = persistence.ApplyTransferRoots({
  accountRoot = { account = { settings = { marker = "reject" }, templates = {} } },
})
expect(rejected == false and type(rejectedReason) == "string",
  "reconcile rejection was reported as a successful import")
expect(canonical.accountRoot.account.settings.marker == committedSnapshot.accountRoot.account.settings.marker,
  "reconcile rejection did not roll back the account root")
expect(canonical.charRoot.orbs.marker == committedSnapshot.charRoot.orbs.marker,
  "account-only rollback changed the character root")

reconcileMode = "error"
local errored = persistence.ApplyTransferRoots({
  charRoot = { orbs = { marker = "error" } },
})
expect(errored == false and canonical.charRoot.orbs.marker == "new-char",
  "reconcile exception escaped rollback")

inCombat = true
expect(persistence.ApplyTransferRoots(acceptedPayload) == false,
  "combat transfer reached the persistence commit boundary")
inCombat = false

reconcileMode = "accept"
reloadMode = "error"
local beforeReset = { accountRoot = copyStrict(canonical.accountRoot), charRoot = copyStrict(canonical.charRoot) }
expect(persistence.ResetAndReload() == false, "failed reload reported a successful destructive reset")
expect(canonical.accountRoot.account.settings.marker == beforeReset.accountRoot.account.settings.marker
    and canonical.charRoot.orbs.marker == beforeReset.charRoot.orbs.marker,
  "failed reload did not roll back the reset roots")

reloadMode = "success"
expect(persistence.ResetAndReload() == true, "valid reset/reload path failed")
expect(canonical.accountRoot == nil and canonical.charRoot == nil,
  "successful reset retained canonical roots in the current execution context")
expect(resetCalls == 2 and reloadCalls == 2, "reset/reload did not execute exactly once per request")

-- Restore roots for lifecycle checks.
canonical.accountRoot = copyStrict(beforeReset.accountRoot)
canonical.charRoot = copyStrict(beforeReset.charRoot)
refreshViews()
eventFrame:onEvent("PLAYER_LOGIN")
expect(eventFrame.events.PLAYER_LOGIN == nil and reconcileCalls >= 1,
  "PLAYER_LOGIN did not reconcile once and release its listener")
eventFrame:onEvent("PLAYER_LOGOUT")
expect(sanitizeCalls == 1, "PLAYER_LOGOUT did not sanitize persistence")

print("persistence control-plane transaction test: OK")
