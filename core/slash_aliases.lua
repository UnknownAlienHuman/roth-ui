-- Backward-compatible command aliases. The command parser and ownership remain
-- in core/slashcmd.lua; this file only exposes established entry points.
assert(type(_G.SlashCmdList) == "table" and type(_G.SlashCmdList.roth) == "function",
  "Roth_UI: /roth handler must load before slash aliases")

_G.SLASH_roth2 = "/rothui"
_G.SLASH_roth3 = "/rui"
