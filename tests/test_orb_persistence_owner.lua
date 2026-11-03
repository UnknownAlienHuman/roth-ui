local function expect(condition, message)
  if not condition then error(message, 2) end
end

local charRoot = { HEALTH = { value = { top = { mode = "current" } } } }
local sanitizeCount = 0
local failedSanitizeRoot = charRoot
local blockedName = nil
local globalWriteAllowed = true
local charWriteAllowed = true
local globalRoot = {
  __schemaPatch = 4,
  __selection = { HEALTH = "", POWER = "" },
  TEMPLATE_LIST = {},
}
local ns = {
  safety = {
    CanAccess = function(value) return blockedName == nil or value ~= blockedName end,
    CopySerializable = function(value)
      if type(value) ~= "table" then return value end
      local copy = {}
      for key, child in pairs(value) do copy[key] = child end
      return copy
    end,
  },
  OrbTextController = {
    GetDefaultMode = function() return "current" end,
    NormalizeMode = function(_, _, fallback) return fallback end,
    GetValueMode = function() return "current" end,
    NormalizeValueConfig = function() end,
  },
  configPersistence = { ACCOUNT_DB_VAR = "Roth_UI_DB", CHAR_DB_VAR = "Roth_UI_DB_Char" },
  store = {
    GetOrbCharRoot = function() return charRoot end,
    SetOrbCharRoot = function(value)
      sanitizeCount = sanitizeCount + 1
      if not charWriteAllowed then return false end
      if value == failedSanitizeRoot then return false end
      charRoot = value
      return true
    end,
    GetOrbGlobalRoot = function() return globalRoot end,
    SetOrbGlobalRoot = function(value)
      if not globalWriteAllowed then return false end
      sanitizeCount = sanitizeCount + 1
      globalRoot = value
      return true
    end,
  },
  db = {
    GetOrbDefaults = function()
      return { HEALTH = { value = { hideOnEmpty = true, hideOnFull = false, top = { mode = "current" }, bottom = { mode = "current" } } },
        POWER = { value = { hideOnEmpty = true, hideOnFull = false, top = { mode = "current" }, bottom = { mode = "current" } } } }
    end,
    GetTemplateDefaults = function()
      return { __selection = { HEALTH = "", POWER = "" }, pearl = { value = { top = { mode = "current" }, bottom = { mode = "current" } } } }
    end,
    GetTemplateSelectionDefaults = function() return { HEALTH = "", POWER = "" } end,
    GetTemplateListDefaults = function() return {} end,
  },
}
_G.CreateFrame = function()
  return { RegisterEvent = function() end, SetScript = function() end }
end
_G.InCombatLockdown = function() return false end

assert(loadfile("core/orb_persistence_owner.lua"))("Roth_UI", ns)
local owner = ns.orbPersistence
for _, reserved in ipairs({ "TEMPLATE_LIST", "__selection", "__schemaPatch", "reset" }) do
  expect(owner.SaveTemplate(reserved, "HEALTH") == false,
    "template save accepted reserved metadata key " .. reserved)
end
blockedName = "restricted-but-not-secret"
expect(owner.SaveTemplate(blockedName, "HEALTH") == false,
  "template save accessed an inaccessible name")
blockedName = nil
expect(owner.SaveTemplate(string.rep("x", 25), "HEALTH") == false,
  "template save accepted a name longer than the settings dialog limit")
local saved, normalizedName = owner.SaveTemplate("  clean  ", "HEALTH")
expect(saved == true and normalizedName == "clean", "valid template save did not return its normalized name")
expect(charRoot ~= failedSanitizeRoot, "failed root sanitization allowed the unsafe store to remain canonical")
expect(type(globalRoot.clean) == "table", "valid template data was not stored")
expect(type(globalRoot.__selection) == "table", "template save damaged selection metadata")
expect(type(globalRoot.TEMPLATE_LIST) == "table", "template save damaged template list metadata")
for _, reserved in ipairs({ "TEMPLATE_LIST", "__selection", "__schemaPatch", "reset" }) do
  local prior = globalRoot[reserved]
  expect(owner.LoadTemplate(reserved, "HEALTH") == false,
    "template load accepted reserved metadata key " .. reserved)
  expect(owner.DeleteTemplate(reserved) == false,
    "template deletion accepted reserved metadata key " .. reserved)
  expect(globalRoot[reserved] == prior,
    "reserved template operation changed metadata key " .. reserved)
end
expect(owner.SaveTemplate(string.rep("é", 24), "HEALTH") == true,
  "valid 24-character UTF-8 template name was rejected")
local sanitationBeforeReads = sanitizeCount
owner.RunPipeline()
owner.RunPipeline()
expect(sanitizeCount == sanitationBeforeReads,
  "routine orb pipeline reads repeated root sanitation after the root owner cached validation")

local previousGlobalRoot = globalRoot
globalWriteAllowed = false
expect(owner.SaveTemplate("rejected-write", "HEALTH") == false,
  "template save reported success after the root setter rejected the write")
expect(globalRoot == previousGlobalRoot and globalRoot["rejected-write"] == nil,
  "rejected template save mutated the live canonical global root")
expect(owner.ResetTemplateLibrary() == false and globalRoot == previousGlobalRoot and globalRoot.reset == nil,
  "rejected template reset mutated or replaced the live global root")
expect(owner.DeleteTemplate("clean") == false and globalRoot == previousGlobalRoot and type(globalRoot.clean) == "table",
  "rejected template deletion mutated or replaced the live global root")

globalWriteAllowed = true
local previousCharRoot = charRoot
charWriteAllowed = false
expect(owner.LoadTemplate("clean", "HEALTH") == false and charRoot == previousCharRoot,
  "rejected template load mutated or replaced the live character root")
expect(owner.ResetOrbToDefaults("HEALTH") == false and charRoot == previousCharRoot,
  "rejected character reset mutated or replaced the live character root")

print("orb persistence template key validation test: OK")
