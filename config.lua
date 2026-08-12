
  ---------------------------------------------
  --  Roth UI
  ---------------------------------------------

  --  A Diablo themed unitframe layout for oUF 1.6.x
  --  Joker119 - 2016-2023
  ---------------------------------------------

  --get the addon namespace
  local addon, ns = ...
  local oUF = ns.oUF or _G.oUF
  ns.oUF = oUF
  local mediapath = "Interface\\AddOns\\Roth_UI\\media\\"
  ns.mediapath = mediapath
  local LSM = LibStub("LibSharedMedia-3.0")

  --object container
  local cfg = {}
  ns.cfg = cfg
  cfg.__version = 60
  local locale = GetLocale()
  ---------------------------------------------
  -- // CONFIG // --
  ---------------------------------------------

  -- NOTE: Embedded module loading has been removed for Midnight.
  -- Module features (chat/minimap/tooltip/etc.) are maintained as separate addons.

  -- colorswitcher define your color for healthbars here
  ----------------------------------------

  --color is in RGB (red (r), green (g), blue (b), alpha (a)), values are from 0 (dark color) to 1 (bright color). 1,1,1 = white / 0,0,0 = black / 1,0,0 = red etc
  cfg.colorswitcher = {
    bright              = { r = 1, g = 0, b = 0, a = 1, },          -- the bright color
    dark                = { r = 1, g = 0, b = 0, a = 0.1, },   -- the dark color
    classcolored        = true,  -- true   -> override the bright color with the unit specific color (class, faction, happiness, threat), if false uses the predefined color
    useBrightForeground = true,  -- true   -> use bright color in foreground and dark color in background
                                 -- false  -> use dark color in foreground and bright color in background
    threatColored       = true,  -- true/false -> enable threat coloring of the health plate for raidframes
  }

  --frames have a new highlight that fades on hp loss, if that is still not enough you can adjust a multiplier here
  cfg.highlightMultiplier = 0 --range 0-1

  -- Глобальный режим отображения HP текста для всех юнит-фреймов.
  -- "cur" = текущее значение, "percent" = процент, "curpercent" = значение + процент
  cfg.healthValueMode = "cur"

  -- Сокращение больших чисел (1k, 1m, 1b). true = сокращать, false = полные числа.
  -- Schema patching keeps malformed legacy values aligned with this default without overwriting explicit user choice.
  cfg.shortNumbers = true

  --simple aura display options (duration text + cooldown swipe)
  cfg.simpleAuras = {
    durationText = false,
    cooldownSwipe = true,
    durationUpdateRate = 0.3, --seconds, lower = smoother but more CPU
  }

  -- Embedded module gates used by legacy rABS/rButtonTemplate code paths.
  cfg.embeds = {
    rActionBarStyler = true,
    rButtonTemplate = true,
  }

  ----------------------------------------
  --units
  ----------------------------------------

  cfg.units = {
    -- PLAYER
    player = {
      show = true,
      size = 160,
      scale = 1,
      pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = -264, y = 2 },
      health = {
        frequentUpdates = false,
        smooth = true,
      },
      power = {
        frequentUpdates = false,
        smooth = true,
      },
      absorb = {
        show = true,
        smooth = true,
      },
      healprediction = { --WIP
        show = false,
        color = {
          myself  = {r = 0, g = 1, b = 0, a = 1 },
          other   = {r = 0, g = 1, b = 0, a = 0.7 },
        },
      },
      icons = {
        pvp = {
          show = true,
          pos = { a1 = "CENTER", a2 = "CENTER", x = -95, y = 42 }, --position in relation to self object
        },
        combat = {
          show = true,
          pos = { a1 = "CENTER", a2 = "CENTER", x = 0, y = 86 }, --position in relation to self object
        },
        resting = {
          show = true,
          pos = { a1 = "CENTER", a2 = "CENTER", x = -72, y = 60 }, --position in relation to self object
        },
      },
      castbar = {
        show = true,
		TextSize = 11,
        hideDefault = true, --if you hide the Roth_UI castbar, should the Blizzard castbar be shown?
        latency = true,
        texture = (mediapath.."statusbar3"),
        scale = 1/1, --divide 1 by current unit scale if you want to prevent scaling of the castbar based on unit scale
        color = {
          bar = { r = 0, g = 0.5, b = 1, a = 0.8, },
          bg = { r = 0.1, g = 0.1, b = 0.1, a = 0.7, },
        },
        pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 180.5 },
      },
      soulshards = { --class bar WARLOCK / AFFLICTION
        show = true,
        scale = 0.40,
        color = {r = 200/255, g = 0/255, b = 255/255, },
        pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 650 },
        combat          = { --fade the bar in/out in combat/out of combat
          enable          = false,
          fadeIn          = {time = 0.4, alpha = 1},
          fadeOut         = {time = 0.3, alpha = 0.2},
        },
      },
      holypower = { --class bar PALADIN
		show = true,
        scale = 0.40,
        color = {r = 200/255, g = 135/255, b = 190/255, },
        pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 650 },
        combat          = { --fade the bar in/out in combat/out of combat
          enable          = false,
          fadeIn          = {time = 0.4, alpha = 1},
          fadeOut         = {time = 0.3, alpha = 0.2},
        },
      },
      harmony = { --class bar MONK
        show = true,
        scale = 0.40,
        color = {r = 41/255, g = 209/255, b = 157/255, },
        pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 650 },
        combat          = { --fade the bar in/out in combat/out of combat
          enable          = false,
          fadeIn          = {time = 0.4, alpha = 1},
          fadeOut         = {time = 0.3, alpha = 0.2},
        },
      },
      runes = { --class bar DK
        show = true,
        scale = 0.40,
        pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 650 },
        combat          = { --fade the bar in/out in combat/out of combat
          enable          = false,
          fadeIn          = {time = 0.4, alpha = 1},
          fadeOut         = {time = 0.3, alpha = 0.2},
        },
      },
      combobar = {
        show = true,
        scale = 0.40,
        color = {r = 0.9, g = 0.59, b = 0, },
        pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 650 },
        combat          = { --fade the bar in/out in combat/out of combat
          enable          = false,
          fadeIn          = {time = 0.4, alpha = 1},
          fadeOut         = {time = 0.3, alpha = 0.2},
        },
      },
	  arcbar = {
        show = true,
        scale = 0.40,
        color = {r = 0.14, g = 0.56, b = .9, },
        pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 650 },
        combat          = { --fade the bar in/out in combat/out of combat
          enable          = false,
          fadeIn          = {time = 0.4, alpha = 1},
          fadeOut         = {time = 0.3, alpha = 0.2},
        },
      },
      altpower = {
        show = false,
        scale = 0.5,
        color = {r = 1, g = 0, b = 1, },
        texture = (mediapath.."statusbar"),
        pos = { a1 = "CENTER", a2 = "CENTER", af = "UIParent", x = 0, y = 0 },
      },
      expbar = { --experience
        show = true,
          width = 365,
          height = 8,
          pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 9 },
          texture = (mediapath.."statusbar2"),
          scale = 1,
          color = {r = 0.8, g = 0, b = 0.8, },
          rested = {
            color = {r = 1, g = 0.7, b = 0, },
          },
      },
      repbar = { --reputation
        show = true,
          width = 365,
          height = 8,
          pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 20 },
          texture = (mediapath.."statusbar2"),
          scale = 1,
      },
	  ArtifactPower = {
		show = true,
			pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 15 },
			texture = (mediapath.."statusbar2"),
			scale = 1,
	  },
      art = {
        actionbarbackground = {
          show = true,
          pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 0 },
          scale = 1,
		  combatfade = true,
        },
        angel = {
          show = true,
          pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 265, y = 0 },
          scale = 1,
        },
        demon = {
          show = true,
          pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = -270, y = 0 },
          scale = 1,
        },
        bottomline = {
          show = true,
          pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = -5 },
          scale = 1,
        },
      },
      portrait = {
        pos = { a1 = "CENTER", a2 = "CENTER", af = "UIParent", x = -100, y = 0 },
        size = 150,
        show = false,
        use3D = true,
      },
    },

    -- TARGET
    target = {
      show = true,
      scale = 1.5,
	  width = 300,
      height = 64,
      pos = { a1 = "TOP", a2 = "TOP", af = "UIParent", x = 0, y = -70 },
      health = {
	frequentUpdates = false,
        texture = (mediapath.."statusbar3"),
        tag = "[diablo:hpval]",
		fontSize = 7,
		point = "RIGHT",
		-- Target: percent is centered; numeric value is on the right side of the Health bar.
		x = -3,
		y = 0,
      },
	  healper = {
	frequentUpdates = false,
		tag = "[perphp]",
		fontSize = 10,
		point = "CENTER",
		x = 0,
		y = 0,
	  },
	  powper = {
	frequentUpdates = false,
		tag = "[perpp]%",
		fontSize = 7,
		point = "CENTER",
		x = 0,
		y = 0,
	  },
      power = {
	frequentUpdates = false,
        texture = (mediapath.."statusbar3"),
        tag = "[diablo:ppval]",
		fontSize = 7,
		-- Target: percent is centered; numeric value is on the right side of the Power bar.
		point = "RIGHT",
		x = -3,
		y = 0,
      },
	  misc = {
		classFontSize = 13,
		NameFontSize = 16,
	  },
      auras = {
        show = true,
        size = 15,
        onlyShowPlayerBuffs = false,
        showStealableBuffs = true,
        onlyShowPlayerDebuffs = true,
        showDebuffType = true,
        desaturateDebuffs = false,
        buffs = {
          pos = { a1 = "BOTTOMLEFT", a2 = "TOPRIGHT", x = 0, y = -15 },
          initialAnchor = "BOTTOMLEFT",
          growthx = "RIGHT",
          growthy = "UP",
        },
        debuffs = {
          pos = { a1 = "TOPLEFT", a2 = "BOTTOMRIGHT", x = 0, y = 15 },
          initialAnchor = "TOPLEFT",
          growthx = "RIGHT",
          growthy = "DOWN",
        },
      },
      castbar = {
        show = true,
		TextSize = 11,
        texture = (mediapath.."statusbar3"),
        scale = 1/1.9, --divide 1 by current unit scale if you want to prevent scaling of the castbar based on unit scale
        color = {
          bar = { r = 1.0, g = 0.7, b = 0.0, a = 1.0, },
          bg = { r = 0.1, g = 0.1, b = 0.1, a = 1, },
          shieldbar = { r = 0.9, g = 0.9, b = 0.9, a = 1, }, --the castbar color while target casting a shielded spell
          shieldbg = { r = 0.1, g = 0.1, b = 0.1, a = 0.7, },  --the castbar background color while target casting a shielded spell
          semantic = {
            interruptibleCast = { r = 1.0, g = 0.7, b = 0.0, a = 1.0, },
            interruptibleChannel = { r = 0.0, g = 1.0, b = 0.0, a = 1.0, },
            nonInterruptible = { r = 0.9, g = 0.9, b = 0.9, a = 1.0, },
            failedOrInterrupted = { r = 1.0, g = 0.15, b = 0.15, a = 1.0, },
          },
        },
        pos = { a1 = "TOP", a2 = "TOP", af = "UIParent", x = -10, y = -125 },
      },
      portrait = {
        pos = { a1 = "CENTER", a2 = "CENTER", af = "UIParent", x = 100, y = 0 },
        size = 150,
        show = false,
        use3D = true,
      },
      healprediction = {
        show = true,
        texture = (mediapath.."statusbar3"),
        color = {
          myself  = {r = 0, g = 1, b = 0, a = 1 },
          other   = {r = 0, g = 1, b = 0, a = 0.7 },
        },
        maxoverflow = 1.00,
      },
      totalabsorb = {
        show = true,
        texture = (mediapath.."absorb_statusbar_overlay"),
        color = {
          bar  = {r = 0.7, g = 1, b = 1, a = 0.9 },
        },
      },
    },

    --TARGETTARGET
    targettarget = {
      show = true,
	  width = 150,
      height = 64,
      scale = 1.3,
      pos = { a1 = "TOP", a2 = "TOP", af = "UIParent", x = -238, y = -80 },
      auras = {
        show = true,
        size = 22,
        onlyShowPlayerDebuffs = false,
        showDebuffType = true,
      },
      health = {
        texture = (mediapath.."statusbar3"),
        tag = "[diablo:misshp]",
      },
      power = {
        texture = (mediapath.."statusbar3"),
      },
	  castbar = {
		show = true,
		TextSize = 9,
		texture = (mediapath.."statusbar3"),
		-- Prevent castbar size inflation from the unitframe scale.
		scale = 1/1.3,
		-- Mini castbar for small targettarget frame.
		mini = true,
		width = 150,
		height = 10,
		color = {
		  bar = { r = 1, g = 0.7, b = 0, a = 1, },
		  bg  = { r = 0.1, g = 0.1, b = 0.1, a = 0.7, },
		},
		-- Default placement below the unitframe.
		pos = { a1 = "TOP", a2 = "BOTTOM", af = "Roth_UITargetTargetFrame", x = 0, y = -6 },
	  },
      healprediction = {
        show = true,
        texture = (mediapath.."statusbar3"),
        color = {
          myself  = {r = 0, g = 1, b = 0, a = 1 },
          other   = {r = 0, g = 1, b = 0, a = 0.7 },
        },
        maxoverflow = 1.00,
      },
    },

    --PET
    pet = {
      show = true,
      scale = 0.85,
	  width = 128,
      height = 64,
      pos = { a1 = "RIGHT", a2 = "RIGHT", af = "UIParent", x = -30, y = -140 },
      auras = {
        show = true,
        size = 22,
        onlyShowPlayerDebuffs = false,
        showDebuffType = false,
      },
      health = {
        texture = (mediapath.."statusbar3"),
        tag = "[diablo:misshp]",
      },
      power = {
        texture = (mediapath.."statusbar3"),
      },
      altpower = {
        show = false,
        scale = 0.5,
        color = {r = 1, g = 0, b = 1, },
        texture = (mediapath.."statusbar3"),
        pos = { a1 = "CENTER", a2 = "CENTER", af = "UIParent", x = 0, y = 0 },
      },
      portrait = {
        show = true,
        use3D = false,
      },
      castbar = {
        show = false,
        hideDefault = true, --if you hide the Roth_UI castbar, should the Blizzard castbar be shown?
        texture = "Interface\\AddOns\\Roth_UI\\media\\statusbar3",
        scale = 1/0.85, --divide 1 by current unit scale if you want to prevent scaling of the castbar based on unit scale
        color = {
          bar = { r = 1, g = 0.7, b = 0, a = 1, },
          bg = { r = 0.1, g = 0.1, b = 0.1, a = 0.7, },
        },
        pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 490 },
      },
      totalabsorb = {
        show = true,
        texture = (mediapath.."absorb_statusbar_overlay"),
        color = {
          bar  = {r = 0.7, g = 1, b = 1, a = 0.9 },
        },
      },
    },

    --FOCUS
    focus = {
      show = true,
	  width = 128,
      height = 64,	  
      scale = 0.85,
      pos = { a1 = "CENTER", a2 = "BOTTOM", af = "UIParent", x = 0, y = 350 },
      aurawatch = {
        show            = false,
        size            = 20,
      },
      auras = {
        show = true,
        size = 22,
        onlyShowPlayerDebuffs = false,
        showDebuffType = false,
        showBuffs = true,
        onlyShowPlayerBuffs = false,
        showBuffType = false,
      },
      health = {
        texture = (mediapath.."statusbar3"),
        tag = "[diablo:misshp]",
      },
      power = {
        texture = (mediapath.."statusbar3"),
      },
      portrait = {
        show = true,
        use3D = false,
      },
      castbar = {
		show = true,
		TextSize = 11,
        texture = (mediapath.."statusbar3"),
        scale = 1/1.9, --divide 1 by current unit scale if you want to prevent scaling of the castbar based on unit scale
        color = {
          bar = { r = 1, g = 0.7, b = 0, a = 1, },
          bg = { r = 0.1, g = 0.1, b = 0.1, a = 0.7, },
        },
        pos = { a1 = "TOP", a2 = "BOTTOM", af = "Roth_UIFocusFrame", x = 0, y = -10 },
      },
      healprediction = {
        show = true,
        texture = (mediapath.."statusbar128_3"),
        color = {
          myself  = {r = 0, g = 1, b = 0, a = 1 },
          other   = {r = 0, g = 1, b = 0, a = 0.7 },
        },
        maxoverflow = 1.00,
      },
      totalabsorb = {
        show = true,
        texture = (mediapath.."absorb_statusbar_overlay"),
        color = {
          bar  = {r = 0.7, g = 1, b = 1, a = 0.9 },
        },
      },
    },

    --PETTARGET
    pettarget = {
      show = false,
	  width = 128,
      height = 64,
      scale = 0.85,
      pos = { a1 = "LEFT", a2 = "LEFT", af = "UIParent", x = 140, y = -140 },
      auras = {
        show = true,
        size = 22,
        onlyShowPlayerDebuffs = false,
        showDebuffType = false,
      },
      health = {
        texture = (mediapath.."statusbar3"),
        tag = "[diablo:misshp]",
      },
      power = {
        texture = (mediapath.."statusbar3"),
      },
      portrait = {
        show = true,
        use3D = true,
      },
    },

    --FOCUSTARGET
    focustarget = {
      show = false,
	  width = 128,
      height = 64,
      scale = 0.85,
      pos = { a1 = "LEFT", a2 = "LEFT", af = "UIParent", x = 140, y = 40 },
      auras = {
        show = true,
        size = 22,
        onlyShowPlayerDebuffs = false,
        showDebuffType = false,
      },
      health = {
        texture = (mediapath.."statusbar128_3"),
        tag = "[diablo:misshp]",
      },
      power = {
        texture = (mediapath.."statusbar128_3"),
      },
      portrait = {
        show = true,
        use3D = true,
      },
    },

    --PARTY
    party = (ns.defaults and ns.defaults.units and ns.defaults.units.party) or {},

    --RAID
    raid = (ns.defaults and ns.defaults.units and ns.defaults.units.raid) or {},

    --BOSSFRAMES
    boss = {
      show = true,
      scale = 1,
	  width = 128,
      height = 64,
      pos = { a1 = "TOP", a2 = "BOTTOM", af = "Minimap", x = 0, y = -80 },
      health = {
        texture = (mediapath.."statusbar3"),
        tag = "[diablo:bosshp]%",
      },
      power = {
        texture = (mediapath.."statusbar3"),
        tag = "[diablo:bosspp]",
      },
      castbar = {
        show = true,
        TextSize = 9,
        texture = (mediapath.."statusbar3"),
        mini = true,
        width = 128,
        height = 10,
        color = {
          bar = { r = 1, g = 0.7, b = 0, a = 1, },
          bg  = { r = 0.1, g = 0.1, b = 0.1, a = 0.7, },
        },
        pos = { a1 = "TOP", a2 = "BOTTOM", af = "$parent", x = 0, y = -6 },
      },
    },

  }

  ----------------------------------------
  -- Action Bars
  ----------------------------------------
    cfg.bars = {
    --General Button Settings
	showMacroName = true,
	showCooldown = true,
	showHotkey = false,
	showStackCount = true,
	secureOwnerBars = false,
    --BAR 1
    bar1 = {
      enable          = true, --enable module
      uselayout2x6    = false,
      scale           = 1,
      padding         = 2, --frame padding
      buttons         = {
        size            = 26,
        margin          = 5,
      },
      pos             = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = -1, y = 16 },
      userplaced      = {
        enable          = true,
      },
      mouseover       = {
        enable          =          false,
        fadeIn          = {time = 0.4, alpha = 1},
        fadeOut         = {time = 0.3, alpha = 0},
      },
    },
    --OVERRIDE BAR (vehicle ui)
    overridebar = { --the new vehicle and override bar
      enable          = true, --enable module
      scale           = 1,
      padding         = 2, --frame padding
      buttons         = {
        size            = 57,
        margin          = 5,
      },
      pos             = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = -1, y = 16 },
      userplaced      = {
        enable          = true,
      },
      mouseover       = {
        enable          =          false,
        fadeIn          = {time = 0.4, alpha = 1},
        fadeOut         = {time = 0.3, alpha = 0},
      },
    },
    --BAR 2
    bar2 = {
      enable          = true, --enable module
      uselayout2x6    = false,
      scale           = 1,
      padding         = 2, --frame padding
      buttons         = {
        size            = 26,
        margin          = 5,
      },
      pos             = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = -1, y = 42 },
      userplaced      = {
        enable          = true,
      },
      mouseover       = {
        enable          =          false,
        fadeIn          = {time = 0.4, alpha = 1},
        fadeOut         = {time = 0.3, alpha = 0},
      },
    },
    --BAR 3
    bar3 = {
      enable          = true, --enable module
      scale           = 1,
      padding         = 2, --frame padding
      buttons         = {
        size            = 26,
        margin          = 5,
      },
      pos             = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = -1, y = 70 },
      userplaced      = {
        enable          = true,
      },
      mouseover       = {
        enable          =          false,
        fadeIn          = {time = 0.4, alpha = 1},
        fadeOut         = {time = 0.3, alpha = 0},
      },
    },
    --BAR 4
    bar4 = {
      enable          = true, --enable module
	  vert = false, --choosing this will make the bar stack vertically instead of horizontally
      combineBar4AndBar5  = true, --by choosing true both bar 4 and 5 will react to the same hover effect, thus true/false at the same time, settings for bar5 will be ignored
      scale           = 1.2,
      padding         = 10, --frame padding
      buttons         = {
        size            = 26,
        margin          = 5,
      },
      pos             = { a1 = "RIGHT", a2 = "RIGHT", af = "UIParent", x = -0, y = 0 },
      userplaced      = {
        enable          = true,
      },
      mouseover       = {
        enable          = true,
        fadeIn          = {time = 0.4, alpha = 1},
        fadeOut         = {time = 0.3, alpha = 0},
      },
    },
    --BAR 5
    bar5 = {
      enable          = true, --enable module
	  vert = true, --choosing this will make the bar stack vertically instead of horizontally
      scale           = 1.2,
      padding         = 10, --frame padding
      buttons         = {
        size            = 26,
        margin          = 5,
      },
      pos             = { a1 = "RIGHT", a2 = "RIGHT", af = "UIParent", x = -36, y = 0 },
      userplaced      = {
        enable          = true,
      },
      mouseover       = {
        enable          = true,
        fadeIn          = {time = 0.4, alpha = 1},
        fadeOut         = {time = 0.3, alpha = 1},
      },
    },
    bar6 = {
      enable          = true, --enable module
	    vert            = false, --choosing this will make the bar stack vertically instead of horizontally
      scale           = 1.2,
      padding         = 10, --frame padding
      buttons         = {
        size            = 26,
        margin          = 5,
      },
      pos             = { a1 = "RIGHT", a2 = "RIGHT", af = "UIParent", x = -36, y = 0 },
      userplaced      = {
        enable          = true,
      },
      mouseover       = {
        enable          = false,
        fadeIn          = {time = 0.4, alpha = 1},
        fadeOut         = {time = 0.3, alpha = 0},
      },
    },
    --PETBAR
    petbar = {
      enable          = true, --enable module
      show            = true, --true/false
      scale           = 1.2,
      padding         = 2, --frame padding
      buttons         = {
        size            = 26,
        margin          = 5,
      },
      pos             = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = -1, y = 180 },
      userplaced      = {
        enable          = true,
      },
      mouseover       = {
        enable          = true,
        fadeIn          = {time = 0.4, alpha = 1},
        fadeOut         = {time = 0.3, alpha = 0},
      },
    },
    --STANCE- + POSSESSBAR
    stancebar = {
      enable          = true, --enable module
      show            = true, --true/false
      scale           = 0.6,
      padding         = 2, --frame padding
      buttons         = {
        size            = 26,
        margin          = 5,
      },
	  pos             = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 97  },
	  userplaced      = {
		  enable          = true,
	  },
      mouseover       = {
        enable          = false,
        fadeIn          = {time = 0.4, alpha = 1},
        fadeOut         = {time = 0.3, alpha = 0},
      },
    },
    --EXTRABAR
    extrabar = {
      enable          = true, --enable module
      scale           = 0.82,
      padding         = 10, --frame padding
      buttons         = {
        size            = 36,
        margin          = 5,
      },
      pos             = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = -210, y = 220 },
      userplaced      = {
        enable          = true,
      },
      mouseover       = {
        enable          = false,
        fadeIn          = {time = 0.4, alpha = 1},
        fadeOut         = {time = 0.3, alpha = 0.2},
      },
    },
    --VEHICLE EXIT (no vehicleui)
    leave_vehicle = {
      enable          = true, --enable module
      scale           = 1.2,
      padding         = 10, --frame padding
      buttons         = {
        size            = 26,
        margin          = 5,
      },
      pos             = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 210, y = 135 },
      userplaced      = {
        enable          = true,
      },
      mouseover       = {
        enable          = false,
        fadeIn          = {time = 0.4, alpha = 1},
        fadeOut         = {time = 0.3, alpha = 0.2},
      },
    },
    --MICROMENU
    micromenu = {
      enable          = true, --enable module
      show            = true, --true/false
      scale           = 0.6,
      padding         = 0, --frame padding
      pos             = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = -180, y = 97 },
      userplaced      = {
        enable          = true,
      },
      mouseover       = {
        enable          = false,
        fadeIn          = {time = 0.4, alpha = 1},
        fadeOut         = {time = 0.3, alpha = 0},
      },
    },
    --BAGS
    bags = {
      enable          = true, --enable module
      show            = true, --true/false
      scale           = 0.6,
      padding         = 15, --frame padding
      pos             = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 180, y = 97 },
      userplaced      = {
        enable          = true,
      },
      mouseover       = {
        enable          = false,
        fadeIn          = {time = 0.4, alpha = 1},
        fadeOut         = {time = 0.3, alpha = 0},
      },
    },
  }

  ----------------------------------------
  -- frame movement
  ----------------------------------------

  --setting this to true will lock the frames in place, false unlocks them
  cfg.framesLocked = true

  ----------------------------------------
  -- player specific data
  ----------------------------------------
  -- Make a copy for Roth_UI and override colors on the copy only.
  local function Roth_CopyTable(src)
    local t = {}
    if type(src) == "table" then
      for k, v in pairs(src) do
        t[k] = v
      end
    end
    return t
  end
  cfg.powercolors = (CopyTable and CopyTable(PowerBarColor)) or Roth_CopyTable(PowerBarColor)
  cfg.powercolors["MANA"] = { r = 0, g = 0.4, b = 1 }
  -- Prepatch (oUF 13.0.0): oUF expects ColorMixin-like colors with :GetRGB().
  -- Only patch oUF's MANA color if it is missing or not compatible.
  if oUF and oUF.colors and oUF.colors.power then
    local mana = oUF.colors.power["MANA"]
    if not (type(mana) == "table" and mana.GetRGB) then
      if CreateColor then
        local c = CreateColor(0, 0.4, 1)
        c[1], c[2], c[3] = 0, 0.4, 1
        oUF.colors.power["MANA"] = c
      else
        oUF.colors.power["MANA"] = {0, 0.4, 1, r = 0, g = 0.4, b = 1, GetRGB = function() return 0, 0.4, 1 end}
      end
    end
  end
  --font
  -- Default UI font (unitframes, castbars, etc.)
  cfg.font = STANDARD_TEXT_FONT
  -- Default to applying the selected font across Blizzard FontObjects as well.
  cfg.applyGlobalFonts = true
  cfg.chat = {
    font = STANDARD_TEXT_FONT,
  }

  --backdrop
  cfg.backdrop = {
    bgFile = (mediapath.."Tooltip_Background"),
    edgeFile = (mediapath.."Tooltip_Border"),
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  }

  ---------------------------------------------
  -- SavedVariables overlay
  --
  -- Goal:
  --   * config.lua remains the DEFAULTS definition.
  --   * In-game Settings edit SavedVariables.
  --   * Runtime reads SavedVariables (with safe fallback to defaults).
  --
  -- Approach:
  --   1) Build defaults table (cfg) above.
  --   2) Seed missing keys into the canonical account settings store WITHOUT overwriting.
  --      Only serializable values are seeded (numbers/strings/booleans/tables).
  --   3) Build a runtime cfg by starting from defaults and applying SV overrides.
  --      This avoids persisting any runtime-only / non-serializable objects.
  ---------------------------------------------

    ---------------------------------------------
  -- SavedVariables: FULL CONFIG MODE (project requirement)
  --
  -- Policy:
  --   * config.lua defines DEFAULTS (schema + values).
  --   * On first run (or when upgrading from overrides-only mode) we copy the
  --     entire defaults table into the canonical account settings store.
  --   * All modules read settings from the canonical account settings store.
  --   * Session-only fields are kept in a thin runtime wrapper and are never
  --     persisted (playername/playerclass/playercolor/playerspec).
  ---------------------------------------------

  
  ---------------------------------------------
  -- SavedVariables: FULL CONFIG MODE (authoritative SV)
  --
  -- Policy (project requirement):
  --   * config.lua defines DEFAULTS (schema + values).
  --   * On first run (or when upgrading), we copy the ENTIRE defaults table into
  --     Roth_UI_DB.account.settings.
  --   * Runtime reads settings from Roth_UI_DB.account.settings (not from config.lua).
  --   * Runtime-only fields are kept in a separate runtime table and are never persisted.
  --
  -- Implementation:
  --   * cfg          = defaults (schema)
  --   * SV           = Roth_UI_DB.account.settings (full persisted config)
  --   * ns.cfg       = SV root (runtime view; persisted)
  --
  -- IMPORTANT:
  --   Do NOT write frames/textures/functions/etc into SV. Only store serializable
  --   primitives and plain tables. SV writes are only allowed via ns.SVSet().
  ---------------------------------------------

  -- Config persistence bootstrap
  --
  -- config.lua now owns only the defaults/schema table.
  -- The config persistence owner handles reconcile, schema patching,
  -- runtime-only proxy fields, and metadata for the canonical config store.
  local configOwner = assert(ns and ns.configPersistence, "Roth_UI: configPersistence owner is required by config.lua")
  local InitializeConfigDefaults = assert(configOwner.InitializeConfigDefaults, "Roth_UI: configPersistence.InitializeConfigDefaults is required by config.lua")

  InitializeConfigDefaults(cfg)
