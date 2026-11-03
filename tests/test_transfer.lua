local function expect(condition, message)
  if not condition then error(message, 2) end
end

local decodeCalls = 0
local decompressOutput = "valid"
local serializeOutput = "valid"
local appliedPayload
local inCombat = false
local decodedEnvelope
_G.InCombatLockdown = function() return inCombat end

_G.Enum = { CompressionMethod = { Deflate = 1 } }
_G.C_EncodingUtil = {
  SerializeCBOR = function()
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
    CopySerializable = function(value) return value end,
    CopySerializableStrict = function(value)
      local seen = {}
      local function copyStrict(source, depth)
        local kind = type(source)
        if kind == "number" and (source ~= source or source == math.huge or source == -math.huge) then return nil end
        if kind == "string" or kind == "number" or kind == "boolean" then return source end
        if kind ~= "table" or depth > 64 or seen[source] then return nil end
        seen[source] = true
        local result = {}
        for key, child in pairs(source) do
          if type(key) ~= "string" and type(key) ~= "number" then return nil end
          local copied = copyStrict(child, depth + 1)
          if copied == nil then return nil end
          result[key] = copied
        end
        seen[source] = nil
        return result
      end
      return copyStrict(value, 0)
    end,
    TryCall = function(fn, ...)
      local ok, result = pcall(fn, ...)
      return ok, result
    end,
  },
  persistence = {
    GetTransferRoots = function() return {} end,
    ApplyTransferRoots = function(payload)
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
decodedEnvelope = nil

serializeOutput = string.rep("x", 4 * 1024 * 1024 + 1)
local exportText, exportError = transfer.Export("full")
expect(exportText == nil and exportError:find("Export is too large", 1, true),
  "oversized export was not rejected before compression")

print("transfer size limits test: OK")
