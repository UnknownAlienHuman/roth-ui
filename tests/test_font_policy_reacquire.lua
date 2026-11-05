local function expect(value, message)
  if not value then error(message, 2) end
end
_G.issecretvalue = function() return false end
_G.canaccessvalue = function() return true end
_G.canaccessallvalues = function() return true end
local font = { path = "stock.ttf", size = 12, flags = "", writes = 0 }
function font:HasAccessConstraints() return false end
function font:IsForbidden() return false end
function font:GetFont() return self.path, self.size, self.flags end
function font:SetFont(path, size, flags)
  self.path, self.size, self.flags = path, size, flags
  self.writes = self.writes + 1
  return true
end
_G.GameFontNormal = font
local ns = {
  func = { ResolveFontPath = function(path) return path end },
  cfg = { font = "roth.ttf", applyGlobalFonts = true },
  framePolicy = { DeferUntilOutOfCombat = function() return false end },
}
assert(loadfile("core/safety.lua"))("Roth_UI", ns)
assert(loadfile("core/font_policy.lua"))("Roth_UI", ns)
local refresh = ns.fontPolicy.Refresh
expect(refresh(), "initial refresh failed")
local writes = font.writes
for i = 1, 50 do refresh() end
expect(font.writes == writes, "unchanged refresh rewrote font")
font.path, font.size, font.flags = "foreign.ttf", 15, "OUTLINE"
expect(refresh() and font.path == "roth.ttf", "reacquire failed")
ns.cfg.applyGlobalFonts = false
expect(refresh(), "restore failed")
expect(font.path == "foreign.ttf" and font.size == 15 and font.flags == "OUTLINE",
  "font reacquire restored an obsolete foreign snapshot")

ns.cfg.applyGlobalFonts = true
refresh()
font.size = 17 -- foreign owner keeps the path but changes the atomic font tuple
refresh()
ns.cfg.font = "roth-new.ttf"
refresh()
ns.cfg.applyGlobalFonts = false
refresh()
expect(font.path == "roth.ttf" and font.size == 17,
  "same-path foreign takeover was not recognized")
print("font compare-and-restore reacquisition test: OK")
