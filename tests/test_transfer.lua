local function expect(condition, message)
  if not condition then error(message, 2) end
end

local function copyStrict(value, seen)
  local kind = type(value)
  if kind == "number" and (value ~= value or value == math.huge or value == -math.huge) then return nil end
  if kind == "string" or kind == "number" or kind == "boolean" then return value end
  if kind ~= "table" then return nil end
  seen = seen or {}
  if seen[value] then return nil end
  seen[value] = true
  local result = {}
  for key, child in pairs(value) do
    local copiedKey = copyStrict(key, seen)
    local copiedValue = copyStrict(child, seen)
    if copiedKey == nil or copiedValue == nil then return nil end
    result[copiedKey] = copiedValue
  end
  return result
end

local decodeCalls = 0
local serializeCalls = 0
local decompressOutput = "valid"
local serializeOutput = "valid"
local appliedPayload
local applyResult, applyError = true, nil
local inCombat = false
local decodedEnvelope
local exportRootsAvailable = true
local transferRoots = {
  accountRoot = { schema = { version = 1 }, account = { settings = {}, templates = {} } },
  charRoot = { schema = { version = 1 }, orbs = {} },
}
_G.InCombatLockdown = function() return inCombat end

_G.Enum = { CompressionMethod = { Deflate = 1 } }
_G.C_EncodingUtil = {
  SerializeCBOR = function()
    serializeCalls = serializeCalls + 1
    return serializeOutput
  end,
  CompressString = function(value)
    return value
  end,
  EncodeBase64 = function(value)
    return value
  end,
  DecodeBase64 = function(value)
    decodeCalls = decodeCalls + 1
    return value
  end,
  DecompressString = function()
    return decompressOutput
  end,
  DeserializeCBOR = function()
    return decodedEnvelope or {
      kind = "Roth_UI_Settings_Export",
      version = 1,
      mode = "full",
      account = { account = { settings = {}, templates = {} } },
      char = { orbs = {} },
    }
  end,
}

local ns = {
  safety = {
    CopySerializableStrict = copyStrict,
    TryCall = function(fn, ...)
      local ok, result = pcall(fn, ...)
      return ok, result
    end,
  },
  persistence = {
    GetTransferRoots = function()
      if not exportRootsAvailable then
        return nil, "strict export snapshot failed"
      end
      return transferRoots
    end,
    ApplyTransferRoots = function(payload)
      if applyResult ~= true then return false, applyError end
      appliedPayload = payload
      return true
    end,
    ReloadUI = function() return true end,
  },
}
_G.Roth_UI = ns

assert(loadfile("core/transfer.lua"))("Roth_UI")
local transfer = assert(ns.transfer)
local ok, message

inCombat = true
ok, message = transfer.Import("full", "RUI1:small")
expect(ok == false and message:find("blocked in combat", 1, true),
  "direct Import bypassed the combat guard")
expect(appliedPayload == nil and decodeCalls == 0, "combat Import touched the transfer payload")
inCombat = false

ok, message = transfer.Import("full", "RUI1:" .. string.rep("x", 2 * 1024 * 1024))
expect(ok == false and message:find("character limit", 1, true), "oversized import text was not rejected")
expect(decodeCalls == 0, "oversized text reached base64 decoding")

decompressOutput = string.rep("x", 4 * 1024 * 1024 + 1)
ok, message = transfer.Import("full", "RUI1:small")
expect(ok == false and message:find("Decompressed import data", 1, true),
  "oversized decompressed data was not rejected")
expect(decodeCalls == 1, "valid-sized import did not reach decoding")
expect(appliedPayload == nil, "oversized import changed live persistence")

decompressOutput = "valid"
ok, message = transfer.Import("full", "RUI1:small")
expect(ok == true and appliedPayload ~= nil, "RUI1 export compatibility was not preserved")
expect(appliedPayload.accountRoot.account.settings ~= nil and appliedPayload.charRoot.orbs ~= nil,
  "compatible import did not stage both roots")

local previousPayload = appliedPayload
decodedEnvelope = {
  kind = "Roth_UI_Settings_Export",
  version = 1,
  mode = "full",
  account = { account = { settings = { invalid = function() end }, templates = {} } },
  char = { orbs = {} },
}
ok, message = transfer.Import("full", "RUI1:small")
expect(ok == false and message:find("Account payload", 1, true),
  "import accepted a root containing a nonserializable descendant")
expect(appliedPayload == previousPayload, "invalid import replaced persisted roots")
decodedEnvelope = {
  kind = "Roth_UI_Settings_Export",
  version = 1,
  mode = "full",
  account = { account = { settings = { invalidNumber = math.huge }, templates = {} } },
  char = { orbs = {} },
}
ok, message = transfer.Import("full", "RUI1:small")
expect(ok == false and message:find("Account payload", 1, true),
  "import accepted a non-finite persisted number")
expect(appliedPayload == previousPayload, "non-finite number import replaced persisted roots")

local shared = { value = true }
decodedEnvelope = {
  kind = "Roth_UI_Settings_Export",
  version = 1,
  mode = "full",
  account = { account = { settings = { first = shared, second = shared }, templates = {} } },
  char = { orbs = {} },
}
ok, message = transfer.Import("full", "RUI1:small")
expect(ok == false and message:find("Account payload", 1, true),
  "import accepted a shared-reference persistence graph")
expect(appliedPayload == previousPayload, "aliased import replaced persisted roots")

decodedEnvelope = nil
applyResult, applyError = false, "transaction rolled back"
ok, message = transfer.Import("full", "RUI1:small")
expect(ok == false and message == applyError,
  "import discarded the persistence transaction failure reason")
expect(appliedPayload == previousPayload, "failed transaction published a new payload")
applyResult, applyError = true, nil

exportRootsAvailable = false
local beforeSerializeCalls = serializeCalls
local unavailableExport, unavailableError = transfer.Export("full")
expect(unavailableExport == nil and unavailableError == "strict export snapshot failed",
  "export hid strict snapshot failure")
expect(serializeCalls == beforeSerializeCalls,
  "failed export snapshot reached native serialization")
exportRootsAvailable = true

serializeOutput = string.rep("x", 4 * 1024 * 1024 + 1)
local exportText, exportError = transfer.Export("full")
expect(exportText == nil and exportError:find("Export is too large", 1, true),
  "oversized export was not rejected before compression")

print("transfer size and transaction boundary test: OK")
