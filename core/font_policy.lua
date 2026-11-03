-- One font owner: Roth FontStrings and optional, reversible Blizzard fonts.
local _, ns = ...
local func = assert(ns.func, "Roth_UI: font helpers are required")
local safety = assert(ns.safety, "Roth_UI: font safety is required")
local CanAccessAll = assert(safety.CanAccessAll)
local CanUseRegion = assert(safety.CanUseRegion)
local TryGet = assert(safety.TryGet)
local TryMethod = assert(safety.TryMethod)
local ResolveFontPath = assert(func.ResolveFontPath)
local DeferUntilOutOfCombat = assert(ns.framePolicy.DeferUntilOutOfCombat)

local fontPolicy = { ResolveFontPath = ResolveFontPath }
ns.fontPolicy = fontPolicy
local originals = setmetatable({}, { __mode = "k" })

-- Iterate names, not a possibly sparse array of objects: some names are absent
-- on particular clients and must not truncate the rest of the whitelist.
local FONT_NAMES = {
  "GameFontNormal", "GameFontHighlight", "GameFontDisable",
  "GameFontNormalSmall", "GameFontHighlightSmall", "GameFontDisableSmall",
  "SystemFont_NamePlateFixed", "SystemFont_Shadow_Small", "SystemFont_Shadow_Med1", "SystemFont_Shadow_Med2",
  "SystemFont_Shadow_Large", "SystemFont_InverseShadow_Small",
  "SystemFont_Tiny", "SystemFont_Small", "SystemFont_Med1", "SystemFont_Med2",
  "SystemFont_Large", "SystemFont_Huge1", "SystemFont_Huge2", "SystemFont_Huge4",
  "NumberFont_GameNormal", "NumberFont_GameNormalSmall", "NumberFont_OutlineThick_Mono_Small",
  "NumberFont_Outline_Huge", "NumberFont_Outline_Large", "NumberFont_Outline_Med",
}

local function ReadFont(object)
  if not CanUseRegion(object) then return end
  local got, getter = TryGet(object, "GetFont")
  if got ~= true or not safety.CanAccess(getter) or type(getter) ~= "function" then return end
  local ok, path, size, flags = pcall(getter, object)
  if ok ~= true or not CanAccessAll(path, size, flags) then return end
  if type(path) ~= "string" or type(size) ~= "number" or size <= 0 or size > 256 then return end
  if type(flags) ~= "string" then return end
  return path, size, flags
end

local function WriteFont(object, path, size, flags)
  local ok, applied = TryMethod(object, "SetFont", path, size, flags)
  return ok == true and safety.CanAccess(applied) and applied ~= false
end

local function RefreshRothFonts(fontPath)
  for fontString in pairs(ns._fontStrings or {}) do
    local current, size, flags = ReadFont(fontString)
    if current and current ~= fontPath then
      WriteFont(fontString, fontPath, size, flags)
    end
  end
end

local function ApplyBlizzardFonts(fontPath)
  for index = 1, #FONT_NAMES do
    local object = rawget(_G, FONT_NAMES[index])
    local current, size, flags = ReadFont(object)
    if current and current ~= fontPath then
      local state = originals[object]
      if not state then
        state = { path = current, size = size, flags = flags }
      end
      if WriteFont(object, fontPath, size, flags) then
        state.appliedPath, state.appliedSize, state.appliedFlags = fontPath, size, flags
        originals[object] = state
      end
    end
  end
end

local function RestoreBlizzardFonts()
  for object, state in pairs(originals) do
    local current, size, flags = ReadFont(object)
    if current then
      -- Another addon may have taken over since our last write. Restore only
      -- the exact state we still own, and never replay a stale foreign snapshot.
      if current ~= state.appliedPath or size ~= state.appliedSize or flags ~= state.appliedFlags
          or WriteFont(object, state.path, state.size, state.flags) then
        originals[object] = nil
      end
    end
  end
end

function fontPolicy.Refresh()
  if DeferUntilOutOfCombat("font-policy", fontPolicy.Refresh) then return false end
  local cfg = ns.cfg
  if type(cfg) ~= "table" then return false end
  local fontPath = ResolveFontPath(cfg.font)
  if type(fontPath) ~= "string" or fontPath == "" then return false end

  RefreshRothFonts(fontPath)
  if cfg.applyGlobalFonts == true then
    ApplyBlizzardFonts(fontPath)
  else
    RestoreBlizzardFonts()
  end
  return true
end

-- Existing integrations delegate to the same owner; no global font-path writes.
func.ApplyGlobalFonts = fontPolicy.Refresh
fontPolicy.ApplyGlobalFonts = fontPolicy.Refresh
