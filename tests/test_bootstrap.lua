local function expect(value, message)
  if not value then error(message, 2) end
end
local function noop() end
local function copyStrict(value)
  if type(value) ~= "table" then return value end
  local copy = {}
  for key, child in pairs(value) do copy[key] = copyStrict(child) end
  return copy
end
local calls = { config = 0, loaded = 0, reconcile = 0, logout = 0, visuals = 0 }
local bootstrapFrame
_G.CreateFrame = function()
  local frame = { events = {} }
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:UnregisterEvent(event) self.events[event] = nil end
  function frame:SetScript(_, callback) self.onEvent = callback end
  bootstrapFrame = frame
  return frame
end
_G.LibStub = function() return { RegisterCallback = noop } end
_G.oUF = {}
_G.InCombatLockdown = function() return false end
local ns = {
  safety = {
    CopySerializableStrict = copyStrict,
    CanAccess = function() return true end,
    TryCall = function(fn, ...)
      local ok, result = pcall(fn, ...)
      return ok, result
    end,
  },
  store = {}, persistenceRuntime = {}, persistence = {},
  GetPersistenceSchemaNodeKeys = function() return {} end,
  RefreshOrbsVisual = function() calls.visuals = calls.visuals + 1 end,
}
for _, name in ipairs({
  "GetPersistenceDescriptors", "GetPersistenceStores", "CommitRoots",
  "ResetRoots", "RestoreRoots",
}) do
  ns.store[name] = noop
end
ns.store.GetCanonicalStores = function()
  return {
    accountRoot = { account = { settings = {}, templates = {} } },
    charRoot = { orbs = {} },
  }
end
for _, name in ipairs({ "GetDebugState", "GetLog", "ClearLog", "GetPersistenceState", "GetSVDoctorState" }) do
  ns.persistenceRuntime[name] = noop
end
ns.store.GetConfigRoot = function() calls.config = calls.config + 1 return {} end
ns.store.ReconcileStores = function()
  calls.reconcile = calls.reconcile + 1
  return { driftAccepted = true }
end
ns.store.SanitizeStores = function(opts)
  expect(opts.logoutEvent == true, "logout lost its persistence context")
  calls.logout = calls.logout + 1
end

assert(loadfile("init.lua"))("Roth_UI", ns)
local retained = setmetatable({}, { __mode = "k" })
do
  local token = {}
  retained[token] = true
  ns:ListenForLoaded(function()
    expect(retained[token] == true, "load callback lost its context before running")
    calls.loaded = calls.loaded + 1
  end)
end
assert(loadfile("core/persistence_control_plane.lua"))("Roth_UI", ns)
assert(loadfile("core/bootstrap.lua"))("Roth_UI", ns)
ns:InitConfig()
expect(calls.config == 1 and calls.loaded == 1, "configuration initialized twice")
collectgarbage("collect")
expect(next(retained) == nil, "completed load callback retained its captured state")
ns:ListenForLoaded(function() calls.loaded = calls.loaded + 1 end)
expect(calls.loaded == 2, "late load listener was not called immediately")

expect(bootstrapFrame.events.ADDON_LOADED == nil,
  "LoadSavedVariablesFirst bootstrap retained a redundant ADDON_LOADED listener")
bootstrapFrame:onEvent("PLAYER_LOGIN")
expect(bootstrapFrame.events.PLAYER_LOGIN == nil and calls.reconcile == 1 and calls.visuals == 1,
  "login bootstrap failed to reconcile once and release its listener")
expect(bootstrapFrame.events.PLAYER_LOGOUT == true, "bootstrap removed the persistence shutdown listener")
bootstrapFrame:onEvent("PLAYER_LOGOUT")
expect(calls.logout == 1, "shutdown no longer sanitizes persistence")

print("bootstrap completion and retained-state test: OK")
