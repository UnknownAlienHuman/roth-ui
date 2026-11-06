local function expect(condition, message)
  if not condition then error(message, 2) end
end

local restrictedName = {}
local secretClass = {}
local restrictedSpec = {}
local ordinary = false

_G.UnitName = function()
  return ordinary and "Tester" or restrictedName
end
_G.UnitClass = function()
  if ordinary then return "Warrior", "WARRIOR" end
  return "Warrior", secretClass
end
_G.C_SpecializationInfo = {
  GetSpecialization = function() return ordinary and 2 or restrictedSpec end,
}
_G.RAID_CLASS_COLORS = setmetatable({
  WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
}, {
  __index = function(_, key)
    if key == secretClass or key == restrictedName or key == restrictedSpec then
      error("restricted identity was used as a table key")
    end
  end,
})

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local result = {}
  seen[value] = result
  for key, child in pairs(value) do result[copy(key, seen)] = copy(child, seen) end
  return result
end

local ns = {
  safety = {
    CanAccess = function(value)
      return value ~= restrictedName and value ~= restrictedSpec
    end,
    IsSecret = function(value)
      return value == secretClass
    end,
    IsForbiddenTable = function() return false end,
    CopySerializable = function(value) return copy(value) end,
    SanitizeSerializableInPlace = function() return true end,
  },
}
_G.Roth_UI_DB = { schema = { version = 1 }, account = { settings = {}, templates = {} } }
_G.Roth_UI_DB_Char = { schema = { version = 1 }, orbs = {} }

assert(loadfile("core/config_persistence_owner.lua"))("Roth_UI", ns)
local defaults = {
  units = { player = { size = 100 } },
  healthValueMode = "cur",
  shortNumbers = true,
}

local ok, message = pcall(ns.configPersistence.InitializeConfigDefaults, defaults)
expect(ok, "restricted runtime identity escaped the access boundary: " .. tostring(message))
expect(ns.runtime.playername == nil and ns.runtime.playerclass == nil
    and ns.runtime.playerspec == nil and ns.runtime.playercolor == nil,
  "restricted runtime identity was retained in addon state")

ordinary = true
ns.configPersistence.RefreshRuntimeConfig()
expect(ns.runtime.playername == "Tester" and ns.runtime.playerclass == "WARRIOR"
    and ns.runtime.playerspec == 2,
  "ordinary runtime identity did not refresh")
expect(type(ns.runtime.playercolor) == "table"
    and ns.runtime.playercolor.r == 0.78 and ns.runtime.playercolor.g == 0.61,
  "ordinary class color was not derived after the identity gate")

print("runtime identity access-boundary test: OK")
