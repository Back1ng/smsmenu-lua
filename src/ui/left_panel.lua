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
    
    local statusBaseColor = isOnline and 
        imgui.ImVec4(0.3, 0.85, 0.39, itemAlpha) or
        imgui.ImVec4(0.56, 0.56, 0.58, itemAlpha)
    local statusPos = imgui.ImVec2(avatarPos.x + scaled(28), avatarPos.y + scaled(28))
    drawList:AddCircleFilled(statusPos, scaled(6), imgui.ColorConvertFloat4ToU32(statusBaseColor))
    local whiteWithAlpha = imgui.ImVec4(1, 1, 1, itemAlpha)
    drawList:AddCircle(statusPos, scaled(6), imgui.ColorConvertFloat4ToU32(whiteWithAlpha), 12, scaled(2))
end

local function drawContactInfo(imgui, scaled, panelWidth, itemHeight, slideX, i, contact, contactName, timeStr, itemAlpha, CONFIG)
    imgui.SetCursorPos(imgui.ImVec2(scaled(60) + slideX, (i - 1) * itemHeight + scaled(10)))
    local nameColor = (contact.unreadCount or 0) > 0 and CONFIG.colors.primary or CONFIG.colors.textDark
    local nameColorWithAlpha = imgui.ImVec4(nameColor.x, nameColor.y, nameColor.z, itemAlpha)
    imgui.TextColored(nameColorWithAlpha, contactName)
    
    imgui.SetCursorPos(imgui.ImVec2(scaled(60) + slideX, (i - 1) * itemHeight + scaled(30)))
    local previewRaw = tostring(contact.lastMessage or "No messages")
    if #previewRaw > 28 then
        previewRaw = previewRaw:sub(1, 28) .. "..."
    end
    local preview = cp1251_to_utf8(previewRaw)
    local previewColorWithAlpha = imgui.ImVec4(CONFIG.colors.textGray.x, CONFIG.colors.textGray.y, CONFIG.colors.textGray.z, itemAlpha)
    imgui.TextColored(previewColorWithAlpha, preview)
    
    if timeStr ~= "" then
        local timeSize = imgui.CalcTextSize(timeStr)
        imgui.SetCursorPos(imgui.ImVec2(panelWidth - timeSize.x - scaled(15), (i - 1) * itemHeight + scaled(10)))
        local timeColorWithAlpha = imgui.ImVec4(CONFIG.colors.textGray.x, CONFIG.colors.textGray.y, CONFIG.colors.textGray.z, itemAlpha)
        imgui.TextColored(timeColorWithAlpha, timeStr)
    end
end

local function drawUnreadBadge(drawList, scaled, windowPos, panelWidth, itemPos, itemHeight, slideX, unreadCount, itemAlpha, pulseScale, pulseAlpha, CONFIG)
    local dotRadius = scaled(5)
    local dotX = panelWidth - scaled(20) - slideX
    local dotY = itemPos.y + itemHeight / 2
    
    local haloColor = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(
        CONFIG.colors.primary.x, CONFIG.colors.primary.y, CONFIG.colors.primary.z, pulseAlpha
    ))
    drawList:AddCircleFilled(
        imgui.ImVec2(windowPos.x + dotX, dotY),
        dotRadius * pulseScale * 1.5,
        haloColor
    )
    
    local mainDotColor = imgui.ImVec4(CONFIG.colors.primary.x, CONFIG.colors.primary.y, CONFIG.colors.primary.z, itemAlpha)
    drawList:AddCircleFilled(
        imgui.ImVec2(windowPos.x + dotX, dotY),
        dotRadius,
        imgui.ColorConvertFloat4ToU32(mainDotColor)
    )
    
    local whiteWithAlpha = imgui.ImVec4(1, 1, 1, itemAlpha)
    drawList:AddCircle(
        imgui.ImVec2(windowPos.x + dotX, dotY),
        dotRadius,
        imgui.ColorConvertFloat4ToU32(whiteWithAlpha),
        12, scaled(1.5)
    )
    
    if unreadCount > 1 then
        local countStr = tostring(unreadCount)
        local countSize = imgui.CalcTextSize(countStr)
        drawList:AddText(
            imgui.ImVec2(windowPos.x + dotX - countSize.x / 2, dotY + dotRadius + scaled(2)),
            imgui.ColorConvertFloat4ToU32(CONFIG.colors.primary),
            countStr
        )
    end
end

local function drawHeader(panelWidth)
    imgui.SetCursorPos(imgui.ImVec2(scaled(15), scaled(15)))
    imgui.TextColored(CONFIG.colors.textDark, "SMS Messenger")
    

    local btnSize = imgui.ImVec2(scaled(28), scaled(28))
    local themeIcon = CONFIG.currentTheme == "light" and "D" or "L"
    local themeBtnX = panelWidth - scaled(113)
    imgui.SetCursorPos(imgui.ImVec2(themeBtnX, scaled(11)))
    
    if helpers.drawStyledButton(imgui, themeIcon .. "##theme", btnSize, {
        button = CONFIG.colors.searchBg,
        hovered = CONFIG.colors.selected,
        active = CONFIG.colors.border,
        text = CONFIG.colors.textDark
    }) then
        local newTheme = CONFIG.currentTheme == "light" and "dark" or "light"
        applyTheme(newTheme)
    end
    
    -- Settings button
    local settingsBtnX = panelWidth - scaled(78)
    imgui.SetCursorPos(imgui.ImVec2(settingsBtnX, scaled(11)))
    local soundIcon = CONFIG.soundEnabled and "S" or "M"
    if helpers.drawStyledButton(imgui, soundIcon .. "##settings", btnSize, {
        button = CONFIG.colors.searchBg,
        hovered = CONFIG.colors.selected,
        active = CONFIG.colors.border,
        text = CONFIG.colors.textDark
    }) then
        state.showSettingsDialog = true
        imgui.OpenPopup("Settings")
    end
    

    local newMsgBtnX = panelWidth - scaled(43)
    imgui.SetCursorPos(imgui.ImVec2(newMsgBtnX, scaled(11)))
    if helpers.drawStyledButton(imgui, "+##newmsg", btnSize, {
        button = CONFIG.colors.primary,
        hovered = CONFIG.colors.primaryHover,
        active = imgui.ImVec4(0.0, 0.4, 0.85, 1.0),
        text = imgui.ImVec4(1, 1, 1, 1)
    }) then
        state.showNewContactDialog = true
        state.newContactPhone[0] = 0
        state.newContactName[0] = 0
        imgui.OpenPopup("New Contact")
    end
    

    local searchHeight = scaled(28)
    imgui.SetCursorPos(imgui.ImVec2(scaled(15), scaled(44)))
    imgui.PushItemWidth(panelWidth - scaled(30))
    
    -- Match search input height/rounding to header button style
    local fontSize = imgui.GetFontSize()
    local framePaddingY = math.max(4, (searchHeight - fontSize) / 2)
    local style = imgui.GetStyle()
    local oldFramePadding = { style.FramePadding.x, style.FramePadding.y }
    local oldFrameRounding = style.FrameRounding
    style.FramePadding = imgui.ImVec2(scaled(10), framePaddingY)
    style.FrameRounding = scaled(5)
    
    if imgui.InputText("##search", state.searchText, 256) then
        state.filteredContacts = filterContacts(ffi.string(state.searchText))
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
        drawList:AddRectFilled(
            itemMin,
            itemMax,
            imgui.ColorConvertFloat4ToU32(CONFIG.colors.selected)
        )
    elseif state.contactHover[i] > 0 then

        local hoverColor = imgui.ImVec4(
            CONFIG.colors.selected.x,
            CONFIG.colors.selected.y,
            CONFIG.colors.selected.z,
            CONFIG.colors.selected.w * state.contactHover[i] * CONFIG.CONSTANTS.ANIMATION.HOVER_MAX_OPACITY
        )
        drawList:AddRectFilled(
            itemMin,
            itemMax,
            imgui.ColorConvertFloat4ToU32(hoverColor)
        )
    end
    
    local slideX = itemSlideOffset
    

    local avatarPos = imgui.ImVec2(itemPos.x + scaled(12) + slideX, itemPos.y + scaled(8))
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
        local pulseScale = 1.0 + math.sin(state.newMessagePulse * math.pi * 2) * CONFIG.CONSTANTS.ANIMATION.PULSE_SCALE
        local pulseAlpha = (CONFIG.CONSTANTS.ANIMATION.PULSE_BASE_ALPHA + math.sin(state.newMessagePulse * math.pi * 2) * CONFIG.CONSTANTS.ANIMATION.PULSE_SCALE) * itemAlpha
        
        drawUnreadBadge(drawList, scaled, windowPos, panelWidth, itemPos, itemHeight, slideX, unreadCount, itemAlpha, pulseScale, pulseAlpha, CONFIG)
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
    
    drawHeader(panelWidth)
    
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
