local M = {}

-- Draw a button with specific styling applied automatically
function M.drawStyledButton(imgui, label, size, colors)
    if colors.button then imgui.PushStyleColor(imgui.Col.Button, colors.button) end
    if colors.hovered then imgui.PushStyleColor(imgui.Col.ButtonHovered, colors.hovered) end
    if colors.active then imgui.PushStyleColor(imgui.Col.ButtonActive, colors.active) end
    if colors.text then imgui.PushStyleColor(imgui.Col.Text, colors.text) end
    
    local numColors = (colors.button and 1 or 0) + (colors.hovered and 1 or 0) + 
                      (colors.active and 1 or 0) + (colors.text and 1 or 0)
                      
    local clicked = imgui.Button(label, size)
    
    if numColors > 0 then
        imgui.PopStyleColor(numColors)
    end
    
    return clicked
end

-- Center a dialog of given width and height
function M.centerDialog(imgui, scaled, width, height)
    local displaySize = imgui.GetIO().DisplaySize
    local windowSize = imgui.ImVec2(scaled(width), scaled(height))
    imgui.SetNextWindowPos(
        imgui.ImVec2((displaySize.x - windowSize.x) / 2, (displaySize.y - windowSize.y) / 2),
        imgui.Cond.Always,
        imgui.ImVec2(0, 0)
    )
    imgui.SetNextWindowSize(windowSize, imgui.Cond.Always)
end

-- Temporarily apply styles, execute a function, and revert
function M.withStyle(imgui, colors, vars, func)
    local colorCount = 0
    if colors then
        for col, val in pairs(colors) do
            imgui.PushStyleColor(col, val)
            colorCount = colorCount + 1
        end
    end
    
    local varCount = 0
    if vars then
        for var, val in pairs(vars) do
            imgui.PushStyleVar(var, val)
            varCount = varCount + 1
        end
    end
    
    func()
    
    if varCount > 0 then imgui.PopStyleVar(varCount) end
    if colorCount > 0 then imgui.PopStyleColor(colorCount) end
end

return M
