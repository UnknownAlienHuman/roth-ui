local function expect(condition, message)
  if not condition then error(message, 2) end
end

local file = assert(io.open("core/mover_runtime.lua", "rb"))
local source = file:read("*a")
file:close()

for _, token in ipairs({
  "NormalizeFiniteNumber",
  "IsForbiddenTable",
  "CanUseRegionFor",
  "UntrustedLayoutScriptExecution",
  "SetMoverPointTransactional",
  "ResolveMoverAnchorFrame",
}) do
  expect(source:find(token, 1, true), "mover safety contract missing: " .. token)
end
expect(not source:find("_G[point.af]", 1, true),
  "mover restored arbitrary global anchors without an access/layout gate")
expect(not source:find("v = tonumber(v)", 1, true),
  "mover converted persisted values before the access gate")

local bootstrap = assert(io.open("core/frame_policy_bootstrap.lua", "rb"))
local bootstrapSource = bootstrap:read("*a")
bootstrap:close()
expect(bootstrapSource:find("local _, isLoaded = C_AddOns.IsAddOnLoaded", 1, true),
  "frame bootstrap does not use the completed IsAddOnLoaded result")
expect(not bootstrapSource:find("ApplyUnitFramePolicy", 1, true),
  "frame bootstrap retained a dead unit-policy compatibility owner")

print("mover/bootstrap source contract test: OK")
