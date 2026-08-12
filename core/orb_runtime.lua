local addonName, ns = ...

local type = type
local tonumber = tonumber
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local storeApi = ns and ns.store
local orbPersistence = ns and ns.orbPersistence
local GetOrbConfig = type(storeApi) == "table" and storeApi.GetOrbConfig or nil
local GetConfigValue = type(storeApi) == "table" and storeApi.GetConfigValue or nil

local function ResolveOrbConfig(orbType)
  if type(storeApi) ~= "table" then
    return nil
  end

  if type(orbPersistence) == "table" and type(orbPersistence.RunPipeline) == "function" then
    orbPersistence.RunPipeline()
  elseif type(orbPersistence) == "table" and type(orbPersistence.EnsureStores) == "function" then
    orbPersistence.EnsureStores()
  end

  local orbConfig = type(GetOrbConfig) == "function" and GetOrbConfig(orbType) or nil
  if type(orbConfig) ~= "table" then
    return nil
  end
  return orbConfig
end

local function ResolveOrbFrame(orbType)
  if orbType == "HEALTH" then
    return ns and ns.HealthOrb
  elseif orbType == "POWER" then
    return ns and ns.PowerOrb
  end
  return nil
end

local function ResolveFontPath()
  local func = ns and ns.func
  local resolver = func and func.ResolveFontPath
  local fontPath = (ns and ns.cfg and ns.cfg.font)
    or (type(GetConfigValue) == "function" and GetConfigValue({ "font" }, STANDARD_TEXT_FONT))
    or STANDARD_TEXT_FONT
  if type(resolver) == "function" then
    return resolver(fontPath)
  end
  return fontPath
end

local function SafeSetFont(fontString, fontPath, defaultSize)
  if not (fontString and fontString.GetFont and fontString.SetFont) then
    return
  end

  local _, size, flags = fontString:GetFont()
  size = tonumber(size) or defaultSize or 12
  flags = (type(flags) == "string") and flags or ""

  if type(fontPath) == "string" and fontPath ~= "" then
    if fontString:SetFont(fontPath, size, flags) then
      return
    end
  end

  if type(STANDARD_TEXT_FONT) == "string" and STANDARD_TEXT_FONT ~= "" then
    fontString:SetFont(STANDARD_TEXT_FONT, size, flags)
  end
end

local function ApplyTextColor(fontString, color)
  if not (fontString and color) then
    return
  end

  local r = color.r or color[1]
  local g = color.g or color[2]
  local b = color.b or color[3]
  local a = color.a
  if type(r) == "number" and type(g) == "number" and type(b) == "number" then
    fontString:SetTextColor(r, g, b, (type(a) == "number" and a) or 1)
  end
end

local function ApplyOrbRuntimeFlags(orbFrame, orbConfig)
  if type(orbFrame) ~= "table" or type(orbConfig) ~= "table" then
    return
  end

  local fill = orbFrame.fill
  local filling = orbConfig.filling
  if not (fill and filling) then
    return
  end

  local auto = filling.colorAuto == true
  if orbFrame.type == "POWER" then
    fill.colorPower = auto
  else
    fill.colorClass = auto
    fill.colorHealth = auto
  end
end

local function EnsureOrbDecorativeRegions(orbFrame, orbConfig)
  if type(orbFrame) ~= "table" or type(orbConfig) ~= "table" then
    return
  end

  local galaxies = orbConfig.galaxies
  if type(galaxies) == "table" and (tonumber(galaxies.alpha) or 0) > 0 and type(orbFrame.EnsureGalaxies) == "function" then
    orbFrame:EnsureGalaxies(galaxies.alpha)
  end

  local bubbles = orbConfig.bubbles
  if type(bubbles) == "table" and (tonumber(bubbles.alpha) or 0) > 0 and type(orbFrame.EnsureBubbles) == "function" then
    orbFrame:EnsureBubbles(bubbles.alpha)
  end
end

local function ApplyRegionColor(regions, r, g, b)
  if type(regions) ~= "table" then
    return
  end

  for i = 1, #regions do
    local region = regions[i]
    if region and region.SetVertexColor then
      region:SetVertexColor(r, g, b)
    end
  end
end

local function SyncOrbTint(orbFrame)
  local fill = orbFrame and orbFrame.fill
  if not (fill and fill.GetStatusBarColor) then
    return
  end

  local r, g, b = fill:GetStatusBarColor()
  if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
    return
  end

  if orbFrame.spark and orbFrame.spark.SetVertexColor then
    orbFrame.spark:SetVertexColor(r, g, b)
  end
  ApplyRegionColor(orbFrame.galaxies, r, g, b)
  ApplyRegionColor(orbFrame.bubbles, r, g, b)
end

local function ApplyOrbModel(orbFrame, orbConfig)
  local model = orbFrame and orbFrame.model
  local cfgm = orbConfig and orbConfig.model
  if not (model and cfgm) then
    return
  end

  if cfgm.enable == false then
    if model.Hide then
      model:Hide()
    end
    return
  end

  if model.Show then
    model:Show()
  end

  if model.SetAlpha and cfgm.alpha ~= nil then
    model:SetAlpha(cfgm.alpha)
  end

  if type(model.Update) == "function" then
    model:Update()
    return
  end

  if model.SetCamDistanceScale and type(cfgm.camDistanceScale) == "number" then
    model:SetCamDistanceScale(cfgm.camDistanceScale)
  end
  if model.SetPosition then
    model:SetPosition(0, tonumber(cfgm.pos_x) or 0, tonumber(cfgm.pos_y) or 0.1)
  end
  if model.SetRotation and type(cfgm.rotation) == "number" then
    model:SetRotation(cfgm.rotation)
  end
  if model.SetPortraitZoom and type(cfgm.portraitZoom) == "number" then
    model:SetPortraitZoom(cfgm.portraitZoom)
  end
  if model.SetDisplayInfo and tonumber(cfgm.displayInfo) then
    model:SetDisplayInfo(tonumber(cfgm.displayInfo))
  end
end

local function ApplyOrbVisual(orbFrame, orbConfig, fontPath)
  if type(orbFrame) ~= "table" or type(orbConfig) ~= "table" then
    return
  end

  ApplyOrbRuntimeFlags(orbFrame, orbConfig)

  local filling = orbConfig.filling
  local value = orbConfig.value
  local bottomValue = value and (value.bottom or value.bot)

  EnsureOrbDecorativeRegions(orbFrame, orbConfig)

  if orbFrame.fill and filling and filling.texture then
    orbFrame.fill:SetStatusBarTexture(filling.texture)
  end

  if orbFrame.fill and filling and filling.color and filling.colorAuto ~= true then
    local color = filling.color
    local r = color.r or color[1]
    local g = color.g or color[2]
    local b = color.b or color[3]
    local a = color.a
    if type(r) == "number" and type(g) == "number" and type(b) == "number" then
      orbFrame.fill:SetStatusBarColor(r, g, b, (type(a) == "number" and a) or 1)
    end
  end

  ApplyOrbModel(orbFrame, orbConfig)

  if orbFrame.glow and orbConfig.glow and orbConfig.glow.alpha ~= nil then
    orbFrame.glow:SetAlpha(orbConfig.glow.alpha)
  end
  if orbFrame.highlight and orbConfig.highlight and orbConfig.highlight.alpha ~= nil then
    orbFrame.highlight:SetAlpha(orbConfig.highlight.alpha)
  end
  if orbFrame.spark and orbConfig.spark and orbConfig.spark.alpha ~= nil then
    orbFrame.spark:SetAlpha(orbConfig.spark.alpha)
  end

  if orbFrame.galaxies and orbConfig.galaxies and orbConfig.galaxies.alpha ~= nil then
    for i = 1, #orbFrame.galaxies do
      local region = orbFrame.galaxies[i]
      if region and region.SetAlpha then
        region:SetAlpha(orbConfig.galaxies.alpha)
      end
    end
  end

  if orbFrame.bubbles and orbConfig.bubbles and orbConfig.bubbles.alpha ~= nil then
    for i = 1, #orbFrame.bubbles do
      local region = orbFrame.bubbles[i]
      if region and region.SetAlpha then
        region:SetAlpha(orbConfig.bubbles.alpha)
      end
    end
  end

  if orbFrame.values and value then
    if orbFrame.values.SetAlpha and value.alpha ~= nil then
      orbFrame.values:SetAlpha(value.alpha)
    end

    if orbFrame.values.top then
      SafeSetFont(orbFrame.values.top, fontPath, 28)
      ApplyTextColor(orbFrame.values.top, value.top and value.top.color)
    end

    if orbFrame.values.bottom then
      SafeSetFont(orbFrame.values.bottom, fontPath, 16)
      ApplyTextColor(orbFrame.values.bottom, bottomValue and bottomValue.color)
    end
  end

  SyncOrbTint(orbFrame)
end

function ns.RefreshOrbsVisual(targetOrbType)
  local fontPath = ResolveFontPath()

  local function RefreshOne(orbType)
    local orbConfig = ResolveOrbConfig(orbType)
    local orbFrame = ResolveOrbFrame(orbType)
    if orbConfig and orbFrame then
      ApplyOrbVisual(orbFrame, orbConfig, fontPath)
    end
  end

  if targetOrbType == "HEALTH" or targetOrbType == "POWER" then
    RefreshOne(targetOrbType)
  else
    RefreshOne("HEALTH")
    RefreshOne("POWER")
  end
end

function ns.ForceOrbValueRefresh(orbType)
  local orbFrame = ResolveOrbFrame(orbType)
  local fill = orbFrame and orbFrame.fill
  if not fill then
    return
  end

  if type(fill.ForceUpdate) == "function" then
    fill:ForceUpdate()
  end

  if type(fill.PostUpdate) ~= "function" then
    return
  end

  local unit = "player"
  if orbType == "HEALTH" then
    fill:PostUpdate(unit, UnitHealth(unit), UnitHealthMax(unit))
  elseif orbType == "POWER" then
    fill:PostUpdate(unit, UnitPower(unit), UnitPowerMax(unit))
  end
end
