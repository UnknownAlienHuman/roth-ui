local addonName, ns = ...

local ui = assert(ns and ns.SettingsUI, "Roth_UI: SettingsUI is required by settings_transfer.lua")
local actions = assert(ns and ns.settingsActions, "Roth_UI: settings actions are required by settings_transfer.lua")

local function AddTransferButton(label, buttonText, tooltip, onClick)
  ui:AddButton({
    category = "root",
    label = label,
    buttonText = buttonText,
    tooltip = tooltip,
    onClick = onClick,
  })
end

ui:RegisterBuilder("transfer", function()
  AddTransferButton(
    "Settings Export",
    "Export",
    "Serializes Roth_UI_DB and Roth_UI_DB_Char into one copy/paste string for the current character setup.",
    function()
      actions.ShowExport("full")
    end
  )

  AddTransferButton(
    "Settings Import",
    "Import",
    "Replaces Roth_UI_DB and Roth_UI_DB_Char from a pasted export string, then reloads the UI.",
    function()
      actions.ShowImport("full")
    end
  )
end)
