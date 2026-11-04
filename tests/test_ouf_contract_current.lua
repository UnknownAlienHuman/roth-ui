local function expect(condition, message)
  if not condition then error(message, 2) end
end

_G.AnchorUtil = { FlowLayoutAxis = { Horizontal = 1, Vertical = 2 } }
_G.AuraContainerSortMethod = { Default = 1 }
_G.AuraContainerSortDirection = { Normal = 1 }
_G.Enum = { StatusBarInterpolation = { Immediate = 1 } }

local required = { "AddElement", "AddMetaElement", "RegisterInitCallback", "RegisterStyle", "SetActiveStyle", "Spawn", "SpawnHeader" }
local function NewOUF()
  local value = {}
  for _, method in ipairs(required) do value[method] = function() end end
  return value
end
local function Run(version)
  _G.C_AddOns = { GetAddOnMetadata = function() return version end }
  local ns = { oUF = NewOUF(), safety = { CanAccess = function() return true end } }
  assert(loadfile("core/ouf_contract.lua"))("Roth_UI", ns)
  return ns
end

local current = Run("14.2.1")
expect(current.oUFContract.minimumVersion == "14.2.1", "current oUF minimum was not published")
local ok, err = pcall(function() Run("14.2.0") end)
expect(ok == false and tostring(err):find("too old", 1, true), "oUF 14.2.0 was not rejected")

print("oUF 14.2.1 contract test: OK")
