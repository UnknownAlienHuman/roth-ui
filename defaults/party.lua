-- Party defaults extracted from config.lua to keep module settings modular.
-- Pure data: safe to load before the rest of the addon.
local addon, ns = ...

local mediapath = ns.mediapath or "Interface\\AddOns\\Roth_UI\\media\\"

ns.defaults = ns.defaults or {}
ns.defaults.units = ns.defaults.units or {}

ns.defaults.units.party = {
  vertical = true,
  show = true,
  alpha = {
    notinrange = 0.5,
  },
  range = {
    driver = "blizzard",
  },
  scale = 1.1,
  vertwidth = 228,
  vertheight = 64,
  width = 128,
  height = 64,
  -- Default anchor: moved slightly left to reduce center clutter (requested).
  pos = { a1 = "CENTER", a2 = "CENTER", af = "UIParent", x = -355, y = 150 },
  aurawatch = {
    show = true,
    size = 18,
  },
  auras = {
    show = true,
    size = 12,
    onlyShowPlayerDebuffs = false,
    showDebuffType = true,
    showBuffs = false,
    onlyShowPlayerBuffs = true,
    showBuffType = true,
    number = 5,
    spacing = 5,
  },
  health = {
    texture = (mediapath .. "statusbar3"),
    tag = "[diablo:misshp]",
    fontSize = 11,
    point = "RIGHT",
    x = -20,
    y = 0,
  },
  power = {
    texture = (mediapath .. "statusbar3"),
  },
  misc = {
    NameFontSize = 14,
  },
  portrait = {
    show = true,
    use3D = true,
    width = 85,
  },
  attributes = {
    visibility = "custom [group:party] show; [group:raid] hide; hide",
    showPlayer = true,
    showSolo = false,
    showParty = true,
    showRaid = false,
    hideInArena = false,
    VerticalPoint = "TOP",
    HorizontalPoint = "LEFT",
    xOffset = 8,
    yOffset = -2,
  },
  healprediction = {
    show = true,
    texture = (mediapath .. "statusbar3"),
    color = {
      myself = { r = 0, g = 1, b = 0, a = 1 },
      other = { r = 0, g = 1, b = 0, a = 0.7 },
    },
    maxoverflow = 1.00,
  },
  totalabsorb = {
    show = true,
    texture = (mediapath .. "absorb_statusbar_overlay"),
    color = {
      bar = { r = 0.7, g = 1, b = 1, a = 0.9 },
    },
  },
}
