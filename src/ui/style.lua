local M = {}

local imgui = nil
local CONFIG = nil
local scaled = nil

function M.init(deps)
    imgui = deps.imgui
    CONFIG = deps.CONFIG
    scaled = deps.scaled
end

local function metric(group, name)
    local ui = CONFIG and CONFIG.CONSTANTS and CONFIG.CONSTANTS.UI
    local values = ui and ui[group]
    local value = values and values[name]
    return scaled(value or 0)
end

function M.spacing(name)
    return metric("SPACING", name)
end

function M.radius(name)
    return metric("RADIUS", name)
end

function M.controlHeight(name)
    return metric("CONTROL_HEIGHT", name)
end

function M.stroke(name)
    return metric("STROKE", name)
end

function M.withAlpha(color, alpha)
    return imgui.ImVec4(color.x, color.y, color.z, alpha)
end

function M.button(variant)
    local colors = CONFIG.colors
    if variant == "primary" then
        return {
            button = colors.primary,
            hovered = colors.primaryHover,
            active = colors.primaryActive,
            text = colors.textLight
        }
    elseif variant == "success" then
        return {
            button = colors.success,
            hovered = colors.successHover,
            active = colors.successActive,
            text = colors.textLight
        }
    elseif variant == "danger" then
        return {
            button = colors.danger,
            hovered = colors.dangerHover,
            active = colors.dangerActive,
            text = colors.textLight
        }
    elseif variant == "dangerGhost" then
        return {
            button = colors.background,
            hovered = colors.dangerSoft,
            active = M.withAlpha(colors.danger, 0.32),
            text = colors.danger
        }
    elseif variant == "dangerIcon" then
        return {
            button = colors.surface,
            hovered = colors.dangerSoft,
            active = M.withAlpha(colors.danger, 0.32),
            text = colors.textDark
        }
    elseif variant == "disabled" then
        return {
            button = colors.disabledSurface,
            hovered = colors.disabledSurface,
            active = colors.disabledSurface,
            text = colors.disabledText
        }
    end

    return {
        button = colors.surface,
        hovered = colors.surfaceHover,
        active = colors.surfaceActive,
        text = colors.textDark
    }
end

function M.inputColors()
    local colors = CONFIG.colors
    return {
        background = colors.surface,
        hovered = colors.surfaceHover,
        active = colors.surface,
        text = colors.textDark,
        placeholder = colors.textGray
    }
end

return M
