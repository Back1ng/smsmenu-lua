local M = {}

local imgui = nil
local ffi = nil
local CONFIG = nil
local state = nil
local scaled = nil
local applyTheme = nil
local cp1251_to_utf8 = nil
local isContactOnline = nil
local filterContacts = nil
local easeOutCubic = nil
local easeOutBack = nil
local getCurrentServerKey = nil
local getContactsList = nil
local markContactAsRead = nil
local formatTime = nil
local helpers = nil
local design = nil
local i18n = nil

function M.init(deps)
    imgui = deps.imgui
    ffi = deps.ffi
    CONFIG = deps.CONFIG
    state = deps.state
    scaled = deps.scaled
    applyTheme = deps.applyTheme
    cp1251_to_utf8 = deps.cp1251_to_utf8
    isContactOnline = deps.isContactOnline
    filterContacts = deps.filterContacts
    easeOutCubic = deps.easeOutCubic
    easeOutBack = deps.easeOutBack
    getCurrentServerKey = deps.getCurrentServerKey
    getContactsList = deps.getContactsList
    markContactAsRead = deps.markContactAsRead
    formatTime = deps.formatTime
    helpers = deps.helpers
    design = deps.design
    i18n = deps.i18n
end

local function drawAvatar(drawList, scaled, avatarPos, initial, isOnline, itemAlpha, CONFIG)
    local primaryWithAlpha = imgui.ImVec4(
        CONFIG.colors.primary.x, CONFIG.colors.primary.y, CONFIG.colors.primary.z,
        itemAlpha
    )
    drawList:AddCircleFilled(
        imgui.ImVec2(avatarPos.x + scaled(18), avatarPos.y + scaled(18)),
        scaled(18),
        imgui.ColorConvertFloat4ToU32(primaryWithAlpha)
    )
    
    local textSize = imgui.CalcTextSize(initial)
    local textLightWithAlpha = imgui.ImVec4(
        CONFIG.colors.textLight.x, CONFIG.colors.textLight.y, CONFIG.colors.textLight.z,
        itemAlpha
    )
    drawList:AddText(
        imgui.ImVec2(avatarPos.x + scaled(18) - textSize.x / 2, avatarPos.y + scaled(18) - textSize.y / 2),
        imgui.ColorConvertFloat4ToU32(textLightWithAlpha),
        initial
    )
    
    local statusBaseColor = design.withAlpha(
        isOnline and CONFIG.colors.statusOnline or CONFIG.colors.statusOffline,
        itemAlpha
    )
    local statusPos = imgui.ImVec2(avatarPos.x + scaled(28), avatarPos.y + scaled(28))
    drawList:AddCircleFilled(statusPos, scaled(6), imgui.ColorConvertFloat4ToU32(statusBaseColor))
    local whiteWithAlpha = imgui.ImVec4(1, 1, 1, itemAlpha)
    drawList:AddCircle(statusPos, scaled(6), imgui.ColorConvertFloat4ToU32(whiteWithAlpha), 12, scaled(2))
end

local function drawContactInfo(imgui, scaled, panelWidth, itemHeight, slideX, i, contact, contactName, timeStr, itemAlpha, CONFIG)
    imgui.SetCursorPos(imgui.ImVec2(scaled(60) + slideX, (i - 1) * itemHeight + scaled(8)))
    local isUnread = (contact.unreadCount or 0) > 0
    local nameColor = CONFIG.colors.textDark
    local nameColorWithAlpha = imgui.ImVec4(nameColor.x, nameColor.y, nameColor.z, itemAlpha)
    imgui.TextColored(nameColorWithAlpha, contactName)
    if isUnread then
        imgui.SetCursorPos(imgui.ImVec2(scaled(61) + slideX, (i - 1) * itemHeight + scaled(8)))
        imgui.TextColored(nameColorWithAlpha, contactName)
    end
    
    imgui.SetCursorPos(imgui.ImVec2(scaled(60) + slideX, (i - 1) * itemHeight + scaled(29)))
    local preview
    if contact.lastMessage then
        local previewRaw = tostring(contact.lastMessage)
        if #previewRaw > 24 then
            previewRaw = previewRaw:sub(1, 24) .. "..."
        end
        preview = cp1251_to_utf8(previewRaw)
    else
        preview = i18n.t("no_messages")
    end
    local previewColorWithAlpha = imgui.ImVec4(CONFIG.colors.textGray.x, CONFIG.colors.textGray.y, CONFIG.colors.textGray.z, itemAlpha)
    imgui.TextColored(previewColorWithAlpha, preview)
    
    if timeStr ~= "" then
        local timeSize = imgui.CalcTextSize(timeStr)
        imgui.SetCursorPos(imgui.ImVec2(panelWidth - timeSize.x - scaled(15), (i - 1) * itemHeight + scaled(8)))
        local timeColorWithAlpha = imgui.ImVec4(CONFIG.colors.textGray.x, CONFIG.colors.textGray.y, CONFIG.colors.textGray.z, itemAlpha)
        imgui.TextColored(timeColorWithAlpha, timeStr)
    end
end

local function drawUnreadBadge(drawList, scaled, windowPos, panelWidth, itemPos, itemHeight, slideX, unreadCount, itemAlpha, CONFIG)
    local countStr = unreadCount > 99 and "99+" or tostring(unreadCount)
    local countSize = imgui.CalcTextSize(countStr)
    local badgeHeight = scaled(18)
    local badgeRadius = badgeHeight / 2
    local badgeWidth = math.max(scaled(22), countSize.x + scaled(14))
    local badgeRight = windowPos.x + panelWidth - scaled(12) - slideX
    local badgeLeft = badgeRight - badgeWidth
    local badgeCenterY = itemPos.y + itemHeight / 2
    local badgeTop = badgeCenterY - badgeHeight / 2
    local badgeBottom = badgeCenterY + badgeHeight / 2

    local badgeColor = imgui.ColorConvertFloat4ToU32(
        imgui.ImVec4(CONFIG.colors.primary.x, CONFIG.colors.primary.y, CONFIG.colors.primary.z, itemAlpha)
    )
    drawList:AddRectFilled(
        imgui.ImVec2(badgeLeft + badgeRadius, badgeTop),
        imgui.ImVec2(badgeRight - badgeRadius, badgeBottom),
        badgeColor
    )
    drawList:AddCircleFilled(imgui.ImVec2(badgeLeft + badgeRadius, badgeCenterY), badgeRadius, badgeColor)
    drawList:AddCircleFilled(imgui.ImVec2(badgeRight - badgeRadius, badgeCenterY), badgeRadius, badgeColor)

    drawList:AddText(
        imgui.ImVec2(badgeLeft + (badgeWidth - countSize.x) / 2, badgeCenterY - countSize.y / 2),
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1, 1, 1, itemAlpha)),
        countStr
    )
end

local function drawHeader(panelWidth, isMobile)
    imgui.SetCursorPos(imgui.ImVec2(scaled(15), scaled(15)))
    imgui.TextColored(CONFIG.colors.textDark, i18n.t("app_title"))
    

    local iconSize = design.controlHeight("ICON")
    local btnSize = imgui.ImVec2(iconSize, iconSize)
    -- In mobile mode the global close button occupies the rightmost header slot.
    local closeButtonReserve = isMobile and design.controlHeight("LARGE") or 0
    local themeTooltip = CONFIG.currentTheme == "light" and i18n.t("theme_to_dark") or i18n.t("theme_to_light")
    local themeBtnX = panelWidth - scaled(114) - closeButtonReserve
    imgui.SetCursorPos(imgui.ImVec2(themeBtnX, scaled(10)))
    
    if helpers.drawIconButton(imgui, "##theme", "contrast", btnSize, design.button("neutral"), themeTooltip, design.radius("MD")) then
        local newTheme = CONFIG.currentTheme == "light" and "dark" or "light"
        applyTheme(newTheme)
    end
    
    -- Settings button
    local settingsBtnX = panelWidth - scaled(78) - closeButtonReserve
    imgui.SetCursorPos(imgui.ImVec2(settingsBtnX, scaled(10)))
    if helpers.drawIconButton(imgui, "##settings", "settings", btnSize, design.button("neutral"), i18n.t("settings"), design.radius("MD")) then
        state.showSettingsDialog = true
        imgui.OpenPopup(i18n.popupTitle("settings", "Settings"))
    end
    

    local newMsgBtnX = panelWidth - scaled(42) - closeButtonReserve
    imgui.SetCursorPos(imgui.ImVec2(newMsgBtnX, scaled(10)))
    if helpers.drawIconButton(imgui, "##newmsg", "plus", btnSize, design.button("primary"), i18n.t("new_conversation"), design.radius("MD")) then
        state.showNewContactDialog = true
        state.newContactPhone[0] = 0
        state.newContactName[0] = 0
        imgui.OpenPopup(i18n.popupTitle("new_contact", "NewContact"))
    end
    

    local searchHeight = design.controlHeight("COMPACT")
    imgui.SetCursorPos(imgui.ImVec2(scaled(15), scaled(44)))
    imgui.PushItemWidth(panelWidth - scaled(30))
    
    -- Match search input height/rounding to header button style
    local fontSize = imgui.GetFontSize()
    local framePaddingY = math.max(4, (searchHeight - fontSize) / 2)
    local style = imgui.GetStyle()
    local oldFramePadding = { style.FramePadding.x, style.FramePadding.y }
    local oldFrameRounding = style.FrameRounding
    style.FramePadding = imgui.ImVec2(scaled(30), framePaddingY)
    style.FrameRounding = design.radius("SM")

    local searchScreenPos = imgui.GetCursorScreenPos()
    local inputColors = design.inputColors()
    imgui.PushStyleColor(imgui.Col.FrameBg, inputColors.background)
    imgui.PushStyleColor(imgui.Col.FrameBgHovered, inputColors.hovered)
    imgui.PushStyleColor(imgui.Col.FrameBgActive, inputColors.active)
    imgui.PushStyleColor(imgui.Col.Text, inputColors.text)
    if imgui.InputText("##search", state.searchText, 256) then
        state.filteredContacts = filterContacts(ffi.string(state.searchText))
    end
    imgui.PopStyleColor(4)

    local drawList = imgui.GetWindowDrawList()
    local iconColor = imgui.ColorConvertFloat4ToU32(CONFIG.colors.textGray)
    local iconCenter = imgui.ImVec2(searchScreenPos.x + scaled(15), searchScreenPos.y + searchHeight / 2 - scaled(1))
    drawList:AddCircle(iconCenter, scaled(5), iconColor, 12, scaled(1.5))
    drawList:AddLine(
        imgui.ImVec2(iconCenter.x + scaled(4), iconCenter.y + scaled(4)),
        imgui.ImVec2(iconCenter.x + scaled(8), iconCenter.y + scaled(8)),
        iconColor,
        scaled(1.5)
    )

    if ffi.string(state.searchText) == "" then
        local placeholder = i18n.t("search")
        local placeholderSize = imgui.CalcTextSize(placeholder)
        local placeholderColor = imgui.ImVec4(CONFIG.colors.textGray.x, CONFIG.colors.textGray.y, CONFIG.colors.textGray.z, 0.85)
        drawList:AddText(
            imgui.ImVec2(searchScreenPos.x + scaled(30), searchScreenPos.y + (searchHeight - placeholderSize.y) / 2),
            imgui.ColorConvertFloat4ToU32(placeholderColor),
            placeholder
        )
    end
    

    style.FramePadding = imgui.ImVec2(oldFramePadding[1], oldFramePadding[2])
    style.FrameRounding = oldFrameRounding
    imgui.PopItemWidth()
end

local function drawContactItem(i, contact, drawList, windowPos, panelWidth)
    local isSelected = state.selectedContact and state.selectedContact.phone == contact.phone
    
    -- Contact item with staggered slide-in animation
    local itemPos = imgui.GetCursorScreenPos()
    local itemHeight = scaled(CONFIG.CONSTANTS.UI.PANEL.LIST_ITEM_HEIGHT)
    local staggerDelay = i * CONFIG.CONSTANTS.ANIMATION.LIST_STAGGER_DELAY
    local itemAnimProgress = math.max(0, math.min(1, (state.windowOpenAnim - staggerDelay) / (1 - staggerDelay)))
    local itemSlideOffset = (1.0 - easeOutBack(itemAnimProgress)) * 30  -- slide from left
    local itemAlpha = easeOutCubic(itemAnimProgress)
    

    local itemMin = imgui.ImVec2(windowPos.x, itemPos.y)
    local itemMax = imgui.ImVec2(windowPos.x + panelWidth, itemPos.y + itemHeight)
    local mousePos = imgui.GetMousePos()
    local isHovered = (mousePos.x >= itemMin.x and mousePos.x <= itemMax.x and 
                      mousePos.y >= itemMin.y and mousePos.y <= itemMax.y)
    

    if not state.contactHover then state.contactHover = {} end
    if not state.contactHover[i] then state.contactHover[i] = 0 end
    
    if isHovered then
        state.contactHover[i] = math.min(state.contactHover[i] + CONFIG.CONSTANTS.ANIMATION.HOVER_SPEED, 1.0)
    else
        state.contactHover[i] = math.max(state.contactHover[i] - CONFIG.CONSTANTS.ANIMATION.HOVER_SPEED, 0.0)
    end
    

    if isSelected then
        local selectedColor = CONFIG.colors.contactSelected
        drawList:AddRectFilled(
            itemMin,
            itemMax,
            imgui.ColorConvertFloat4ToU32(selectedColor)
        )
        drawList:AddRectFilled(
            itemMin,
            imgui.ImVec2(itemMin.x + design.stroke("ACCENT"), itemMax.y),
            imgui.ColorConvertFloat4ToU32(CONFIG.colors.primary)
        )
    elseif state.contactHover[i] > 0 then

        local rowHover = CONFIG.colors.contactHover
        local hoverColor = imgui.ImVec4(
            rowHover.x,
            rowHover.y,
            rowHover.z,
            rowHover.w * state.contactHover[i]
        )
        drawList:AddRectFilled(
            itemMin,
            itemMax,
            imgui.ColorConvertFloat4ToU32(hoverColor)
        )
    end
    
    local slideX = itemSlideOffset
    

    local avatarPos = imgui.ImVec2(
        itemPos.x + scaled(12) + slideX,
        itemPos.y + (itemHeight - scaled(36)) / 2
    )
    local contactNameRaw = tostring(contact.name or "?")
    local contactName = cp1251_to_utf8(contactNameRaw)
    local initial = cp1251_to_utf8(contactNameRaw:sub(1, 1)):upper()
    local isOnline = isContactOnline(contact.name)
    
    drawAvatar(drawList, scaled, avatarPos, initial, isOnline, itemAlpha, CONFIG)
    
    -- Name, Message Preview, and Time
    local timeStr = tostring(formatTime(contact.lastTimestamp) or "")
    drawContactInfo(imgui, scaled, panelWidth, itemHeight, slideX, i, contact, contactName, timeStr, itemAlpha, CONFIG)
    
    -- Unread indicator
    local unreadCount = contact.unreadCount or 0
    if unreadCount > 0 and itemAlpha > 0.5 then
        drawUnreadBadge(drawList, scaled, windowPos, panelWidth, itemPos, itemHeight, slideX, unreadCount, itemAlpha, CONFIG)
    end
    
    -- Click handler
    imgui.SetCursorPos(imgui.ImVec2(0, (i - 1) * itemHeight))
    if imgui.InvisibleButton("##contact_" .. i, imgui.ImVec2(panelWidth, itemHeight)) then
        state.selectedContact = contact
        state.scrollToBottom = true
        state.lastScrollMax = 0
        -- Mark as read when selecting contact
        markContactAsRead(contact.phone)
        -- Refresh contacts list to re-sort
        local serverKey = getCurrentServerKey()
        if serverKey then
            state.contacts = getContactsList(serverKey)
            state.filteredContacts = filterContacts(ffi.string(state.searchText))
        end
    end
    
    imgui.SetCursorPosY(i * itemHeight)
end

M.drawLeftPanel = function()
    if not CONFIG.colors then return end
    
    local style = imgui.GetStyle()
    local drawList = imgui.GetWindowDrawList()
    local windowPos = imgui.GetWindowPos()
    local windowSize = imgui.GetWindowSize()
    

    local isMobile = windowSize.x < CONFIG.CONSTANTS.UI.MOBILE_BREAKPOINT
    
    -- In mobile mode, don't draw left panel if a contact is selected
    if isMobile and state.selectedContact then return end
    
    -- Panel width: full width in mobile, fixed in desktop
    local panelWidth = isMobile and windowSize.x or scaled(CONFIG.leftPanelWidth)
    

    drawList:AddRectFilled(
        windowPos,
        imgui.ImVec2(windowPos.x + panelWidth, windowPos.y + windowSize.y),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.leftPanel)
    )
    
    drawHeader(panelWidth, isMobile)
    
    -- Separator
    local separatorY = scaled(77)
    imgui.SetCursorPosY(separatorY)
    drawList:AddLine(
        imgui.ImVec2(windowPos.x + scaled(15), windowPos.y + separatorY),
        imgui.ImVec2(windowPos.x + panelWidth - scaled(15), windowPos.y + separatorY),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.border),
        1.0
    )
    

    imgui.SetCursorPos(imgui.ImVec2(0, scaled(80)))
    
    helpers.withStyle(imgui, {
        [imgui.Col.ScrollbarBg] = CONFIG.colors.leftPanel,
        [imgui.Col.ScrollbarGrab] = CONFIG.colors.scrollbarGrab,
        [imgui.Col.ScrollbarGrabHovered] = CONFIG.colors.scrollbarGrabHovered,
        [imgui.Col.ScrollbarGrabActive] = CONFIG.colors.scrollbarGrabActive
    }, nil, function()
        imgui.BeginChild("ContactsList", imgui.ImVec2(panelWidth, windowSize.y - scaled(105)), false)
        
        local innerDrawList = imgui.GetWindowDrawList()
        
        local contactsToShow = state.filteredContacts
        if #contactsToShow == 0 then
            contactsToShow = state.contacts
        end
        
        for i, contact in ipairs(contactsToShow) do
            drawContactItem(i, contact, innerDrawList, windowPos, panelWidth)
        end
    
        imgui.EndChild()
    end)
end

return M
