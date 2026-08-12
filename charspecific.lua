-- Optional character-specific overrides.
-- Disabled by default to avoid silently overriding SavedVariables.
local addon, ns = ...

local cfg = ns.cfg
if not (cfg and cfg._allowCharSpecific) then
  return
end

-- Put any manual per-character tweaks below.
-- Example:
-- if cfg.playername == "Loral" and cfg.playerclass == "DRUID" then
--   cfg.units.focus.auras.showBuffs = false
-- end
