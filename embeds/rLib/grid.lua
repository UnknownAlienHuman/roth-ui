-- rLib: grid overlay
-- Adapted from FeelsGoodUI Movers.lua for Roth_UI

local A, L = ...

-----------------------------
-- Config
-----------------------------

local GRID_STEP = 32
local GRID_ALPHA_FAINT = 0.10
local GRID_ALPHA_STRONG = 0.25

-----------------------------
-- State
-----------------------------

local grid = {
    frame = nil,
    textures = {},
    builtW = 0,
    builtH = 0,
    step = 0,
}

-----------------------------
-- Helpers
-----------------------------

local function UIWH()
    local w = UIParent:GetWidth()
    local h = UIParent:GetHeight()
    if type(w) ~= "number" or type(h) ~= "number" then
        return 0, 0
    end
    return w, h
end

-----------------------------
-- Build / rebuild grid
-----------------------------

local function EnsureGridBuilt()
    if not grid.frame then
        local f = CreateFrame("Frame", nil, UIParent)
        f:SetAllPoints(UIParent)
        f:SetFrameStrata("BACKGROUND")
        f:SetFrameLevel(1)
        f:Hide()
        grid.frame = f
    end

    local w, h = UIWH()
    local step = GRID_STEP

    if w <= 0 or h <= 0 then return end
    if grid.builtW == w and grid.builtH == h and grid.step == step then return end

    -- Clear old lines
    for _, t in ipairs(grid.textures) do
        if t and t.Hide then t:Hide() end
    end
    wipe(grid.textures)

    local function LineV(x, alpha)
        local t = grid.frame:CreateTexture(nil, "BACKGROUND")
        t:SetColorTexture(1, 1, 1, alpha)
        t:SetPoint("TOPLEFT", grid.frame, "TOPLEFT", x, 0)
        t:SetPoint("BOTTOMLEFT", grid.frame, "BOTTOMLEFT", x, 0)
        t:SetWidth(1)
        table.insert(grid.textures, t)
    end

    local function LineH(y, alpha)
        local t = grid.frame:CreateTexture(nil, "BACKGROUND")
        t:SetColorTexture(1, 1, 1, alpha)
        t:SetPoint("BOTTOMLEFT", grid.frame, "BOTTOMLEFT", 0, y)
        t:SetPoint("BOTTOMRIGHT", grid.frame, "BOTTOMRIGHT", 0, y)
        t:SetHeight(1)
        table.insert(grid.textures, t)
    end

    -- Regular grid lines
    local x = 0
    while x <= w do
        LineV(x, GRID_ALPHA_FAINT)
        x = x + step
    end

    local y = 0
    while y <= h do
        LineH(y, GRID_ALPHA_FAINT)
        y = y + step
    end

    -- Center cross (stronger)
    LineV(w * 0.5, GRID_ALPHA_STRONG)
    LineH(h * 0.5, GRID_ALPHA_STRONG)

    grid.builtW = w
    grid.builtH = h
    grid.step = step
end

-----------------------------
-- Public API
-----------------------------

function rLib:ShowGrid()
    EnsureGridBuilt()
    if grid.frame then grid.frame:Show() end
end

function rLib:HideGrid()
    if grid.frame then grid.frame:Hide() end
end

function rLib:IsGridVisible()
    return grid.frame and grid.frame:IsShown() or false
end

function rLib:GetGridStep()
    return GRID_STEP
end

-----------------------------
-- Rebuild on resolution change
-----------------------------

local gridEvents = CreateFrame("Frame")
gridEvents:RegisterEvent("DISPLAY_SIZE_CHANGED")
gridEvents:RegisterEvent("UI_SCALE_CHANGED")
gridEvents:SetScript("OnEvent", function()
    if rLib:IsGridVisible() then
        EnsureGridBuilt()
    end
end)
