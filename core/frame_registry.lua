local addonName, ns = ...

local registry = ns.frameRegistry or {}
ns.frameRegistry = registry
ns.registry = ns.registry or {}

local type = type
local pairs = pairs

local CATEGORY_ORDER = {
  "art",
  "bars",
  "units",
  "orbs",
}

local CATEGORY_SET = {
  art = true,
  bars = true,
  units = true,
  orbs = true,
}

local DEFAULTS = {
  bars = {
    "Roth_UIExpBar",
    "Roth_UIRepBar",
    "Roth_UISoulShardPower",
    "Roth_UIHolyPower",
    "Roth_UIHarmonyPower",
    "Roth_UIRuneBar",
    "Roth_UIComboPoints",
    "Roth_UIArcanePower",
    "Roth_DruidMana",
  },
  orbs = {
    "Roth_UIPowerOrb",
    "Roth_UIPlayerFrame",
  },
  units = {
    "Roth_UITargetFrame",
    "Roth_UITargetTargetFrame",
    "Roth_UIPetTargetFrame",
    "Roth_UIPetFrame",
    "Roth_UIFocusTargetFrame",
    "Roth_UIFocusFrame",
  },
  art = {
    "Roth_UIActionBarBackground",
    "Roth_UIAngelFrame",
    "Roth_UIDemonFrame",
    "Roth_UIBottomLine",
    "Roth_UIPlayerPortrait",
    "Roth_UITargetPortrait",
  },
}

registry._lists = registry._lists or {}
registry._lookup = registry._lookup or {}

local function GetFrameName(entry)
  if type(entry) == "string" and entry ~= "" then
    return entry
  end

  if type(entry) == "table" and type(entry.GetName) == "function" then
    local name = entry:GetName()
    if type(name) == "string" and name ~= "" then
      return name
    end
  end

  return nil
end

local function EnsureCategory(category)
  if type(category) ~= "string" then
    return nil, nil
  end

  local list = registry._lists[category]
  if type(list) ~= "table" then
    list = {}
    registry._lists[category] = list
  end

  local lookup = registry._lookup[category]
  if type(lookup) ~= "table" then
    lookup = {}
    registry._lookup[category] = lookup
  end

  ns.registry[category] = list
  return list, lookup
end

local function SeedCategory(category)
  local list, lookup = EnsureCategory(category)
  if type(list) ~= "table" or type(lookup) ~= "table" then
    return
  end
  local seedList = DEFAULTS[category]

  if type(seedList) ~= "table" then
    return
  end

  for i = 1, #seedList do
    local frameName = seedList[i]
    if type(frameName) == "string" and frameName ~= "" and not lookup[frameName] then
      lookup[frameName] = true
      list[#list + 1] = frameName
    end
  end
end

local function ResolveGlobalFrame(frameName)
  if type(frameName) ~= "string" or frameName == "" then
    return nil
  end

  local frame = _G[frameName]
  if type(frame) == "table" and type(frame.GetName) == "function" then
    return frame
  end

  return nil
end

local function ResolveEntryFrame(list, lookup, index)
  if type(list) ~= "table" then
    return nil
  end

  local entry = list[index]
  if type(entry) == "table" then
    return entry
  end

  if type(entry) ~= "string" or entry == "" then
    return nil
  end

  local frame = ResolveGlobalFrame(entry)
  if not frame then
    return nil
  end

  list[index] = frame
  if type(lookup) == "table" then
    lookup[entry] = true
    lookup[frame] = true
  end

  return frame
end

local function NormalizeTwoArgs(first, second, third)
  if type(first) == "table" then
    return second, third
  end
  return first, second
end

local function FindEntryIndex(list, entry, entryName)
  if type(list) ~= "table" then
    return nil
  end

  for i = 1, #list do
    local current = list[i]
    if current == entry then
      return i
    end
    if entryName and GetFrameName(current) == entryName then
      return i
    end
  end

  return nil
end

local function RegisterEntry(category, entry)
  if type(entry) ~= "string" and type(entry) ~= "table" then
    return false
  end
  if type(entry) == "string" and entry == "" then
    return false
  end
  if type(entry) == "table" and type(entry.GetName) ~= "function" then
    return false
  end

  local list, lookup = EnsureCategory(category)
  if type(list) ~= "table" or type(lookup) ~= "table" then
    return false
  end

  local entryName = GetFrameName(entry)
  local existingIndex = FindEntryIndex(list, entry, entryName)
  if existingIndex then
    local existing = list[existingIndex]
    if existing == entry then
      lookup[entry] = true
      if entryName then
        lookup[entryName] = true
      end
      return false
    end

    if type(existing) == "string" and type(entry) == "table" then
      list[existingIndex] = entry
      lookup[existing] = true
      lookup[entry] = true
      if entryName then
        lookup[entryName] = true
      end
      return true
    end

    return false
  end

  list[#list + 1] = entry
  lookup[entry] = true
  if entryName then
    lookup[entryName] = true
  end
  return true
end

function registry.Register(category, frameOrName, methodFrameOrName)
  category, frameOrName = NormalizeTwoArgs(category, frameOrName, methodFrameOrName)
  return RegisterEntry(category, frameOrName)
end

function registry.RegisterFrame(category, frame, methodFrame)
  category, frame = NormalizeTwoArgs(category, frame, methodFrame)
  return RegisterEntry(category, frame)
end

function registry.RegisterName(category, frameName, methodFrameName)
  category, frameName = NormalizeTwoArgs(category, frameName, methodFrameName)
  if type(frameName) ~= "string" or frameName == "" then
    return false
  end

  return RegisterEntry(category, frameName)
end

function registry.GetList(category, methodCategory)
  category = NormalizeTwoArgs(category, methodCategory)
  local list = EnsureCategory(category)
  return list
end

function registry.GetAllLists(self)
  local lists = {}
  for i = 1, #CATEGORY_ORDER do
    lists[i] = registry.GetList(CATEGORY_ORDER[i])
  end
  return lists
end

function registry.GetCategory(frameOrName, methodFrameOrName)
  frameOrName = NormalizeTwoArgs(frameOrName, methodFrameOrName)

  local entryName = GetFrameName(frameOrName)
  if not entryName and type(frameOrName) == "string" and frameOrName ~= "" then
    entryName = frameOrName
  end

  if type(frameOrName) ~= "table" and type(entryName) ~= "string" then
    return nil
  end

  for i = 1, #CATEGORY_ORDER do
    local category = CATEGORY_ORDER[i]
    local list = registry.GetList(category)
    if FindEntryIndex(list, frameOrName, entryName) then
      return category
    end
  end

  return nil
end

function registry.ResolveFrame(category, frameOrName, methodFrameOrName)
  category, frameOrName = NormalizeTwoArgs(category, frameOrName, methodFrameOrName)

  if type(frameOrName) == "table" then
    return frameOrName
  end

  local entryName = type(frameOrName) == "string" and frameOrName or GetFrameName(frameOrName)
  if type(entryName) ~= "string" or entryName == "" then
    return nil
  end

  local function ResolveFromCategory(targetCategory)
    local list, lookup = EnsureCategory(targetCategory)
    if type(list) ~= "table" or type(lookup) ~= "table" then
      return nil
    end

    local index = FindEntryIndex(list, entryName, entryName)
    if not index then
      return nil
    end

    return ResolveEntryFrame(list, lookup, index)
  end

  if CATEGORY_SET[category] then
    return ResolveFromCategory(category)
  end

  if category == nil or category == "all" then
    for i = 1, #CATEGORY_ORDER do
      local frame = ResolveFromCategory(CATEGORY_ORDER[i])
      if frame then
        return frame
      end
    end
  end

  return nil
end

function registry.ForEachSelection(selection, callback, methodCallback)
  selection, callback = NormalizeTwoArgs(selection, callback, methodCallback)
  if type(callback) ~= "function" then
    return
  end

  if selection == "all" then
    for i = 1, #CATEGORY_ORDER do
      local category = CATEGORY_ORDER[i]
      callback(category, registry.GetList(category))
    end
    return
  end

  if CATEGORY_SET[selection] then
    callback(selection, registry.GetList(selection))
  end
end

function registry.ForEachEntry(selection, callback, methodCallback)
  selection, callback = NormalizeTwoArgs(selection, callback, methodCallback)
  if type(callback) ~= "function" then
    return
  end

  registry.ForEachSelection(selection or "all", function(category, list)
    if type(list) ~= "table" then
      return
    end

    for i = 1, #list do
      callback(list[i], category, i)
    end
  end)
end

function registry.ForEachFrame(selection, callback, methodCallback)
  selection, callback = NormalizeTwoArgs(selection, callback, methodCallback)
  if type(callback) ~= "function" then
    return
  end

  local seen = {}

  registry.ForEachEntry(selection or "all", function(_, category, index)
    local list = registry._lists[category]
    local lookup = registry._lookup[category]
    local frame = ResolveEntryFrame(list, lookup, index)
    if type(frame) == "table" and not seen[frame] then
      seen[frame] = true
      callback(frame, category, frame)
    end
  end)
end

for i = 1, #CATEGORY_ORDER do
  SeedCategory(CATEGORY_ORDER[i])
end
