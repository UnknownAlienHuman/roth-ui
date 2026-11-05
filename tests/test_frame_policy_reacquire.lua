local function expect(value, message)
  if not value then error(message, 2) end
end
_G.issecretvalue = function() return false end
_G.canaccessvalue = function() return true end
_G.canaccessallvalues = function() return true end
_G.InCombatLockdown = function() return false end
_G.CreateFrame = function() error("noncombat path allocated an event frame") end
local ns = {}
assert(loadfile("core/safety.lua"))("Roth_UI", ns)
assert(loadfile("core/frame_policy.lua"))("Roth_UI", ns)
local policy = ns.framePolicy
local function region()
  local r = { alpha = 0.75, mouse = true, writes = 0 }
  function r:HasAccessConstraints() return false end
  function r:IsForbidden() return false end
  function r:GetAlpha() return self.alpha end
  function r:IsMouseEnabled() return self.mouse end
  function r:SetAlpha(value) self.alpha = value; self.writes = self.writes + 1 end
  function r:EnableMouse(value) self.mouse = value; self.writes = self.writes + 1 end
  return r
end
local failures = {}
local function check(name, fn)
  local ok, message = pcall(fn)
  if not ok then failures[#failures + 1] = name .. ": " .. message end
end
check("idempotent suppression", function()
  local r = region()
  expect(policy.SetSuppressed(r, true), "initial suppression failed")
  local writes = r.writes
  for i = 1, 50 do expect(policy.SetSuppressed(r, true), "repeated suppression failed") end
  expect(r.writes == writes, "unchanged suppression repeated native mutations")
  expect(policy.SetSuppressed(r, false), "restore failed")
  expect(r.alpha == 0.75 and r.mouse, "idempotent path lost restore ownership")
end)
check("foreign property changed before reapply", function()
  local r = region()
  expect(policy.SetSuppressed(r, true), "initial suppression failed")
  r.alpha = 0.35
  expect(policy.SetSuppressed(r, true), "reacquire failed")
  expect(policy.SetSuppressed(r, false), "restore failed")
  expect(r.alpha == 0.35 and r.mouse, "reapply restored an obsolete foreign snapshot")
end)
check("failed reacquire rollback", function()
  local r = region()
  expect(policy.SetSuppressed(r, true), "initial suppression failed")
  r.alpha, r.mouse = 0.45, true
  local setter = r.EnableMouse
  function r:EnableMouse(value)
    setter(self, value)
    if value == false then error("failure after mutation") end
  end
  expect(not policy.SetSuppressed(r, true), "partial failure accepted")
  expect(r.alpha == 0.45 and r.mouse, "rollback replayed stale state after reacquire")
end)
expect(#failures == 0, table.concat(failures, "\n"))
print("foreign-frame reacquisition and idempotence tests: OK")
