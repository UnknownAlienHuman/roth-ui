local function fail(message)
  error(message, 2)
end

local function expect(condition, message)
  if not condition then fail(message) end
end

_G.issecretvalue = function() return false end
_G.canaccessvalue = function() return true end
_G.canaccessallvalues = function() return true end
_G.STANDARD_TEXT_FONT = "font"
_G.Enum = { ForbiddenAspect = { SetTexture = 2048 } }

local inCombat = false
_G.InCombatLockdown = function() return inCombat end

local createdFrames = {}
_G.CreateFrame = function()
  local frame = { events = {}, scripts = {} }
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:UnregisterEvent(event) self.events[event] = nil end
  function frame:SetScript(script, callback) self.scripts[script] = callback end
  createdFrames[#createdFrames + 1] = frame
  return frame
end

local hookedOnLoad
_G.ActionBarActionButtonMixin = { OnLoad = function() end }
_G.hooksecurefunc = function(owner, methodName, callback)
  expect(owner == _G.ActionBarActionButtonMixin and methodName == "OnLoad",
    "unexpected secure hook target")
  hookedOnLoad = callback
end

local function AddSecurityMethods(region, forbiddenTexture)
  function region:HasAccessConstraints() return false end
  function region:IsForbidden() return false end
  function region:HasAnyForbiddenAspects(aspect)
    return forbiddenTexture == true and aspect == _G.Enum.ForbiddenAspect.SetTexture
  end
  return region
end

local function NewRegion(options)
  options = options or {}
  local region = AddSecurityMethods({ points = {}, setTextureCalls = 0 }, options.forbiddenTexture)
  function region:ClearAllPoints() self.cleared = true end
  function region:SetPoint(...) self.points[#self.points + 1] = { ... } end
  function region:SetTexture(value) self.setTextureCalls = self.setTextureCalls + 1; self.texture = value end
  function region:SetVertexColor(...) self.vertexColor = { ... } end
  function region:SetTexCoord(...) self.texCoord = { ... } end
  function region:SetFont(...) self.font = { ... } end
  function region:SetAlpha(value) self.alpha = value end
  function region:SetSwipeColor(...) self.swipe = { ... } end
  function region:Hide() self.hidden = true end
  return region
end

local function NewButton(name, options)
  options = options or {}
  local button = AddSecurityMethods({ name = name, textures = {} }, false)
  button.icon = options.icon or NewRegion()
  button.HotKey = NewRegion()
  button.Name = NewRegion()
  button.Count = NewRegion()
  button.cooldown = NewRegion()
  button.FloatingBG = NewRegion()
  function button:GetName() return self.name end
  function button:CreateTexture()
    local texture = NewRegion({ forbiddenTexture = options.forbidArtworkTexture })
    self.textures[#self.textures + 1] = texture
    return texture
  end
  _G[name .. "FloatingBG"] = button.FloatingBG
  return button
end

local primary = NewButton("ActionButton1")
_G.ActionButton1 = primary

local ns = {
  cfg = {
    font = "font",
    bars = {
      showHotkey = false,
      showMacroName = true,
      showStackCount = true,
      showCooldown = true,
    },
  },
  func = {},
}

assert(loadfile("core/safety.lua"))("Roth_UI", ns)
assert(loadfile("core/safety_aspects.lua"))("Roth_UI", ns)
assert(loadfile("core/action_button_skin.lua"))("Roth_UI", ns)

expect(type(hookedOnLoad) == "function", "action-button OnLoad hook was not installed")
expect(type(ns.RefreshActionButtonSkin) == "function", "refresh API was not published")
expect(#createdFrames == 1, "initial load created unexpected event frames")
expect(createdFrames[1].events.PLAYER_LOGIN == true, "bounded login rescan was not registered")
expect(#primary.textures == 2, "initial skin did not create exactly two artwork regions")
expect(primary.__rothSkinBackground == nil and primary.__rothSkinBorder == nil,
  "Roth metadata leaked onto a Blizzard button")
expect(primary.icon.cleared == true and #primary.icon.points == 2,
  "button icon was not re-anchored")
expect(primary.icon.texCoord[1] == 0.1 and primary.icon.texCoord[4] == 0.9,
  "button icon crop changed")
expect(primary.HotKey.alpha == 0, "hotkey visibility setting was not applied")
expect(primary.Name.alpha == 1, "macro-name visibility setting was not applied")
expect(primary.Count.alpha == 1, "stack-count visibility setting was not applied")
expect(primary.cooldown.swipe[4] == 0.8, "cooldown swipe setting was not applied")
expect(primary.FloatingBG.hidden == true, "floating background was not suppressed")

ns.RefreshActionButtonSkin()
expect(#primary.textures == 2, "refresh duplicated additive artwork")

local inaccessibleIcon = NewRegion()
function inaccessibleIcon:HasAccessConstraints() return true end
function inaccessibleIcon:CanBeAccessedInContext() return false end
local inaccessibleButton = NewButton("ActionButton2", { icon = inaccessibleIcon })
hookedOnLoad(inaccessibleButton)
expect(inaccessibleIcon.texCoord == nil, "inaccessible icon was mutated")

local forbiddenArtwork = NewButton("ActionButton3", { forbidArtworkTexture = true })
hookedOnLoad(forbiddenArtwork)
expect(#forbiddenArtwork.textures == 2, "forbidden artwork probe count changed")
expect(forbiddenArtwork.textures[1].setTextureCalls == 0
    and forbiddenArtwork.textures[2].setTextureCalls == 0,
  "SetTexture ran on a region carrying the SetTexture forbidden aspect")
hookedOnLoad(forbiddenArtwork)
expect(#forbiddenArtwork.textures == 2,
  "failed forbidden artwork attempts leaked blank textures on refresh")

local late = NewButton("ActionButton4")
inCombat = true
hookedOnLoad(late)
expect(#late.textures == 0, "late action button was skinned during combat")
expect(#createdFrames == 2, "combat queue did not create exactly one regen frame")
local regenFrame = createdFrames[2]
expect(regenFrame.events.PLAYER_REGEN_ENABLED == true, "regen event was not registered")

inCombat = false
regenFrame.scripts.OnEvent(regenFrame, "PLAYER_REGEN_ENABLED")
expect(#late.textures == 2, "queued action button was not skinned after combat")
expect(regenFrame.events.PLAYER_REGEN_ENABLED == nil,
  "action-button regen event remained permanently registered")

print("action button safety test: OK")
