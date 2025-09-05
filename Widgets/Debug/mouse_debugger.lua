function widget:GetInfo()
    return {
        name      = "Mouse Button Event Logger",
        desc      = "Logs mouse press and release events",
        author    = "ChatGPT",
        date      = "2025-06-05",
        license   = "MIT",
        layer     = 0,
        enabled   = true
    }
end

local buttonNames = {
    [1] = "Left Click",
    [2] = "Middle Click",
    [3] = "Right Click",
    [4] = "Mouse 4 (Back)",
    [5] = "Mouse 5 (Forward)",
    [6] = "Mouse 6",
    [7] = "Mouse 7",
    [8] = "Mouse 8",
    [9] = "Mouse 9",
    [10] = "Mouse 10",
}

function widget:MousePress(x, y, button)
    Spring.Echo("[MouseLogger] PRESSED Button " .. button .. " (" .. (buttonNames[button] or "Unknown") .. ")")
    return false -- Let other widgets handle this too
end

function widget:MouseRelease(x, y, button)
    Spring.Echo("[MouseLogger] RELEASED Button " .. button .. " (" .. (buttonNames[button] or "Unknown") .. ")")
    return false
end
