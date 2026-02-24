local M = {}

local imgui = nil
local ffi = nil
local CONFIG = nil
local state = nil
local scaled = nil
local getCurrentServerKey = nil
local getOrCreateServer = nil
local updateContactCache = nil
local saveData = nil
local getContactsList = nil
local cp1251_to_utf8 = nil
local deleteContact = nil
local filterContacts = nil
local smsData = nil
local saveSettings = nil
local ALERT_SOUNDS = nil
local playAlertSound = nil
local helpers = nil

function M.init(deps)
    imgui = deps.imgui
    ffi = deps.ffi
    CONFIG = deps.CONFIG
    state = deps.state
    scaled = deps.scaled
    getCurrentServerKey = deps.getCurrentServerKey
    getOrCreateServer = deps.getOrCreateServer
    updateContactCache = deps.updateContactCache
    saveData = deps.saveData
    getContactsList = deps.getContactsList
    cp1251_to_utf8 = deps.cp1251_to_utf8
    deleteContact = deps.deleteContact
    filterContacts = deps.filterContacts
    smsData = deps.smsData
    saveSettings = deps.saveSettings
    ALERT_SOUNDS = deps.ALERT_SOUNDS
    playAlertSound = deps.playAlertSound
    helpers = deps.helpers
end

M.drawNewContactDialog = function()
    if not state.showNewContactDialog then return end
    
    helpers.centerDialog(imgui, scaled, 350, 200)
    
    if imgui.BeginPopupModal("New Contact", nil, imgui.WindowFlags.AlwaysAutoResize) then
        imgui.SetWindowFontScale(CONFIG.fontScale)
        
        -- Adjust input frame padding to match dialog style
        local inputHeight = scaled(30)
        local fontSize = imgui.GetFontSize()
        local framePaddingY = math.max(4, (inputHeight - fontSize) / 2)
        local dlgStyle = imgui.GetStyle()
        local oldDlgFramePadding = { dlgStyle.FramePadding.x, dlgStyle.FramePadding.y }
        dlgStyle.FramePadding = imgui.ImVec2(scaled(10), framePaddingY)
        
        imgui.TextColored(CONFIG.colors.textDark, "Start New Conversation")
        imgui.Spacing()
        
        imgui.TextColored(CONFIG.colors.textGray, "Phone Number")
        imgui.SetNextItemWidth(scaled(300))
        local phoneEntered = imgui.InputText("##newphone", state.newContactPhone, 32, imgui.InputTextFlags.EnterReturnsTrue)
        
        imgui.Spacing()
        imgui.TextColored(CONFIG.colors.textGray, "Name (optional)")
        imgui.SetNextItemWidth(scaled(300))
        local nameEntered = imgui.InputText("##newname", state.newContactName, 64, imgui.InputTextFlags.EnterReturnsTrue)
        
        imgui.Spacing()
        imgui.Spacing()
        

        local btnWidth = scaled(100)
        imgui.SetCursorPosX(scaled(350) / 2 - btnWidth - scaled(10))
        
        if imgui.Button("Cancel", imgui.ImVec2(btnWidth, scaled(30))) then
            state.showNewContactDialog = false
            imgui.CloseCurrentPopup()
        end
        
        imgui.SameLine()
        imgui.SetCursorPosX(scaled(350) / 2 + scaled(10))
        
        local startClicked = helpers.drawStyledButton(imgui, "Start Chat", imgui.ImVec2(btnWidth, scaled(30)), {
            button = CONFIG.colors.primary,
            hovered = CONFIG.colors.primaryHover
        })
        
        if startClicked or phoneEntered or nameEntered then
            local phone = ffi.string(state.newContactPhone):gsub("%s+", "")
            local name = ffi.string(state.newContactName):gsub("^%s*", ""):gsub("%s*$", "")
            
            if phone ~= "" then

                if name == "" then
                    name = "Contact " .. phone
                end
                
                local serverKey = getCurrentServerKey()
                if serverKey then

                    local server = getOrCreateServer(serverKey)
                    if not server.contacts[phone] then
                        server.contacts[phone] = {
                            name = name,
                            phone = phone,
                            messages = {},
                            lastMessage = nil,
                            lastTimestamp = 0
                        }

                        updateContactCache(serverKey, nil, name, nil, phone)
                        saveData()
                    end
                    

                    state.contacts = getContactsList(serverKey)
                    for _, c in ipairs(state.contacts) do
                        if c.phone == phone then
                            state.selectedContact = c
                            break
                        end
                    end
                    
                    state.scrollToBottom = true
                end
                
                state.showNewContactDialog = false
                imgui.CloseCurrentPopup()
            end
        end
        

        dlgStyle.FramePadding = imgui.ImVec2(oldDlgFramePadding[1], oldDlgFramePadding[2])
        imgui.EndPopup()
    end
end

M.drawDeleteConfirmDialog = function()
    if not state.showDeleteConfirmDialog then return end
    
    helpers.centerDialog(imgui, scaled, 350, 150)
    
    if imgui.BeginPopupModal("Confirm Delete", nil, imgui.WindowFlags.AlwaysAutoResize) then
        imgui.SetWindowFontScale(CONFIG.fontScale)
        imgui.TextColored(CONFIG.colors.textDark, "Delete Contact?")
        imgui.Spacing()
        
        local name = cp1251_to_utf8(state.deleteContactName or "")
        local phone = state.deleteContactPhone or ""
        imgui.TextColored(CONFIG.colors.textGray, "Are you sure you want to delete")
        imgui.TextColored(CONFIG.colors.textDark, name .. " (" .. phone .. ")")
        imgui.TextColored(CONFIG.colors.textGray, "This action cannot be undone.")
        
        imgui.Spacing()
        imgui.Spacing()
        

        local btnWidth = scaled(100)
        imgui.SetCursorPosX(scaled(350) / 2 - btnWidth - scaled(10))
        
        if imgui.Button("Cancel", imgui.ImVec2(btnWidth, scaled(30))) then
            state.showDeleteConfirmDialog = false
            state.deleteContactName = ""
            state.deleteContactPhone = ""
            imgui.CloseCurrentPopup()
        end
        
        imgui.SameLine()
        imgui.SetCursorPosX(scaled(350) / 2 + scaled(10))
        
        if helpers.drawStyledButton(imgui, "Delete", imgui.ImVec2(btnWidth, scaled(30)), {
            button = imgui.ImVec4(0.9, 0.3, 0.3, 1.0),
            hovered = imgui.ImVec4(1.0, 0.4, 0.4, 1.0)
        }) then

            if state.deleteContactPhone ~= "" then
                deleteContact(state.deleteContactPhone)

                local serverKey = getCurrentServerKey()
                if serverKey then
                    state.contacts = getContactsList(serverKey)

                    state.filteredContacts = filterContacts(ffi.string(state.searchText))
                end
            end
            state.showDeleteConfirmDialog = false
            state.deleteContactName = ""
            state.deleteContactPhone = ""
            imgui.CloseCurrentPopup()
        end
        
        imgui.EndPopup()
    end
end

M.drawEditContactDialog = function()
    if not state.showEditContactDialog then return end
    
    helpers.centerDialog(imgui, scaled, 350, 200)
    
    if imgui.BeginPopupModal("Edit Contact", nil, imgui.WindowFlags.AlwaysAutoResize) then
        imgui.SetWindowFontScale(CONFIG.fontScale)
        
        -- Adjust input frame padding to match dialog style
        local inputHeight = scaled(30)
        local fontSize = imgui.GetFontSize()
        local framePaddingY = math.max(4, (inputHeight - fontSize) / 2)
        local editDlgStyle = imgui.GetStyle()
        local oldEditFramePadding = { editDlgStyle.FramePadding.x, editDlgStyle.FramePadding.y }
        editDlgStyle.FramePadding = imgui.ImVec2(scaled(10), framePaddingY)
        
        imgui.TextColored(CONFIG.colors.textDark, "Edit Contact")
        imgui.Spacing()
        
        imgui.TextColored(CONFIG.colors.textGray, "Phone Number")
        imgui.SetNextItemWidth(scaled(300))
        local phoneEntered = imgui.InputText("##editphone", state.editContactPhone, 32, imgui.InputTextFlags.EnterReturnsTrue)
        
        imgui.Spacing()
        imgui.TextColored(CONFIG.colors.textGray, "Name")
        imgui.SetNextItemWidth(scaled(300))
        local nameEntered = imgui.InputText("##editname", state.editContactName, 64, imgui.InputTextFlags.EnterReturnsTrue)
        
        imgui.Spacing()
        imgui.Spacing()
        

        local btnWidth = scaled(100)
        imgui.SetCursorPosX(scaled(350) / 2 - btnWidth - scaled(10))
        
        if imgui.Button("Cancel", imgui.ImVec2(btnWidth, scaled(30))) then
            state.showEditContactDialog = false
            imgui.CloseCurrentPopup()
        end
        
        imgui.SameLine()
        imgui.SetCursorPosX(scaled(350) / 2 + scaled(10))
        
        local saveClicked = helpers.drawStyledButton(imgui, "Save", imgui.ImVec2(btnWidth, scaled(30)), {
            button = CONFIG.colors.primary,
            hovered = CONFIG.colors.primaryHover
        })
        
        if saveClicked or phoneEntered or nameEntered then
            local newPhone = ffi.string(state.editContactPhone):gsub("%s+", "")
            local newName = ffi.string(state.editContactName):gsub("^%s*", ""):gsub("%s*$", "")
            
            if newPhone ~= "" and newName ~= "" and state.selectedContact then
                local serverKey = getCurrentServerKey()
                if serverKey and smsData.servers[serverKey] then
                    local oldPhone = state.selectedContact.phone
                    local contact = smsData.servers[serverKey].contacts[oldPhone]
                    
                    if contact then
                        local oldName = contact.name
                        

                        if oldPhone ~= newPhone then

                            smsData.servers[serverKey].contacts[newPhone] = contact

                            smsData.servers[serverKey].contacts[oldPhone] = nil

                            contact.phone = newPhone
                        end
                        

                        contact.name = newName
                        

                        updateContactCache(serverKey, oldName, newName, oldPhone, newPhone)
                        
                        saveData()
                        

                        state.contacts = getContactsList(serverKey)
                        for _, c in ipairs(state.contacts) do
                            if c.phone == newPhone then
                                state.selectedContact = c
                                break
                            end
                        end
                    end
                end
                
                state.showEditContactDialog = false
                imgui.CloseCurrentPopup()
            end
        end
        

        editDlgStyle.FramePadding = imgui.ImVec2(oldEditFramePadding[1], oldEditFramePadding[2])
        imgui.EndPopup()
    end
end

M.drawSettingsDialog = function()
    if not state.showSettingsDialog then return end
    
    helpers.centerDialog(imgui, scaled, 400, 480)
    
    if imgui.BeginPopupModal("Settings", nil, imgui.WindowFlags.AlwaysAutoResize) then
        imgui.SetWindowFontScale(CONFIG.fontScale)
        imgui.TextColored(CONFIG.colors.textDark, "Notification Settings")
        imgui.Spacing()
        

        local soundEnabled = imgui.new.bool(CONFIG.soundEnabled)
        if imgui.Checkbox("Enable sound notifications", soundEnabled) then
            CONFIG.soundEnabled = soundEnabled[0]
            saveSettings()
        end
        

        imgui.Spacing()
        local hideSMS = imgui.new.bool(CONFIG.hideSMSFromChat)
        if imgui.Checkbox("Hide SMS messages from game chat", hideSMS) then
            CONFIG.hideSMSFromChat = hideSMS[0]
            saveSettings()
        end
        imgui.TextColored(CONFIG.colors.textGray, "SMS will only appear in this messenger")
        
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()
        

        imgui.TextColored(CONFIG.colors.textGray, "Alert Sound")
        
        if #ALERT_SOUNDS > 0 then

            imgui.TextColored(CONFIG.colors.textGray, "Select sound (" .. #ALERT_SOUNDS .. " found):")
            imgui.TextColored(CONFIG.colors.textDark, "Current: " .. (CONFIG.currentSound or "None"))
            imgui.Spacing()
            
            for i, sound in ipairs(ALERT_SOUNDS) do
                local isSelected = (sound == CONFIG.currentSound)
                
                local buttonColors = isSelected and {
                    button = CONFIG.colors.primary,
                    hovered = CONFIG.colors.primaryHover,
                    text = imgui.ImVec4(1, 1, 1, 1)
                } or {
                    button = CONFIG.colors.searchBg,
                    hovered = CONFIG.colors.selected,
                    text = CONFIG.colors.textDark
                }
                
                if helpers.drawStyledButton(imgui, sound .. "##sound" .. i, imgui.ImVec2(scaled(200), scaled(25)), buttonColors) then
                    CONFIG.currentSound = sound
                    saveSettings()

                    playAlertSound()
                end
                
                if i < #ALERT_SOUNDS then
                    imgui.Spacing()
                end
            end
            
            imgui.Spacing()
            

            if helpers.drawStyledButton(imgui, "Test Sound", imgui.ImVec2(scaled(200), scaled(30)), {
                button = imgui.ImVec4(0.2, 0.7, 0.3, 1.0),
                hovered = imgui.ImVec4(0.2, 0.8, 0.35, 1.0),
                text = imgui.ImVec4(1, 1, 1, 1)
            }) then
                playAlertSound()
            end
            
        else
            imgui.TextColored(CONFIG.colors.textGray, "No sounds found in smsmenu/alerts/")
        end
        
        imgui.Spacing()
        imgui.Spacing()
        

        imgui.Separator()
        imgui.Spacing()
        imgui.TextColored(CONFIG.colors.textGray, "Interface Scale")
        
        local fontScale = imgui.new.float(CONFIG.fontScale)
        imgui.SetNextItemWidth(scaled(250))
        if imgui.SliderFloat("##fontscale", fontScale, 0.8, 1.5, "%.1fx") then
            CONFIG.fontScale = fontScale[0]
            saveSettings()
        end
        imgui.TextColored(CONFIG.colors.textGray, "Adjust UI text size (0.8x - 1.5x)")
        
        imgui.Spacing()
        imgui.Spacing()
        

        local btnWidth = scaled(100)
        imgui.SetCursorPosX((scaled(400) - btnWidth) / 2)
        if imgui.Button("Close", imgui.ImVec2(btnWidth, scaled(30))) then
            state.showSettingsDialog = false
            imgui.CloseCurrentPopup()
        end
        
        imgui.EndPopup()
    end
end

return M
