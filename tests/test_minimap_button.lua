local function fail(message)
  error(message, 2)
end

local function expect(condition, message)
  if not condition then fail(message) end
end

local function NewTexture()
  local texture = {}
  function texture:SetPoint(...) self.lastPoint = { ... } end
  function texture:SetAllPoints(...) self.allPoints = { ... } end
  function texture:SetTexture(value) self.texture = value end
  function texture:SetTexCoord(...) self.texCoord = { ... } end
  function texture:SetBlendMode(value) self.blendMode = value end
  return texture
end

local button = { scripts = {}, textures = {} }
function button:SetSize(width, height) self.width, self.height = width, height end
function button:SetPoint(...) self.point = { ... } end
function button:SetFrameStrata(value) self.strata = value end
function button:SetFrameLevel(value) self.level = value end
function button:RegisterForClicks(...) self.clicks = { ... } end
function button:CreateTexture()
  local texture = NewTexture()
  self.textures[#self.textures + 1] = texture
  return texture
end
function button:SetScript(script, callback) self.scripts[script] = callback end

local minimap = {}
function minimap:GetFrameLevel() return 4 end
_G.Minimap = minimap

local createCount = 0
_G.CreateFrame = function(frameType, name, parent)
  createCount = createCount + 1
  expect(frameType == "Button", "minimap owner created a non-button frame")
  expect(name == "Roth_UIMinimapButton", "minimap button name changed")
  expect(parent == minimap, "minimap button parent changed")
  return button
end

local inCombat = false
_G.InCombatLockdown = function() return inCombat end

local opened = 0
local help = 0
_G.SlashCmdList = {
  roth = function(command)
    expect(command == "help", "right-click did not request help")
    help = help + 1
  end,
}

local tooltip = { lines = {}, shown = false }
function tooltip:SetOwner(owner, anchor) self.owner, self.anchor = owner, anchor end
function tooltip:ClearLines() self.lines = {} end
function tooltip:AddLine(text) self.lines[#self.lines + 1] = text end
function tooltip:Show() self.shown = true end
function tooltip:Hide() self.shown = false end
_G.GameTooltip = tooltip

local ns = {
  settingsActions = {
    OpenOptions = function()
      opened = opened + 1
      return true
    end,
  },
}

assert(loadfile("core/minimap_button.lua"))("Roth_UI", ns)
expect(createCount == 1, "minimap module created unexpected frames")
expect(ns.MinimapButton == button, "minimap button was not published")
expect(button.width == 31 and button.height == 31, "minimap button size changed")
expect(button.level == 12, "minimap button level was not derived from Minimap")
expect(type(button.scripts.OnClick) == "function", "minimap click handler missing")
expect(type(button.scripts.OnEnter) == "function" and type(button.scripts.OnLeave) == "function",
  "minimap tooltip handlers missing")

button.scripts.OnClick(button, "LeftButton")
expect(opened == 1, "left-click did not open settings")

inCombat = true
button.scripts.OnClick(button, "LeftButton")
expect(opened == 1, "settings opened during combat")
inCombat = false

button.scripts.OnClick(button, "RightButton")
expect(help == 1, "right-click did not route to /roth help")

button.scripts.OnEnter(button)
expect(tooltip.shown == true and tooltip.owner == button, "tooltip did not open")
button.scripts.OnLeave(button)
expect(tooltip.shown == false, "tooltip did not close")

print("minimap button test: OK")
