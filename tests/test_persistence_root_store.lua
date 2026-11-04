local function expect(condition, message)
  if not condition then error(message, 2) end
end

local denied = {}
_G.issecretvalue = function() return false end
_G.canaccessvalue = function(value) return not denied[value] end
_G.canaccessallvalues = nil

local canonical = {
  accountRoot = { account = { settings = {}, templates = {} } },
  charRoot = { orbs = {} },
  settings = {},
  templates = {},
  orbChar = {},
}
local ns = {
  configPersistence = {
    EnsureCanonicalStores = function() return canonical end,
    SetCanonicalConfigStore = function(store) canonical.settings = store return store end,
    SetCanonicalTemplateStore = function(store) canonical.templates = store return store end,
    SetCanonicalOrbCharStore = function(store) canonical.orbChar = store return store end,
    AttachCfgProxy = function() end,
    ReplaceCanonicalRoots = function(roots)
      if roots.accountRoot then canonical.accountRoot = roots.accountRoot end
      if roots.charRoot then canonical.charRoot = roots.charRoot end
      return true
    end,
    ResetCanonicalRoots = function() return true end,
  },
  persistenceRuntime = {
    PurgeLegacyKeys = function() end,
    MigrateLegacyState = function() end,
  },
  db = { GetTemplateListDefaults = function() return {} end },
}
assert(loadfile("core/safety.lua"))("Roth_UI", ns)
assert(loadfile("core/persistence_root_store.lua"))("Roth_UI", ns)

local restrictedRoot = {}
denied[restrictedRoot] = true
local oldAccountRoot = canonical.accountRoot
expect(ns.ReplacePersistenceRoots({ accountRoot = restrictedRoot }) == false,
  "replacement accepted an inaccessible account root")
expect(canonical.accountRoot == oldAccountRoot,
  "restricted account root replaced the canonical root")
expect(ns.ReplacePersistenceRoots({ charRoot = "malformed" }) == false,
  "replacement accepted a non-table character root")
expect(canonical.accountRoot == oldAccountRoot and canonical.charRoot.orbs ~= nil,
  "malformed root partially replaced canonical roots")

local restrictedKeyRoot = { [1] = { valid = true }, blocked = true }
denied.blocked = true
expect(ns.store.SetDomainRoot("orbChar", restrictedKeyRoot) == false,
  "root setter accepted an inaccessible direct key")
expect(canonical.orbChar ~= restrictedKeyRoot,
  "failed sanitation installed an unsafe root")

-- A failed in-place sanitation must leave a current canonical root and its
-- previously live child tables untouched.
local liveChild = { valid = true, unsupported = function() end }
local liveRoot = { [1] = liveChild, blocked = true }
canonical.orbChar = liveRoot
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
  "successful sanitation broke the normal live root/child identity contract")
expect(validChild.unsupported == nil,
  "successful sanitation failed to remove a non-serializable descendant")

local previousRoots = canonical.accountRoot
expect(ns.ReplacePersistenceRoots({ accountRoot = false }) == false,
  "replacement accepted a malformed scalar account root")
expect(canonical.accountRoot == previousRoots,
  "malformed replacement modified the canonical account root")

local invalidDescendant = {
  account = {
    settings = { callback = function() end },
    templates = {},
  },
}
expect(ns.ReplacePersistenceRoots({ accountRoot = invalidDescendant }) == false,
  "root replacement silently dropped a non-serializable descendant")
expect(canonical.accountRoot == previousRoots,
  "invalid detached root partially replaced canonical persistence")

local shared = { value = true }
local aliasedRoot = {
  account = {
    settings = { first = shared, second = shared },
    templates = {},
  },
}
expect(ns.ReplacePersistenceRoots({ accountRoot = aliasedRoot }) == false,
  "root replacement accepted a shared-reference document")
expect(canonical.accountRoot == previousRoots,
  "aliased detached root partially replaced canonical persistence")

local crossRootAlias = { value = true }
expect(ns.ReplacePersistenceRoots({
  accountRoot = { account = { settings = { shared = crossRootAlias }, templates = {} } },
  charRoot = { orbs = { shared = crossRootAlias } },
}) == false, "root replacement accepted an alias shared across roots")
expect(canonical.accountRoot == previousRoots,
  "cross-root alias partially replaced canonical persistence")
expect(ns.ReplacePersistenceRoots({ accountRoot = { account = { settings = {}, templates = {} } }, unexpected = {} }) == false,
  "root replacement ignored an unsupported top-level root")

print("persistence root sanitizer regression test: OK")
