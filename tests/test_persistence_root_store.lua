local function expect(condition, message)
  if not condition then error(message, 2) end
end

local denied = {}
_G.issecretvalue = function() return false end
_G.canaccessvalue = function(value) return not denied[value] end
_G.canaccessallvalues = nil

local canonical = {
  accountRoot = { schema = { version = 1 }, account = { settings = {}, templates = {} } },
  charRoot = { schema = { version = 1 }, orbs = {} },
}
local function refreshViews()
  canonical.settings = canonical.accountRoot and canonical.accountRoot.account.settings or nil
  canonical.templates = canonical.accountRoot and canonical.accountRoot.account.templates or nil
  canonical.orbChar = canonical.charRoot and canonical.charRoot.orbs or nil
end
refreshViews()

local ns = {
  configPersistence = {
    EnsureCanonicalStores = function() refreshViews(); return canonical end,
    SetCanonicalConfigStore = function(store)
      canonical.accountRoot.account.settings = store
      refreshViews()
      return store
    end,
    SetCanonicalTemplateStore = function(store)
      canonical.accountRoot.account.templates = store
      refreshViews()
      return store
    end,
    SetCanonicalOrbCharStore = function(store)
      canonical.charRoot.orbs = store
      refreshViews()
      return store
    end,
    AttachCfgProxy = function() end,
    ReplaceCanonicalRoots = function(roots)
      if roots.accountRoot then canonical.accountRoot = roots.accountRoot end
      if roots.charRoot then canonical.charRoot = roots.charRoot end
      refreshViews()
      return true
    end,
    ResetCanonicalRoots = function()
      canonical.accountRoot = nil
      canonical.charRoot = nil
      refreshViews()
      return true
    end,
  },
  persistenceRuntime = {
    PurgeLegacyKeys = function() end,
    MigrateLegacyState = function() end,
  },
  db = { GetTemplateListDefaults = function() return {} end },
}
assert(loadfile("core/safety.lua"))("Roth_UI", ns)
assert(loadfile("core/persistence_root_store.lua"))("Roth_UI", ns)

expect(ns.configPersistence.EnsureCanonicalRootTables == nil
    and ns.configPersistence.EnsureCanonicalStores == nil
    and ns.configPersistence.GetConfigRoot == nil
    and ns.configPersistence.GetCanonicalTemplateStore == nil
    and ns.configPersistence.GetCanonicalOrbCharStore == nil
    and ns.configPersistence.GetConfigDefaults == nil
    and ns.configPersistence.SetCanonicalConfigStore == nil
    and ns.configPersistence.SetCanonicalTemplateStore == nil
    and ns.configPersistence.SetCanonicalOrbCharStore == nil
    and ns.configPersistence.ReplaceCanonicalRoots == nil
    and ns.configPersistence.ResetCanonicalRoots == nil
    and ns.configPersistence.AttachCfgProxy == nil
    and ns.configPersistence.RefreshRuntimeConfig == nil
    and ns.configPersistence.InitializeConfigDefaults == nil,
  "raw config-owner root access remained available after root-store capture")
expect(ns.ReplacePersistenceRoots == nil and ns.ResetPersistenceRoots == nil,
  "raw root mutation was exported on the public addon namespace")
expect(ns.store.SetConfigRoot == nil,
  "unused raw config-root writer was exported by the root store")
expect(type(ns.store.CommitRoots) == "function"
    and type(ns.store.ResetRoots) == "function"
    and type(ns.store.RestoreRoots) == "function",
  "root-store transaction closures are missing")

-- Public domain setters retain the migration-oriented in-place sanitizer.
local restrictedKeyRoot = { [1] = { valid = true }, blocked = true }
denied.blocked = true
expect(ns.store.SetDomainRoot("orbChar", restrictedKeyRoot) == false,
  "root setter accepted an inaccessible direct key")

local liveChild = { valid = true, unsupported = function() end }
local liveRoot = { [1] = liveChild, blocked = true }
canonical.charRoot.orbs = liveRoot
refreshViews()
expect(ns.store.SetDomainRoot("orbChar", liveRoot) == false,
  "root setter did not reject an inaccessible direct key")
expect(canonical.orbChar == liveRoot and liveRoot[1] == liveChild,
  "failed root sanitation changed canonical root/child identity")
expect(liveChild.unsupported ~= nil,
  "failed root sanitation partially modified a live descendant")

denied.blocked = nil
local validChild = { valid = true, unsupported = function() end }
local validRoot = { child = validChild }
expect(ns.store.SetDomainRoot("unknown", validRoot) == false and validChild.unsupported ~= nil,
  "invalid domain mutated input before rejection")
expect(ns.store.SetDomainRoot("orbChar", validRoot) == true,
  "ordinary sanitizable live root was rejected")
expect(canonical.orbChar == validRoot and canonical.orbChar.child == validChild,
  "successful sanitation broke the live root/child identity contract")
expect(validChild.unsupported == nil,
  "successful sanitation failed to remove a non-serializable descendant")

-- Strict document validation belongs to the control plane. This lower owner
-- accepts only the already-staged root keys and performs one normalized swap.
local beforeAccount = canonical.accountRoot
local beforeChar = canonical.charRoot
expect(ns.store.CommitRoots({}) == false, "empty root commit was accepted")
expect(ns.store.CommitRoots({ unexpected = {} }) == false, "unknown root key was accepted")
expect(ns.store.CommitRoots({ accountRoot = false }) == false, "scalar account root was accepted")
expect(canonical.accountRoot == beforeAccount and canonical.charRoot == beforeChar,
  "rejected root commit partially changed canonical roots")

local committedAccount = {
  schema = { version = 1 },
  account = { settings = { marker = "new" }, templates = {} },
}
local committedChar = { schema = { version = 1 }, orbs = { marker = "new-char" } }
expect(ns.store.CommitRoots({ accountRoot = committedAccount, charRoot = committedChar }) == true,
  "valid staged roots were not committed")
expect(canonical.accountRoot == committedAccount and canonical.charRoot == committedChar,
  "root commit copied or split the staged transaction")

-- Rollback reattaches exact trusted references so file-scope unit config views
-- are not orphaned when import/reload fails.
local restoreAccount = {
  schema = { version = 1 },
  account = { settings = { marker = "old" }, templates = {} },
}
local restoreChar = { schema = { version = 1 }, orbs = { marker = "old-char" } }
expect(ns.store.RestoreRoots({ accountRoot = restoreAccount, charRoot = restoreChar }) == true,
  "trusted rollback references were rejected")
expect(canonical.accountRoot == restoreAccount and canonical.charRoot == restoreChar,
  "rollback copied roots and orphaned existing configuration views")
expect(ns.store.RestoreRoots({ accountRoot = {}, charRoot = false }) == false,
  "rollback accepted malformed trusted references")
expect(canonical.accountRoot == restoreAccount and canonical.charRoot == restoreChar,
  "malformed rollback partially changed canonical roots")

expect(ns.store.ResetRoots() == true, "canonical reset failed")
expect(canonical.accountRoot == nil and canonical.charRoot == nil,
  "canonical reset retained a persistence root")

print("persistence root-store ownership test: OK")
