-- rLib: snap guides (crosshair visual feedback)
-- Adapted from FeelsGoodUI Movers.lua for Roth_UI

local A, L = ...

-----------------------------
-- Config
-----------------------------

local SNAP_THRESHOLD = 8
local GUIDE_COLOR_R, GUIDE_COLOR_G, GUIDE_COLOR_B = 0, 0.8, 1
local GUIDE_ALPHA = 0.65
local GRID_GUIDE_R, GRID_GUIDE_G, GRID_GUIDE_B = 0.2, 1, 0.35
local GRID_GUIDE_ALPHA = 0.40

-----------------------------
-- State
-----------------------------

local guides = nil -- lazy created { frame, v, h, m }

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

local function Clamp(v, minV, maxV)
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

local function RoundToStep(v, step)
    if not step or step <= 0 then return v end
    return math.floor(v / step + 0.5) * step
end

-----------------------------
-- Guides frame (lazy create)
-----------------------------

local function EnsureGuides()
    if guides then return guides end

    local f = CreateFrame("Frame", nil, UIParent)
    f:SetAllPoints(UIParent)
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(5)
    f:Hide()

    local v = f:CreateTexture(nil, "OVERLAY")
    v:SetColorTexture(GUIDE_COLOR_R, GUIDE_COLOR_G, GUIDE_COLOR_B, GUIDE_ALPHA)
    v:SetWidth(2)
    v:Hide()

    local h = f:CreateTexture(nil, "OVERLAY")
    h:SetColorTexture(GUIDE_COLOR_R, GUIDE_COLOR_G, GUIDE_COLOR_B, GUIDE_ALPHA)
    h:SetHeight(2)
    h:Hide()

    local m = f:CreateTexture(nil, "OVERLAY")
    m:SetColorTexture(GUIDE_COLOR_R, GUIDE_COLOR_G, GUIDE_COLOR_B, 0.85)
    m:SetSize(6, 6)
    m:Hide()

    guides = { frame = f, v = v, h = h, m = m }
    return guides
end

-----------------------------
-- Show / Hide guides
-----------------------------

function rLib:ShowGuides(xAbs, yAbs, style)
    local g = EnsureGuides()
    local W, H = UIWH()
    if W <= 0 or H <= 0 then return end

    local r, gg, b, a = GUIDE_COLOR_R, GUIDE_COLOR_G, GUIDE_COLOR_B, GUIDE_ALPHA
    local thickness = 2
    if style == "grid" then
        r, gg, b, a = GRID_GUIDE_R, GRID_GUIDE_G, GRID_GUIDE_B, GRID_GUIDE_ALPHA
        thickness = 1
    end

    g.v:SetColorTexture(r, gg, b, a)
    g.h:SetColorTexture(r, gg, b, a)
    g.v:SetWidth(thickness)
    g.h:SetHeight(thickness)
    if g.m then
        g.m:SetColorTexture(r, gg, b, math.min(1, a + 0.20))
        g.m:SetSize(6 + thickness, 6 + thickness)
    end

    g.frame:Show()

    if type(xAbs) == "number" then
        g.v:ClearAllPoints()
        g.v:SetPoint("TOPLEFT", g.frame, "TOPLEFT", xAbs, 0)
        g.v:SetPoint("BOTTOMLEFT", g.frame, "BOTTOMLEFT", xAbs, 0)
        g.v:Show()
    else
        g.v:Hide()
    end

    if type(yAbs) == "number" then
        g.h:ClearAllPoints()
        g.h:SetPoint("BOTTOMLEFT", g.frame, "BOTTOMLEFT", 0, yAbs)
        g.h:SetPoint("BOTTOMRIGHT", g.frame, "BOTTOMRIGHT", 0, yAbs)
        g.h:Show()
    else
        g.h:Hide()
    end

    if g.m then
        if type(xAbs) == "number" and type(yAbs) == "number" then
            g.m:ClearAllPoints()
            g.m:SetPoint("CENTER", g.frame, "BOTTOMLEFT", xAbs, yAbs)
            g.m:Show()
        else
            g.m:Hide()
        end
    end
end

function rLib:HideGuides()
    if not guides then return end
    if guides.v then guides.v:Hide() end
    if guides.h then guides.h:Hide() end
    if guides.m then guides.m:Hide() end
    if guides.frame then guides.frame:Hide() end
end

-----------------------------
-- Snap engine
-----------------------------

-- Build snap targets from screen edges + grid + other visible drag frames.
function rLib:BuildSnapTargets(dragFrameList, activeFrame)
    local W, H = UIWH()
    local xt, yt = {}, {}

    if W <= 0 or H <= 0 then return xt, yt end

    -- Screen anchors (edges + center)
    xt[#xt + 1] = { pos = 0 }
    xt[#xt + 1] = { pos = W * 0.5 }
    xt[#xt + 1] = { pos = W }

    yt[#yt + 1] = { pos = 0 }
    yt[#yt + 1] = { pos = H * 0.5 }
    yt[#yt + 1] = { pos = H }

    -- Other visible frames as snap targets
    if dragFrameList then
        for _, fr in ipairs(dragFrameList) do
            if fr and fr ~= activeFrame and fr.IsShown and fr:IsShown() and fr.GetRect then
                local l, b, w, h = fr:GetRect()
                if type(l) == "number" and type(b) == "number" and type(w) == "number" and type(h) == "number" then
                    local r = l + w
                    local t = b + h
                    xt[#xt + 1] = { pos = l }
                    xt[#xt + 1] = { pos = r }
                    xt[#xt + 1] = { pos = (l + r) * 0.5 }
                    yt[#yt + 1] = { pos = b }
                    yt[#yt + 1] = { pos = t }
                    yt[#yt + 1] = { pos = (b + t) * 0.5 }
                end
            end
        end
    end

    return xt, yt
end

-- Apply snap offsets to a CENTER-relative position.
-- Returns snapped (x, y) and guide positions.
function rLib:SnapOffsets(x, y, fw, fh, xt, yt)
    local W, H = UIWH()
    if W <= 0 or H <= 0 then
        rLib:HideGuides()
        return x, y
    end

    -- Convert center-relative to absolute
    local absCx = (W * 0.5) + x
    local absCy = (H * 0.5) + y

    local left = absCx - (fw * 0.5)
    local right = absCx + (fw * 0.5)
    local bottom = absCy - (fh * 0.5)
    local top = absCy + (fh * 0.5)

    local bestDX, bestDY = 0, 0
    local guideX, guideY = nil, nil
    local th = SNAP_THRESHOLD

    -- X snap: left/right/center edges → targets
    local bestAbs = th + 1
    for _, t in ipairs(xt) do
        local tx = t.pos
        if type(tx) == "number" then
            for _, edge in ipairs({ left, right, absCx }) do
                local d = tx - edge
                local a = math.abs(d)
                if a < bestAbs and a <= th then
                    bestAbs = a; bestDX = d; guideX = tx
                end
            end
        end
    end

    -- Y snap: bottom/top/center edges → targets
    bestAbs = th + 1
    for _, t in ipairs(yt) do
        local ty = t.pos
        if type(ty) == "number" then
            for _, edge in ipairs({ bottom, top, absCy }) do
                local d = ty - edge
                local a = math.abs(d)
                if a < bestAbs and a <= th then
                    bestAbs = a; bestDY = d; guideY = ty
                end
            end
        end
    end

    local snapped = (bestDX ~= 0) or (bestDY ~= 0)
    local guideStyle = snapped and "target" or nil

    x = x + bestDX
    y = y + bestDY

    -- If not snapped to explicit targets, try grid snap
    if (not snapped) and rLib.GetGridStep then
        local step = rLib:GetGridStep()
        if step and step > 0 then
            local gx = RoundToStep(x, step)
            local gy = RoundToStep(y, step)
            local snappedGX = (gx ~= x)
            local snappedGY = (gy ~= y)
            x, y = gx, gy
            if snappedGX then guideX = (W * 0.5) + x end
            if snappedGY then guideY = (H * 0.5) + y end
            if snappedGX or snappedGY then
                guideStyle = "grid"
            end
        end
    end

    -- Clamp within screen
    local minX = (fw * 0.5) - (W * 0.5)
    local maxX = (W - (fw * 0.5)) - (W * 0.5)
    local minY = (fh * 0.5) - (H * 0.5)
    local maxY = (H - (fh * 0.5)) - (H * 0.5)
    x = Clamp(x, minX, maxX)
    y = Clamp(y, minY, maxY)

    if guideStyle then
        rLib:ShowGuides(guideX, guideY, guideStyle)
    else
        rLib:HideGuides()
    end

    return x, y
end

-- Expose snap threshold for external use
function rLib:GetSnapThreshold()
    return SNAP_THRESHOLD
end
