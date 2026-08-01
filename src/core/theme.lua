local imgui = require "lib.mimgui"

local M = {}
local CONFIG = nil
local saveSettings = nil

local THEMES = {
    light = {
        primary = imgui.ImVec4(0.0, 0.518, 1.0, 1.0),
        primaryHover = imgui.ImVec4(0.0, 0.45, 0.9, 1.0),
        primaryActive = imgui.ImVec4(0.0, 0.40, 0.85, 1.0),
        background = imgui.ImVec4(1.0, 1.0, 1.0, 1.0),
        leftPanel = imgui.ImVec4(0.98, 0.98, 0.98, 1.0),
        receivedBubble = imgui.ImVec4(0.9, 0.9, 0.9, 1.0),
        sentBubble = imgui.ImVec4(0.0, 0.518, 1.0, 1.0),
        textDark = imgui.ImVec4(0.15, 0.15, 0.15, 1.0),
        textLight = imgui.ImVec4(1.0, 1.0, 1.0, 1.0),
        textGray = imgui.ImVec4(0.5, 0.5, 0.5, 1.0),
        border = imgui.ImVec4(0.88, 0.88, 0.88, 1.0),
        surface = imgui.ImVec4(0.93, 0.93, 0.93, 1.0),
        surfaceHover = imgui.ImVec4(0.82, 0.91, 1.0, 1.0),
        surfaceActive = imgui.ImVec4(0.76, 0.87, 0.98, 1.0),
        disabledSurface = imgui.ImVec4(0.94, 0.94, 0.94, 1.0),
        disabledText = imgui.ImVec4(0.62, 0.62, 0.62, 1.0),
        danger = imgui.ImVec4(0.90, 0.30, 0.30, 1.0),
        dangerHover = imgui.ImVec4(1.0, 0.40, 0.40, 1.0),
        dangerActive = imgui.ImVec4(0.80, 0.20, 0.20, 1.0),
        dangerSoft = imgui.ImVec4(0.90, 0.30, 0.30, 0.18),
        success = imgui.ImVec4(0.20, 0.70, 0.30, 1.0),
        successHover = imgui.ImVec4(0.20, 0.80, 0.35, 1.0),
        successActive = imgui.ImVec4(0.15, 0.60, 0.25, 1.0),
        statusOnline = imgui.ImVec4(0.30, 0.85, 0.39, 1.0),
        statusOffline = imgui.ImVec4(0.56, 0.56, 0.58, 1.0),
        contactSelected = imgui.ImVec4(0.91, 0.95, 0.99, 1.0),
        contactHover = imgui.ImVec4(0.95, 0.97, 0.99, 1.0),
        scrollbarGrab = imgui.ImVec4(0.8, 0.8, 0.8, 1.0),
        scrollbarGrabHovered = imgui.ImVec4(0.7, 0.7, 0.7, 1.0),
        scrollbarGrabActive = imgui.ImVec4(0.6, 0.6, 0.6, 1.0)
    },
    dark = {
        primary = imgui.ImVec4(0.0, 0.6, 1.0, 1.0),
        primaryHover = imgui.ImVec4(0.0, 0.7, 1.0, 1.0),
        primaryActive = imgui.ImVec4(0.0, 0.52, 0.88, 1.0),
        background = imgui.ImVec4(0.12, 0.12, 0.12, 1.0),
        leftPanel = imgui.ImVec4(0.18, 0.18, 0.18, 1.0),
        receivedBubble = imgui.ImVec4(0.25, 0.25, 0.25, 1.0),
        sentBubble = imgui.ImVec4(0.0, 0.6, 1.0, 1.0),
        textDark = imgui.ImVec4(0.95, 0.95, 0.95, 1.0),
        textLight = imgui.ImVec4(1.0, 1.0, 1.0, 1.0),
        textGray = imgui.ImVec4(0.6, 0.6, 0.6, 1.0),
        border = imgui.ImVec4(0.3, 0.3, 0.3, 1.0),
        surface = imgui.ImVec4(0.25, 0.25, 0.25, 1.0),
        surfaceHover = imgui.ImVec4(0.16, 0.34, 0.52, 1.0),
        surfaceActive = imgui.ImVec4(0.12, 0.28, 0.43, 1.0),
        disabledSurface = imgui.ImVec4(0.20, 0.20, 0.20, 1.0),
        disabledText = imgui.ImVec4(0.46, 0.46, 0.46, 1.0),
        danger = imgui.ImVec4(0.90, 0.30, 0.30, 1.0),
        dangerHover = imgui.ImVec4(1.0, 0.40, 0.40, 1.0),
        dangerActive = imgui.ImVec4(0.80, 0.20, 0.20, 1.0),
        dangerSoft = imgui.ImVec4(0.90, 0.30, 0.30, 0.22),
        success = imgui.ImVec4(0.20, 0.70, 0.30, 1.0),
        successHover = imgui.ImVec4(0.20, 0.80, 0.35, 1.0),
        successActive = imgui.ImVec4(0.15, 0.60, 0.25, 1.0),
        statusOnline = imgui.ImVec4(0.30, 0.85, 0.39, 1.0),
        statusOffline = imgui.ImVec4(0.56, 0.56, 0.58, 1.0),
        contactSelected = imgui.ImVec4(0.15, 0.21, 0.27, 1.0),
        contactHover = imgui.ImVec4(0.15, 0.18, 0.21, 1.0),
        scrollbarGrab = imgui.ImVec4(0.3, 0.3, 0.3, 1.0),
        scrollbarGrabHovered = imgui.ImVec4(0.4, 0.4, 0.4, 1.0),
        scrollbarGrabActive = imgui.ImVec4(0.5, 0.5, 0.5, 1.0)
    }
}

M.THEMES = THEMES

function M.init(deps)
    CONFIG = deps.CONFIG
    saveSettings = deps.saveSettings
end

function M.applyTheme(themeName)
    if not CONFIG or not saveSettings then return end
    CONFIG.currentTheme = themeName
    CONFIG.colors = THEMES[themeName]
    saveSettings()
end

return M
