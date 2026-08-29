local addonName = ...
local ns = assert(_G.Roth_UI, "Roth_UI_Options: main Roth_UI namespace is required")

local ui = assert(ns and ns.SettingsUI, "Roth_UI: SettingsUI is required by settings_orbs.lua")
local orbText = assert(ns and ns.OrbTextController, "Roth_UI: ns.OrbTextController is required by settings_orbs.lua")
local storeApi = assert(ns and ns.store, "Roth_UI: store service is required by settings_orbs.lua")
local type = type
local tonumber = tonumber
local tostring = tostring
local format = string.format
local math_deg = math.deg
local math_floor = math.floor
local TWO_PI = math.pi * 2
local CONFIRM_DELETE = _G.DELETE or "Delete"
local CONFIRM_RESET = _G.RESET or "Reset"
local CONFIRM_SAVE = _G.SAVE or "Save"

local GetOrbGlobalValue = assert(storeApi.GetOrbGlobalValue, "Roth_UI: store.GetOrbGlobalValue is required by settings_orbs.lua")
local SetOrbGlobalValue = assert(storeApi.SetOrbGlobalValue, "Roth_UI: store.SetOrbGlobalValue is required by settings_orbs.lua")
local GetOrbConfigValue = assert(storeApi.GetOrbConfigValue, "Roth_UI: store.GetOrbConfigValue is required by settings_orbs.lua")
local SetOrbConfigValue = assert(storeApi.SetOrbConfigValue, "Roth_UI: store.SetOrbConfigValue is required by settings_orbs.lua")

local function NormalizeTemplateSelection(value)
  if type(value) ~= "string" then
    return ""
  end
  return value
end

local function GetStoredTemplateSelection(orbType)
  return NormalizeTemplateSelection(GetOrbGlobalValue({ "__selection", orbType }, ""))
end

local function SetStoredTemplateSelection(orbType, value)
  return SetOrbGlobalValue({ "__selection", orbType }, NormalizeTemplateSelection(value))
end

local function GetOrbDb()
  local db = ns and ns.db
  if type(db) ~= "table" then
    return nil
  end

  return db
end

local function GetOrbPersistence()
  local orbPersistence = ns and ns.orbPersistence
  if type(orbPersistence) ~= "table" then
    return nil
  end

  return orbPersistence
end

local function GetOrbValue(orbType, path, fallback)
  return GetOrbConfigValue(orbType, path, fallback)
end

local function SetOrbValue(orbType, path, value)
  return SetOrbConfigValue(orbType, path, value)
end

local function ApplyOrbSetting(orbType, mode)
  if mode == "visual" or mode == "both" then
    if ns and type(ns.RefreshOrbsVisual) == "function" then
      ns.RefreshOrbsVisual(orbType)
    end
  end
  if mode == "value" or mode == "both" then
    if ns and type(ns.ForceOrbValueRefresh) == "function" then
      ns.ForceOrbValueRefresh(orbType)
    end
  end
end

local function BuildModelOptions(db)
  local options = {}
  local list = db and db.getListModel and db.getListModel() or {}
  for i = 1, #list do
    local group = list[i]
    if type(group) == "table" and type(group.menuList) == "table" then
      local groupLabel = group.key or group.label or tostring(group.value)
      for j = 1, #group.menuList do
        local item = group.menuList[j]
        if type(item) == "table" and item.value ~= nil then
          options[#options + 1] = {
            label = format("%s: %s", groupLabel, item.key or tostring(item.value)),
            value = item.value,
          }
        end
      end
    elseif type(group) == "table" and group.value ~= nil then
      options[#options + 1] = {
        label = group.key or group.label or tostring(group.value),
        value = group.value,
      }
    end
  end
  return options
end

local function BuildTemplateOptions()
  local options = {}
  local orbPersistence = GetOrbPersistence()
  local list = type(orbPersistence) == "table" and type(orbPersistence.GetTemplateList) == "function"
    and orbPersistence.GetTemplateList()
    or nil
  if type(list) ~= "table" then
    list = {}
  end
  for i = 1, #list do
    local item = list[i]
    if type(item) == "table" and item.value ~= nil then
      options[#options + 1] = {
        label = item.label or item.key or tostring(item.value),
        value = item.value,
      }
    end
  end
  return options
end

local function HasTemplate(options, value)
  if type(value) ~= "string" or value == "" then
    return false
  end
  for i = 1, #options do
    if options[i].value == value then
      return true
    end
  end
  return false
end

local function GetSelectedTemplate(orbType)
  local options = BuildTemplateOptions()
  local current = GetStoredTemplateSelection(orbType)
  if HasTemplate(options, current) then
    return current
  end
  current = (#options > 0 and options[1].value) or ""
  SetStoredTemplateSelection(orbType, current)
  return current
end

local function SetSelectedTemplate(orbType, value)
  SetStoredTemplateSelection(orbType, value)
end

local function NormalizeTemplateName(name)
  if type(name) ~= "string" then
    return nil
  end
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then
    return nil
  end
  if name == "TEMPLATE_LIST" then
    return nil
  end
  return name
end

local function ShowConfirmation(text, acceptText, callback)
  if type(StaticPopup_Show) ~= "function" then
    if type(callback) == "function" then
      callback()
    end
    return
  end

  StaticPopup_Show("GENERIC_CONFIRMATION", nil, nil, {
    text = text,
    acceptText = acceptText or YES,
    cancelText = CANCEL,
    callback = callback,
  })
end

local function SaveTemplateAs(orbType, name)
  name = NormalizeTemplateName(name)
  if not name then
    print("Roth_UI: template name is required.")
    return
  end

  local orbPersistence = GetOrbPersistence()
  if not (orbPersistence and type(orbPersistence.SaveTemplate) == "function") then
    print("Roth_UI: template save is not available.")
    return
  end

  orbPersistence.SaveTemplate(name, orbType)
  SetSelectedTemplate(orbType, name)
end

local function OpenTemplateSaveDialog(orbType)
  if type(StaticPopup_Show) ~= "function" then
    print("Roth_UI: template save prompt is not available in this client build.")
    return
  end

  local current = GetSelectedTemplate(orbType)
  local dialog = StaticPopup_Show("GENERIC_INPUT_BOX", nil, nil, {
    text = orbType == "HEALTH" and "Save health orb template as:" or "Save power orb template as:",
    acceptText = CONFIRM_SAVE,
    cancelText = CANCEL,
    maxLetters = 24,
    callback = function(name)
      SaveTemplateAs(orbType, name)
    end,
  })

  if dialog and dialog.GetEditBox then
    local editBox = dialog:GetEditBox()
    if editBox and editBox.SetText then
      editBox:SetText(current ~= "" and current or "")
      if editBox.HighlightText then
        editBox:HighlightText()
      end
    end
  end
end

local function LoadSelectedTemplate(orbType)
  local name = GetSelectedTemplate(orbType)
  if name == "" then
    print("Roth_UI: no orb template is selected.")
    return
  end

  local orbPersistence = GetOrbPersistence()
  if not (orbPersistence and type(orbPersistence.LoadTemplate) == "function") then
    print("Roth_UI: template load is not available.")
    return
  end

  orbPersistence.LoadTemplate(name, orbType)
end

local function DeleteSelectedTemplate(orbType)
  local name = GetSelectedTemplate(orbType)
  if name == "" then
    print("Roth_UI: no orb template is selected.")
    return
  end

  local orbPersistence = GetOrbPersistence()
  if not (orbPersistence and type(orbPersistence.DeleteTemplate) == "function") then
    print("Roth_UI: template delete is not available.")
    return
  end

  ShowConfirmation(
    format("Delete orb template '%s'?", name),
    CONFIRM_DELETE,
    function()
      orbPersistence.DeleteTemplate(name)
      SetSelectedTemplate(orbType, "")
    end
  )
end

local function ResetTemplateLibrary()
  local actions = ns and ns.settingsActions
  if not (type(actions) == "table" and type(actions.ResetTemplateLibrary) == "function") then
    print("Roth_UI: template reset is not available.")
    return
  end

  ShowConfirmation(
    "Reset the shared orb template library and reload the UI?",
    CONFIRM_RESET,
    function()
      actions.ResetTemplateLibrary()
    end
  )
end

local function ResetOrbDefaults(orbType)
  local orbPersistence = GetOrbPersistence()
  if not (orbPersistence and type(orbPersistence.ResetOrbToDefaults) == "function") then
    print("Roth_UI: orb reset is not available.")
    return
  end

  ShowConfirmation(
    orbType == "HEALTH" and "Reset the health orb to addon defaults?" or "Reset the power orb to addon defaults?",
    CONFIRM_RESET,
    function()
      orbPersistence.ResetOrbToDefaults(orbType)
    end
  )
end

local function RegisterOrbPage(categoryKey, orbType, prefix)
  local function AddCheckbox(variable, label, tooltip, path, applyMode, defaultValue)
    ui:AddCheckbox({
      category = categoryKey,
      variable = variable,
      label = label,
      tooltip = tooltip,
      path = path,
      defaultValue = GetOrbValue(orbType, path, defaultValue),
      get = function()
        return GetOrbValue(orbType, path, defaultValue)
      end,
      set = function(nextValue)
        if SetOrbValue(orbType, path, nextValue) then
          ApplyOrbSetting(orbType, applyMode)
        end
      end,
    })
  end

  local function AddSlider(variable, label, tooltip, path, minValue, maxValue, step, applyMode, labelFormatter)
    ui:AddSlider({
      category = categoryKey,
      variable = variable,
      label = label,
      tooltip = tooltip,
      path = path,
      minValue = minValue,
      maxValue = maxValue,
      step = step,
      labelFormatter = labelFormatter,
      defaultValue = tonumber(GetOrbValue(orbType, path, minValue)) or minValue,
      get = function()
        return tonumber(GetOrbValue(orbType, path, minValue)) or minValue
      end,
      set = function(nextValue)
        if SetOrbValue(orbType, path, nextValue) then
          ApplyOrbSetting(orbType, applyMode)
        end
      end,
    })
  end

  local function AddDropdown(variable, label, tooltip, path, optionsProvider, applyMode, defaultValue)
    ui:AddDropdown({
      category = categoryKey,
      variable = variable,
      label = label,
      tooltip = tooltip,
      path = path,
      defaultValue = GetOrbValue(orbType, path, defaultValue),
      options = function()
        local db = GetOrbDb()
        return type(optionsProvider) == "function" and optionsProvider(db) or {}
      end,
      get = function()
        return GetOrbValue(orbType, path, defaultValue)
      end,
      set = function(nextValue)
        if SetOrbValue(orbType, path, nextValue) then
          ApplyOrbSetting(orbType, applyMode)
        end
      end,
    })
  end

  local function AddColor(variable, label, tooltip, path, applyMode)
    ui:AddColorSwatch({
      category = categoryKey,
      variable = variable,
      label = label,
      tooltip = tooltip,
      path = path,
      varType = Settings.VarType.String,
      defaultValue = ui:ColorToHex(GetOrbValue(orbType, path)),
      get = function()
        return ui:ColorToHex(GetOrbValue(orbType, path))
      end,
      set = function(hexColor)
        local current = GetOrbValue(orbType, path)
        if SetOrbValue(orbType, path, ui:HexToColor(hexColor, current)) then
          ApplyOrbSetting(orbType, applyMode)
        end
      end,
    })
  end

  local function AddActionButton(variable, label, buttonText, tooltip, onClick)
    ui:AddButton({
      category = categoryKey,
      label = label,
      buttonText = buttonText,
      tooltip = tooltip,
      onClick = onClick,
    })
  end

  AddDropdown(
    prefix .. "_FILL_TEXTURE",
    "Fill Texture",
    "Updates the orb fill texture immediately on the live orb.",
    { "filling", "texture" },
    function(db) return db and db.getListFillingTexture and db.getListFillingTexture() or {} end,
    "visual",
    "Interface\\AddOns\\Roth_UI\\media\\orb_filling16"
  )

  AddCheckbox(
    prefix .. "_FILL_COLOR_AUTO",
    "Auto Fill Color",
    "Uses class or power coloring instead of the saved manual color.",
    { "filling", "colorAuto" },
    "both",
    false
  )

  AddColor(
    prefix .. "_FILL_COLOR",
    "Fill Color",
    "Applies a manual fill color when auto coloring is disabled.",
    { "filling", "color" },
    "visual"
  )

  AddCheckbox(
    prefix .. "_MODEL_ENABLE",
    "Model Enabled",
    "Shows or hides the embedded orb model immediately without requiring a respawn.",
    { "model", "enable" },
    "visual",
    true
  )

  AddDropdown(
    prefix .. "_MODEL_DISPLAY",
    "Model Style",
    "Changes the orb model displayInfo and refreshes the model immediately.",
    { "model", "displayInfo" },
    BuildModelOptions,
    "visual",
    tonumber(GetOrbValue(orbType, { "model", "displayInfo" }, 32368)) or 32368
  )

  AddSlider(
    prefix .. "_MODEL_ALPHA",
    "Model Alpha",
    "Adjusts the live alpha of the embedded orb model.",
    { "model", "alpha" },
    0,
    1,
    0.01,
    "visual",
    function(value) return format("%.2f", value) end
  )

  AddSlider(
    prefix .. "_MODEL_DISTANCE",
    "Model Distance",
    "Adjusts the model camera distance scale immediately.",
    { "model", "camDistanceScale" },
    0.1,
    3,
    0.01,
    "visual",
    function(value) return format("%.2f", value) end
  )

  AddSlider(
    prefix .. "_MODEL_OFFSET_X",
    "Model Offset X",
    "Moves the model horizontally inside the orb.",
    { "model", "pos_x" },
    -1.5,
    1.5,
    0.01,
    "visual",
    function(value) return format("%.2f", value) end
  )

  AddSlider(
    prefix .. "_MODEL_OFFSET_Y",
    "Model Offset Y",
    "Moves the model vertically inside the orb.",
    { "model", "pos_y" },
    -1.5,
    1.5,
    0.01,
    "visual",
    function(value) return format("%.2f", value) end
  )

  AddSlider(
    prefix .. "_MODEL_ROTATION",
    "Model Rotation",
    "Rotates the model in radians; the live preview uses a degree label for readability.",
    { "model", "rotation" },
    0,
    TWO_PI,
    0.01,
    "visual",
    function(value) return format("%d°", math_floor(math_deg(value) + 0.5)) end
  )

  AddSlider(
    prefix .. "_MODEL_ZOOM",
    "Model Zoom",
    "Adjusts portrait zoom for the model immediately.",
    { "model", "portraitZoom" },
    0,
    1.5,
    0.01,
    "visual",
    function(value) return format("%.2f", value) end
  )

  AddSlider(
    prefix .. "_GALAXIES_ALPHA",
    "Galaxies Alpha",
    "Updates the decorative galaxy overlay alpha for existing regions.",
    { "galaxies", "alpha" },
    0,
    1,
    0.01,
    "visual",
    function(value) return format("%.2f", value) end
  )

  AddSlider(
    prefix .. "_BUBBLES_ALPHA",
    "Bubbles Alpha",
    "Updates the decorative bubble overlay alpha for existing regions.",
    { "bubbles", "alpha" },
    0,
    1,
    0.01,
    "visual",
    function(value) return format("%.2f", value) end
  )

  AddSlider(
    prefix .. "_SPARK_ALPHA",
    "Spark Alpha",
    "Updates the live orb spark alpha.",
    { "spark", "alpha" },
    0,
    1,
    0.01,
    "visual",
    function(value) return format("%.2f", value) end
  )

  AddSlider(
    prefix .. "_HIGHLIGHT_ALPHA",
    "Highlight Alpha",
    "Updates the live orb gloss alpha.",
    { "highlight", "alpha" },
    0,
    1,
    0.01,
    "visual",
    function(value) return format("%.2f", value) end
  )

  AddSlider(
    prefix .. "_VALUES_ALPHA",
    "Text Alpha",
    "Adjusts the alpha of the orb text container.",
    { "value", "alpha" },
    0,
    1,
    0.01,
    "visual",
    function(value) return format("%.2f", value) end
  )

  AddCheckbox(
    prefix .. "_HIDE_ON_EMPTY",
    "Hide Text On Empty",
    "Refreshes the live orb text policy when the orb has no value.",
    { "value", "hideOnEmpty" },
    "value",
    true
  )

  AddCheckbox(
    prefix .. "_HIDE_ON_FULL",
    "Hide Text On Full",
    "Refreshes the live orb text policy when the orb is effectively full.",
    { "value", "hideOnFull" },
    "value",
    false
  )

  AddDropdown(
    prefix .. "_TOP_MODE",
    "Top Text",
    "Selects what the top orb text shows. Number shortening is controlled globally by Short Numbers.",
    { "value", "top", "mode" },
    function()
      return orbText.GetValueModeOptions()
    end,
    "value",
    orbText.GetDefaultMode("top")
  )

  AddDropdown(
    prefix .. "_BOTTOM_MODE",
    "Bottom Text",
    "Selects what the bottom orb text shows. Number shortening is controlled globally by Short Numbers.",
    { "value", "bottom", "mode" },
    function()
      return orbText.GetValueModeOptions()
    end,
    "value",
    orbText.GetDefaultMode("bottom")
  )

  AddColor(
    prefix .. "_TOP_COLOR",
    "Top Text Color",
    "Updates the top orb text color immediately.",
    { "value", "top", "color" },
    "visual"
  )

  AddColor(
    prefix .. "_BOTTOM_COLOR",
    "Bottom Text Color",
    "Updates the bottom orb text color immediately.",
    { "value", "bottom", "color" },
    "visual"
  )

  ui:AddDropdown({
    category = categoryKey,
    variable = prefix .. "_TEMPLATE_SELECTION",
    label = "Template",
    tooltip = "Selects the shared orb template used by the load/delete actions below.",
    path = { "__selection", orbType },
    defaultValue = "",
    options = function()
      return BuildTemplateOptions()
    end,
    get = function()
      return GetSelectedTemplate(orbType)
    end,
    set = function(nextValue)
      SetSelectedTemplate(orbType, nextValue)
    end,
  })

  AddActionButton(
    prefix .. "_TEMPLATE_SAVE",
    "Templates",
    "Save Current As...",
    "Prompts for a shared template name and stores the current orb settings in Roth_UI_DB.account.templates.",
    function()
      OpenTemplateSaveDialog(orbType)
    end
  )

  AddActionButton(
    prefix .. "_TEMPLATE_LOAD",
    "",
    "Load Selected",
    "Loads the selected shared template into the current orb and refreshes the live orb immediately.",
    function()
      LoadSelectedTemplate(orbType)
    end
  )

  AddActionButton(
    prefix .. "_TEMPLATE_DELETE",
    "",
    "Delete Selected",
    "Deletes the selected shared template after confirmation.",
    function()
      DeleteSelectedTemplate(orbType)
    end
  )

  AddActionButton(
    prefix .. "_TEMPLATE_RESET",
    "",
    "Reset Template Library",
    "Clears the shared template library and reloads the UI after confirmation.",
    function()
      ResetTemplateLibrary()
    end
  )

  AddActionButton(
    prefix .. "_RESET_DEFAULTS",
    "Current Orb",
    "Reset Orb To Defaults",
    "Resets the current orb to addon defaults and refreshes the live orb immediately.",
    function()
      ResetOrbDefaults(orbType)
    end
  )
end

ui:RegisterBuilder("orbs", function()
  RegisterOrbPage("orb_health", "HEALTH", "ROTH_UI_ORB_HEALTH")
  RegisterOrbPage("orb_power", "POWER", "ROTH_UI_ORB_POWER")
end)
