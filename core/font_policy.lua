local addonName, ns = ...

local func = assert(ns and ns.func, "Roth_UI: ns.func is required by font_policy.lua")

local fontPolicy = ns.fontPolicy or {}
ns.fontPolicy = fontPolicy

local ResolveFontPath = func.ResolveFontPath
if type(ResolveFontPath) ~= "function" then
  ResolveFontPath = function(fontPath)
    if type(fontPath) == "string" and fontPath ~= "" then
      return fontPath
    end
    return (ns and ns.cfg and ns.cfg.font) or _G.STANDARD_TEXT_FONT
  end
end

func.ResolveFontPath = ResolveFontPath
fontPolicy.ResolveFontPath = ResolveFontPath

local function ApplyFontObject(fontPath, fontObject)
  if type(fontPath) ~= "string" or fontPath == "" then
    return
  end
  if not fontObject or not fontObject.GetFont or not fontObject.SetFont then
    return
  end

  local _, size, flags = fontObject:GetFont()
  size = tonumber(size)
  if not size or size <= 0 or size > 256 then
    return
  end

  flags = (type(flags) == "string") and flags or ""
  fontObject:SetFont(fontPath, size, flags)
end

function func:ApplyGlobalFonts()
  local cfg = ns and ns.cfg
  if not cfg or cfg.applyGlobalFonts ~= true then
    return
  end

  local fontPath = ResolveFontPath(cfg.font)
  if type(fontPath) ~= "string" or fontPath == "" then
    return
  end

  _G.STANDARD_TEXT_FONT = fontPath
  _G.UNIT_NAME_FONT = fontPath
  _G.DAMAGE_TEXT_FONT = fontPath

  local fontObjects = {
    _G.GameFontNormal, _G.GameFontHighlight, _G.GameFontDisable,
    _G.GameFontNormalSmall, _G.GameFontHighlightSmall, _G.GameFontDisableSmall,
    _G.SystemFont_NamePlateFixed, _G.SystemFont_Shadow_Small, _G.SystemFont_Shadow_Med1, _G.SystemFont_Shadow_Med2,
    _G.SystemFont_Shadow_Large, _G.SystemFont_InverseShadow_Small,
    _G.SystemFont_Tiny, _G.SystemFont_Small, _G.SystemFont_Med1, _G.SystemFont_Med2,
    _G.SystemFont_Large, _G.SystemFont_Huge1, _G.SystemFont_Huge2, _G.SystemFont_Huge4,
    _G.NumberFont_GameNormal, _G.NumberFont_GameNormalSmall, _G.NumberFont_OutlineThick_Mono_Small,
    _G.NumberFont_Outline_Huge, _G.NumberFont_Outline_Large, _G.NumberFont_Outline_Med,
  }

  for i = 1, #fontObjects do
    ApplyFontObject(fontPath, fontObjects[i])
  end

  local registry = ns and ns._fontStrings
  if type(registry) ~= "table" then
    return
  end

  for fontString, info in pairs(registry) do
    if fontString and fontString.SetFont then
      local _, size, flags = fontString:GetFont()
      size = tonumber(size) or (info and info.size) or 12
      if not size or size <= 0 or size > 256 then
        size = (info and info.size) or 12
      end
      if type(flags) ~= "string" then
        flags = (info and info.flags) or ""
      end
      fontString:SetFont(fontPath, size, flags)
    end
  end
end

fontPolicy.ApplyGlobalFonts = func.ApplyGlobalFonts
