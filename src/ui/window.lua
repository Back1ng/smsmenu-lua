local M = {}

local imgui = nil
local state = nil
local CONFIG = nil
local scaled = nil
local drawLeftPanel = nil
local drawRightPanel = nil
local drawNewContactDialog = nil
local drawEditContactDialog = nil
local drawDeleteConfirmDialog = nil
local drawSettingsDialog = nil
local getCurrentServerKey = nil
local getContactsList = nil

function M.init(deps)
    imgui = deps.imgui
    state = deps.state
    CONFIG = deps.CONFIG
    scaled = deps.scaled
    drawLeftPanel = deps.drawLeftPanel
    drawRightPanel = deps.drawRightPanel
    drawNewContactDialog = deps.drawNewContactDialog
    drawEditContactDialog = deps.drawEditContactDialog
    drawDeleteConfirmDialog = deps.drawDeleteConfirmDialog
    drawSettingsDialog = deps.drawSettingsDialog
    getCurrentServerKey = deps.getCurrentServerKey
    getContactsList = deps.getContactsList
end

function M.setup()
    -- Register imgui frame handler
    imgui.OnFrame(function() return state and state.windowOpen[0] end, function()
        imgui.SetNextWindowSize(imgui.ImVec2(scaled(CONFIG.windowWidth), scaled(CONFIG.windowHeight)), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowPos(imgui.ImVec2(200, 100), imgui.Cond.FirstUseEver)
        
        local flags = imgui.WindowFlags.NoCollapse + 
                      imgui.WindowFlags.NoScrollbar +
                      imgui.WindowFlags.NoScrollWithMouse +
                      imgui.WindowFlags.NoTitleBar
        
        if imgui.Begin("SMS Menu##main", state.windowOpen, flags) then
            -- Apply font scale
            imgui.SetWindowFontScale(CONFIG.fontScale)
            
            -- Update contacts list when window opens
            local serverKey = getCurrentServerKey()
            if serverKey then
                state.currentServer = serverKey
                state.contacts = getContactsList(serverKey)
            end
            
            -- Only draw panels if colors are initialized
            if CONFIG.colors then
                drawLeftPanel()
                drawRightPanel()
                drawNewContactDialog()
                drawEditContactDialog()
                drawDeleteConfirmDialog()
                drawSettingsDialog()
            end
            
            -- Custom close button (top right) - drawn LAST to be on top, aligned with Edit button
            local winPos = imgui.GetWindowPos()
            local winSize = imgui.GetWindowSize()
            imgui.SetCursorPos(imgui.ImVec2(winSize.x - scaled(40), scaled(12)))
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.8, 0.8, 1.0))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.9, 0.3, 0.3, 1.0))
            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.8, 0.2, 0.2, 1.0))
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.1, 0.1, 0.1, 1.0))
            if imgui.Button("X##close", imgui.ImVec2(scaled(32), scaled(26))) then
                state.windowOpen[0] = false
            end
            imgui.PopStyleColor(4)
        end
        
        -- Reset font scale to default
        imgui.SetWindowFontScale(1.0)
        
        imgui.End()
    end)
end

return M
