local function expect(condition, message)
  if not condition then error(message, 2) end
end

local function expectLoadFailure(path, ns, expected)
  local chunk = assert(loadfile(path))
  local ok, message = pcall(chunk, "Roth_UI", ns)
  expect(ok == false, path .. " accepted a missing canonical owner")
  expect(tostring(message):find(expected, 1, true) ~= nil,
    path .. " failed for the wrong reason: " .. tostring(message))
end

_G.C_Timer = nil
expectLoadFailure("core/deferred_scheduler.lua", {
  safety = { TryCall = function() return true end },
}, "C_Timer.After is required")

expectLoadFailure("core/movegrid.lua", {}, "defer.RunNextFrame is required")

_G.oUF = { AddElement = function() end }
local nsWithoutOwner = {
  cfg = { units = { player = { expbar = {}, repbar = {} } } },
  safety = {
    CanAccess = function() return true end,
    IsSecret = function() return false end,
  },
}
expectLoadFailure("oUF/elements/experience.lua", nsWithoutOwner, "ns.oUF is required")
expectLoadFailure("oUF/elements/reputation.lua", nsWithoutOwner, "ns.oUF is required")
expectLoadFailure("oUF/elements/target_border.lua", nsWithoutOwner, "ns.oUF is required")

local runtimeFiles = {
  "config.lua",
  "core/aura_runtime.lua",
  "core/lib.lua",
  "units/target.lua",
  "units/targettarget.lua",
  "units/pet.lua",
  "units/focus.lua",
  "units/pettarget.lua",
  "units/focustarget.lua",
  "units/party.lua",
  "units/raid.lua",
  "units/boss.lua",
  "units/player.lua",
}
for i = 1, #runtimeFiles do
  local source = assert(io.open(runtimeFiles[i], "r")):read("*a")
  expect(not source:find("ns.oUF or", 1, true) and not source:find("_G.oUF", 1, true)
      and not source:find('_G["oUF"]', 1, true),
    runtimeFiles[i] .. " retained a parallel global oUF owner")
end

print("required runtime owner contract test: OK")
