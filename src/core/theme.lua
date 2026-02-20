local imgui = require "lib.mimgui"

local M = {}
local CONFIG = nil
local saveSettings = nil

local THEMES = {
    light = {
        primary = imgui.ImVec4(0.0, 0.518, 1.0, 1.0),
        primaryHover = imgui.ImVec4(0.0, 0.45, 0.9, 1.0),
        background = imgui.ImVec4(1.0, 1.0, 1.0, 1.0),
        leftPanel = imgui.ImVec4(0.98, 0.98, 0.98, 1.0),
        receivedBubble = imgui.ImVec4(0.9, 0.9, 0.9, 1.0),
        sentBubble = imgui.ImVec4(0.0, 0.518, 1.0, 1.0),
        textDark = imgui.ImVec4(0.15, 0.15, 0.15, 1.0),
        textLight = imgui.ImVec4(1.0, 1.0, 1.0, 1.0),
        textGray = imgui.ImVec4(0.5, 0.5, 0.5, 1.0),
        border = imgui.ImVec4(0.88, 0.88, 0.88, 1.0),
        searchBg = imgui.ImVec4(0.93, 0.93, 0.93, 1.0),
        selected = imgui.ImVec4(0.88, 0.94, 1.0, 1.0)
    },
    dark = {
        primary = imgui.ImVec4(0.0, 0.6, 1.0, 1.0),
        primaryHover = imgui.ImVec4(0.0, 0.7, 1.0, 1.0),
        background = imgui.ImVec4(0.12, 0.12, 0.12, 1.0),
        leftPanel = imgui.ImVec4(0.18, 0.18, 0.18, 1.0),
        receivedBubble = imgui.ImVec4(0.25, 0.25, 0.25, 1.0),
        sentBubble = imgui.ImVec4(0.0, 0.6, 1.0, 1.0),
        textDark = imgui.ImVec4(0.95, 0.95, 0.95, 1.0),
        textLight = imgui.ImVec4(1.0, 1.0, 1.0, 1.0),
        textGray = imgui.ImVec4(0.6, 0.6, 0.6, 1.0),
        border = imgui.ImVec4(0.3, 0.3, 0.3, 1.0),
        searchBg = imgui.ImVec4(0.25, 0.25, 0.25, 1.0),
        selected = imgui.ImVec4(0.2, 0.35, 0.5, 1.0)
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
