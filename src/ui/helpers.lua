local M = {}


local function drawLineIcon(imgui, drawList, icon, center, color, size)
    local scale = math.max(0.75, math.min(size.x, size.y) / 28)
    local thickness = math.max(1.5, 1.8 * scale)
    local function point(x, y)
        return imgui.ImVec2(center.x + x * scale, center.y + y * scale)
    end

    if icon == "plus" then
        drawList:AddLine(point(-5, 0), point(5, 0), color, thickness)
        drawList:AddLine(point(0, -5), point(0, 5), color, thickness)
    elseif icon == "close" then
        drawList:AddLine(point(-4.5, -4.5), point(4.5, 4.5), color, thickness)
        drawList:AddLine(point(4.5, -4.5), point(-4.5, 4.5), color, thickness)
    elseif icon == "back" then
        drawList:AddLine(point(-5, 0), point(4, 0), color, thickness)
        drawList:AddLine(point(-5, 0), point(-1, -4), color, thickness)
        drawList:AddLine(point(-5, 0), point(-1, 4), color, thickness)
    elseif icon == "more" then
        for x = -5, 5, 5 do
            drawList:AddCircleFilled(point(x, 0), 1.4 * scale, color)
        end
    elseif icon == "contrast" then
        -- Half-filled circle: visually distinct from the radial settings gear.
        drawList:AddCircle(point(0, 0), 7 * scale, color, 20, thickness)
        drawList:AddLine(point(-5, -4.5), point(-5, 4.5), color, 2.2 * scale)
        drawList:AddLine(point(-3, -6.1), point(-3, 6.1), color, 2.2 * scale)
        drawList:AddLine(point(-1, -6.8), point(-1, 6.8), color, 2.2 * scale)
    elseif icon == "settings" then
        drawList:AddCircle(point(0, 0), 4.3 * scale, color, 16, thickness)
        drawList:AddCircleFilled(point(0, 0), 1.5 * scale, color, 12)
        for i = 0, 7 do
            local angle = i * math.pi / 4
            drawList:AddLine(
                point(math.cos(angle) * 5.5, math.sin(angle) * 5.5),
                point(math.cos(angle) * 7.5, math.sin(angle) * 7.5),
                color,
                thickness
            )
        end
    elseif icon == "phone" then
        drawList:AddLine(point(-6, -6), point(-3, -8), color, thickness)
        drawList:AddLine(point(-3, -8), point(0, -4), color, thickness)
        drawList:AddLine(point(0, -4), point(-2, -1), color, thickness)
        drawList:AddLine(point(-2, -1), point(2, 3), color, thickness)
        drawList:AddLine(point(2, 3), point(5, 1), color, thickness)
        drawList:AddLine(point(5, 1), point(8, 4), color, thickness)
        drawList:AddLine(point(8, 4), point(6, 7), color, thickness)
        drawList:AddLine(point(6, 7), point(3, 7), color, thickness)
        drawList:AddLine(point(3, 7), point(-1, 5), color, thickness)
        drawList:AddLine(point(-1, 5), point(-5, 1), color, thickness)
        drawList:AddLine(point(-5, 1), point(-7, -3), color, thickness)
        drawList:AddLine(point(-7, -3), point(-6, -6), color, thickness)
    end
end


function M.drawIconButton(imgui, id, icon, size, colors, tooltip, rounding)
    colors = colors or {}
    local cursor = imgui.GetCursorScreenPos()
    local clicked = imgui.InvisibleButton(id, size)
    local hovered = imgui.IsItemHovered()
    local active = imgui.IsItemActive()

    local background = colors.button or imgui.ImVec4(0, 0, 0, 0)
    if active and colors.active then
        background = colors.active
    elseif hovered and colors.hovered then
        background = colors.hovered
    end

    local iconColor = colors.text or imgui.ImVec4(1, 1, 1, 1)
    local drawList = imgui.GetWindowDrawList()
    local backgroundU32 = imgui.ColorConvertFloat4ToU32(background)
    drawList:AddRectFilled(
        cursor,
        imgui.ImVec2(cursor.x + size.x, cursor.y + size.y),
        backgroundU32,
        rounding or math.min(size.x, size.y) * 0.22
    )
    drawLineIcon(
        imgui,
        drawList,
        icon,
        imgui.ImVec2(cursor.x + size.x / 2, cursor.y + size.y / 2),
        imgui.ColorConvertFloat4ToU32(iconColor),
        size
    )

    if hovered and tooltip and tooltip ~= "" then
        imgui.BeginTooltip()
        imgui.TextUnformatted(tooltip)
        imgui.EndTooltip()
    end

    return clicked
end


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
