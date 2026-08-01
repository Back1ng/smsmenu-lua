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

local function messengerModalFlags()
    return imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse
end

local function pushMessengerModalStyle()
    imgui.PushStyleColor(imgui.Col.PopupBg, CONFIG.colors.background)
    imgui.PushStyleColor(imgui.Col.Border, CONFIG.colors.border)
end

local function popMessengerModalStyle()
    imgui.PopStyleColor(2)
end

local function drawModalHeading(title, description)
    imgui.TextColored(CONFIG.colors.textDark, title)
    imgui.TextColored(CONFIG.colors.textGray, description)
    imgui.Spacing()
    imgui.Spacing()
end

local function drawMessengerInput(id, label, placeholder, buffer, capacity)
    imgui.TextColored(CONFIG.colors.textDark, label)
    imgui.Spacing()

    local inputHeight = scaled(32)
    local fontSize = imgui.GetFontSize()
    local framePaddingY = math.max(4, (inputHeight - fontSize) / 2)
    local style = imgui.GetStyle()
    local oldFramePadding = { style.FramePadding.x, style.FramePadding.y }
    local oldFrameRounding = style.FrameRounding
    style.FramePadding = imgui.ImVec2(scaled(10), framePaddingY)
    style.FrameRounding = scaled(8)

    imgui.SetNextItemWidth(imgui.GetContentRegionAvail().x)
    local inputPos = imgui.GetCursorScreenPos()
    imgui.PushStyleColor(imgui.Col.FrameBg, CONFIG.colors.searchBg)
    imgui.PushStyleColor(imgui.Col.FrameBgHovered, CONFIG.colors.selected)
    imgui.PushStyleColor(imgui.Col.FrameBgActive, CONFIG.colors.searchBg)
    imgui.PushStyleColor(imgui.Col.Text, CONFIG.colors.textDark)
    local submitted = imgui.InputText(id, buffer, capacity, imgui.InputTextFlags.EnterReturnsTrue)
    local active = imgui.IsItemActive()
    imgui.PopStyleColor(4)

    if ffi.string(buffer) == "" and not active then
        local placeholderSize = imgui.CalcTextSize(placeholder)
        imgui.GetWindowDrawList():AddText(
            imgui.ImVec2(
                inputPos.x + scaled(10),
                inputPos.y + (inputHeight - placeholderSize.y) / 2
            ),
            imgui.ColorConvertFloat4ToU32(CONFIG.colors.textGray),
            placeholder
        )
    end

    style.FramePadding = imgui.ImVec2(oldFramePadding[1], oldFramePadding[2])
    style.FrameRounding = oldFrameRounding
    return submitted
end

local function drawModalActions(confirmLabel, confirmEnabled, destructive)
    local availableWidth = imgui.GetContentRegionAvail().x
    local gap = scaled(8)
    local buttonWidth = (availableWidth - gap) / 2
    local buttonHeight = scaled(32)
    local style = imgui.GetStyle()
    local oldRounding = style.FrameRounding
    style.FrameRounding = scaled(8)

    local cancelClicked = helpers.drawStyledButton(imgui, "Cancel##modalcancel", imgui.ImVec2(buttonWidth, buttonHeight), {
        button = CONFIG.colors.searchBg,
        hovered = CONFIG.colors.selected,
        active = CONFIG.colors.border,
        text = CONFIG.colors.textDark
    })
    imgui.SameLine(0, gap)

    local confirmColors
    if not confirmEnabled then
        confirmColors = {
            button = CONFIG.colors.searchBg,
            hovered = CONFIG.colors.searchBg,
            active = CONFIG.colors.searchBg,
            text = CONFIG.colors.textGray
        }
    elseif destructive then
        confirmColors = {
            button = imgui.ImVec4(0.9, 0.3, 0.3, 1.0),
            hovered = imgui.ImVec4(1.0, 0.4, 0.4, 1.0),
            active = imgui.ImVec4(0.8, 0.2, 0.2, 1.0),
            text = imgui.ImVec4(1, 1, 1, 1)
        }
    else
        confirmColors = {
            button = CONFIG.colors.primary,
            hovered = CONFIG.colors.primaryHover,
            active = CONFIG.colors.primaryHover,
            text = CONFIG.colors.textLight
        }
    end

    local confirmClicked = helpers.drawStyledButton(
        imgui,
        confirmLabel .. "##modalconfirm",
        imgui.ImVec2(buttonWidth, buttonHeight),
        confirmColors
    )
    style.FrameRounding = oldRounding
    return cancelClicked, confirmClicked and confirmEnabled
end

local function drawContactSummary(name, phone)
    local width = imgui.GetContentRegionAvail().x
    local height = scaled(54)
    local cursor = imgui.GetCursorScreenPos()
    local drawList = imgui.GetWindowDrawList()
    local rawName = state.deleteContactName or "?"
    local initial = cp1251_to_utf8(rawName:sub(1, 1)):upper()

    imgui.Dummy(imgui.ImVec2(width, height))
    drawList:AddRectFilled(
        cursor,
        imgui.ImVec2(cursor.x + width, cursor.y + height),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.searchBg),
        scaled(9)
    )
    local avatarCenter = imgui.ImVec2(cursor.x + scaled(27), cursor.y + height / 2)
    drawList:AddCircleFilled(avatarCenter, scaled(18), imgui.ColorConvertFloat4ToU32(CONFIG.colors.primary), 20)
    local initialSize = imgui.CalcTextSize(initial)
    drawList:AddText(
        imgui.ImVec2(avatarCenter.x - initialSize.x / 2, avatarCenter.y - initialSize.y / 2),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.textLight),
        initial
    )
    drawList:AddText(
        imgui.ImVec2(cursor.x + scaled(55), cursor.y + scaled(8)),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.textDark),
        name
    )
    drawList:AddText(
        imgui.ImVec2(cursor.x + scaled(55), cursor.y + scaled(29)),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.textGray),
        phone
    )
end

M.drawNewContactDialog = function()
    if not state.showNewContactDialog then return end

    helpers.centerDialog(imgui, scaled, 380, 270)
    pushMessengerModalStyle()
    if imgui.BeginPopupModal("New Contact", nil, messengerModalFlags()) then
        imgui.SetWindowFontScale(CONFIG.fontScale)
        drawModalHeading("Start a new conversation", "Add a phone number to begin messaging.")

        local phoneEntered = drawMessengerInput("##newphone", "Phone number", "Enter phone number", state.newContactPhone, 32)
        imgui.Spacing()
        local nameEntered = drawMessengerInput("##newname", "Contact name", "Optional", state.newContactName, 64)

        local phone = ffi.string(state.newContactPhone):gsub("%s+", "")
        local name = ffi.string(state.newContactName):gsub("^%s*", ""):gsub("%s*$", "")
        local canStart = phone ~= ""

        imgui.Spacing()
        imgui.Spacing()
        local cancelClicked, startClicked = drawModalActions("Start chat", canStart, false)
        if cancelClicked then
            state.showNewContactDialog = false
            imgui.CloseCurrentPopup()
        elseif (startClicked or phoneEntered or nameEntered) and canStart then
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
                for _, contact in ipairs(state.contacts) do
                    if contact.phone == phone then
                        state.selectedContact = contact
                        break
                    end
                end
                state.scrollToBottom = true
            end

            state.showNewContactDialog = false
            imgui.CloseCurrentPopup()
        end
        imgui.EndPopup()
    end
    popMessengerModalStyle()
end

M.drawDeleteConfirmDialog = function()
    if not state.showDeleteConfirmDialog then return end

    helpers.centerDialog(imgui, scaled, 380, 235)
    pushMessengerModalStyle()
    if imgui.BeginPopupModal("Confirm Delete", nil, messengerModalFlags()) then
        imgui.SetWindowFontScale(CONFIG.fontScale)
        drawModalHeading("Delete this conversation?", "The contact and message history will be removed.")

        local name = cp1251_to_utf8(state.deleteContactName or "")
        local phone = state.deleteContactPhone or ""
        drawContactSummary(name, phone)
        imgui.Spacing()
        imgui.TextColored(imgui.ImVec4(0.9, 0.3, 0.3, 1.0), "This action cannot be undone.")

        imgui.Spacing()
        imgui.Spacing()
        local cancelClicked, deleteClicked = drawModalActions("Delete", phone ~= "", true)
        if cancelClicked then
            state.showDeleteConfirmDialog = false
            state.deleteContactName = ""
            state.deleteContactPhone = ""
            imgui.CloseCurrentPopup()
        elseif deleteClicked then
            deleteContact(phone)
            local serverKey = getCurrentServerKey()
            if serverKey then
                state.contacts = getContactsList(serverKey)
                state.filteredContacts = filterContacts(ffi.string(state.searchText))
            end
            state.showDeleteConfirmDialog = false
            state.deleteContactName = ""
            state.deleteContactPhone = ""
            imgui.CloseCurrentPopup()
        end
        imgui.EndPopup()
    end
    popMessengerModalStyle()
end

M.drawEditContactDialog = function()
    if not state.showEditContactDialog then return end

    helpers.centerDialog(imgui, scaled, 380, 270)
    pushMessengerModalStyle()
    if imgui.BeginPopupModal("Edit Contact", nil, messengerModalFlags()) then
        imgui.SetWindowFontScale(CONFIG.fontScale)
        drawModalHeading("Contact details", "Update the name or phone number for this chat.")

        local phoneEntered = drawMessengerInput("##editphone", "Phone number", "Enter phone number", state.editContactPhone, 32)
        imgui.Spacing()
        local nameEntered = drawMessengerInput("##editname", "Contact name", "Enter contact name", state.editContactName, 64)

        local newPhone = ffi.string(state.editContactPhone):gsub("%s+", "")
        local newName = ffi.string(state.editContactName):gsub("^%s*", ""):gsub("%s*$", "")
        local canSave = newPhone ~= "" and newName ~= "" and state.selectedContact ~= nil

        imgui.Spacing()
        imgui.Spacing()
        local cancelClicked, saveClicked = drawModalActions("Save changes", canSave, false)
        if cancelClicked then
            state.showEditContactDialog = false
            imgui.CloseCurrentPopup()
        elseif (saveClicked or phoneEntered or nameEntered) and canSave then
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
                    for _, updatedContact in ipairs(state.contacts) do
                        if updatedContact.phone == newPhone then
                            state.selectedContact = updatedContact
                            break
                        end
                    end
                end
            end

            state.showEditContactDialog = false
            imgui.CloseCurrentPopup()
        end
        imgui.EndPopup()
    end
    popMessengerModalStyle()
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
