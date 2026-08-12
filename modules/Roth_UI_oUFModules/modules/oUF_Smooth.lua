
local _, ns = ...
local oUF = _G.oUF
if not oUF then return end

-- Midnight/12.x: some values passed into StatusBars can be "secret" (protected in combat).
-- Never compare/arith on secrets; when we detect one, bypass smoothing and set the value directly.
local IsSecretValue = (ns and ns.safety and ns.safety.IsSecret) or function(v)
  local fn = _G.issecretvalue or _G.IsSecretValue
  return type(fn) == "function" and fn(v) or false
end

local smoothing = {}
local smoothingCount = 0
local updater = CreateFrame("Frame")
local updaterShown = false

local function UpdateTickerState()
  local shouldShow = smoothingCount > 0
  if shouldShow == updaterShown then
    return
  end
  updaterShown = shouldShow
  if shouldShow then
    updater:Show()
  else
    updater:Hide()
  end
end

local function SetSmoothingTarget(bar, value)
  local hadValue = smoothing[bar] ~= nil
  if value == nil then
    if hadValue then
      smoothing[bar] = nil
      smoothingCount = smoothingCount - 1
      UpdateTickerState()
    end
    return
  end
  smoothing[bar] = value
  if not hadValue then
    smoothingCount = smoothingCount + 1
    UpdateTickerState()
  end
end

local function Smooth(self, value)
  if not self.SetValue_ then
    return
  end
  local cur = self:GetValue()
  if IsSecretValue(value) or IsSecretValue(cur) then
    -- Bypass smoothing for secret values.
    self:SetValue_(value)
    SetSmoothingTarget(self, nil)
    return
  end
  if type(value) ~= "number" or type(cur) ~= "number" then
    self:SetValue_(value)
    SetSmoothingTarget(self, nil)
    return
  end
  if value ~= cur or value == 0 then
    SetSmoothingTarget(self, value)
  else
    SetSmoothingTarget(self, nil)
  end
end

local function SmoothBar(self, bar)
  if not bar or bar.__rothSmoothWrapped then
    return
  end
  bar.SetValue_ = bar.SetValue
  bar.SetValue = Smooth
  bar.__rothSmoothWrapped = true
end

local function hook(frame)
  frame.SmoothBar = SmoothBar
  if frame.Health and frame.Health.Smooth then
    frame:SmoothBar(frame.Health)
  end
  if frame.Power and frame.Power.Smooth then
    frame:SmoothBar(frame.Power)
  end
  if frame.TotalAbsorb and frame.TotalAbsorb.Smooth then
    frame:SmoothBar(frame.TotalAbsorb)
  end
end

for i, frame in ipairs(oUF.objects) do hook(frame) end
oUF:RegisterInitCallback(hook)

local max, abs = math.max, math.abs
local lastUpdate, div, new, cur = 0, 15, 0, 0
updater:SetScript("OnUpdate", function(_, elapsed)
  if smoothingCount <= 0 then
    UpdateTickerState()
    return
  end
  lastUpdate = lastUpdate + elapsed
  if lastUpdate > 1 then
    local fps = GetFramerate and GetFramerate() or 0
    if type(fps) ~= "number" or fps <= 0 then
      div = 15
    else
      div = max(1, 15 * fps / 100)
    end
    lastUpdate = 0
  end
  local bar, value = next(smoothing)
  while bar do
    if not (bar and bar.SetValue_ and bar.GetValue) then
      SetSmoothingTarget(bar, nil)
    else
      cur = bar:GetValue()
      -- Safety: if either side becomes secret, stop smoothing and snap to the target.
      if IsSecretValue(cur) or IsSecretValue(value) then
        bar:SetValue_(value)
        SetSmoothingTarget(bar, nil)
      elseif type(cur) ~= "number" or type(value) ~= "number" then
        bar:SetValue_(value)
        SetSmoothingTarget(bar, nil)
      else
        -- At a rate of 100 fps the divisor should be 15.
        new = cur + (value - cur) / div
        bar:SetValue_(new)
        local threshold = max(1, abs(value) * 0.001)
        if cur == value or abs(cur - value) < threshold then
          bar:SetValue_(value)
          SetSmoothingTarget(bar, nil)
        end
      end
    end
    bar, value = next(smoothing, bar)
  end
end)

updater:Hide()
