
-- rButtonTemplate_Default: theme
-- zork, 2016

-- Default Button Theme for rButtonTemplate

-----------------------------
-- Variables
-----------------------------

local A, L = ...
local addon, ns = ...
local root = _G.Roth_UI or ns
local cfg = ns.cfg
local mediapath = ns.mediapath or "Interface\\AddOns\\Roth_UI\\media\\"
if not cfg.embeds.rButtonTemplate then return end
if not _G.rButtonTemplate then return end
local barsCfg = cfg.bars or {}
local showMacroName = barsCfg.showMacroName
if showMacroName == nil then
  showMacroName = barsCfg.showName
end
-----------------------------
-- actionButtonConfig
-----------------------------

local actionButtonConfig = {}

--backdrop
actionButtonConfig.backdrop = {
  bgFile = mediapath.."backdrop",
  edgeFile = mediapath.."backdropBorder",
  tile = false,
  tileSize = 32,
  edgeSize = 5,
  insets = {
    left = 5,
    right = 5,
    top = 5,
    bottom = 5,
  },
  backgroundColor = {0.1,0.1,0.1,0.8},
  borderColor = {0,0,0,1},
  points = {
    {"TOPLEFT", -3, 3 },
    {"BOTTOMRIGHT", 3, -3 },
  },
}

--icon
actionButtonConfig.icon = {
  texCoord = {0.1,0.9,0.1,0.9},
  points = {
    {"TOPLEFT", 1, -1 },
    {"BOTTOMRIGHT", -1, 1 },
  },
}

--flyoutBorder
actionButtonConfig.flyoutBorder = {
  file = ""
}

--flyoutBorderShadow
actionButtonConfig.flyoutBorderShadow = {
  file = ""
}

--border
actionButtonConfig.border = {
  file = mediapath.."icon_border",
  points = {
    {"TOPLEFT", -2, 2 },
    {"BOTTOMRIGHT", 2, -2 },
  },
}

actionButtonConfig.checkedTexture = {
	file = mediapath.."gloss2",
	points = {
		{"TOPLEFT", -2, 2 },
		{ "BOTTOMRIGHT", 2, -2 },
	},
}

--normalTexture
actionButtonConfig.normalTexture = {
  file = mediapath.."icon_border",
  color = {0.5,0.5,0.5,0.6},
  points = {
    {"TOPLEFT", 0, 0 },
    {"BOTTOMRIGHT", 0, 0 },
  },
}

actionButtonConfig.pushedTexture = {
	file = mediapath.."pushed",
	points = {
		{ "TOPLEFT", -2, 2 },
		{ "BOTTOMRIGHT", 2, -2 },
	},
}

actionButtonConfig.highlightTexture = {
	file = mediapath.."icon_border",
	points = {
		{ "TOPLEFT", -2, 2 },
		{ "BOTTOMRIGHT", 2, -2 },
	},
}

--cooldown
if barsCfg.showCooldown then
	actionButtonConfig.cooldown = {
		font = { STANDARD_TEXT_FONT, 15, "OUTLINE"},
		points = {
			{"TOPLEFT", 0, 0 },
			{"BOTTOMRIGHT", 0, 0 },
		},
		alpha = 1,
	}
else
	actionButtonConfig.cooldown = {
		alpha = 0,
	}
end

--name (macro name fontstring)
if showMacroName then
	actionButtonConfig.name = {
		font = { STANDARD_TEXT_FONT, 10, "OUTLINE"},
		points = {
			{"BOTTOMLEFT", 0, 0 },
			{"BOTTOMRIGHT", 0, 0 },
		},
		alpha = 1,
	}
else
	actionButtonConfig.name = {
		alpha = 0,
	}
end

--hotkey
if barsCfg.showHotkey then
	actionButtonConfig.hotkey = {
		font = { STANDARD_TEXT_FONT, 11, "OUTLINE"},
		points = {
			{"TOPRIGHT", 0, 0 },
			{"TOPLEFT", 0, 0 },
		},
		alpha = 1,
	}
else
	actionButtonConfig.hotkey = {
		alpha = 0,
	}
end

--count
if barsCfg.showStackCount then
	actionButtonConfig.count = {
		font = { STANDARD_TEXT_FONT, 11, "OUTLINE"},
		points = {
			{"BOTTOMRIGHT", 0, 0 },
		},
		alpha = 1,
	}
else
	actionButtonConfig.count = {
		alpha = 0,
	}
end

--rButtonTemplate:StyleAllActionButtons
rButtonTemplate:StyleAllActionButtons(actionButtonConfig)
if type(root) == "table" then
  root.actionButtonSkinConfig = actionButtonConfig
  if root.secureActionBarRuntime and type(root.secureActionBarRuntime.RestyleAll) == "function" then
    root.secureActionBarRuntime.RestyleAll()
  end
end


-----------------------------
-- itemButtonConfig
-----------------------------

local itemButtonConfig = {}

itemButtonConfig.backdrop = actionButtonConfig.backdrop
itemButtonConfig.icon = actionButtonConfig.icon
itemButtonConfig.count = actionButtonConfig.count
itemButtonConfig.stock = actionButtonConfig.name
itemButtonConfig.border = actionButtonConfig.border
itemButtonConfig.highlightTexture = actionButtonConfig.highlightTexture
itemButtonConfig.normalTexture = actionButtonConfig.normalTexture
if type(root) == "table" then
  root.itemButtonSkinConfig = itemButtonConfig
end

--rButtonTemplate:StyleItemButton
local itemButtons = {
  CharacterBag0Slot,
  CharacterBag1Slot,
  CharacterBag2Slot,
  CharacterBag3Slot,
  CharacterReagentBag0Slot,
}
for i, button in ipairs(itemButtons) do
  rButtonTemplate:StyleItemButton(button, itemButtonConfig)
end

local function StyleContainerFrameItems(frame)
  if not (frame and frame.EnumerateItems) then
    return
  end
  for _, button in frame:EnumerateItems() do
    rButtonTemplate:StyleItemButton(button, itemButtonConfig)
  end
end

-- WoW 12.x:
-- Container item buttons are pooled and (re)generated in ContainerFrame_GenerateFrame.
-- Style lazily on frame generation instead of scanning all bag slots on login.
if _G.ContainerFrameUtil_EnumerateContainerFrames then
  for _, frame in _G.ContainerFrameUtil_EnumerateContainerFrames() do
    StyleContainerFrameItems(frame)
  end
end
hooksecurefunc("ContainerFrame_GenerateFrame", function(frame)
  StyleContainerFrameItems(frame)
end)

-----------------------------
-- extraButtonConfig
-----------------------------

local extraButtonConfig = actionButtonConfig
extraButtonConfig.buttonstyle = { file = "" }
if type(root) == "table" then
  root.extraActionButtonSkinConfig = extraButtonConfig
end

--rButtonTemplate:StyleExtraActionButton
rButtonTemplate:StyleExtraActionButton(extraButtonConfig)

-----------------------------
-- auraButtonConfig
-----------------------------

local auraButtonConfig = {}

auraButtonConfig.backdrop = actionButtonConfig.backdrop
auraButtonConfig.icon = actionButtonConfig.icon
auraButtonConfig.border = actionButtonConfig.border
auraButtonConfig.border.texCoord = {0,1,0,1} --fix the settexcoord on debuff borders
auraButtonConfig.normalTexture = actionButtonConfig.normalTexture
auraButtonConfig.count = actionButtonConfig.count
auraButtonConfig.duration = actionButtonConfig.cooldown
auraButtonConfig.duration.points = {
                                     {"TOPRIGHT", 0, -3 },
                                     {"TOPLEFT", 0, -3 },
                                   }
auraButtonConfig.symbol = actionButtonConfig.name
if type(root) == "table" then
  root.auraButtonSkinConfig = auraButtonConfig
end

--fix blizzard time abbrev
-- WoW 12.x: avoid overriding global duration formats.
-- Blizzard's aura/buff systems may pass Secret Values, and these globals are used widely.
-- Keep defaults to reduce the chance of hitting protected branches.

--rButtonTemplate:StyleAllAuraButtons
--rButtonTemplate:StyleAllAuraButtons(auraButtonConfig)
