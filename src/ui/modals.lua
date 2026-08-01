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
local design = nil
local i18n = nil

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
    design = deps.design
    i18n = deps.i18n
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

    local inputHeight = design.controlHeight("DEFAULT")
    local fontSize = imgui.GetFontSize()
    local framePaddingY = math.max(4, (inputHeight - fontSize) / 2)
    local style = imgui.GetStyle()
    local oldFramePadding = { style.FramePadding.x, style.FramePadding.y }
    local oldFrameRounding = style.FrameRounding
    style.FramePadding = imgui.ImVec2(design.spacing("MD"), framePaddingY)
    style.FrameRounding = design.radius("MD")

    imgui.SetNextItemWidth(imgui.GetContentRegionAvail().x)
    local inputPos = imgui.GetCursorScreenPos()
    local inputColors = design.inputColors()
    imgui.PushStyleColor(imgui.Col.FrameBg, inputColors.background)
    imgui.PushStyleColor(imgui.Col.FrameBgHovered, inputColors.hovered)
    imgui.PushStyleColor(imgui.Col.FrameBgActive, inputColors.active)
    imgui.PushStyleColor(imgui.Col.Text, inputColors.text)
    local submitted = imgui.InputText(id, buffer, capacity, imgui.InputTextFlags.EnterReturnsTrue)
    local active = imgui.IsItemActive()
    imgui.PopStyleColor(4)

    if ffi.string(buffer) == "" and not active then
        local placeholderSize = imgui.CalcTextSize(placeholder)
        imgui.GetWindowDrawList():AddText(
            imgui.ImVec2(
                inputPos.x + design.spacing("MD"),
                inputPos.y + (inputHeight - placeholderSize.y) / 2
            ),
            imgui.ColorConvertFloat4ToU32(inputColors.placeholder),
            placeholder
        )
    end

    style.FramePadding = imgui.ImVec2(oldFramePadding[1], oldFramePadding[2])
    style.FrameRounding = oldFrameRounding
    return submitted
end

local function drawModalActions(confirmLabel, confirmEnabled, destructive)
    local availableWidth = imgui.GetContentRegionAvail().x
    local gap = design.spacing("SM")
    local buttonWidth = (availableWidth - gap) / 2
    local buttonHeight = design.controlHeight("DEFAULT")
    local style = imgui.GetStyle()
    local oldRounding = style.FrameRounding
    style.FrameRounding = design.radius("MD")

    local cancelClicked = helpers.drawStyledButton(
        imgui,
        i18n.t("cancel") .. "##modalcancel",
        imgui.ImVec2(buttonWidth, buttonHeight),
        design.button("neutral")
    )
    imgui.SameLine(0, gap)

    local confirmColors
    if not confirmEnabled then
        confirmColors = design.button("disabled")
    elseif destructive then
        confirmColors = design.button("danger")
    else
        confirmColors = design.button("primary")
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
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.surface),
        design.radius("MD")
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
    if imgui.BeginPopupModal(i18n.popupTitle("new_contact", "NewContact"), nil, messengerModalFlags()) then
        imgui.SetWindowFontScale(CONFIG.fontScale)
        drawModalHeading(i18n.t("start_conversation_title"), i18n.t("start_conversation_hint"))

        local phoneEntered = drawMessengerInput("##newphone", i18n.t("phone_number"), i18n.t("enter_phone"), state.newContactPhone, 32)
        imgui.Spacing()
        local nameEntered = drawMessengerInput("##newname", i18n.t("contact_name"), i18n.t("optional"), state.newContactName, 64)

        local phone = ffi.string(state.newContactPhone):gsub("%s+", "")
        local name = ffi.string(state.newContactName):gsub("^%s*", ""):gsub("%s*$", "")
        local canStart = phone ~= ""

        imgui.Spacing()
        imgui.Spacing()
        local cancelClicked, startClicked = drawModalActions(i18n.t("start_chat"), canStart, false)
        if cancelClicked then
            state.showNewContactDialog = false
            imgui.CloseCurrentPopup()
        elseif (startClicked or phoneEntered or nameEntered) and canStart then
            if name == "" then
                name = i18n.t("default_contact_name", phone)
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
    if imgui.BeginPopupModal(i18n.popupTitle("confirm_delete", "ConfirmDelete"), nil, messengerModalFlags()) then
        imgui.SetWindowFontScale(CONFIG.fontScale)
        drawModalHeading(i18n.t("delete_conversation_title"), i18n.t("delete_conversation_hint"))

        local name = cp1251_to_utf8(state.deleteContactName or "")
        local phone = state.deleteContactPhone or ""
        drawContactSummary(name, phone)
        imgui.Spacing()
        imgui.TextColored(CONFIG.colors.danger, i18n.t("irreversible_warning"))

        imgui.Spacing()
        imgui.Spacing()
        local cancelClicked, deleteClicked = drawModalActions(i18n.t("delete"), phone ~= "", true)
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
    if imgui.BeginPopupModal(i18n.popupTitle("edit_contact_title", "EditContact"), nil, messengerModalFlags()) then
        imgui.SetWindowFontScale(CONFIG.fontScale)
        drawModalHeading(i18n.t("contact_details"), i18n.t("contact_details_hint"))

        local phoneEntered = drawMessengerInput("##editphone", i18n.t("phone_number"), i18n.t("enter_phone"), state.editContactPhone, 32)
        imgui.Spacing()
        local nameEntered = drawMessengerInput("##editname", i18n.t("contact_name"), i18n.t("enter_contact_name"), state.editContactName, 64)

        local newPhone = ffi.string(state.editContactPhone):gsub("%s+", "")
        local newName = ffi.string(state.editContactName):gsub("^%s*", ""):gsub("%s*$", "")
        local canSave = newPhone ~= "" and newName ~= "" and state.selectedContact ~= nil

        imgui.Spacing()
        imgui.Spacing()
        local cancelClicked, saveClicked = drawModalActions(i18n.t("save_changes"), canSave, false)
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
    local surface = hovered and CONFIG.colors.surfaceHover or CONFIG.colors.surface
    local drawList = imgui.GetWindowDrawList()

    drawList:AddRectFilled(
        cursor,
        imgui.ImVec2(cursor.x + width, cursor.y + height),
        imgui.ColorConvertFloat4ToU32(surface),
        design.radius("MD")
    )
    drawList:AddText(
        imgui.ImVec2(cursor.x + design.spacing("MD"), cursor.y + design.spacing("SM")),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.textDark),
        title
    )
    drawList:AddText(
        imgui.ImVec2(cursor.x + design.spacing("MD"), cursor.y + scaled(29)),
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
    local surface = hovered and CONFIG.colors.surfaceHover or CONFIG.colors.surface
    local drawList = imgui.GetWindowDrawList()

    drawList:AddRectFilled(
        cursor,
        imgui.ImVec2(cursor.x + width, cursor.y + height),
        imgui.ColorConvertFloat4ToU32(surface),
        design.radius("MD")
    )
    drawList:AddText(
        imgui.ImVec2(cursor.x + design.spacing("MD"), cursor.y + scaled(7)),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.textDark),
        i18n.t("alert_sound")
    )
    drawList:AddText(
        imgui.ImVec2(cursor.x + design.spacing("MD"), cursor.y + scaled(26)),
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
                button = CONFIG.colors.surfaceHover,
                hovered = CONFIG.colors.surfaceHover,
                active = CONFIG.colors.surfaceActive,
                text = CONFIG.colors.primary
            } or design.button("neutral")
            if helpers.drawStyledButton(imgui, sound .. "##soundoption" .. i, imgui.ImVec2(imgui.GetContentRegionAvail().x, design.controlHeight("COMPACT")), colors) then
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

local function drawLanguageSelector()
    imgui.TextColored(CONFIG.colors.textDark, i18n.t("language"))
    imgui.Spacing()

    local width = imgui.GetContentRegionAvail().x
    local gap = design.spacing("SM")
    local buttonWidth = (width - gap) / 2
    local buttonHeight = design.controlHeight("DEFAULT")
    local style = imgui.GetStyle()
    local oldRounding = style.FrameRounding
    style.FrameRounding = design.radius("MD")

    local englishColors = CONFIG.language == "en" and design.button("primary") or design.button("neutral")
    if helpers.drawStyledButton(imgui, i18n.t("english") .. "##language_en", imgui.ImVec2(buttonWidth, buttonHeight), englishColors) then
        CONFIG.language = "en"
        saveSettings()
    end

    imgui.SameLine(0, gap)
    local russianColors = CONFIG.language == "ru" and design.button("primary") or design.button("neutral")
    if helpers.drawStyledButton(imgui, i18n.t("russian") .. "##language_ru", imgui.ImVec2(buttonWidth, buttonHeight), russianColors) then
        CONFIG.language = "ru"
        saveSettings()
    end

    style.FrameRounding = oldRounding
end

M.drawSettingsDialog = function()
    if not state.showSettingsDialog then return end

    helpers.centerDialog(imgui, scaled, 400, 465)
    imgui.PushStyleColor(imgui.Col.PopupBg, CONFIG.colors.background)
    imgui.PushStyleColor(imgui.Col.Border, CONFIG.colors.border)

    local flags = imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse
    if imgui.BeginPopupModal(i18n.popupTitle("settings", "Settings"), nil, flags) then
        imgui.SetWindowFontScale(CONFIG.fontScale)

        drawSettingsSection(i18n.t("section_notifications"))
        if drawSettingsToggle(
            "##soundenabled",
            i18n.t("sound_notifications"),
            i18n.t("sound_notifications_hint"),
            CONFIG.soundEnabled
        ) then
            CONFIG.soundEnabled = not CONFIG.soundEnabled
            saveSettings()
        end

        imgui.Spacing()
        if drawSettingsToggle(
            "##hidesms",
            i18n.t("messenger_only_sms"),
            i18n.t("messenger_only_sms_hint"),
            CONFIG.hideSMSFromChat
        ) then
            CONFIG.hideSMSFromChat = not CONFIG.hideSMSFromChat
            saveSettings()
        end

        imgui.Spacing()
        imgui.Spacing()
        drawSettingsSection(i18n.t("section_sound"))
        if #ALERT_SOUNDS > 0 then
            drawSoundSelector()
            imgui.Spacing()
            local testSoundColors = design.button("neutral")
            testSoundColors.text = CONFIG.colors.primary
            if helpers.drawStyledButton(imgui, i18n.t("play_selected_sound") .. "##testsound", imgui.ImVec2(imgui.GetContentRegionAvail().x, design.controlHeight("ICON")), testSoundColors) then
                playAlertSound()
            end
        else
            imgui.TextColored(CONFIG.colors.textGray, i18n.t("no_sounds_found"))
        end

        imgui.Spacing()
        imgui.Spacing()
        drawSettingsSection(i18n.t("section_appearance"))
        imgui.TextColored(CONFIG.colors.textDark, i18n.t("interface_scale"))
        local fontScale = imgui.new.float(CONFIG.fontScale)
        imgui.SetNextItemWidth(imgui.GetContentRegionAvail().x)
        if imgui.SliderFloat("##fontscale", fontScale, 0.8, 1.5, "%.1fx") then
            CONFIG.fontScale = fontScale[0]
            saveSettings()
        end

        imgui.Spacing()
        drawLanguageSelector()

        imgui.Spacing()
        imgui.Spacing()
        if helpers.drawStyledButton(imgui, i18n.t("done") .. "##closesettings", imgui.ImVec2(imgui.GetContentRegionAvail().x, design.controlHeight("DEFAULT")), design.button("primary")) then
            state.showSettingsDialog = false
            imgui.CloseCurrentPopup()
        end

        imgui.EndPopup()
    end
    imgui.PopStyleColor(2)
end

return M
