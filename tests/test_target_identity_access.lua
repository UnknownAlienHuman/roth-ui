local function expect(condition, message)
  if not condition then error(message, 2) end
end

local inaccessible = setmetatable({}, {
  __tostring = function() error("inaccessible value was stringified") end,
})
local mode = "restricted"

_G.UnitLevel = function() return mode == "restricted" and inaccessible or 70 end
_G.UnitRace = function() return mode == "restricted" and inaccessible or "Human" end
_G.UnitCreatureType = function() return mode == "restricted" and inaccessible or nil end
_G.UnitIsPlayer = function() return mode == "restricted" and inaccessible or true end
_G.UnitClassification = function() return mode == "restricted" and inaccessible or "elite" end
_G.UnitClass = function() return mode == "restricted" and inaccessible or "Mage" end

local oUF = { Tags = { Methods = {}, Events = {} } }
local ns = {
  oUF = oUF,
  cfg = { units = { target = { show = false } } },
  func = {
    IsSecretValue = function() return false end,
  },
  safety = {
    CanAccess = function(value) return value ~= inaccessible end,
    IsSecret = function() return false end,
  },
  unit = {},
}

assert(loadfile("units/target.lua"))("Roth_UI", ns)
local classText = assert(oUF.Tags.Methods["diablo:classtext"])
local ok, text = pcall(classText, "target")
expect(ok, "inaccessible target identity reached Lua formatting: " .. tostring(text))
expect(text == "??", "inaccessible target identity did not collapse to the neutral level marker")

mode = "ordinary"
expect(classText("target") == "70 Human Elite Mage",
  "ordinary target class text changed")

local source = assert(io.open("units/target.lua", "r")):read("*a")
expect(source:find("if not CanReadOrdinaryValue(exists) then return end", 1, true),
  "target sound path does not gate UnitExists before comparison")
expect(source:find("local enemyReadable = CanReadOrdinaryValue(enemy)", 1, true)
    and source:find("local friendlyReadable = CanReadOrdinaryValue(friendly)", 1, true),
  "target sound path does not gate reaction booleans before branching")

print("target identity and sound access-boundary test: OK")
