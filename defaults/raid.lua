-- Raid defaults extracted from config.lua to keep module settings modular.
-- Pure data: safe to load before the rest of the addon.
local addon, ns = ...

local mediapath = ns.mediapath or "Interface\\AddOns\\Roth_UI\\media\\"

ns.defaults = ns.defaults or {}
ns.defaults.units = ns.defaults.units or {}

ns.defaults.units.raid = {
  show = true,
  special = {
    chains = false,
  },
  alpha = {
    notinrange = 0.4,
  },
  scale = 1.3,
  -- Default anchor: moved slightly left (requested).
  pos = { a1 = "TOPLEFT", a2 = "TOPLEFT", af = "UIParent", x = -15, y = -5 },
  health = {
    texture = (mediapath .. "statusbar3"),
  },
  power = {
    texture = (mediapath .. "statusbar3"),
  },
  aurawatch = {
    show = true,
  },
  auras = {
    whitelist = {
      223306,
      53563,
      6940,
      287280,
      156910,
      200025,
      313255,
      774,
      155777,
      8936,
      33763,
      48438,
      335305,
    },
    show = false,
    disableCooldown = false,
    showBuffType = true,
    onlyShowPlayer = true,
    showDebuffType = true,
    size = 13,
    num = 5,
    spacing = 3,
    debuffPos = { a1 = "CENTER", x = 0, y = -23 },
    buffPos = { a1 = "CENTER", x = 33, y = 0 },
  },
  attributes = {
    visibility = "custom [nogroup] show; [group:party] show; [group:raid] show; hide",
    showPlayer = true,
    showSolo = true,
    showParty = true,
    showRaid = true,
    showInArena = false,
    point = "TOP",
    yOffset = 15,
    xoffset = 0,
    maxColumns = 4,
    unitsPerColumn = 10,
    columnSpacing = -20,
    columnAnchorPoint = "LEFT",
  },
  healprediction = {
    show = false,
    texture = (mediapath .. "statusbar3"),
    color = {
      myself = { r = 0, g = 1, b = 0, a = 1 },
      other = { r = 0, g = 1, b = 0, a = 0.7 },
    },
    maxoverflow = 1.05,
  },
  totalabsorb = {
    show = true,
    texture = (mediapath .. "absorb_statusbar_overlay"),
    color = {
      bar = { r = 0.7, g = 1, b = 1, a = 0.9 },
    },
  },

  -- Layout (Midnight): keep historical 2x4 grouping as a single anchor.
  layout = {
    columns = 2,
    groupSpacingX = 128,
    groupSpacingY = 310,
  },
}
