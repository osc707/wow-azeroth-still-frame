-- Azeroth Stillframe: composition guides drawn outside UIParent.
-- Geometry is in normalized screen coordinates (origin: top-left).
local canvas = CreateFrame("Frame", "AzerothStillframeOverlays", WorldFrame)
canvas:SetAllPoints(WorldFrame)
canvas:SetFrameStrata("TOOLTIP")
canvas:SetFrameLevel(100)
canvas:EnableMouse(false)
canvas:Hide()

local stroke = {}
local count = 0
local mode = "thirds"
local orientation = 0
local opacity = 0.45

local function segment(x1, y1, x2, y2)
    local w, h = canvas:GetSize()
    if w <= 0 or h <= 0 then return end
    x1, x2, y1, y2 = x1 * w, x2 * w, y1 * h, y2 * h
    count = count + 1
    local line = stroke[count]
    if not line then
        line = canvas:CreateLine(nil, "OVERLAY")
        stroke[count] = line
    end
    line:SetColorTexture(1, 1, 1, opacity)
    line:SetThickness(1)
    line:SetStartPoint("TOPLEFT", canvas, x1, -y1)
    line:SetEndPoint("TOPLEFT", canvas, x2, -y2)
    line:Show()
end

local function oriented(x, y)
    -- Four orientations for asymmetric guides: original, horizontal flip,
    -- vertical flip, and both. (Equivalent to 180 degree rotation.)
    if orientation == 1 or orientation == 3 then x = 1 - x end
    if orientation == 2 or orientation == 3 then y = 1 - y end
    return x, y
end

local function add(x1, y1, x2, y2)
    x1, y1 = oriented(x1, y1)
    x2, y2 = oriented(x2, y2)
    segment(x1, y1, x2, y2)
end

local function draw()
    local w, h = canvas:GetSize()
    if w <= 0 or h <= 0 then return end
    count = 0
    if mode == "thirds" then
        for i = 1, 2 do
            local f = i / 3
            segment(f, 0, f, 1)
            segment(0, f, 1, f)
        end
    elseif mode == "phi" then
        local a = 1 / (1 + 1.61803398875)
        segment(a, 0, a, 1)
        segment(1-a, 0, 1-a, 1)
        segment(0, a, 1, a)
        segment(0, 1-a, 1, 1-a)
    elseif mode == "triangle" then
        -- Diagonal plus the perpendicular from each of the other corners.
        -- Projection uses pixel dimensions so lines are truly perpendicular
        -- on rectangular / ultrawide screens.
        local t = (w*w) / (w*w + h*h)
        add(0, 0, 1, 1)
        add(1, 0, t, t)
        add(0, 1, 1-t, 1-t)
    elseif mode == "spiral" then
        -- Frame-sized logarithmic golden spiral, winding inward toward a
        -- golden-ratio focal point.  Two complete turns provide a natural
        -- composition guide while retaining recognizable curvature.
        --
        -- Normalize to the viewport so the entire guide remains visible on
        -- widescreen displays.  The aspect ratio stretches its presentation
        -- slightly, as composition overlays commonly do to fill the frame.
        local phi = 1.61803398875
        local cx, cy = 1 / phi, 0.46
        local outerX, outerY = 0.56, 0.78
        local growth = math.log(phi) / (math.pi / 2)
        local previousX, previousY
        for i = 0, 192 do
            local theta = -4 * math.pi + i * (4 * math.pi / 192)
            local radius = math.exp(growth * theta)
            local angle = theta + math.pi
            local x = cx + outerX * radius * math.cos(angle)
            local y = cy + outerY * radius * math.sin(angle)
            if previousX then
                add(previousX, previousY, x, y)
            end
            previousX, previousY = x, y
        end
    end
    for i = count+1, #stroke do stroke[i]:Hide() end
end

canvas:SetScript("OnSizeChanged", draw)
AzerothStillframeOverlayAPI = {
    Show = function() draw(); if mode ~= "off" then canvas:Show() else canvas:Hide() end end,
    Hide = function() canvas:Hide() end,
    Configure = function(newMode, newOrientation)
        mode = newMode or mode
        orientation = newOrientation or 0
        draw()
        if mode == "off" then canvas:Hide() end
    end,
}
