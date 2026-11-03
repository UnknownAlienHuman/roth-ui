local function Font(path, size, flags)
  local object = { path = path, size = size or 12, flags = flags or "", writes = 0 }
  function object:HasAccessConstraints() return false end
  function object:IsForbidden() return false end
  function object:GetFont() return self.path, self.size, self.flags end
  function object:SetFont(value, height, style)
    self.path, self.size, self.flags = value, height, style
    self.writes = self.writes + 1
  end
  return object
end
issecretvalue = function() return false end
canaccessvalue = function() return true end
local inCombat = false
InCombatLockdown = function() return inCombat end
local frames = {}
CreateFrame = function()
  local f = { events = {} }
  function f:RegisterEvent(event) self.events[event] = true end
  function f:UnregisterEvent(event) self.events[event] = nil end
  function f:SetScript(_, callback) self.callback = callback end
  frames[#frames + 1] = f
  return f
end

STANDARD_TEXT_FONT, UNIT_NAME_FONT, DAMAGE_TEXT_FONT = "standard", "name", "damage"
GameFontNormal = Font("original", 14, "OUTLINE")
-- GameFontHighlight is deliberately absent: a hole must not truncate the list.
NumberFont_Outline_Med = Font("numbers", 18)
local own = Font("original", 11)
local ns = {
  cfg = { font = "custom", applyGlobalFonts = true },
  func = { ResolveFontPath = function(path) return path end },
  _fontStrings = { [own] = { size = 11, flags = "" } },
}
assert(loadfile("core/safety.lua"))("Roth_UI", ns)
assert(loadfile("core/frame_policy.lua"))("Roth_UI", ns)
assert(loadfile("core/font_policy.lua"))("Roth_UI", ns)
assert(ns.fontPolicy.Refresh())
assert(own.path == "custom" and own.size == 11)
assert(GameFontNormal.path == "custom" and GameFontNormal.flags == "OUTLINE")
assert(NumberFont_Outline_Med.path == "custom", "missing FontObject truncated the list")
assert(STANDARD_TEXT_FONT == "standard" and UNIT_NAME_FONT == "name" and DAMAGE_TEXT_FONT == "damage",
  "font policy overwrote Blizzard global font paths")
ns.fontPolicy.Refresh()
assert(GameFontNormal.writes == 1 and own.writes == 1, "unchanged fonts were needlessly rewritten")

ns.cfg.font = "second"
ns.fontPolicy.Refresh()
assert(GameFontNormal.path == "second")
NumberFont_Outline_Med:SetFont("foreign-owner", 20, "THICKOUTLINE")
ns.cfg.applyGlobalFonts = false
ns.fontPolicy.Refresh()
assert(GameFontNormal.path == "original" and GameFontNormal.size == 14,
  "disabling did not restore the original FontObject")
assert(NumberFont_Outline_Med.path == "foreign-owner", "restore overwrote a later foreign owner")
assert(own.path == "second", "global-font disable changed Roth's own font")

-- Each new enable cycle captures the current foreign state.
GameFontNormal:SetFont("new-default", 16, "")
ns.cfg.applyGlobalFonts = true
inCombat = true
local writes = GameFontNormal.writes
assert(ns.fontPolicy.Refresh() == false)
ns.fontPolicy.Refresh()
assert(ns.framePolicy.GetPendingCount() == 1 and GameFontNormal.writes == writes,
  "combat font changes were not coalesced/deferred")
inCombat = false
frames[1].callback(frames[1], "PLAYER_REGEN_ENABLED")
assert(GameFontNormal.path == "second")
ns.cfg.applyGlobalFonts = false
ns.fontPolicy.Refresh()
assert(GameFontNormal.path == "new-default" and GameFontNormal.size == 16,
  "new enable cycle restored a stale original")

GameFontNormal.IsForbidden = function() return true end
ns.cfg.applyGlobalFonts = true
ns.cfg.font = "blocked"
ns.fontPolicy.Refresh()
assert(GameFontNormal.path == "new-default", "forbidden FontObject was mutated")
print("font ownership and restore test: OK")
