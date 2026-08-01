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
local helpers = nil

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
    helpers = deps.helpers
end

function M.setup()

    imgui.OnFrame(function() return state and state.windowOpen[0] end, function()
        imgui.SetNextWindowSize(imgui.ImVec2(scaled(CONFIG.windowWidth), scaled(CONFIG.windowHeight)), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowPos(imgui.ImVec2(200, 100), imgui.Cond.FirstUseEver)
        
        local flags = imgui.WindowFlags.NoCollapse + 
                      imgui.WindowFlags.NoScrollbar +
                      imgui.WindowFlags.NoScrollWithMouse +
                      imgui.WindowFlags.NoTitleBar
        
        if imgui.Begin("SMS Menu##main", state.windowOpen, flags) then

            imgui.SetWindowFontScale(CONFIG.fontScale)
            

            local serverKey = getCurrentServerKey()
            if serverKey then
                state.currentServer = serverKey
                state.contacts = getContactsList(serverKey)
            end
            

            if CONFIG.colors then
                drawLeftPanel()
                drawRightPanel()
                drawNewContactDialog()
                drawEditContactDialog()
                drawDeleteConfirmDialog()
                drawSettingsDialog()
            end
            
            -- Drawn last so it renders on top of all panels
            local winSize = imgui.GetWindowSize()
            imgui.SetCursorPos(imgui.ImVec2(winSize.x - scaled(40), scaled(10)))
            if helpers.drawIconButton(imgui, "##close", "close", imgui.ImVec2(scaled(30), scaled(30)), {
                button = CONFIG.colors.searchBg,
                hovered = imgui.ImVec4(0.9, 0.3, 0.3, 0.22),
                active = imgui.ImVec4(0.9, 0.3, 0.3, 0.35),
                text = CONFIG.colors.textDark
            }, "Close", scaled(7)) then
                state.windowOpen[0] = false
            end
        end
        

        imgui.SetWindowFontScale(1.0)
        
        imgui.End()
    end)
end

return M
