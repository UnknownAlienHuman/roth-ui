local _, ns = ...

-- Own orb schema targets and store reconcile pipeline separately from db defaults/templates.
local safety = assert(ns and ns.safety, "Roth_UI: ns.safety is required by orb_persistence_owner.lua")
local CopySerializable = assert(safety.CopySerializable, "Roth_UI: safety.CopySerializable is required by orb_persistence_owner.lua")
local SanitizeSerializableInPlace = assert(safety.SanitizeSerializableInPlace, "Roth_UI: safety.SanitizeSerializableInPlace is required by orb_persistence_owner.lua")
local orbText = assert(ns and ns.OrbTextController, "Roth_UI: ns.OrbTextController is required by orb_persistence_owner.lua")
local configOwner = assert(ns and ns.configPersistence, "Roth_UI: ns.configPersistence is required by orb_persistence_owner.lua")
local storeApi = assert(ns and ns.store, "Roth_UI: ns.store is required by orb_persistence_owner.lua")
local db = assert(ns and ns.db, "Roth_UI: ns.db is required by orb_persistence_owner.lua")
local GetOrbCharRoot = assert(storeApi.GetOrbCharRoot, "Roth_UI: store.GetOrbCharRoot is required by orb_persistence_owner.lua")
local SetOrbCharRoot = assert(storeApi.SetOrbCharRoot, "Roth_UI: store.SetOrbCharRoot is required by orb_persistence_owner.lua")
local GetOrbGlobalRoot = assert(storeApi.GetOrbGlobalRoot, "Roth_UI: store.GetOrbGlobalRoot is required by orb_persistence_owner.lua")
local SetOrbGlobalRoot = assert(storeApi.SetOrbGlobalRoot, "Roth_UI: store.SetOrbGlobalRoot is required by orb_persistence_owner.lua")

local orbPersistence = ns.orbPersistence or {}
ns.orbPersistence = orbPersistence

local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local ReloadUI = _G.ReloadUI
local ORB_OWNER_FILE = "core/orb_persistence_owner.lua"
local CHAR_SCHEMA_VERSION = 4
local GLOBAL_SCHEMA_VERSION = 4
local ACCOUNT_VAR = configOwner.ACCOUNT_DB_VAR or "Roth_UI_DB"
local CHAR_VAR = configOwner.CHAR_DB_VAR or "Roth_UI_DB_Char"
local ORB_CHAR_PATH = "orbs"
local ORB_GLOBAL_PATH = "account.templates"

orbPersistence.OWNER_FILE = ORB_OWNER_FILE

local function BuildStorageId(variable, path)
  if type(variable) ~= "string" or variable == "" then
    return nil
  end
  if type(path) ~= "string" or path == "" then
    return variable
  end
  return variable .. "." .. path
end

local function BuildPersistenceNode(owner, variable, path)
  return {
    owner = owner,
    variable = variable,
    path = path,
    storageId = BuildStorageId(variable, path),
  }
end

function orbPersistence.GetSchemaTargets()
  return {
    char = CHAR_SCHEMA_VERSION,
    global = GLOBAL_SCHEMA_VERSION,
  }
end

local function NormalizeStoreTable(v)
  if type(v) ~= "table" then
    return nil
  end
  return v
end

local function GetCharStore()
  return GetOrbCharRoot()
end

local function SetCharStore(v)
  local store = NormalizeStoreTable(v)
  if type(store) ~= "table" then
    return false
  end
  SanitizeSerializableInPlace(store)
  return SetOrbCharRoot(store)
end

local function GetGlobalStore()
  return GetOrbGlobalRoot()
end

local function SetGlobalStore(v)
  local store = NormalizeStoreTable(v)
  if type(store) ~= "table" then
    return false
  end
  if type(store.TEMPLATE_LIST) ~= "table" then
    local defaults = (db.GetTemplateListDefaults and db:GetTemplateListDefaults()) or {}
    store.TEMPLATE_LIST = defaults
  end
  SanitizeSerializableInPlace(store)
  return SetOrbGlobalRoot(store)
end

local function GetStores()
  return {
    char = GetCharStore(),
    global = GetGlobalStore(),
  }
end

local function SeedMissing(dst, src)
  if type(dst) ~= "table" or type(src) ~= "table" then
    return
  end
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then
        dst[k] = {}
      end
      SeedMissing(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

local function NormalizeBoolFlag(value, fallback)
  if type(value) == "boolean" then
    return value
  end
  if type(value) == "number" then
    if value == 0 then
      return false
    end
    if value == 1 then
      return true
    end
    return fallback
  end
  if type(value) == "string" then
    local s = value:gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if s == "0" or s == "false" or s == "off" or s == "no" then
      return false
    end
    if s == "1" or s == "true" or s == "on" or s == "yes" then
      return true
    end
  end
  return fallback
end

local LEGACY_VALUE_MODE_ALIASES = {
  current = "current", cur = "current", curs = "current", cmax = "current", cmaxs = "current",
  max = "max", maxs = "max",
  percent = "percent", per = "percent", perp = "percent",
  topdef = "__top_default__", topdefhp = "__top_default__", topdefpp = "__top_default__",
  botdef = "__bottom_default__", botdefhp = "__bottom_default__", botdefpp = "__bottom_default__",
  null = "__default__",
}

local function MigrateLegacyValueMode(which, rawMode, fallbackMode)
  if type(rawMode) ~= "string" then
    return orbText.NormalizeMode(which, nil, fallbackMode)
  end
  local token = rawMode:gsub("^%s+", ""):gsub("%s+$", "")
  local wrapped = token:match("^%[(.-)%]$")
  if wrapped then token = wrapped end
  if token:sub(-1) == "%" then token = token:sub(1, -2) end
  token = token:lower():gsub("^diablo:", "")
  token = LEGACY_VALUE_MODE_ALIASES[token] or token
  if token == "__top_default__" then return orbText.GetDefaultMode("top") end
  if token == "__bottom_default__" then return orbText.GetDefaultMode("bottom") end
  if token == "__default__" then return orbText.NormalizeMode(which, nil, fallbackMode) end
  return orbText.NormalizeMode(which, token, fallbackMode)
end

local function NormalizeOrbValueConfig(cfg, defaultCfg)
  if type(cfg) ~= "table" then return end

  local value = cfg.value
  if type(value) ~= "table" then
    value = {}
    cfg.value = value
  end
  if value.bottom == nil and value.bot ~= nil then value.bottom = value.bot end
  value.bot = nil
  if type(value.top) ~= "table" then value.top = { mode = value.top } end
  if type(value.bottom) ~= "table" then value.bottom = { mode = value.bottom } end

  local defaultsValue = defaultCfg and defaultCfg.value or nil
  local defaultTopMode = orbText.GetValueMode(defaultsValue, "top")
  local defaultBottomMode = orbText.GetValueMode(defaultsValue, "bottom")
  local topSource = value.top.mode ~= nil and value.top.mode or value.top.tag
  local bottomSource = value.bottom.mode ~= nil and value.bottom.mode or value.bottom.tag
  value.top.mode = MigrateLegacyValueMode("top", topSource, defaultTopMode)
  value.bottom.mode = MigrateLegacyValueMode("bottom", bottomSource, defaultBottomMode)
  value.top.tag = nil
  value.bottom.tag = nil

  orbText.NormalizeValueConfig(cfg, defaultCfg)
  local defaultHideOnEmpty = (type(defaultsValue) == "table" and type(defaultsValue.hideOnEmpty) == "boolean") and defaultsValue.hideOnEmpty or true
  local defaultHideOnFull = (type(defaultsValue) == "table" and type(defaultsValue.hideOnFull) == "boolean") and defaultsValue.hideOnFull or false
  value.hideOnEmpty = NormalizeBoolFlag(value.hideOnEmpty, defaultHideOnEmpty)
  value.hideOnFull = NormalizeBoolFlag(value.hideOnFull, defaultHideOnFull)
end

local function ApplyCharSchemaPatches(char, defaults)
  if type(char) ~= "table" then
    return
  end
  local schemaPatch = tonumber(char.__schemaPatch) or 0

  if schemaPatch < CHAR_SCHEMA_VERSION then
    for _, key in ipairs({ "HEALTH", "POWER" }) do
      if type(char[key]) ~= "table" then
        char[key] = {}
      end
      if defaults and type(defaults[key]) == "table" then
        SeedMissing(char[key], defaults[key])
      end
      NormalizeOrbValueConfig(char[key], defaults and defaults[key])
    end
    schemaPatch = CHAR_SCHEMA_VERSION
  end

  char.__schemaPatch = schemaPatch
end

local function ApplyGlobalSchemaPatches(glob)
  if type(glob) ~= "table" then
    return
  end
  local schemaPatch = tonumber(glob.__schemaPatch) or 0

  if schemaPatch < GLOBAL_SCHEMA_VERSION then
    if type(glob.TEMPLATE_LIST) ~= "table" then
      glob.TEMPLATE_LIST = db:GetTemplateListDefaults()
    end
    if type(glob.__selection) ~= "table" then
      glob.__selection = db:GetTemplateSelectionDefaults()
    end
    schemaPatch = GLOBAL_SCHEMA_VERSION
  end

  if type(glob.__selection) ~= "table" then
    glob.__selection = db:GetTemplateSelectionDefaults()
  end
  for _, orbType in ipairs({ "HEALTH", "POWER" }) do
    if type(glob.__selection[orbType]) ~= "string" then
      glob.__selection[orbType] = ""
    end
  end

  local templateDefaults = db:GetOrbDefaults().HEALTH
  for key, value in pairs(glob) do
    if key ~= "TEMPLATE_LIST" and key ~= "__selection" and key ~= "__schemaPatch" and type(value) == "table" then
      NormalizeOrbValueConfig(value, templateDefaults)
    end
  end

  glob.__schemaPatch = schemaPatch
end

local function EnsureCharDB()
  local char = GetCharStore()
  if type(char) ~= "table" then
    char = db:GetOrbDefaults()
    SetCharStore(char)
  end

  local defaults = db:GetOrbDefaults()
  if type(char) == "table" then
    ApplyCharSchemaPatches(char, defaults)
    SetCharStore(char)
  end
end

local function EnsureGlobalDB()
  local glob = GetGlobalStore()
  if type(glob) ~= "table" then
    glob = db:GetTemplateDefaults()
    SetGlobalStore(glob)
  end
  if type(glob) == "table" then
    ApplyGlobalSchemaPatches(glob)
    SetGlobalStore(glob)
  end
end

local function SyncTemplateListCache()
  local globalStore = GetGlobalStore()
  local templateList = type(globalStore) == "table" and type(globalStore.TEMPLATE_LIST) == "table" and globalStore.TEMPLATE_LIST or nil
  return templateList or {}
end

local function RefreshOrbRuntime(orbType)
  if type(ns.RefreshOrbsVisual) == "function" then
    ns.RefreshOrbsVisual(orbType)
  end
  if type(ns.ForceOrbValueRefresh) == "function" then
    if type(orbType) == "string" and orbType ~= "" then
      ns.ForceOrbValueRefresh(orbType)
    else
      ns.ForceOrbValueRefresh("HEALTH")
      ns.ForceOrbValueRefresh("POWER")
    end
  end
end

local function CopyOrbPayload(source, fallback)
  local copy = CopySerializable(source)
  if type(copy) ~= "table" and type(fallback) == "table" then
    copy = CopySerializable(fallback)
  end
  if type(copy) ~= "table" then
    copy = {}
  end
  return copy
end

local function BuildTemplateListEntry(name)
  return {
    key = name,
    value = name,
    notCheckable = true,
    keepShownOnClick = false,
  }
end

function orbPersistence.GetPersistenceInfo()
  local owner = orbPersistence.OWNER_FILE or ORB_OWNER_FILE
  return {
    key = "orb",
    owner = owner,
    char = BuildPersistenceNode(owner, CHAR_VAR, ORB_CHAR_PATH),
    global = BuildPersistenceNode(owner, ACCOUNT_VAR, ORB_GLOBAL_PATH),
  }
end

function orbPersistence.GetSchemaInfo(currentStores)
  local descriptor = orbPersistence.GetPersistenceInfo()
  local stores = type(currentStores) == "table" and currentStores or GetStores()
  local charStore = type(stores) == "table" and (stores.char or stores.orbChar) or nil
  local globalStore = type(stores) == "table" and (stores.global or stores.orbGlobal) or nil
  local targets = orbPersistence.GetSchemaTargets()
  local charNode = type(descriptor.char) == "table" and descriptor.char or {}
  local globalNode = type(descriptor.global) == "table" and descriptor.global or {}

  return {
    owner = descriptor.owner or ORB_OWNER_FILE,
    char = {
      variable = charNode.variable or CHAR_VAR,
      path = charNode.path or ORB_CHAR_PATH,
      patch = (type(charStore) == "table" and tonumber(charStore.__schemaPatch)) or 0,
      targetPatch = (type(targets) == "table" and tonumber(targets.char)) or 0,
    },
    global = {
      variable = globalNode.variable or ACCOUNT_VAR,
      path = globalNode.path or ORB_GLOBAL_PATH,
      patch = (type(globalStore) == "table" and tonumber(globalStore.__schemaPatch)) or 0,
      targetPatch = (type(targets) == "table" and tonumber(targets.global)) or 0,
    },
  }
end

function orbPersistence.GetSchemaPolicy()
  local schemaInfo = orbPersistence.GetSchemaInfo()
  return {
    owner = schemaInfo.owner,
    char = {
      variable = schemaInfo.char.variable,
      path = schemaInfo.char.path,
      targetPatch = schemaInfo.char.targetPatch,
    },
    global = {
      variable = schemaInfo.global.variable,
      path = schemaInfo.global.path,
      targetPatch = schemaInfo.global.targetPatch,
    },
    mode = "strict",
  }
end

function orbPersistence.GetStores()
  return GetStores()
end

function orbPersistence.EnsureStores()
  EnsureGlobalDB()
  EnsureCharDB()
  return GetStores()
end

function orbPersistence.SanitizeStores()
  local glob = GetGlobalStore()
  if type(glob) == "table" then
    SanitizeSerializableInPlace(glob)
    ApplyGlobalSchemaPatches(glob)
    SetGlobalStore(glob)
  end

  local char = GetCharStore()
  if type(char) == "table" then
    SanitizeSerializableInPlace(char)
    ApplyCharSchemaPatches(char, db:GetOrbDefaults())
    SetCharStore(char)
  end

  SyncTemplateListCache()
  return GetStores()
end

function orbPersistence.ReconcileStores()
  orbPersistence.EnsureStores()
  orbPersistence.SanitizeStores()
  return orbPersistence.GetSchemaInfo()
end

function orbPersistence.RunPipeline()
  orbPersistence.ReconcileStores()
  SyncTemplateListCache()
  return GetStores()
end

function orbPersistence.GetTemplateList()
  orbPersistence.RunPipeline()
  return SyncTemplateListCache()
end

function orbPersistence.LoadGlobalDataDefaults()
  print("Roth_UI: global data defaults loaded")
  local glob = db:GetTemplateDefaults()
  glob.TEMPLATE_LIST = db:GetTemplateListDefaults()
  SetGlobalStore(glob)
  orbPersistence.RunPipeline()
  return GetGlobalStore()
end

function orbPersistence.LoadGlobalData()
  EnsureGlobalDB()
  orbPersistence.RunPipeline()
  return GetGlobalStore()
end

function orbPersistence.ResetOrbToDefaults(orbType)
  local defaults = db:GetOrbDefaults()
  local char = GetCharStore()
  if type(char) ~= "table" then
    char = {}
  end

  if orbType ~= nil then
    if orbType ~= "HEALTH" and orbType ~= "POWER" then
      return false
    end
    char[orbType] = CopyOrbPayload(defaults[orbType], {})
    print(("Roth_UI: %s orb reseted to default"):format(string.lower(orbType)))
  else
    char = CopyOrbPayload(defaults, {})
    print("Roth_UI: character data reset to default")
  end

  SetCharStore(char)
  orbPersistence.RunPipeline()
  RefreshOrbRuntime(orbType)
  return true
end

function orbPersistence.LoadCharacterDataDefaults(orbType)
  return orbPersistence.ResetOrbToDefaults(orbType)
end

function orbPersistence.LoadCharacterData()
  orbPersistence.RunPipeline()
  local char = GetCharStore()
  if type(char) == "table" and char.reload then
    char.reload = false
    SetCharStore(char)
  end
  RefreshOrbRuntime()
  return true
end

function orbPersistence.ResetTemplateLibrary()
  if InCombatLockdown and InCombatLockdown() then
    print("Roth_UI: template reset is not possible in combat.")
    return false
  end

  local glob = GetGlobalStore()
  if type(glob) ~= "table" then
    glob = db:GetTemplateDefaults()
  end
  glob.reset = true
  if SetGlobalStore(glob) ~= true then
    print("Roth_UI: template reset failed. UI was not reloaded.")
    return false
  end
  return true
end

function orbPersistence.LoadTemplate(name, orbType)
  if type(name) ~= "string" or name == "" then
    return false
  end
  if orbType ~= "HEALTH" and orbType ~= "POWER" then
    return false
  end

  orbPersistence.RunPipeline()
  local glob = GetGlobalStore()
  local char = GetCharStore()
  if type(glob) ~= "table" or type(char) ~= "table" then
    return false
  end
  if type(glob[name]) ~= "table" then
    print("Roth_UI: template |c003399FF"..name.."|r not found")
    return false
  end

  local defaults = db:GetOrbDefaults()
  char[orbType] = CopyOrbPayload(glob[name], defaults and defaults[orbType])
  SetCharStore(char)
  orbPersistence.RunPipeline()
  print("Roth_UI: template |c003399FF"..name.."|r loaded into "..string.lower(orbType).." orb")
  RefreshOrbRuntime(orbType)
  return true
end

function orbPersistence.SaveTemplate(name, orbType)
  if type(name) ~= "string" or name == "" then
    return false
  end
  if orbType ~= "HEALTH" and orbType ~= "POWER" then
    return false
  end

  orbPersistence.RunPipeline()
  local glob = GetGlobalStore()
  local char = GetCharStore()
  local defaults = db:GetOrbDefaults()
  if type(glob) ~= "table" then
    glob = db:GetTemplateDefaults()
  end
  if type(char) ~= "table" then
    char = CopyOrbPayload(defaults, {})
    SetCharStore(char)
  end
  if type(char[orbType]) ~= "table" then
    char[orbType] = CopyOrbPayload(defaults and defaults[orbType], {})
    SetCharStore(char)
  end

  glob[name] = CopyOrbPayload(char[orbType], defaults and defaults.HEALTH)
  if type(glob.TEMPLATE_LIST) ~= "table" then
    glob.TEMPLATE_LIST = db:GetTemplateListDefaults()
  end

  local nameFound = false
  for i = 1, #glob.TEMPLATE_LIST do
    local entry = glob.TEMPLATE_LIST[i]
    if type(entry) == "table" and entry.key == name then
      nameFound = true
      break
    end
  end
  if not nameFound then
    glob.TEMPLATE_LIST[#glob.TEMPLATE_LIST + 1] = BuildTemplateListEntry(name)
  end

  SetGlobalStore(glob)
  orbPersistence.RunPipeline()
  print("Roth_UI: "..string.lower(orbType).." orb data saved as template |c003399FF"..name.."|r")
  if type(ns.RefreshOrbsVisual) == "function" then
    ns.RefreshOrbsVisual()
  end
  return true
end

function orbPersistence.DeleteTemplate(name)
  if type(name) ~= "string" or name == "" then
    return false
  end

  orbPersistence.RunPipeline()
  local glob = GetGlobalStore()
  if type(glob) ~= "table" then
    return false
  end
  if type(glob[name]) ~= "table" then
    print("Roth_UI: template |c003399FF"..name.."|r not found")
    return false
  end

  glob[name] = nil
  print("Roth_UI: template |c003399FF"..name.."|r deleted")
  if type(glob.TEMPLATE_LIST) == "table" then
    for i = 1, #glob.TEMPLATE_LIST do
      local entry = glob.TEMPLATE_LIST[i]
      if type(entry) == "table" and entry.key == name then
        table.remove(glob.TEMPLATE_LIST, i)
        break
      end
    end
  end
  SetGlobalStore(glob)
  orbPersistence.RunPipeline()
  if type(ns.RefreshOrbsVisual) == "function" then
    ns.RefreshOrbsVisual()
  end
  return true
end

local addonName = select(1, ...)
local orbBootstrap = CreateFrame("Frame")
orbBootstrap:RegisterEvent("ADDON_LOADED")
orbBootstrap:SetScript("OnEvent", function(self, event, arg1)
  if event ~= "ADDON_LOADED" or arg1 ~= addonName then
    return
  end

  local hadCharStore = type(GetCharStore()) == "table"
  local glob = GetGlobalStore()
  if type(glob) == "table" and glob.reset then
    glob.reset = nil
    glob = db:GetTemplateDefaults()
    glob.TEMPLATE_LIST = db:GetTemplateListDefaults()
    SetGlobalStore(glob)
  end

  orbPersistence.LoadGlobalData()
  if hadCharStore then
    orbPersistence.LoadCharacterData()
  else
    orbPersistence.LoadCharacterDataDefaults()
  end

  self:UnregisterEvent("ADDON_LOADED")
end)
