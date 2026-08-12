local addonName, ns = ...

local func = assert(ns and ns.func, "Roth_UI: ns.func is required by mover_runtime.lua")
local storeApi = assert(ns and ns.store, "Roth_UI: ns.store is required by mover_runtime.lua")
local GetConfigValue = assert(storeApi.GetConfigValue, "Roth_UI: store GetConfigValue is required by mover_runtime.lua")
local SetConfigValue = assert(storeApi.SetConfigValue, "Roth_UI: store SetConfigValue is required by mover_runtime.lua")

local cfg = ns and ns.cfg or {}
local floor = floor
local tonumber = tonumber
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local IsSecretValue = func.IsSecretValue
local pairs = pairs
local setmetatable = setmetatable

local moverRuntime = ns.moverRuntime or {}
ns.moverRuntime = moverRuntime
moverRuntime._frames = moverRuntime._frames or setmetatable({}, { __mode = "k" })
moverRuntime._categories = moverRuntime._categories or setmetatable({}, { __mode = "k" })
moverRuntime._legacyFrameList = moverRuntime._legacyFrameList or nil
moverRuntime._legacyPrimed = moverRuntime._legacyPrimed or false

local CATEGORY_ORDER = { "art", "bars", "units", "orbs" }

local MOVER_SCALE_MIN = 0.50
local MOVER_SCALE_MAX = 2.50
local MOVER_SCALE_STEP = 0.03
local MOVER_SCALE_FINE_STEP = 0.01
local MOVER_SIZE_MIN = 24
local MOVER_SIZE_MAX = 4096

local function NormalizeMoverScale(v)
  if type(v) ~= "number" then return nil end
  if IsSecretValue and IsSecretValue(v) then return nil end
  if v < MOVER_SCALE_MIN then
    v = MOVER_SCALE_MIN
  elseif v > MOVER_SCALE_MAX then
    v = MOVER_SCALE_MAX
  end
  return floor((v * 100) + 0.5) / 100
end

local function GetMoverFrameName(f)
  if not (f and f.GetName) then return nil end
  local n = f:GetName()
  if type(n) ~= "string" or n == "" then return nil end
  return n
end

local function InsertUnique(list, entry)
  if type(list) ~= "table" or entry == nil then
    return false
  end

  for i = 1, #list do
    if list[i] == entry then
      return false
    end
  end

  list[#list + 1] = entry
  return true
end

local function EnsureCompatDragFrameList()
  local list = moverRuntime._legacyFrameList
  local rLib = _G.rLib
  if type(list) ~= "table" and type(rLib) == "table" then
    list = rLib.dragFrameList
  end
  if type(list) ~= "table" then
    list = {}
  end

  moverRuntime._legacyFrameList = list
  if type(rLib) == "table" then
    rLib.dragFrameList = list
  end

  return list
end

local function ResolveMoverDragHandle(frame)
  if type(frame) ~= "table" then
    return nil
  end

  local handle = frame.dragframe or frame.dragFrame
  if handle then
    frame.dragframe = handle
    frame.dragFrame = handle
  end
  return handle
end

local function RegisterCanonicalFrame(frame, category)
  if type(frame) ~= "table" or type(category) ~= "string" or category == "" then
    return false
  end

  local frameRegistry = ns and ns.frameRegistry
  local registerFrame = type(frameRegistry) == "table" and (frameRegistry.RegisterFrame or frameRegistry.Register) or nil
  if type(registerFrame) ~= "function" then
    return false
  end

  registerFrame(frameRegistry, category, frame)
  return true
end

local function TrackLegacyMoverFrame(frame)
  if type(frame) ~= "table" then
    return nil
  end

  local list = EnsureCompatDragFrameList()
  InsertUnique(list, frame)
  return list
end

local function ResolveMoverCategoryFromRegistry(frame, frameName)
  local frameRegistry = ns and ns.frameRegistry
  local getCategory = type(frameRegistry) == "table" and frameRegistry.GetCategory or nil
  if type(getCategory) == "function" then
    local category = getCategory(frameRegistry, frame)
    if not category and type(frameName) == "string" and frameName ~= "" then
      category = getCategory(frameRegistry, frameName)
    end
    if type(category) == "string" and category ~= "" then
      return category
    end
  end

  local getList = type(frameRegistry) == "table" and frameRegistry.GetList or nil
  if type(getList) ~= "function" then
    return nil
  end

  for i = 1, #CATEGORY_ORDER do
    local category = CATEGORY_ORDER[i]
    local list = getList(category)
    if type(list) == "table" then
      for _, entry in pairs(list) do
        if entry == frame or (type(frameName) == "string" and entry == frameName) then
          return category
        end
      end
    end
  end

  return nil
end

local function GuessMoverCategory(frame)
  if type(frame) ~= "table" then
    return nil
  end

  local category = moverRuntime._categories[frame]
  if type(category) == "string" and category ~= "" then
    return category
  end

  local frameName = GetMoverFrameName(frame)
  category = ResolveMoverCategoryFromRegistry(frame, frameName)
  if category then
    return category
  end

  if type(frameName) == "string" then
    if frameName == "Roth_UIActionBarBackground" then
      return "art"
    end
    if frameName:find("^rABS_") then
      return "bars"
    end
  end

  return nil
end

local function ResolveMoverCategoryHint(frame, categoryHint)
  if type(categoryHint) == "string" and categoryHint ~= "" then
    return categoryHint
  end

  return GuessMoverCategory(frame)
end

local function RegisterMoverFrame(frame, category)
  if type(frame) ~= "table" then
    return nil
  end

  moverRuntime._frames[frame] = true
  local handle = ResolveMoverDragHandle(frame)
  if handle then
    TrackLegacyMoverFrame(frame)
  end

  category = ResolveMoverCategoryHint(frame, category)
  if type(category) == "string" and category ~= "" then
    moverRuntime._categories[frame] = category
    RegisterCanonicalFrame(frame, category)
  end

  return frame
end

local function PrimeLegacyMoverFrames()
  if moverRuntime._legacyPrimed == true then
    return
  end
  moverRuntime._legacyPrimed = true

  local dragFrameList = EnsureCompatDragFrameList()
  for i = 1, #dragFrameList do
    RegisterMoverFrame(dragFrameList[i])
  end
end

local function ShouldVisitMoverSelection(selection, category)
  if selection == nil or selection == "" or selection == "all" then
    return true
  end
  return selection == category
end

function moverRuntime.GetDragHandle(frame)
  return ResolveMoverDragHandle(frame)
end

function moverRuntime.GetCompatDragFrameList()
  return EnsureCompatDragFrameList()
end

function moverRuntime.RegisterFrame(frame, category)
  return RegisterMoverFrame(frame, category)
end

function moverRuntime.AttachLegacyDragFrame(frame, category, resize, inset, clamp)
  if type(frame) ~= "table" then
    return false
  end

  if ResolveMoverDragHandle(frame) then
    RegisterMoverFrame(frame, category)
    return true
  end

  local rLib = _G.rLib
  if type(rLib) ~= "table" then
    return false
  end

  local dragFrameList = EnsureCompatDragFrameList()
  if resize == true then
    if type(rLib.CreateDragResizeFrame) ~= "function" then
      return false
    end
    rLib:CreateDragResizeFrame(frame, dragFrameList, inset, clamp)
  else
    if type(rLib.CreateDragFrame) ~= "function" then
      return false
    end
    rLib:CreateDragFrame(frame, dragFrameList, inset, clamp)
  end

  RegisterMoverFrame(frame, category)
  return true
end

function moverRuntime.ForEachFrame(selection, callback)
  if type(selection) == "function" and callback == nil then
    callback = selection
    selection = "all"
  end
  if type(callback) ~= "function" then
    return
  end

  PrimeLegacyMoverFrames()

  local seen = {}

  local function VisitFrame(frame, category)
    frame = RegisterMoverFrame(frame, category)
    if not frame or seen[frame] then
      return
    end

    if not ResolveMoverDragHandle(frame) then
      return
    end

    local effectiveCategory = moverRuntime._categories[frame] or GuessMoverCategory(frame)
    if not ShouldVisitMoverSelection(selection, effectiveCategory) then
      return
    end

    seen[frame] = true
    callback(frame, effectiveCategory)
  end

  local frameRegistry = ns and ns.frameRegistry
  local forEachRegisteredFrame = type(frameRegistry) == "table" and frameRegistry.ForEachFrame or nil
  if type(forEachRegisteredFrame) == "function" then
    forEachRegisteredFrame(selection or "all", VisitFrame)
  end

  for frame in pairs(moverRuntime._frames) do
    VisitFrame(frame, moverRuntime._categories[frame])
  end

end

ns.ForEachMoverFrame = moverRuntime.ForEachFrame
ns.GetMoverDragHandle = moverRuntime.GetDragHandle
ns.RegisterMoverFrame = moverRuntime.RegisterFrame
func.RegisterMoverFrame = RegisterMoverFrame

local function NormalizeMoverOffset(v)
  v = tonumber(v)
  if not v then return nil end
  if IsSecretValue and IsSecretValue(v) then return nil end
  return floor((v * 100) + 0.5) / 100
end

local function NormalizeMoverDimension(v)
  v = tonumber(v)
  if not v then return nil end
  if IsSecretValue and IsSecretValue(v) then return nil end
  if v < MOVER_SIZE_MIN then
    v = MOVER_SIZE_MIN
  elseif v > MOVER_SIZE_MAX then
    v = MOVER_SIZE_MAX
  end
  return floor(v + 0.5)
end

local function NormalizeMoverPointData(point)
  if type(point) ~= "table" then return nil end

  local a1 = type(point.a1) == "string" and point.a1 or "CENTER"
  local af = type(point.af) == "string" and point.af or "UIParent"
  local a2 = type(point.a2) == "string" and point.a2 or a1
  local x = NormalizeMoverOffset(point.x)
  local y = NormalizeMoverOffset(point.y)
  if not x or not y then
    return nil
  end

  return {
    a1 = a1,
    af = af,
    a2 = a2,
    x = x,
    y = y,
  }
end

local function NormalizeMoverSizeData(size)
  if type(size) ~= "table" then return nil end

  local w = NormalizeMoverDimension(size.w or size[1])
  local h = NormalizeMoverDimension(size.h or size[2])
  if not w or not h then
    return nil
  end

  return {
    w = w,
    h = h,
  }
end

local function GetMoverAnchorName(anchor)
  if type(anchor) == "string" and anchor ~= "" then
    return anchor
  end

  if type(anchor) == "table" and anchor.GetName then
    local name = anchor:GetName()
    if type(name) == "string" and name ~= "" then
      return name
    end
  end

  return "UIParent"
end

local function GetMoverStorePath(key, frameName)
  return { "movers", key, frameName }
end

local function SaveMoverScale(f)
  local frameName = GetMoverFrameName(f)
  if not frameName then return end
  local scale = NormalizeMoverScale(f:GetScale())
  if not scale then return end
  SetConfigValue(GetMoverStorePath("scale", frameName), scale)
end

local function ClearMoverScale(f)
  local frameName = GetMoverFrameName(f)
  if not frameName then return end
  SetConfigValue(GetMoverStorePath("scale", frameName), nil)
end

local function ApplySavedMoverScale(f)
  local frameName = GetMoverFrameName(f)
  if not frameName then return end
  local scale = GetConfigValue(GetMoverStorePath("scale", frameName), nil)
  scale = NormalizeMoverScale(scale)
  if not scale then return end
  f:SetScale(scale)
end

local function SaveMoverPoint(f)
  if not (f and f.GetPoint) then return end

  local frameName = GetMoverFrameName(f)
  if not frameName then return end

  local a1, af, a2, x, y = f:GetPoint()
  local point = NormalizeMoverPointData({
    a1 = a1,
    af = GetMoverAnchorName(af),
    a2 = a2,
    x = x,
    y = y,
  })
  if not point then return end

  SetConfigValue(GetMoverStorePath("point", frameName), point)
end

local function ClearMoverPoint(f)
  local frameName = GetMoverFrameName(f)
  if not frameName then return end
  SetConfigValue(GetMoverStorePath("point", frameName), nil)
end

local function ApplySavedMoverPoint(f)
  if not (f and f.SetPoint and f.ClearAllPoints) then return end

  local frameName = GetMoverFrameName(f)
  if not frameName then return end

  local point = NormalizeMoverPointData(GetConfigValue(GetMoverStorePath("point", frameName), nil))
  if not point then return end

  local anchorFrame = _G[point.af] or UIParent
  f:ClearAllPoints()
  f:SetPoint(point.a1, anchorFrame, point.a2, point.x, point.y)
end

local function SaveMoverSize(f)
  if not (f and f.GetSize and f.SetSize) then return end

  local frameName = GetMoverFrameName(f)
  if not frameName then return end

  local w, h = f:GetSize()
  local size = NormalizeMoverSizeData({ w = w, h = h })
  if not size then return end

  SetConfigValue(GetMoverStorePath("size", frameName), size)
end

local function ClearMoverSize(f)
  local frameName = GetMoverFrameName(f)
  if not frameName then return end
  SetConfigValue(GetMoverStorePath("size", frameName), nil)
end

local function ApplySavedMoverSize(f)
  if not (f and f.SetSize) then return end

  local frameName = GetMoverFrameName(f)
  if not frameName then return end

  local size = NormalizeMoverSizeData(GetConfigValue(GetMoverStorePath("size", frameName), nil))
  if not size then return end
  f:SetSize(size.w, size.h)
end

local function SaveMoverLayout(f, opts)
  opts = type(opts) == "table" and opts or {}
  if opts.point ~= false then
    SaveMoverPoint(f)
  end
  if opts.scale ~= false then
    SaveMoverScale(f)
  end
  if opts.size ~= false then
    SaveMoverSize(f)
  end
end

local function ClearMoverLayout(f, opts)
  opts = type(opts) == "table" and opts or {}
  if opts.point ~= false then
    ClearMoverPoint(f)
  end
  if opts.scale ~= false then
    ClearMoverScale(f)
  end
  if opts.size ~= false then
    ClearMoverSize(f)
  end
end

local function ApplySavedMoverLayout(f, opts)
  opts = type(opts) == "table" and opts or {}
  if opts.size ~= false then
    ApplySavedMoverSize(f)
  end
  if opts.point ~= false then
    ApplySavedMoverPoint(f)
  end
  if opts.scale ~= false then
    ApplySavedMoverScale(f)
  end
end

ns.SaveMoverLayout = SaveMoverLayout
ns.ClearMoverLayout = ClearMoverLayout
ns.ApplySavedMoverLayout = ApplySavedMoverLayout

local function SetMoverUserPlaced(f, userPlaced)
  if not (f and f.SetUserPlaced) then return end
  local movable = f.IsMovable and f:IsMovable() or false
  local resizable = f.IsResizable and f:IsResizable() or false
  if not movable and not resizable then return end
  f:SetUserPlaced(userPlaced and true or false)
end

local function ShowMoverTooltip(df, parent)
  if InCombatLockdown and InCombatLockdown() then return end
  local t = ns and ns.Tooltip
  if t and type(t.OnMoverEnter) == "function" then
    local handled = t.OnMoverEnter(t, df, parent)
    if handled then
      df.__tooltipHandled = true
      return
    end
  end
  if not GameTooltip then return end
  GameTooltip:SetOwner(df, "ANCHOR_TOP")
  GameTooltip:AddLine((parent and parent:GetName()) or "Roth_UI Mover", 0, 1, 0.5, true)
  GameTooltip:AddLine("SHIFT+Drag: move frame", 1, 1, 1, true)
  GameTooltip:AddLine("MouseWheel: scale frame", 0.8, 0.95, 1, true)
  GameTooltip:AddLine("SHIFT+MouseWheel: fine scale", 0.8, 0.95, 1, true)
  if parent and parent.GetSize and parent.SetSize then
    GameTooltip:AddLine("CTRL+ALT+MouseWheel: resize frame", 0.8, 0.95, 1, true)
  end
  GameTooltip:AddLine("SHIFT+RightClick: reset scale", 0.8, 0.95, 1, true)
  if parent and parent.GetScale then
    local s = NormalizeMoverScale(parent:GetScale()) or 1
    GameTooltip:AddLine(("Scale: %.2f"):format(s), 1, 0.82, 0.2, true)
  end
  GameTooltip:Show()
  df.__tooltipHandled = true
end

local function HideMoverTooltip(df)
  local t = ns and ns.Tooltip
  if t and type(t.OnMoverLeave) == "function" then
    t.OnMoverLeave(t, df)
    df.__tooltipHandled = nil
    return
  end
  if df.__tooltipHandled and GameTooltip then GameTooltip:Hide() end
  df.__tooltipHandled = nil
end

local function HandleMoverMouseWheel(df, delta)
  if InCombatLockdown and InCombatLockdown() then return end
  local parent = df and df:GetParent()
  if not parent then return end

  local ctrlDown = (_G.IsControlKeyDown and IsControlKeyDown()) or false
  local altDown = (_G.IsAltKeyDown and IsAltKeyDown()) or false
  if ctrlDown and altDown and parent.GetSize and parent.SetSize then
    local w, h = parent:GetSize()
    w = tonumber(w) or 1
    h = tonumber(h) or 1
    if w < 1 then w = 1 end
    local ratio = h / w
    local step = IsShiftKeyDown() and 4 or 10
    local nextW = w + ((delta > 0) and step or -step)
    if nextW < 24 then nextW = 24 end
    if nextW > 4096 then nextW = 4096 end
    local nextH = nextW * ratio
    if nextH < 24 then nextH = 24 end
    if nextH > 4096 then nextH = 4096 end
    parent:SetSize(nextW, nextH)
    SaveMoverSize(parent)
    if df.IsMouseOver and df:IsMouseOver() then
      ShowMoverTooltip(df, parent)
    end
    return
  end

  if not (parent.GetScale and parent.SetScale) then return end

  local step = IsShiftKeyDown() and MOVER_SCALE_FINE_STEP or MOVER_SCALE_STEP
  local cur = NormalizeMoverScale(parent:GetScale()) or 1
  local nextScale = NormalizeMoverScale(cur + ((delta > 0) and step or -step))
  if not nextScale or nextScale == cur then return end

  parent:SetScale(nextScale)
  SaveMoverScale(parent)
  if df.IsMouseOver and df:IsMouseOver() then
    ShowMoverTooltip(df, parent)
  end
end

local function HandleMoverMouseUp(df, button)
  if button ~= "RightButton" then return end
  if not IsShiftKeyDown() then return end
  if InCombatLockdown and InCombatLockdown() then return end
  local parent = df and df:GetParent()
  if not (parent and parent.SetScale) then return end

  local defaultScale = NormalizeMoverScale(parent.defaultScale) or 1
  parent:SetScale(defaultScale)
  ClearMoverScale(parent)
  if df.IsMouseOver and df:IsMouseOver() then
    ShowMoverTooltip(df, parent)
  end
end

func.SetMoverUnlocked = function(f, isUnlocked)
  if not f then return false end
  local df = ResolveMoverDragHandle(f)
  if not df then return false end
  if isUnlocked then
    df:Show()
    df:EnableMouse(true)
    df:EnableMouseWheel(true)
    df:RegisterForDrag("LeftButton")
    df:SetScript("OnEnter", function(s) ShowMoverTooltip(s, s:GetParent()) end)
    df:SetScript("OnLeave", HideMoverTooltip)
    df:SetScript("OnMouseWheel", HandleMoverMouseWheel)
    df:SetScript("OnMouseUp", HandleMoverMouseUp)
    if ns and type(ns.ShowMoveGrid) == "function" then
      ns.ShowMoveGrid()
    end
    return true
  end

  df:Hide()
  df:EnableMouse(false)
  df:EnableMouseWheel(false)
  df:SetScript("OnEnter", nil)
  df:SetScript("OnLeave", nil)
  df:SetScript("OnMouseWheel", nil)
  df:SetScript("OnMouseUp", nil)
  HideMoverTooltip(df)
  return true
end

func.ResetMoverScale = function(f)
  if not f then return end
  local defaultScale = NormalizeMoverScale(f.defaultScale) or 1
  if f.SetScale then
    f:SetScale(defaultScale)
  end
  ClearMoverScale(f)
end

func.ResetMoverLayout = function(f)
  if not f then return end

  SetMoverUserPlaced(f, false)

  local point = f.defaultPosition or f.defaultPoint
  if point and f.SetPoint and f.ClearAllPoints then
    f:ClearAllPoints()
    if point.af and point.a2 then
      f:SetPoint(point.a1 or "CENTER", point.af, point.a2, point.x or 0, point.y or 0)
    elseif point.af then
      f:SetPoint(point.a1 or "CENTER", point.af, point.x or 0, point.y or 0)
    else
      f:SetPoint(point.a1 or "CENTER", point.x or 0, point.y or 0)
    end
  end

  if f.defaultSize and f.SetSize then
    f:SetSize(f.defaultSize.w, f.defaultSize.h)
  end

  if f.defaultScale and f.SetScale then
    f:SetScale(NormalizeMoverScale(f.defaultScale) or 1)
  end

  ClearMoverLayout(f)
end

function moverRuntime.SaveLayout(frame, opts)
  return SaveMoverLayout(frame, opts)
end

function moverRuntime.ClearLayout(frame, opts)
  return ClearMoverLayout(frame, opts)
end

function moverRuntime.ApplySavedLayout(frame, opts)
  return ApplySavedMoverLayout(frame, opts)
end

function moverRuntime.SetUnlocked(frame, isUnlocked)
  return func.SetMoverUnlocked(frame, isUnlocked)
end

function moverRuntime.ResetLayout(frame)
  return func.ResetMoverLayout(frame)
end

local function PublishLegacyMoverBridge()
  local rLib = _G.rLib
  if type(rLib) ~= "table" then
    return
  end

  rLib.dragFrameList = EnsureCompatDragFrameList()
  rLib.moverCallbacks = rLib.moverCallbacks or {}
  local callbacks = rLib.moverCallbacks
  callbacks.SaveLayout = SaveMoverLayout
  callbacks.ClearLayout = ClearMoverLayout
  callbacks.ApplySavedLayout = ApplySavedMoverLayout
  callbacks.ResetLayout = func.ResetMoverLayout
  callbacks.RegisterFrame = RegisterMoverFrame
end

PublishLegacyMoverBridge()

func.applyDragFunctionality = function(f, special)
  if not f then return end
  local category = ResolveMoverCategoryHint(f, special == "orb" and "orbs" or special == "bottomline" and "art" or nil)
  if ResolveMoverDragHandle(f) then
    RegisterMoverFrame(f, category)
    return
  end

  local getPoint = function(self)
    local pos = {}
    pos.a1, pos.af, pos.a2, pos.x, pos.y = self:GetPoint()
    if pos.af and pos.af:GetName() then pos.af = pos.af:GetName() end
    return pos
  end
  f.defaultPosition = getPoint(f)
  f.defaultScale = NormalizeMoverScale(f:GetScale()) or 1
  if f.GetSize then
    local w, h = f:GetSize()
    f.defaultSize = { w = tonumber(w) or 1, h = tonumber(h) or 1 }
  end

  local df = CreateFrame("Frame", nil, f)
  df:SetAllPoints(f)
  df:SetFrameStrata("HIGH")
  df:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:GetParent():StartMoving() end end)
  df:SetScript("OnDragStop", function(self)
    local parent = self:GetParent()
    if not parent then return end
    parent:StopMovingOrSizing()
    SaveMoverPoint(parent)
  end)
  local t = df:CreateTexture(nil, "OVERLAY", nil, 6)
  t:SetAllPoints(df)
  t:SetColorTexture(0, 1, 0)
  t:SetAlpha(0.2)
  df.texture = t
  f.dragframe = df
  f.dragFrame = df
  f.dragframe:Hide()
  if not special then
    f:SetClampedToScreen(true)
  end
  f:SetMovable(true)
  SetMoverUserPlaced(f, false)
  RegisterMoverFrame(f, category)

  ApplySavedMoverLayout(f)

  if not cfg.framesLocked then
    func.SetMoverUnlocked(f, true)
  end
end

func.simpleDragFunc = function(f)
  f:SetHitRectInsets(-15, -15, -15, -15)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  SetMoverUserPlaced(f, false)

  if not f.defaultPoint and f.GetPoint then
    local a1, af, a2, x, y = f:GetPoint()
    if af and af.GetName then
      af = af:GetName()
    end
    f.defaultPoint = { a1 = a1, af = af, a2 = a2, x = x, y = y }
  end
  if not f.defaultScale and f.GetScale then
    f.defaultScale = NormalizeMoverScale(f:GetScale()) or 1
  end

  RegisterMoverFrame(f, ResolveMoverCategoryHint(f))
  ApplySavedMoverLayout(f, { size = false })

  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(s) s:StartMoving() end)
  f:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    SaveMoverPoint(s)
  end)
end
