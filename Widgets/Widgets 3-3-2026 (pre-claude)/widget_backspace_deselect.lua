function widget:GetInfo()
    return {
        name    = "Backspace Deselect",
        desc    = "Deselects all units when backspace is pressed",
        author  = "ChatGPT",
        date    = "2025-06-04",
        license = "GNU GPL v2",
        layer   = 0,
        enabled = true
    }
end

function widget:KeyPress(key, mods, isRepeat)
    if key == Spring.GetKeyCode("backspace") then
        Spring.SelectUnitArray({})
        Spring.Echo("[BackspaceDeselect] Deselected all units")
        return true
    end
end
