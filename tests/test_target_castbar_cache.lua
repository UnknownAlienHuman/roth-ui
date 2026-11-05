local function expect(value, message)
  if not value then error(message, 2) end
end
local created = 0
_G.CreateColor = function(r, g, b, a)
  created = created + 1
  return { r = r, g = g, b = b, a = a }
end
local ns = {}
assert(loadfile("core/target_castbar.lua"))("Roth_UI", ns)
local runtime = ns.TargetCastbarRuntime
local secret = {}
local noop = function() end
local overlay = { SetAlpha = noop, Show = noop }
function overlay:SetVertexColorFromBoolean(value, yes)
  expect(value == secret, "opaque boolean was transformed")
  self.color = yes
end
local bar = {
  SetStatusBarColor = noop,
  __rothInterruptOverlay = overlay,
  Shield = { SetAlphaFromBoolean = noop, Show = noop },
  castbarCfg = { color = { semantic = {
    nonInterruptible = { r = 0.9, g = 0.8, b = 0.7, a = 1 },
  } } },
}
runtime.PostCastStart(bar, "target", 123, secret)
local first, initial = overlay.color, created
local concat = table.concat
local concatenations = 0
table.concat = function(...)
  concatenations = concatenations + 1
  return concat(...)
end
for i = 1, 100 do runtime.PostCastInterruptible(bar, "target", 123, secret) end
table.concat = concat
expect(overlay.color == first and created == initial, "unchanged color was recreated")
expect(concatenations == 0, "steady-state color cache allocates a fingerprint table/string")
bar.castbarCfg.color.semantic.nonInterruptible.g = 0.2
runtime.PostCastStart(bar, "target", 123, secret)
expect(overlay.color ~= first and overlay.color.g == 0.2 and created == initial + 1,
  "configuration mutation did not invalidate the color cache")
print("castbar scalar color-cache and opaque-sink test: OK")
