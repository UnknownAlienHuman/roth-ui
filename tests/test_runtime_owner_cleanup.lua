local function expect(condition, message)
  if not condition then error(message, 2) end
end

local function read(path)
  local file = assert(io.open(path, "r"))
  local text = file:read("*a")
  file:close()
  return text
end

local function absent(path, token)
  expect(not read(path):find(token, 1, true), path .. " retained retired route: " .. token)
end

local castConsumers = {
  "units/target.lua",
  "units/focus.lua",
  "units/boss.lua",
  "units/mini_target_scaffold.lua",
}
for i = 1, #castConsumers do
  absent(castConsumers[i], "TargetCastbarRuntime")
  absent(castConsumers[i], "onCastbarCreated")
end
absent("core/target_castbar.lua", "__rothCastUnit")
absent("core/target_castbar.lua", "runtime.RefreshActive()\n  end")

local mover = read("core/mover_runtime.lua")
for _, token in ipairs({
  "ns.ForEachMoverFrame", "ns.GetMoverDragHandle", "ns.RegisterMoverFrame",
  "func.RegisterMoverFrame", "ns.SaveMoverLayout", "ns.ClearMoverLayout",
  "ns.ApplySavedMoverLayout",
}) do
  expect(not mover:find(token, 1, true), "mover runtime retained alias: " .. token)
end

local action = read("core/action_bar_background.lua")
for _, token in ipairs({
  "ns.RefreshActionBarArtwork", "ns.ActionBarBackground",
  "playerFrame.ActionBarBackground", "RefreshActionBarArtwork = function",
}) do
  expect(not action:find(token, 1, true), "action artwork retained parallel route: " .. token)
end
for _, path in ipairs({ "oUF/elements/experience.lua", "oUF/elements/reputation.lua", "core/settings_general.lua" }) do
  absent(path, "ns.RefreshActionBarArtwork")
  absent(path, ".RefreshActionBarArtwork")
end

local visibility = read("core/group_header_visibility.lua")
for _, token in ipairs({
  "RegisterStateDriver", "UnregisterStateDriver", "service.states",
  "service.SetDesired", "service.GetDesired", "service.Park", "service.Forget",
}) do
  expect(not visibility:find(token, 1, true), "group visibility retained parallel route: " .. token)
end

print("runtime owner cleanup test: OK")
