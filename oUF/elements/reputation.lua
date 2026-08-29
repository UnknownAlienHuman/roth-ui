local addonName, ns = ...

local oUF = (ns and (ns.oUF or _G.oUF)) or _G.oUF
if not oUF then
  return
end

local type = type
local math_min = math.min
local UnitHasVehicleUI = UnitHasVehicleUI
local IsSecretValue = (ns and ns.safety and ns.safety.IsSecret) or function(value)
  return type(_G.issecretvalue) == "function" and _G.issecretvalue(value) or false
end

local function PlayerHasVehicleUI()
  if type(UnitHasVehicleUI) ~= "function" then return false end
  local value = UnitHasVehicleUI("player")
  return not IsSecretValue(value) and value == true
end
local C_Reputation = C_Reputation
local C_MajorFactions = C_MajorFactions
local C_GossipInfo = C_GossipInfo

local function IsEnabledInConfig(self)
  local frameCfg = self and self.cfg
  local repCfg = frameCfg and frameCfg.repbar
  if type(repCfg) == "table" then
    return repCfg.show ~= false
  end
  local globalCfg = ns and ns.cfg
  local units = globalCfg and globalCfg.units
  local playerCfg = units and units.player
  local cfg = playerCfg and playerCfg.repbar
  if type(cfg) == "table" then
    return cfg.show ~= false
  end
  return true
end

local function RefreshActionBarArtwork(self)
  if ns and type(ns.RefreshActionBarArtwork) == "function" then
    ns.RefreshActionBarArtwork()
    return
  end
  local artwork = self and self.ActionBarBackground
  local refresh = artwork and artwork.RefreshActionBarArtwork
  if type(refresh) == "function" then
    refresh(artwork)
  end
end

local function SetVisibility(self, element, shouldShow)
  local previous = element.__rothActive == true
  if shouldShow then
    element.__rothActive = true
    element:Show()
  else
    element.__rothActive = false
    element:Hide()
  end

  if previous ~= shouldShow and type(element.PostVisibility) == "function" then
    element:PostVisibility(shouldShow)
  end

  return previous ~= shouldShow
end

local function ResolveStandingColor(standing)
  local colors = _G.FACTION_BAR_COLORS
  local color = colors and colors[standing]
  if type(color) ~= "table" then
    return 0, 0.7, 0
  end
  return color.r or 0, color.g or 0.7, color.b or 0
end

local function GetWatchedFactionProgressInfo()
  local watchedFaction = (C_Reputation and C_Reputation.GetWatchedFactionData and C_Reputation.GetWatchedFactionData()) or nil
  if not watchedFaction or watchedFaction.factionID == 0 then
    return nil
  end

  local factionID = watchedFaction.factionID
  local minimum = tonumber(watchedFaction.currentReactionThreshold) or 0
  local maximum = tonumber(watchedFaction.nextReactionThreshold) or 0
  local current = tonumber(watchedFaction.currentStanding) or 0
  local standing = tonumber(watchedFaction.reaction) or 5
  local maxLevel = _G.MAX_REPUTATION_REACTION
  local level = standing
  local overrideUseBlueBar = false
  local friendshipID = 0

  if C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
    local friendshipInfo = C_GossipInfo.GetFriendshipReputation(factionID)
    friendshipID = tonumber(friendshipInfo and friendshipInfo.friendshipFactionID) or 0
  end

  if C_Reputation and C_Reputation.IsFactionParagonForCurrentPlayer and C_Reputation.IsFactionParagonForCurrentPlayer(factionID) then
    maxLevel = nil
    if C_Reputation.GetFactionParagonInfo then
      local currentValue, threshold, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionID)
      minimum = 0
      maximum = tonumber(threshold) or 0
      if type(currentValue) == "number" and type(threshold) == "number" and threshold > 0 then
        current = currentValue % threshold
      end
      if hasRewardPending and type(threshold) == "number" and threshold > 0 then
        current = current + threshold
      end
    end
    if C_Reputation.IsMajorFaction and C_Reputation.IsMajorFaction(factionID) then
      overrideUseBlueBar = true
    end
  elseif C_Reputation and C_Reputation.IsMajorFaction and C_Reputation.IsMajorFaction(factionID) then
    overrideUseBlueBar = true
    if C_MajorFactions and C_MajorFactions.GetMajorFactionData then
      local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID)
      if type(majorFactionData) == "table" then
        minimum = 0
        maximum = tonumber(majorFactionData.renownLevelThreshold) or maximum
        level = tonumber(majorFactionData.renownLevel) or level
      end
    end
    if C_MajorFactions and C_MajorFactions.GetRenownLevels then
      local renownLevels = C_MajorFactions.GetRenownLevels(factionID)
      if type(renownLevels) == "table" and #renownLevels > 0 then
        local lastLevel = renownLevels[#renownLevels]
        maxLevel = tonumber(lastLevel and lastLevel.level) or maxLevel
      end
    end
  elseif friendshipID > 0 then
    standing = 5
    if C_GossipInfo and C_GossipInfo.GetFriendshipReputationRanks then
      local rankInfo = C_GossipInfo.GetFriendshipReputationRanks(factionID)
      if type(rankInfo) == "table" then
        level = tonumber(rankInfo.currentLevel) or level
        maxLevel = tonumber(rankInfo.maxLevel) or maxLevel
      end
    end
    if C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
      local reputationInfo = C_GossipInfo.GetFriendshipReputation(factionID)
      if type(reputationInfo) == "table" then
        if reputationInfo.nextThreshold then
          minimum = tonumber(reputationInfo.reactionThreshold) or minimum
          maximum = tonumber(reputationInfo.nextThreshold) or maximum
          current = tonumber(reputationInfo.standing) or current
        else
          minimum = 0
          maximum = 1
          current = 1
        end
      end
    end
  end

  local isCapped = (type(level) == "number" and type(maxLevel) == "number" and level >= maxLevel) or false
  local maxBar = maximum - minimum
  local value = current - minimum
  if isCapped and maxBar == 0 then
    maxBar = 1
    value = 1
  end
  if maxBar <= 0 then
    maxBar = 1
  end
  if value < 0 then
    value = 0
  elseif value > maxBar then
    value = maxBar
  end

  return {
    factionID = factionID,
    name = watchedFaction.name,
    standing = standing,
    level = level,
    maxLevel = maxLevel,
    currentReactionThreshold = minimum,
    nextReactionThreshold = maximum,
    currentStanding = current,
    minimum = 0,
    maximum = maxBar,
    value = value,
    isCapped = isCapped,
    overrideUseBlueBar = overrideUseBlueBar,
    watchedFactionData = watchedFaction,
  }
end

ns.GetWatchedFactionProgressInfo = GetWatchedFactionProgressInfo

local function Update(self, event, unit)
  if unit and unit ~= self.__unit then
    return
  end

  local reputation = self.Reputation
  if not reputation then
    return
  end

  if type(reputation.PreUpdate) == "function" then
    reputation:PreUpdate(self.__unit)
  end

  local watchedFaction = GetWatchedFactionProgressInfo()
  local shouldShow = IsEnabledInConfig(self)
    and watchedFaction ~= nil
    and not PlayerHasVehicleUI()

  local visibilityChanged = SetVisibility(self, reputation, shouldShow)
  if not shouldShow then
    RefreshActionBarArtwork(self)
    return
  end

  reputation:SetMinMaxValues(0, watchedFaction.maximum)
  reputation:SetValue(watchedFaction.value)

  if reputation.colorStanding ~= false then
    local r, g, b = ResolveStandingColor(watchedFaction.standing)
    reputation:SetStatusBarColor(r, g, b)
    if reputation.bg and reputation.bg.SetVertexColor then
      reputation.bg:SetVertexColor(r, g, b, 0.3)
    end
  end

  if type(reputation.PostUpdate) == "function" then
    reputation:PostUpdate(
      self.__unit,
      watchedFaction.name,
      watchedFaction.standing,
      watchedFaction.currentReactionThreshold,
      watchedFaction.nextReactionThreshold,
      watchedFaction.currentStanding,
      watchedFaction.watchedFactionData
    )
  end

  if visibilityChanged or event ~= "ForceUpdate" then
    RefreshActionBarArtwork(self)
  end
end

local function Path(self, ...)
  return (self.Reputation.Override or Update)(self, ...)
end

local function ForceUpdate(element)
  return Path(element.__owner, "ForceUpdate", element.__owner.__unit)
end

local function Enable(self, unit)
  local reputation = self.Reputation
  if not reputation or unit ~= "player" then
    return
  end

  reputation.__owner = self
  reputation.ForceUpdate = ForceUpdate

  if reputation:IsObjectType("StatusBar") and not reputation:GetStatusBarTexture() then
    reputation:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
  end

  self:RegisterEvent("PLAYER_ENTERING_WORLD", Path, true)
  self:RegisterEvent("UPDATE_FACTION", Path, true)
  self:RegisterEvent("UNIT_ENTERED_VEHICLE", Path)
  self:RegisterEvent("UNIT_EXITED_VEHICLE", Path)

  return true
end

local function Disable(self)
  local reputation = self.Reputation
  if not reputation then
    return
  end

  reputation.__rothActive = false
  reputation:Hide()

  self:UnregisterEvent("PLAYER_ENTERING_WORLD", Path)
  self:UnregisterEvent("UPDATE_FACTION", Path)
  self:UnregisterEvent("UNIT_ENTERED_VEHICLE", Path)
  self:UnregisterEvent("UNIT_EXITED_VEHICLE", Path)
end

oUF:AddElement("Reputation", Path, Enable, Disable)
