
  -----------------------------
  -- INIT
  -----------------------------

  --get the addon namespace
  local addon, ns = ...
  local gcfg = ns.cfg
  if not gcfg then return end

  -----------------------------
  -- FUNCTIONS
  -----------------------------
if not gcfg.embeds.rActionBarStyler then return end
  --cooldown spiral alpha fix

  --SetCooldownSwipeAlpha
  local function SetCooldownSwipeAlpha(self,cooldown,alpha)
    if not (cooldown and cooldown.SetSwipeColor) then
      return
    end
    cooldown:SetSwipeColor(0,0,0,0.8*(alpha or 1))
  end

  local parentHooked = setmetatable({}, { __mode = "k" })
  local parentCooldowns = setmetatable({}, { __mode = "k" })

  local function ApplyParentCooldownAlpha(parent, alpha)
    if not (parent and parent.IsShown and parent:IsShown()) then
      return
    end
    local cooldowns = parentCooldowns[parent]
    if not cooldowns then
      return
    end
    for i = 1, #cooldowns do
      SetCooldownSwipeAlpha(parent, cooldowns[i], alpha)
    end
  end

  local function RegisterParentCooldown(parent, cooldown)
    if not (parent and cooldown) then
      return
    end
    if cooldown.__rABS_AlphaFixRegistered then
      return
    end
    local cooldowns = parentCooldowns[parent]
    if not cooldowns then
      cooldowns = {}
      parentCooldowns[parent] = cooldowns
    end
    cooldowns[#cooldowns + 1] = cooldown
    cooldown.__rABS_AlphaFixRegistered = true

    if not parentHooked[parent] then
      parentHooked[parent] = true
      hooksecurefunc(parent, "SetAlpha", ApplyParentCooldownAlpha)
    end
    SetCooldownSwipeAlpha(parent, cooldown, parent.GetAlpha and parent:GetAlpha() or 1)
  end

  --ApplyButtonCooldownAlphaFix
  local function ApplyButtonCooldownAlphaFix(button)
    if not button then return end
    if not button.cooldown then return end
    local buttonParent = button:GetParent()
    local parent = buttonParent and buttonParent:GetParent() or buttonParent
    if not parent then
      return
    end
    RegisterParentCooldown(parent, button.cooldown)
  end
   
  do
    --style the actionbar buttons
    for i = 1, NUM_ACTIONBAR_BUTTONS do
      ApplyButtonCooldownAlphaFix(_G["ActionButton"..i])
      ApplyButtonCooldownAlphaFix(_G["MultiBarBottomLeftButton"..i])
      ApplyButtonCooldownAlphaFix(_G["MultiBarBottomRightButton"..i])
      ApplyButtonCooldownAlphaFix(_G["MultiBarRightButton"..i])
      ApplyButtonCooldownAlphaFix(_G["MultiBarLeftButton"..i])
    end
    --override buttons
    for i = 1, 6 do
      ApplyButtonCooldownAlphaFix(_G["OverrideActionBarButton"..i])
    end
    --petbar buttons
    for i=1, NUM_PET_ACTION_SLOTS do
      ApplyButtonCooldownAlphaFix(_G["PetActionButton"..i])
    end
    --stancebar buttons
    for i=1, 10 do
      ApplyButtonCooldownAlphaFix(_G["StanceButton"..i])
    end
  end
