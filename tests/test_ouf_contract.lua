local function fail(message)
  error(message, 2)
end

local function expect(condition, message)
  if not condition then fail(message) end
end

_G.AnchorUtil = {
  FlowLayoutAxis = {
    Horizontal = 1,
    Vertical = 2,
  },
}
_G.AuraContainerSortMethod = { Default = 1 }
_G.AuraContainerSortDirection = { Normal = 1 }
_G.Enum = {
  StatusBarInterpolation = {
    Immediate = 1,
  },
}

local requiredMethods = {
  "AddElement",
  "AddMetaElement",
  "RegisterInitCallback",
  "RegisterStyle",
  "SetActiveStyle",
  "Spawn",
}

local function NewOUF()
  local oUF = {}
  for index = 1, #requiredMethods do
    oUF[requiredMethods[index]] = function() end
  end
  return oUF
end

local function Run(version, oUF)
  _G.C_AddOns = {
    GetAddOnMetadata = function(addonName, field)
      expect(addonName == "oUF" and field == "Version", "unexpected metadata lookup")
      return version
    end,
  }

  local ns = {
    oUF = oUF or NewOUF(),
    safety = {
      CanAccess = function() return true end,
    },
  }
  assert(loadfile("core/ouf_contract.lua"))("Roth_UI", ns)
  return ns
end

local current = Run("14.0.2", NewOUF())
expect(type(current.oUFContract) == "table", "oUF contract was not published")
expect(current.oUFContract.minimumVersion == "14.0.2", "minimum oUF version changed")
expect(current.oUFContract.detectedVersion == "14.0.2", "detected version was lost")
expect(current.oUFContract.managedAuras == true, "managed-aura capability was not declared")

local oldOK, oldError = pcall(function()
  Run("13.9.9", NewOUF())
end)
expect(oldOK == false and tostring(oldError):find("too old", 1, true),
  "old oUF version was not rejected")

local broken = NewOUF()
broken.Spawn = nil
local brokenOK, brokenError = pcall(function()
  Run("14.0.2", broken)
end)
expect(brokenOK == false and tostring(brokenError):find("missing Spawn", 1, true),
  "missing oUF capability was not rejected")

local development = Run("@project-version@", NewOUF())
expect(development.oUFContract.detectedVersion == "@project-version@",
  "unexpanded development version was not preserved")

print("oUF contract test: OK")
