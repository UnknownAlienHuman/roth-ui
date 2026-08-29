local _, ns = ...

local configOwner = ns.configPersistence or {}
ns.configPersistence = configOwner

configOwner.ACCOUNT_DB_VAR = configOwner.ACCOUNT_DB_VAR or "Roth_UI_DB"
configOwner.CHAR_DB_VAR = configOwner.CHAR_DB_VAR or "Roth_UI_DB_Char"
configOwner.OWNER_FILE = configOwner.OWNER_FILE or "core/config_persistence_owner.lua"

local ACCOUNT_DB_VAR = configOwner.ACCOUNT_DB_VAR
local CHAR_DB_VAR = configOwner.CHAR_DB_VAR
local OWNER_FILE = configOwner.OWNER_FILE
local CONFIG_STORAGE_PATH = "account.settings"
local CONFIG_SCHEMA_PATCH_TARGET = 20
local VALID_HEALTH_VALUE_MODES = {
  cur = true,
  percent = true,
  curpercent = true,
}
local LEGACY_TARGET_CASTBAR_BAR = { r = 0, g = 0.5, b = 1, a = 0.7 }
local LEGACY_TARGET_CASTBAR_SHIELDBAR = { r = 0.5, g = 0.5, b = 0.5, a = 1 }

local safety = assert(ns and ns.safety, "Roth_UI: ns.safety is required by config_persistence_owner.lua")
local IsSecret = assert(safety.IsSecret, "Roth_UI: safety.IsSecret is required by config_persistence_owner.lua")
local IsForbiddenTable = assert(safety.IsForbiddenTable, "Roth_UI: safety.IsForbiddenTable is required by config_persistence_owner.lua")
local CopySerializable = assert(safety.CopySerializable, "Roth_UI: safety.CopySerializable is required by config_persistence_owner.lua")
local SanitizeSerializableInPlace = assert(safety.SanitizeSerializableInPlace, "Roth_UI: safety.SanitizeSerializableInPlace is required by config_persistence_owner.lua")

local configDefaults
local activeConfigStore
local readOnlyConfigViews = setmetatable({}, { __mode = "k" })

local function ResolveConfigDefaults()
  local defaults = configDefaults or ns.cfgDefaults
  if type(defaults) ~= "table" then
    error("Roth_UI: config defaults are required by config_persistence_owner.lua")
  end
  return defaults
end

local function EnsureCanonicalRootTables()
  local accountRoot = _G[ACCOUNT_DB_VAR]
  if type(accountRoot) ~= "table" then
    accountRoot = {}
    _G[ACCOUNT_DB_VAR] = accountRoot
  end
  if type(accountRoot.schema) ~= "table" then
    accountRoot.schema = {}
  end
  if type(accountRoot.account) ~= "table" then
    accountRoot.account = {}
  end
  if type(accountRoot.account.settings) ~= "table" then
    accountRoot.account.settings = {}
  end
  if type(accountRoot.account.templates) ~= "table" then
    accountRoot.account.templates = {}
  end

  local charRoot = _G[CHAR_DB_VAR]
  if type(charRoot) ~= "table" then
    charRoot = {}
    _G[CHAR_DB_VAR] = charRoot
  end
  if type(charRoot.schema) ~= "table" then
    charRoot.schema = {}
  end
  if type(charRoot.orbs) ~= "table" then
    charRoot.orbs = {}
  end

  accountRoot.schema.version = tonumber(accountRoot.schema.version) or 1
  charRoot.schema.version = tonumber(charRoot.schema.version) or 1

  return accountRoot, charRoot
end

local function ReplaceCanonicalRoots(payload)
  payload = type(payload) == "table" and payload or {}
  local replaced = false
  if payload.accountRoot ~= nil then
    _G[ACCOUNT_DB_VAR] = payload.accountRoot
    replaced = true
  end
  if payload.charRoot ~= nil then
    _G[CHAR_DB_VAR] = payload.charRoot
    replaced = true
  end
  if replaced then
    EnsureCanonicalRootTables()
  end
  return replaced
end

local function ResetCanonicalRoots()
  _G[ACCOUNT_DB_VAR] = nil
  _G[CHAR_DB_VAR] = nil
  return true
end

local function GetCanonicalStores()
  local accountRoot, charRoot = EnsureCanonicalRootTables()
  return {
    accountRoot = accountRoot,
    charRoot = charRoot,
    settings = accountRoot.account.settings,
    templates = accountRoot.account.templates,
    orbChar = charRoot.orbs,
  }
end

local function SetCanonicalStore(domain, store)
  if type(store) ~= "table" then
    store = {}
  end

  local stores = GetCanonicalStores()
  if domain == "config" then
    stores.accountRoot.account.settings = store
  elseif domain == "templates" then
    stores.accountRoot.account.templates = store
  elseif domain == "orbChar" then
    stores.charRoot.orbs = store
  end

  return GetCanonicalStores()
end

local function ResolveColorComponent(color, key, index, fallback)
  if type(color) ~= "table" then
    return fallback
  end
  local value = color[key]
  if value == nil then
    value = color[index]
  end
  if type(value) ~= "number" then
    return fallback
  end
  return value
end

local function ColorsMatch(left, right)
  return ResolveColorComponent(left, "r", 1, 0) == ResolveColorComponent(right, "r", 1, 0)
    and ResolveColorComponent(left, "g", 2, 0) == ResolveColorComponent(right, "g", 2, 0)
    and ResolveColorComponent(left, "b", 3, 0) == ResolveColorComponent(right, "b", 3, 0)
    and ResolveColorComponent(left, "a", 4, 1) == ResolveColorComponent(right, "a", 4, 1)
end

local function SeedMissing(dst, defaults)
  if type(dst) ~= "table" or type(defaults) ~= "table" then
    return
  end

  for k, v in pairs(defaults) do
    if dst[k] == nil then
      local copyValue = CopySerializable(v)
      if copyValue ~= nil then
        dst[k] = copyValue
      end
    elseif type(v) == "table" and type(dst[k]) == "table" and not IsSecret(v) and not IsForbiddenTable(v) and not IsForbiddenTable(dst[k]) then
      SeedMissing(dst[k], v)
    end
  end
end

local function NormalizeLegacyUnitConfig(store)
  local cfg = ResolveConfigDefaults()
  local units = store and store.units
  if type(units) ~= "table" then
    return
  end

  local function NormalizeCastbar(unitKey)
    local unitConfig = units[unitKey]
    if type(unitConfig) ~= "table" then
      return
    end

    local castbar = unitConfig.castbar
    if castbar == nil then
      return
    end

    if type(castbar) == "boolean" then
      local defaults = CopySerializable(cfg.units[unitKey] and cfg.units[unitKey].castbar) or {}
      defaults.show = castbar
      unitConfig.castbar = defaults
      return
    end

    if type(castbar) ~= "table" then
      unitConfig.castbar = CopySerializable(cfg.units[unitKey] and cfg.units[unitKey].castbar) or { show = true }
      return
    end

    if castbar.show == nil then
      castbar.show = true
    end
  end

  NormalizeCastbar("player")
  NormalizeCastbar("target")
  NormalizeCastbar("focus")
  NormalizeCastbar("boss")
end

local function ApplyConfigSchemaPatches(store)
  local cfg = ResolveConfigDefaults()
  if type(store) ~= "table" then
    return
  end

  store.__schemaPatch = tonumber(store.__schemaPatch) or 0

  if store.__schemaPatch < 9 then
    local units = store.units
    if type(units) == "table" then
      if units.player then
        if units.player.holypower == nil then
          units.player.holypower = CopySerializable(cfg.units.player.holypower) or { show = true }
        end
        if units.player.holypower and units.player.holypower.show == false then
          units.player.holypower.show = true
        end
      end

      if units.focus then
        local castbar = units.focus.castbar
        if castbar == nil then
          units.focus.castbar = CopySerializable(cfg.units.focus.castbar) or { show = true }
        elseif type(castbar) == "boolean" then
          local defaults = CopySerializable(cfg.units.focus.castbar) or {}
          defaults.show = castbar
          units.focus.castbar = defaults
        elseif type(castbar) == "table" then
          if castbar.show == nil or castbar.show == false then
            castbar.show = true
          end
        else
          units.focus.castbar = CopySerializable(cfg.units.focus.castbar) or { show = true }
        end
      end

      if units.target and units.target.health and units.target.health.x == 25 and units.target.health.y == -30 then
        units.target.health.x = -3
        units.target.health.y = 0
      end
      if units.target and units.target.power and units.target.power.point == "LEFT" and units.target.power.x == -25 and units.target.power.y == -30 then
        units.target.power.point = "RIGHT"
        units.target.power.x = -3
        units.target.power.y = 0
      end

    end
    store.__schemaPatch = 9
  end

  if store.__schemaPatch < 10 then
    local units = store.units
    if type(units) == "table" then
      if units.focus and units.focus.castbar and type(units.focus.castbar.pos) == "table" then
        local pos = units.focus.castbar.pos
        if pos.af == "UIParent" and pos.a1 == "BOTTOM" and pos.a2 == "BOTTOM" and pos.x == 0 and pos.y == 420 then
          units.focus.castbar.pos = CopySerializable(cfg.units.focus.castbar.pos)
        end
      end

    end
    store.__schemaPatch = 10
  end

  if store.__schemaPatch < 11 then
    local units = store.units
    if type(units) == "table" then
      if units.party and type(units.party.pos) == "table" and type(cfg.units.party) == "table" and type(cfg.units.party.pos) == "table" then
        local pos = units.party.pos
        if pos.af == "UIParent" and pos.a1 == "CENTER" and pos.a2 == "CENTER" and pos.x == -335 and pos.y == 150 then
          units.party.pos = CopySerializable(cfg.units.party.pos) or units.party.pos
        end
      end

      if units.raid and type(units.raid.pos) == "table" and type(cfg.units.raid) == "table" and type(cfg.units.raid.pos) == "table" then
        local pos = units.raid.pos
        if pos.af == "UIParent" and pos.a1 == "TOPLEFT" and pos.a2 == "TOPLEFT" and pos.x == 5 and pos.y == -5 then
          units.raid.pos = CopySerializable(cfg.units.raid.pos) or units.raid.pos
        end
      end
    end
    store.__schemaPatch = 11
  end

  if store.__schemaPatch < 12 then
    local units = store.units
    if type(units) == "table" and type(units.target) == "table" and type(units.target.castbar) == "table" then
      local color = units.target.castbar.color
      local defaults = cfg.units.target.castbar.color
      if type(color) ~= "table" then
        color = CopySerializable(defaults) or {}
        units.target.castbar.color = color
      end

      local semantic = color.semantic
      if type(semantic) ~= "table" then
        semantic = {}
        color.semantic = semantic
      end

      if type(semantic.interruptibleCast) ~= "table" then
        if type(color.bar) == "table" and not ColorsMatch(color.bar, LEGACY_TARGET_CASTBAR_BAR) then
          semantic.interruptibleCast = CopySerializable(color.bar)
        else
          semantic.interruptibleCast = CopySerializable(defaults.semantic and defaults.semantic.interruptibleCast)
        end
      end

      if type(semantic.interruptibleChannel) ~= "table" then
        semantic.interruptibleChannel = CopySerializable(defaults.semantic and defaults.semantic.interruptibleChannel)
      end

      if type(semantic.nonInterruptible) ~= "table" then
        if type(color.shieldbar) == "table" and not ColorsMatch(color.shieldbar, LEGACY_TARGET_CASTBAR_SHIELDBAR) then
          semantic.nonInterruptible = CopySerializable(color.shieldbar)
        else
          semantic.nonInterruptible = CopySerializable(defaults.semantic and defaults.semantic.nonInterruptible)
        end
      end

      if type(semantic.failedOrInterrupted) ~= "table" then
        semantic.failedOrInterrupted = CopySerializable(defaults.semantic and defaults.semantic.failedOrInterrupted)
      end

      color.bar = CopySerializable(semantic.interruptibleCast) or color.bar
      color.shieldbar = CopySerializable(semantic.nonInterruptible) or color.shieldbar
    end
    store.__schemaPatch = 12
  end

  if store.__schemaPatch < 13 then
    store.__schemaPatch = 13
  end

  if store.__schemaPatch < 14 then
    if store.applyGlobalFonts ~= true then
      store.applyGlobalFonts = true
    end
    store.__schemaPatch = 14
  end

  if store.__schemaPatch < 15 then
    if type(store.healthValueMode) ~= "string" or not VALID_HEALTH_VALUE_MODES[store.healthValueMode] then
      store.healthValueMode = cfg.healthValueMode or "cur"
    end
    store.__schemaPatch = 15
  end

  if store.__schemaPatch < 16 then
    if type(store.shortNumbers) ~= "boolean" then
      store.shortNumbers = cfg.shortNumbers == true
    end
    store.__schemaPatch = 16
  end

  if store.__schemaPatch < 17 then
    store.__schemaPatch = 17
  end

  if store.__schemaPatch < 18 then
    local oldBars = type(store.bars) == "table" and store.bars or {}
    store.bars = {
      showMacroName = oldBars.showMacroName ~= false,
      showCooldown = oldBars.showCooldown ~= false,
      showHotkey = oldBars.showHotkey == true,
      showStackCount = oldBars.showStackCount ~= false,
    }

    local units = store.units
    if type(units) == "table" then
      if type(units.targettarget) == "table" then
        units.targettarget.castbar = nil
      end
      local target = units.target
      local color = type(target) == "table" and type(target.castbar) == "table" and target.castbar.color or nil
      if type(color) == "table" then
        color.shieldbar = nil
        color.shieldbg = nil
        if type(color.semantic) == "table" then
          color.semantic.interruptibleChannel = nil
        end
      end
    end

    store.__schemaPatch = 18
  end

  if store.__schemaPatch < 19 then
    local units = store.units
    if type(units) == "table" then
      for _, unitConfig in pairs(units) do
        if type(unitConfig) == "table" then
          for _, key in ipairs({ "health", "power", "healper", "powper" }) do
            local node = unitConfig[key]
            if type(node) == "table" then
              node.tag = nil
              node.frequentUpdates = nil
            end
          end
          local auras = unitConfig.auras
          if type(auras) == "table" then
            auras.blacklist = nil
            auras.useCustomFilter = nil
            auras.desaturateDebuffs = nil
          end
        end
      end
    end
    store.__schemaPatch = 19
  end


  if store.__schemaPatch < 20 then
    local units = store.units
    if type(units) == "table" then
      for _, key in ipairs({ "party", "raid" }) do
        local unitConfig = units[key]
        if type(unitConfig) == "table" then
          unitConfig.range = nil
        end
      end
    end
    store.__schemaPatch = 20
  end

  if store.__schemaPatch < CONFIG_SCHEMA_PATCH_TARGET then
    store.__schemaPatch = CONFIG_SCHEMA_PATCH_TARGET
  end
end

local function RefreshRuntimeConfig()
  ns.runtime = ns.runtime or {}
  local runtime = ns.runtime

  runtime.playername = UnitName("player")
  runtime.playerclass = select(2, UnitClass("player"))
  runtime.playerspec = C_SpecializationInfo.GetSpecialization()

  do
    local classColor = RAID_CLASS_COLORS and runtime.playerclass and RAID_CLASS_COLORS[runtime.playerclass] or nil
    if type(classColor) == "table" then
      local color = { r = classColor.r or 1, g = classColor.g or 1, b = classColor.b or 1 }
      color[1], color[2], color[3] = color.r, color.g, color.b
      function color:GetRGB()
        return self.r, self.g, self.b
      end
      runtime.playercolor = color
    else
      runtime.playercolor = nil
    end
  end

  return runtime
end

local function ReconcileConfigStore(store)
  local cfg = ResolveConfigDefaults()
  if type(store) ~= "table" then
    store = {}
  end

  store.__mode = store.__mode or "full_v3"
  store.__build = store.__build or "noace_fullsv_v3"

  SeedMissing(store, cfg)

  store.framesUserplaced = nil
  store.playername = nil
  store.playerclass = nil
  store.playercolor = nil
  store.playerspec = nil

  SanitizeSerializableInPlace(store, { maxDepth = 12 })
  NormalizeLegacyUnitConfig(store)
  ApplyConfigSchemaPatches(store)
  return store
end

local function AttachCfgProxy(saved)
  saved = type(saved) == "table" and saved or activeConfigStore or configOwner.GetConfigRoot()
  activeConfigStore = saved

  local runtime = ns.runtime or RefreshRuntimeConfig()
  local proxy = ns._cfgProxy
  if type(proxy) ~= "table" then
    proxy = {}
    ns._cfgProxy = proxy
  end

  for key in pairs(proxy) do
    proxy[key] = nil
  end

  setmetatable(proxy, {
    __index = function(_, key)
      local runtimeValue = runtime[key]
      if runtimeValue ~= nil then
        return runtimeValue
      end
      return saved[key]
    end,
    __newindex = function(_, key, value)
      local keyType = type(key)
      if keyType ~= "string" and keyType ~= "number" then
        return
      end
      if IsSecret(key) then
        return
      end

      if key == "playername" or key == "playerclass" or key == "playercolor" or key == "playerspec" then
        runtime[key] = value
        return
      end

      local valueType = type(value)
      if value == nil or valueType == "number" or valueType == "string" or valueType == "boolean" then
        if not IsSecret(value) then
          saved[key] = value
        end
        return
      end

      if valueType == "table" then
        if IsSecret(value) or IsForbiddenTable(value) then
          return
        end
        saved[key] = CopySerializable(value) or {}
      end
    end,
  })

  ns.cfg = proxy
  return proxy
end

local function CreateReadOnlyConfigView(source)
  if type(source) ~= "table" then
    return source
  end

  local cached = readOnlyConfigViews[source]
  if cached then
    return cached
  end

  local proxy = {}
  local function iterator(_, previousKey)
    local nextKey, nextValue = next(source, previousKey)
    if nextKey == nil then
      return nil
    end
    if type(nextValue) == "table" then
      nextValue = CreateReadOnlyConfigView(nextValue)
    end
    return nextKey, nextValue
  end

  setmetatable(proxy, {
    __index = function(_, key)
      local value = source[key]
      if type(value) == "table" then
        return CreateReadOnlyConfigView(value)
      end
      return value
    end,
    __newindex = function(_, key)
      error(("Roth_UI: runtime config view is read-only for key '%s'; use SavedVariables APIs instead."):format(tostring(key)), 2)
    end,
    __pairs = function()
      return iterator, nil, nil
    end,
    __len = function()
      return #source
    end,
    __metatable = false,
  })

  readOnlyConfigViews[source] = proxy
  return proxy
end

local function BuildConfigSchemaInfo(currentStore)
  local info = configOwner.GetConfigPersistenceInfo()
  local current = type(currentStore) == "table" and currentStore or activeConfigStore or configOwner.GetConfigRoot()
  return {
    owner = info.owner,
    variable = info.variable,
    path = info.path,
    patch = tonumber(current and current.__schemaPatch) or 0,
    targetPatch = CONFIG_SCHEMA_PATCH_TARGET,
  }
end

local function BuildConfigSchemaPolicy()
  local info = configOwner.GetConfigPersistenceInfo()
  return {
    domain = "config",
    owner = info.owner,
    variable = info.variable,
    path = info.path,
    targetPatch = CONFIG_SCHEMA_PATCH_TARGET,
    mode = "strict",
  }
end

configOwner.EnsureCanonicalRootTables = EnsureCanonicalRootTables
configOwner.EnsureCanonicalStores = GetCanonicalStores
configOwner.ReplaceCanonicalRoots = ReplaceCanonicalRoots
configOwner.ResetCanonicalRoots = ResetCanonicalRoots
configOwner.GetConfigRoot = function()
  return GetCanonicalStores().settings
end
configOwner.GetCanonicalTemplateStore = function()
  return GetCanonicalStores().templates
end
configOwner.GetCanonicalOrbCharStore = function()
  return GetCanonicalStores().orbChar
end
configOwner.SetCanonicalConfigStore = function(store)
  return SetCanonicalStore("config", store).settings
end
configOwner.SetCanonicalTemplateStore = function(store)
  return SetCanonicalStore("templates", store).templates
end
configOwner.SetCanonicalOrbCharStore = function(store)
  return SetCanonicalStore("orbChar", store).orbChar
end
configOwner.GetConfigPersistenceInfo = function()
  return {
    owner = OWNER_FILE,
    variable = ACCOUNT_DB_VAR,
    path = CONFIG_STORAGE_PATH,
  }
end
configOwner.GetConfigDefaults = function()
  return ResolveConfigDefaults()
end
configOwner.GetConfigSchemaInfo = function(currentStore)
  return BuildConfigSchemaInfo(currentStore)
end
configOwner.GetConfigSchemaPolicy = function()
  return BuildConfigSchemaPolicy()
end
configOwner.AttachCfgProxy = function(saved)
  return AttachCfgProxy(saved)
end
configOwner.RefreshRuntimeConfig = function()
  return RefreshRuntimeConfig()
end
configOwner.ReconcileConfigStore = function(store)
  local target = store
  if type(target) ~= "table" then
    target = configOwner.GetConfigRoot()
  end
  target = configOwner.SetCanonicalConfigStore(ReconcileConfigStore(target))
  activeConfigStore = target
  AttachCfgProxy(target)
  return target
end
configOwner.InitializeConfigDefaults = function(cfg)
  if type(cfg) ~= "table" then
    error("Roth_UI: config defaults table is required by config_persistence_owner.lua")
  end

  configDefaults = cfg
  ns.cfgDefaults = cfg

  local store = configOwner.GetConfigRoot()
  store = configOwner.SetCanonicalConfigStore(ReconcileConfigStore(store))
  activeConfigStore = store
  RefreshRuntimeConfig()
  AttachCfgProxy(store)
  return store
end

function ns.EnsureCanonicalPersistenceStores()
  return configOwner.EnsureCanonicalStores()
end

function ns.GetCanonicalTemplateStore()
  return configOwner.GetCanonicalTemplateStore()
end

function ns.GetCanonicalOrbCharStore()
  return configOwner.GetCanonicalOrbCharStore()
end

function ns.SetCanonicalConfigStore(store)
  return configOwner.SetCanonicalConfigStore(store)
end

function ns.SetCanonicalTemplateStore(store)
  return configOwner.SetCanonicalTemplateStore(store)
end

function ns.SetCanonicalOrbCharStore(store)
  return configOwner.SetCanonicalOrbCharStore(store)
end

function ns.GetConfigPersistenceInfo()
  return configOwner.GetConfigPersistenceInfo()
end

function ns.GetReadOnlyConfigView(source)
  return CreateReadOnlyConfigView(source)
end

function ns.GetUnitConfig(unitKey)
  local units = ns.cfg and ns.cfg.units
  local unitConfig = units and units[unitKey]
  if type(unitConfig) ~= "table" then
    return nil
  end
  return CreateReadOnlyConfigView(unitConfig)
end

function ns.ReconcileConfigStore(store)
  return configOwner.ReconcileConfigStore(store)
end
