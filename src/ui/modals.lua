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

local function drawSettingsSection(label)
    imgui.TextColored(CONFIG.colors.textGray, label)
    imgui.Spacing()
end

local function drawSettingsToggle(id, title, description, value)
    local width = imgui.GetContentRegionAvail().x
    local height = scaled(52)
    local cursor = imgui.GetCursorScreenPos()
    local clicked = imgui.InvisibleButton(id, imgui.ImVec2(width, height))
    local hovered = imgui.IsItemHovered()
    local surface = hovered and CONFIG.colors.selected or CONFIG.colors.searchBg
    local drawList = imgui.GetWindowDrawList()

    drawList:AddRectFilled(
        cursor,
        imgui.ImVec2(cursor.x + width, cursor.y + height),
        imgui.ColorConvertFloat4ToU32(surface),
        scaled(9)
    )
    drawList:AddText(
        imgui.ImVec2(cursor.x + scaled(12), cursor.y + scaled(8)),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.textDark),
        title
    )
    drawList:AddText(
        imgui.ImVec2(cursor.x + scaled(12), cursor.y + scaled(29)),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.textGray),
        description
    )

    local trackWidth = scaled(36)
    local trackHeight = scaled(20)
    local trackLeft = cursor.x + width - trackWidth - scaled(12)
    local trackTop = cursor.y + (height - trackHeight) / 2
    local trackColor = value and CONFIG.colors.primary or CONFIG.colors.border
    drawList:AddRectFilled(
        imgui.ImVec2(trackLeft, trackTop),
        imgui.ImVec2(trackLeft + trackWidth, trackTop + trackHeight),
        imgui.ColorConvertFloat4ToU32(trackColor),
        trackHeight / 2
    )

    local knobRadius = scaled(8)
    local knobX = value and (trackLeft + trackWidth - scaled(10)) or (trackLeft + scaled(10))
    drawList:AddCircleFilled(
        imgui.ImVec2(knobX, trackTop + trackHeight / 2),
        knobRadius,
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1, 1, 1, 1)),
        16
    )

    return clicked
end

local function drawSoundSelector()
    local width = imgui.GetContentRegionAvail().x
    local height = scaled(46)
    local cursor = imgui.GetCursorScreenPos()
    local clicked = imgui.InvisibleButton("##soundselector", imgui.ImVec2(width, height))
    local hovered = imgui.IsItemHovered()
    local surface = hovered and CONFIG.colors.selected or CONFIG.colors.searchBg
    local drawList = imgui.GetWindowDrawList()

    drawList:AddRectFilled(
        cursor,
        imgui.ImVec2(cursor.x + width, cursor.y + height),
        imgui.ColorConvertFloat4ToU32(surface),
        scaled(9)
    )
    drawList:AddText(
        imgui.ImVec2(cursor.x + scaled(12), cursor.y + scaled(7)),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.textDark),
        "Alert sound"
    )
    drawList:AddText(
        imgui.ImVec2(cursor.x + scaled(12), cursor.y + scaled(26)),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.textGray),
        CONFIG.currentSound or "None"
    )

    local chevronX = cursor.x + width - scaled(17)
    local chevronY = cursor.y + height / 2
    local chevronColor = imgui.ColorConvertFloat4ToU32(CONFIG.colors.textGray)
    drawList:AddLine(
        imgui.ImVec2(chevronX - scaled(4), chevronY - scaled(2)),
        imgui.ImVec2(chevronX, chevronY + scaled(2)),
        chevronColor,
        scaled(1.5)
    )
    drawList:AddLine(
        imgui.ImVec2(chevronX, chevronY + scaled(2)),
        imgui.ImVec2(chevronX + scaled(4), chevronY - scaled(2)),
        chevronColor,
        scaled(1.5)
    )

    if clicked and #ALERT_SOUNDS > 0 then
        imgui.OpenPopup("##soundpicker")
    end

    local popupHeight = scaled(math.min(220, #ALERT_SOUNDS * 34 + 16))
    imgui.SetNextWindowSize(imgui.ImVec2(width, popupHeight), imgui.Cond.Always)
    imgui.PushStyleColor(imgui.Col.PopupBg, CONFIG.colors.background)
    imgui.PushStyleColor(imgui.Col.Border, CONFIG.colors.border)
    if imgui.BeginPopup("##soundpicker") then
        for i, sound in ipairs(ALERT_SOUNDS) do
            local isSelected = sound == CONFIG.currentSound
            local colors = isSelected and {
                button = CONFIG.colors.selected,
                hovered = CONFIG.colors.selected,
                active = CONFIG.colors.border,
                text = CONFIG.colors.primary
            } or {
                button = CONFIG.colors.background,
                hovered = CONFIG.colors.searchBg,
                active = CONFIG.colors.selected,
                text = CONFIG.colors.textDark
            }
            if helpers.drawStyledButton(imgui, sound .. "##soundoption" .. i, imgui.ImVec2(imgui.GetContentRegionAvail().x, scaled(28)), colors) then
                CONFIG.currentSound = sound
                saveSettings()
                playAlertSound()
                imgui.CloseCurrentPopup()
            end
        end
        imgui.EndPopup()
    end
    imgui.PopStyleColor(2)
end

M.drawSettingsDialog = function()
    if not state.showSettingsDialog then return end

    helpers.centerDialog(imgui, scaled, 400, 410)
    imgui.PushStyleColor(imgui.Col.PopupBg, CONFIG.colors.background)
    imgui.PushStyleColor(imgui.Col.Border, CONFIG.colors.border)

    local flags = imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse
    if imgui.BeginPopupModal("Settings", nil, flags) then
        imgui.SetWindowFontScale(CONFIG.fontScale)

        drawSettingsSection("NOTIFICATIONS")
        if drawSettingsToggle(
            "##soundenabled",
            "Sound notifications",
            "Play a sound for new messages",
            CONFIG.soundEnabled
        ) then
            CONFIG.soundEnabled = not CONFIG.soundEnabled
            saveSettings()
        end

        imgui.Spacing()
        if drawSettingsToggle(
            "##hidesms",
            "Messenger-only SMS",
            "Hide SMS messages from game chat",
            CONFIG.hideSMSFromChat
        ) then
            CONFIG.hideSMSFromChat = not CONFIG.hideSMSFromChat
            saveSettings()
        end

        imgui.Spacing()
        imgui.Spacing()
        drawSettingsSection("SOUND")
        if #ALERT_SOUNDS > 0 then
            drawSoundSelector()
            imgui.Spacing()
            if helpers.drawStyledButton(imgui, "Play selected sound##testsound", imgui.ImVec2(imgui.GetContentRegionAvail().x, scaled(30)), {
                button = CONFIG.colors.searchBg,
                hovered = CONFIG.colors.selected,
                active = CONFIG.colors.border,
                text = CONFIG.colors.primary
            }) then
                playAlertSound()
            end
        else
            imgui.TextColored(CONFIG.colors.textGray, "No sounds found in smsmenu/alerts/")
        end

        imgui.Spacing()
        imgui.Spacing()
        drawSettingsSection("APPEARANCE")
        imgui.TextColored(CONFIG.colors.textDark, "Interface scale")
        local fontScale = imgui.new.float(CONFIG.fontScale)
        imgui.SetNextItemWidth(imgui.GetContentRegionAvail().x)
        if imgui.SliderFloat("##fontscale", fontScale, 0.8, 1.5, "%.1fx") then
            CONFIG.fontScale = fontScale[0]
            saveSettings()
        end

        imgui.Spacing()
        imgui.Spacing()
        if helpers.drawStyledButton(imgui, "Done##closesettings", imgui.ImVec2(imgui.GetContentRegionAvail().x, scaled(32)), {
            button = CONFIG.colors.primary,
            hovered = CONFIG.colors.primaryHover,
            active = CONFIG.colors.primaryHover,
            text = CONFIG.colors.textLight
        }) then
            state.showSettingsDialog = false
            imgui.CloseCurrentPopup()
        end

        imgui.EndPopup()
    end
    imgui.PopStyleColor(2)
end

return M
