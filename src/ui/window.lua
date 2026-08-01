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
local design = nil
local i18n = nil

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
    design = deps.design
    i18n = deps.i18n
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
            local closeSize = design.controlHeight("ICON")
            imgui.SetCursorPos(imgui.ImVec2(
                winSize.x - closeSize - design.spacing("SM"),
                (scaled(CONFIG.headerHeight) - closeSize) / 2
            ))
            if helpers.drawIconButton(
                imgui,
                "##close",
                "close",
                imgui.ImVec2(closeSize, closeSize),
                design.button("dangerIcon"),
                i18n.t("close"),
                design.radius("MD")
            ) then
                state.windowOpen[0] = false
            end
        end
        

        imgui.SetWindowFontScale(1.0)
        
        imgui.End()
    end)
end

return M
