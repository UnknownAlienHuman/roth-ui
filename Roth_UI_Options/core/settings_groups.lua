local addonName = ...
local ns = assert(_G.Roth_UI, "Roth_UI_Options: main Roth_UI namespace is required")

local ui = assert(ns and ns.SettingsUI, "Roth_UI: SettingsUI is required by settings_groups.lua")

local function ApplyGroupPolicy()
  if ns and ns.func and type(ns.func.ApplyGroupFramePolicy) == "function" then
    ns.func.ApplyGroupFramePolicy(ns.func)
  end
end

local function ApplyPartyLayout()
  if type(ns.ApplyPartyLayoutRuntime) == "function" then
    ui:RunOutOfCombat("settings_party_layout", ns.ApplyPartyLayoutRuntime)
  end
end

local function ApplyPartyStructure()
  if type(ns.RebuildPartyStructureRuntime) == "function" then
    ui:RunOutOfCombat("settings_party_structure", ns.RebuildPartyStructureRuntime)
  end
end

local function ApplyRaidLayout()
  if type(ns.ApplyRaidLayoutRuntime) == "function" then
    ui:RunOutOfCombat("settings_raid_layout", ns.ApplyRaidLayoutRuntime)
  end
end

local function ApplyRaidStructure()
  if type(ns.RebuildRaidStructureRuntime) == "function" then
    ui:RunOutOfCombat("settings_raid_structure", ns.RebuildRaidStructureRuntime)
  end
end

local function RefreshGroupRange()
  if type(ns.RefreshGroupRangeRuntime) == "function" then
    ui:RunOutOfCombat("settings_group_range_refresh", ns.RefreshGroupRangeRuntime)
  end
end

local function FormatScale(value)
  return string.format("%.2f", value)
end

local function FormatInteger(value)
  return tostring(math.floor((tonumber(value) or 0) + 0.5))
end

local function FormatAlpha(value)
  return string.format("%.2f", tonumber(value) or 0)
end

ui:RegisterBuilder("groups", function()
  ui:AddCheckbox({
    category = "party",
    variable = "ROTH_UI_PARTY_PROVIDER",
    label = "Use Roth Party Frames",
    tooltip = "Toggles Roth party headers against Blizzard party frames through the compatibility policy layer.",
    path = { "units", "party", "show" },
    defaultValue = ui:GetConfigDefault({ "units", "party", "show" }, true),
    reloadRequired = false,
    apply = ApplyGroupPolicy,
  })

  ui:AddSlider({
    category = "party",
    variable = "ROTH_UI_PARTY_SCALE",
    label = "Party Scale",
    tooltip = "Applies the current party header scale out of combat.",
    path = { "units", "party", "scale" },
    defaultValue = ui:GetConfigDefault({ "units", "party", "scale" }, 1),
    minValue = 0.5,
    maxValue = 2.0,
    step = 0.01,
    reloadRequired = false,
    apply = ApplyPartyLayout,
    labelFormatter = FormatScale,
  })

  ui:AddSlider({
    category = "party",
    variable = "ROTH_UI_PARTY_POS_X",
    label = "Party X",
    tooltip = "Moves the party anchor out of combat.",
    path = { "units", "party", "pos", "x" },
    defaultValue = ui:GetConfigDefault({ "units", "party", "pos", "x" }, 0),
    minValue = -1000,
    maxValue = 1000,
    step = 1,
    reloadRequired = false,
    apply = ApplyPartyLayout,
    labelFormatter = FormatInteger,
  })

  ui:AddSlider({
    category = "party",
    variable = "ROTH_UI_PARTY_POS_Y",
    label = "Party Y",
    tooltip = "Moves the party anchor out of combat.",
    path = { "units", "party", "pos", "y" },
    defaultValue = ui:GetConfigDefault({ "units", "party", "pos", "y" }, 0),
    minValue = -1000,
    maxValue = 1000,
    step = 1,
    reloadRequired = false,
    apply = ApplyPartyLayout,
    labelFormatter = FormatInteger,
  })

  ui:AddCheckbox({
    category = "party",
    variable = "ROTH_UI_PARTY_PORTRAIT_3D",
    label = "Party Portraits Use 3D",
    tooltip = "Changes the portrait region type for party frames and rebuilds the party header out of combat.",
    path = { "units", "party", "portrait", "use3D" },
    defaultValue = ui:GetConfigDefault({ "units", "party", "portrait", "use3D" }, true),
    reloadRequired = false,
    apply = ApplyPartyStructure,
  })

  ui:AddCheckbox({
    category = "party",
    variable = "ROTH_UI_PARTY_VERTICAL",
    label = "Vertical Party Frames",
    tooltip = "Restores the vertical party layout and rebuilds the party header out of combat.",
    path = { "units", "party", "vertical" },
    defaultValue = ui:GetConfigDefault({ "units", "party", "vertical" }, true),
    reloadRequired = false,
    apply = ApplyPartyStructure,
  })


  ui:AddSlider({
    category = "party",
    variable = "ROTH_UI_PARTY_RANGE_ALPHA",
    label = "Party Out-of-Range Alpha",
    tooltip = "Controls the faded alpha used by the upstream oUF Range element.",
    path = { "units", "party", "alpha", "notinrange" },
    defaultValue = ui:GetConfigDefault({ "units", "party", "alpha", "notinrange" }, 0.5),
    minValue = 0.1,
    maxValue = 1.0,
    step = 0.05,
    reloadRequired = false,
    apply = RefreshGroupRange,
    labelFormatter = FormatAlpha,
  })

  ui:AddCheckbox({
    category = "party",
    variable = "ROTH_UI_PARTY_HEAL_PREDICTION",
    label = "Party Heal Prediction",
    tooltip = "Lets oUF Health handle incoming-heal prediction for party frames. Reload is required because the prediction bars are created when the party style is spawned.",
    path = { "units", "party", "healprediction", "show" },
    defaultValue = ui:GetConfigDefault({ "units", "party", "healprediction", "show" }, true),
    reloadRequired = true,
  })

  ui:AddCheckbox({
    category = "party",
    variable = "ROTH_UI_PARTY_AURAWATCH",
    label = "Party Aura Watch",
    tooltip = "Creates or removes the party aura watch indicators out of combat.",
    path = { "units", "party", "aurawatch", "show" },
    defaultValue = ui:GetConfigDefault({ "units", "party", "aurawatch", "show" }, true),
    reloadRequired = false,
    apply = ApplyPartyStructure,
  })

  ui:AddCheckbox({
    category = "raid",
    variable = "ROTH_UI_RAID_PROVIDER",
    label = "Use Roth Raid Frames",
    tooltip = "Toggles Roth raid headers against Blizzard raid frames through the compatibility policy layer.",
    path = { "units", "raid", "show" },
    defaultValue = ui:GetConfigDefault({ "units", "raid", "show" }, true),
    reloadRequired = false,
    apply = ApplyGroupPolicy,
  })

  ui:AddSlider({
    category = "raid",
    variable = "ROTH_UI_RAID_SCALE",
    label = "Raid Scale",
    tooltip = "Applies the current raid header scale out of combat.",
    path = { "units", "raid", "scale" },
    defaultValue = ui:GetConfigDefault({ "units", "raid", "scale" }, 1),
    minValue = 0.5,
    maxValue = 2.0,
    step = 0.01,
    reloadRequired = false,
    apply = ApplyRaidLayout,
    labelFormatter = FormatScale,
  })


  ui:AddSlider({
    category = "raid",
    variable = "ROTH_UI_RAID_RANGE_ALPHA",
    label = "Raid Out-of-Range Alpha",
    tooltip = "Controls the faded alpha used by the upstream oUF Range element.",
    path = { "units", "raid", "alpha", "notinrange" },
    defaultValue = ui:GetConfigDefault({ "units", "raid", "alpha", "notinrange" }, 0.4),
    minValue = 0.1,
    maxValue = 1.0,
    step = 0.05,
    reloadRequired = false,
    apply = RefreshGroupRange,
    labelFormatter = FormatAlpha,
  })

  ui:AddCheckbox({
    category = "raid",
    variable = "ROTH_UI_RAID_HEAL_PREDICTION",
    label = "Raid Heal Prediction",
    tooltip = "Lets oUF Health handle incoming-heal prediction for raid frames. Reload is required because the prediction bars are created when the raid style is spawned.",
    path = { "units", "raid", "healprediction", "show" },
    defaultValue = ui:GetConfigDefault({ "units", "raid", "healprediction", "show" }, false),
    reloadRequired = true,
  })

  ui:AddCheckbox({
    category = "raid",
    variable = "ROTH_UI_RAID_AURAS_ENABLED",
    label = "Raid Aura Icons",
    tooltip = "Creates or removes native raid aura icon frames out of combat.",
    path = { "units", "raid", "auras", "show" },
    defaultValue = ui:GetConfigDefault({ "units", "raid", "auras", "show" }, false),
    reloadRequired = false,
    apply = ApplyRaidStructure,
  })

  ui:AddCheckbox({
    category = "raid",
    variable = "ROTH_UI_RAID_AURA_BUFFS",
    label = "Raid Buff Icons",
    tooltip = "Adds the raid buff row out of combat when raid aura icons are enabled.",
    path = { "units", "raid", "auras", "showBuffs" },
    defaultValue = ui:GetConfigDefault({ "units", "raid", "auras", "showBuffs" }, false),
    reloadRequired = false,
    apply = ApplyRaidStructure,
  })

  ui:AddCheckbox({
    category = "raid",
    variable = "ROTH_UI_RAID_AURAWATCH",
    label = "Raid Aura Watch",
    tooltip = "Creates or removes the raid aura watch indicators out of combat.",
    path = { "units", "raid", "aurawatch", "show" },
    defaultValue = ui:GetConfigDefault({ "units", "raid", "aurawatch", "show" }, true),
    reloadRequired = false,
    apply = ApplyRaidStructure,
  })

  ui:AddSlider({
    category = "raid",
    variable = "ROTH_UI_RAID_POS_X",
    label = "Raid X",
    tooltip = "Moves the raid anchor out of combat.",
    path = { "units", "raid", "pos", "x" },
    defaultValue = ui:GetConfigDefault({ "units", "raid", "pos", "x" }, 0),
    minValue = -1000,
    maxValue = 1000,
    step = 1,
    reloadRequired = false,
    apply = ApplyRaidLayout,
    labelFormatter = FormatInteger,
  })

  ui:AddSlider({
    category = "raid",
    variable = "ROTH_UI_RAID_POS_Y",
    label = "Raid Y",
    tooltip = "Moves the raid anchor out of combat.",
    path = { "units", "raid", "pos", "y" },
    defaultValue = ui:GetConfigDefault({ "units", "raid", "pos", "y" }, 0),
    minValue = -1000,
    maxValue = 1000,
    step = 1,
    reloadRequired = false,
    apply = ApplyRaidLayout,
    labelFormatter = FormatInteger,
  })
end)
