local addonName = ...
local ns = assert(_G.Roth_UI, "Roth_UI_Options: main Roth_UI namespace is required")

local safety = assert(ns and ns.safety, "Roth_UI: ns.safety is required by transfer.lua")
local CopySerializable = assert(safety.CopySerializable, "Roth_UI: safety.CopySerializable is required by transfer.lua")
local TryCall = assert(safety.TryCall, "Roth_UI: safety.TryCall is required by transfer.lua")
local persistence = assert(ns and ns.persistence, "Roth_UI: persistence service is required by transfer.lua")
local GetTransferRoots = assert(persistence.GetTransferRoots, "Roth_UI: persistence.GetTransferRoots is required by transfer.lua")
local ApplyTransferRoots = assert(persistence.ApplyTransferRoots, "Roth_UI: persistence.ApplyTransferRoots is required by transfer.lua")
local ReloadPersistenceUI = assert(persistence.ReloadUI, "Roth_UI: persistence.ReloadUI is required by transfer.lua")

local transfer = ns.transfer or {}
ns.transfer = transfer

local EXPORT_PREFIX = "RUI1:"
local EXPORT_KIND = "Roth_UI_Settings_Export"
local EXPORT_VERSION = 1
local COMPRESSION_METHOD = Enum and Enum.CompressionMethod and Enum.CompressionMethod.Deflate or 0

local MODE_ALIASES = {
  full = "full",
  account = "account",
  char = "char",
  character = "char",
}

local MODE_LABELS = {
  full = "Full",
  account = "Account",
  char = "Character",
}

local function NormalizeMode(mode)
  local key = type(mode) == "string" and mode:lower() or "full"
  return MODE_ALIASES[key]
end

local function GetModeLabel(mode)
  return MODE_LABELS[mode] or MODE_LABELS.full
end

local function EnsureEncodingApi()
  if not (C_EncodingUtil and C_EncodingUtil.SerializeCBOR and C_EncodingUtil.DeserializeCBOR and C_EncodingUtil.EncodeBase64 and C_EncodingUtil.DecodeBase64) then
    return false, "Blizzard encoding API is not available on this client build."
  end
  if not (C_EncodingUtil.CompressString and C_EncodingUtil.DecompressString) then
    return false, "Blizzard compression API is not available on this client build."
  end
  return true
end

local function StripWhitespace(text)
  if type(text) ~= "string" then
    return nil
  end
  local cleaned = text:gsub("%s+", "")
  if cleaned == "" then
    return nil
  end
  return cleaned
end

local function BuildExportEnvelope(mode)
  local transferRoots = GetTransferRoots(mode)

  local envelope = {
    kind = EXPORT_KIND,
    version = EXPORT_VERSION,
    mode = mode,
    exportedAt = type(time) == "function" and time() or nil,
  }

  if mode == "full" or mode == "account" then
    local accountRoot = type(transferRoots) == "table" and transferRoots.accountRoot or nil
    envelope.account = CopySerializable(accountRoot) or {}
  end

  if mode == "full" or mode == "char" then
    local charRoot = type(transferRoots) == "table" and transferRoots.charRoot or nil
    envelope.char = CopySerializable(charRoot) or {}
  end

  return envelope
end

local function SerializeEnvelope(envelope)
  local ok, err = EnsureEncodingApi()
  if not ok then
    return nil, err
  end

  local okSerialize, serialized = TryCall(C_EncodingUtil.SerializeCBOR, envelope)
  if okSerialize ~= true or type(serialized) ~= "string" or serialized == "" then
    return nil, "Failed to serialize the export payload."
  end

  local okCompress, compressed = TryCall(C_EncodingUtil.CompressString, serialized, COMPRESSION_METHOD)
  if okCompress ~= true or type(compressed) ~= "string" or compressed == "" then
    return nil, "Failed to compress the export payload."
  end

  local okEncode, encoded = TryCall(C_EncodingUtil.EncodeBase64, compressed)
  if okEncode ~= true or type(encoded) ~= "string" or encoded == "" then
    return nil, "Failed to encode the export payload."
  end

  return EXPORT_PREFIX .. encoded
end

local function DeserializeEnvelope(text)
  local ok, err = EnsureEncodingApi()
  if not ok then
    return nil, err
  end

  local cleaned = StripWhitespace(text)
  if not cleaned then
    return nil, "No import text was provided."
  end

  if cleaned:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
    return nil, "Import text does not have a Roth_UI export header."
  end

  local encoded = cleaned:sub(#EXPORT_PREFIX + 1)
  if encoded == "" then
    return nil, "Import text is empty after the Roth_UI export header."
  end

  local okDecode, compressed = TryCall(C_EncodingUtil.DecodeBase64, encoded)
  if okDecode ~= true or type(compressed) ~= "string" or compressed == "" then
    return nil, "Import text is not valid base64 data."
  end

  local okDecompress, serialized = TryCall(C_EncodingUtil.DecompressString, compressed, COMPRESSION_METHOD)
  if okDecompress ~= true or type(serialized) ~= "string" or serialized == "" then
    return nil, "Import text could not be decompressed."
  end

  local okDeserialize, envelope = TryCall(C_EncodingUtil.DeserializeCBOR, serialized)
  if okDeserialize ~= true or type(envelope) ~= "table" then
    return nil, "Import text did not decode into a table payload."
  end

  if envelope.kind ~= EXPORT_KIND then
    return nil, "Import payload is not a Roth_UI settings export."
  end

  if tonumber(envelope.version) ~= EXPORT_VERSION then
    return nil, ("Import payload version '%s' is not supported by this build."):format(tostring(envelope.version))
  end

  return envelope
end

local function ValidateAccountRoot(root)
  local copy = CopySerializable(root)
  if type(copy) ~= "table" then
    return nil, "Account payload is missing or invalid."
  end
  if type(copy.account) ~= "table" then
    return nil, "Account payload is missing the account table."
  end
  if type(copy.account.settings) ~= "table" then
    return nil, "Account payload is missing account.settings."
  end
  if type(copy.account.templates) ~= "table" then
    return nil, "Account payload is missing account.templates."
  end
  return copy
end

local function ValidateCharRoot(root)
  local copy = CopySerializable(root)
  if type(copy) ~= "table" then
    return nil, "Character payload is missing or invalid."
  end
  if type(copy.orbs) ~= "table" then
    return nil, "Character payload is missing Roth_UI_DB_Char.orbs."
  end
  return copy
end

function transfer.Export(mode)
  local normalizedMode = NormalizeMode(mode)
  if not normalizedMode then
    return nil, ("Unknown export mode '%s'."):format(tostring(mode))
  end
  return SerializeEnvelope(BuildExportEnvelope(normalizedMode))
end

function transfer.Import(mode, text)
  local normalizedMode = NormalizeMode(mode)
  if not normalizedMode then
    return false, ("Unknown import mode '%s'."):format(tostring(mode))
  end

  local envelope, err = DeserializeEnvelope(text)
  if not envelope then
    return false, err
  end

  local replacePayload = {}

  if normalizedMode == "account" or normalizedMode == "full" then
    local accountRoot, accountErr = ValidateAccountRoot(envelope.account)
    if not accountRoot then
      return false, accountErr
    end
    replacePayload.accountRoot = accountRoot
  end

  if normalizedMode == "char" or normalizedMode == "full" then
    local charRoot, charErr = ValidateCharRoot(envelope.char)
    if not charRoot then
      return false, charErr
    end
    replacePayload.charRoot = charRoot
  end

  if next(replacePayload) ~= nil then
    if ApplyTransferRoots(replacePayload) ~= true then
      return false, "Controlled persistence root replacement is unavailable."
    end
  end

  return true, ("%s settings imported successfully."):format(GetModeLabel(normalizedMode))
end

local function UpdateEditBoxLayout(dialog)
  local scrollFrame = dialog and dialog.ScrollFrame
  local editBox = dialog and dialog.EditBox
  if not (scrollFrame and editBox) then
    return
  end

  local width = scrollFrame:GetWidth() - 24
  if width > 0 then
    editBox:SetWidth(width)
  end

  local minHeight = scrollFrame:GetHeight()
  local contentHeight = editBox:GetStringHeight() + 24
  editBox:SetHeight(math.max(minHeight, contentHeight))
  if scrollFrame.UpdateScrollChildRect then
    scrollFrame:UpdateScrollChildRect()
  end
end

local function SetDialogTitle(dialog, text)
  local title = dialog and dialog.TitleText
  if title and title.SetText then
    title:SetText(text or "")
  end
end

local function EnsureDialog()
  if transfer.dialog then
    return transfer.dialog
  end

  local dialog = CreateFrame("Frame", "Roth_UITransferDialog", UIParent, "BasicFrameTemplateWithInset")
  dialog:SetSize(760, 520)
  dialog:SetPoint("CENTER")
  dialog:SetFrameStrata("DIALOG")
  dialog:SetMovable(true)
  dialog:SetClampedToScreen(true)
  dialog:EnableMouse(true)
  dialog:RegisterForDrag("LeftButton")
  dialog:SetScript("OnDragStart", dialog.StartMoving)
  dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
  dialog:SetScript("OnSizeChanged", UpdateEditBoxLayout)
  dialog:Hide()

  SetDialogTitle(dialog, "Roth_UI Transfer")

  local subtitle = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", dialog, "TOPLEFT", 16, -32)
  subtitle:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -16, -32)
  subtitle:SetJustifyH("LEFT")
  subtitle:SetJustifyV("TOP")
  dialog.Subtitle = subtitle

  local scrollFrame = CreateFrame("ScrollFrame", "$parentScrollFrame", dialog, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", dialog, "TOPLEFT", 16, -58)
  scrollFrame:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -32, 52)
  dialog.ScrollFrame = scrollFrame

  local editBox = CreateFrame("EditBox", "$parentEditBox", scrollFrame)
  editBox:SetMultiLine(true)
  editBox:SetAutoFocus(false)
  if ChatFontNormal then
    editBox:SetFontObject(ChatFontNormal)
  else
    editBox:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
  end
  editBox:SetTextInsets(8, 8, 8, 8)
  editBox:SetJustifyH("LEFT")
  editBox:SetJustifyV("TOP")
  editBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    dialog:Hide()
  end)
  editBox:SetScript("OnTextChanged", function(self)
    UpdateEditBoxLayout(dialog)
    if dialog.operation == "import" and dialog.Status then
      dialog.Status:SetText("")
    end
  end)
  scrollFrame:SetScrollChild(editBox)
  dialog.EditBox = editBox

  local status = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  status:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 18, 20)
  status:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -300, 20)
  status:SetJustifyH("LEFT")
  status:SetJustifyV("MIDDLE")
  dialog.Status = status

  local closeButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
  closeButton:SetSize(90, 22)
  closeButton:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 16, 14)
  closeButton:SetText(_G["CLOSE"] or "Close")
  closeButton:SetScript("OnClick", function()
    dialog:Hide()
  end)
  dialog.CloseButton = closeButton

  local secondaryButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
  secondaryButton:SetSize(110, 22)
  secondaryButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -136, 14)
  dialog.SecondaryButton = secondaryButton

  local primaryButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
  primaryButton:SetSize(130, 22)
  primaryButton:SetPoint("RIGHT", secondaryButton, "LEFT", -8, 0)
  dialog.PrimaryButton = primaryButton

  primaryButton:SetScript("OnClick", function()
    if type(dialog.RunPrimary) == "function" then
      dialog:RunPrimary()
    end
  end)

  secondaryButton:SetScript("OnClick", function()
    if type(dialog.RunSecondary) == "function" then
      dialog:RunSecondary()
    end
  end)

  transfer.dialog = dialog
  UpdateEditBoxLayout(dialog)
  return dialog
end

local function PrepareDialog(operation, mode)
  local dialog = EnsureDialog()
  dialog.operation = operation
  dialog.mode = mode
  dialog.ScrollFrame:SetVerticalScroll(0)
  return dialog
end

function transfer.ShowExportDialog(mode)
  local normalizedMode = NormalizeMode(mode or "full")
  if not normalizedMode then
    print(("Roth_UI: unknown export mode '%s'."):format(tostring(mode)))
    return false
  end

  local exportText, err = transfer.Export(normalizedMode)
  if not exportText then
    print("Roth_UI: " .. err)
    return false
  end

  local dialog = PrepareDialog("export", normalizedMode)
  SetDialogTitle(dialog, ("Roth_UI %s Export"):format(GetModeLabel(normalizedMode)))
  dialog.Subtitle:SetText("Copy this string to transfer Roth_UI SavedVariables to another client or character.")
  dialog.Status:SetText(("Export length: %d characters"):format(#exportText))
  dialog.EditBox:SetText(exportText)
  dialog.PrimaryButton:SetText("Refresh")
  dialog.SecondaryButton:SetText("Select All")

  dialog.RunPrimary = function(self)
    local refreshedText, refreshErr = transfer.Export(self.mode)
    if not refreshedText then
      self.Status:SetText(refreshErr)
      print("Roth_UI: " .. refreshErr)
      return
    end
    self.EditBox:SetText(refreshedText)
    self.Status:SetText(("Export length: %d characters"):format(#refreshedText))
    self.EditBox:SetFocus()
    self.EditBox:HighlightText()
  end

  dialog.RunSecondary = function(self)
    self.EditBox:SetFocus()
    self.EditBox:HighlightText()
  end

  dialog:Show()
  UpdateEditBoxLayout(dialog)
  dialog.EditBox:SetFocus()
  dialog.EditBox:HighlightText()
  return true
end

function transfer.ShowImportDialog(mode)
  local normalizedMode = NormalizeMode(mode or "full")
  if not normalizedMode then
    print(("Roth_UI: unknown import mode '%s'."):format(tostring(mode)))
    return false
  end

  local dialog = PrepareDialog("import", normalizedMode)
  SetDialogTitle(dialog, ("Roth_UI %s Import"):format(GetModeLabel(normalizedMode)))
  dialog.Subtitle:SetText("Paste a Roth_UI export string. Valid data replaces the selected SavedVariables root and reloads the UI.")
  dialog.Status:SetText("")
  dialog.EditBox:SetText("")
  dialog.PrimaryButton:SetText("Import & Reload")
  dialog.SecondaryButton:SetText("Clear")

  dialog.RunPrimary = function(self)
    if InCombatLockdown and InCombatLockdown() then
      local combatErr = "Import is blocked in combat. Leave combat and try again."
      self.Status:SetText(combatErr)
      print("Roth_UI: " .. combatErr)
      return
    end

    local ok, result = transfer.Import(self.mode, self.EditBox:GetText())
    if ok ~= true then
      self.Status:SetText(result)
      print("Roth_UI: " .. result)
      return
    end

    print(("Roth_UI: %s Reloading UI."):format(result))
    if ReloadPersistenceUI() ~= true then
      local reloadErr = "Import applied, but UI reload is not available."
      self.Status:SetText(reloadErr)
      print("Roth_UI: " .. reloadErr)
    end
  end

  dialog.RunSecondary = function(self)
    self.EditBox:SetText("")
    self.EditBox:SetFocus()
    self.Status:SetText("")
  end

  dialog:Show()
  UpdateEditBoxLayout(dialog)
  dialog.EditBox:SetFocus()
  return true
end

transfer.NormalizeMode = NormalizeMode
transfer.GetModeLabel = GetModeLabel
