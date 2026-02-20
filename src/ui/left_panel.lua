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
end

M.drawLeftPanel = function()
    if not CONFIG.colors then return end
    
    local style = imgui.GetStyle()
    local drawList = imgui.GetWindowDrawList()
    local windowPos = imgui.GetWindowPos()
    local windowSize = imgui.GetWindowSize()
    
    -- Responsive breakpoint at 600px
    local isMobile = windowSize.x < 600
    
    -- In mobile mode, don't draw left panel if a contact is selected
    if isMobile and state.selectedContact then return end
    
    -- Panel width: full width in mobile, fixed in desktop
    local panelWidth = isMobile and windowSize.x or scaled(CONFIG.leftPanelWidth)
    
    -- Left panel background
    drawList:AddRectFilled(
        windowPos,
        imgui.ImVec2(windowPos.x + panelWidth, windowPos.y + windowSize.y),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.leftPanel)
    )
    
    -- Header with icon/title and new message button
    imgui.SetCursorPos(imgui.ImVec2(scaled(15), scaled(15)))
    imgui.TextColored(CONFIG.colors.textDark, "SMS Messenger")
    
    -- Theme toggle button
    local btnSize = imgui.ImVec2(scaled(28), scaled(28))
    local themeIcon = CONFIG.currentTheme == "light" and "D" or "L"
    -- Position: leftmost of the three buttons
    local themeBtnX = panelWidth - scaled(113)
    imgui.SetCursorPos(imgui.ImVec2(themeBtnX, scaled(11)))
    imgui.PushStyleColor(imgui.Col.Button, CONFIG.colors.searchBg)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, CONFIG.colors.selected)
    imgui.PushStyleColor(imgui.Col.ButtonActive, CONFIG.colors.border)
    imgui.PushStyleColor(imgui.Col.Text, CONFIG.colors.textDark)
    if imgui.Button(themeIcon .. "##theme", btnSize) then
        local newTheme = CONFIG.currentTheme == "light" and "dark" or "light"
        applyTheme(newTheme)
    end
    imgui.PopStyleColor(4)
    
    -- Settings button (sound icon)
    -- Position: middle of the three buttons
    local settingsBtnX = panelWidth - scaled(78)
    imgui.SetCursorPos(imgui.ImVec2(settingsBtnX, scaled(11)))
    imgui.PushStyleColor(imgui.Col.Button, CONFIG.colors.searchBg)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, CONFIG.colors.selected)
    imgui.PushStyleColor(imgui.Col.ButtonActive, CONFIG.colors.border)
    imgui.PushStyleColor(imgui.Col.Text, CONFIG.colors.textDark)
    local soundIcon = CONFIG.soundEnabled and "S" or "M"
    if imgui.Button(soundIcon .. "##settings", btnSize) then
        state.showSettingsDialog = true
        imgui.OpenPopup("Settings")
    end
    imgui.PopStyleColor(4)
    
    -- New Message button (+ icon)
    -- Position: rightmost of the three buttons
    local newMsgBtnX = panelWidth - scaled(43)
    imgui.SetCursorPos(imgui.ImVec2(newMsgBtnX, scaled(11)))
    imgui.PushStyleColor(imgui.Col.Button, CONFIG.colors.primary)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, CONFIG.colors.primaryHover)
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.0, 0.4, 0.85, 1.0))
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1, 1, 1, 1))
    if imgui.Button("+##newmsg", btnSize) then
        state.showNewContactDialog = true
        state.newContactPhone[0] = 0
        state.newContactName[0] = 0
        imgui.OpenPopup("New Contact")
    end
    imgui.PopStyleColor(4)
    
    -- Search bar
    local searchHeight = scaled(32)
    imgui.SetCursorPos(imgui.ImVec2(scaled(15), scaled(48)))
    imgui.PushItemWidth(panelWidth - scaled(30))
    
    -- Search background
    local searchPos = imgui.GetCursorScreenPos()
    drawList:AddRectFilled(
        searchPos,
        imgui.ImVec2(searchPos.x + panelWidth - scaled(30), searchPos.y + searchHeight),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.searchBg),
        scaled(16.0)
    )
    
    -- Устанавливаем высоту инпута поиска через прямое изменение стиля
    local fontSize = imgui.GetFontSize()
    local framePaddingY = math.max(4, (searchHeight - fontSize) / 2)
    local style = imgui.GetStyle()
    local oldFramePadding = { style.FramePadding.x, style.FramePadding.y }
    style.FramePadding = imgui.ImVec2(scaled(10), framePaddingY)
    
    imgui.SetCursorPosX(scaled(22))
    if imgui.InputText("##search", state.searchText, 256) then
        state.filteredContacts = filterContacts(ffi.string(state.searchText))
    end
    
    -- Восстанавливаем стиль
    style.FramePadding = imgui.ImVec2(oldFramePadding[1], oldFramePadding[2])
    imgui.PopItemWidth()
    
    -- Separator
    local separatorY = scaled(98)
    imgui.SetCursorPosY(separatorY)
    drawList:AddLine(
        imgui.ImVec2(windowPos.x + scaled(15), windowPos.y + separatorY),
        imgui.ImVec2(windowPos.x + panelWidth - scaled(15), windowPos.y + separatorY),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.border),
        1.0
    )
    
    -- Contacts list
    imgui.SetCursorPos(imgui.ImVec2(0, scaled(103)))
    imgui.BeginChild("ContactsList", imgui.ImVec2(panelWidth, windowSize.y - scaled(105)), false)
    
    local contactsToShow = state.filteredContacts
    if #contactsToShow == 0 then
        contactsToShow = state.contacts
    end
    
    -- Animation offset for slide-in effect
    local contactAnimOffset = 0
    if state.windowOpenAnim < 1.0 then
        contactAnimOffset = (1.0 - easeOutCubic(state.windowOpenAnim)) * 50
    end
    
    for i, contact in ipairs(contactsToShow) do
        local isSelected = state.selectedContact and state.selectedContact.phone == contact.phone
        
        -- Contact item with staggered slide-in animation
        local itemPos = imgui.GetCursorScreenPos()
        local itemHeight = scaled(70)
        local staggerDelay = i * 0.05  -- 50ms delay per item
        local itemAnimProgress = math.max(0, math.min(1, (state.windowOpenAnim - staggerDelay) / (1 - staggerDelay)))
        local itemSlideOffset = (1.0 - easeOutBack(itemAnimProgress)) * 30  -- slide from left
        local itemAlpha = easeOutCubic(itemAnimProgress)
        
        -- Check hover for animation
        local itemMin = imgui.ImVec2(windowPos.x, itemPos.y)
        local itemMax = imgui.ImVec2(windowPos.x + panelWidth, itemPos.y + itemHeight)
        local mousePos = imgui.GetMousePos()
        local isHovered = (mousePos.x >= itemMin.x and mousePos.x <= itemMax.x and 
                          mousePos.y >= itemMin.y and mousePos.y <= itemMax.y)
        
        -- Update hover animation state
        if not state.contactHover then state.contactHover = {} end
        if not state.contactHover[i] then state.contactHover[i] = 0 end
        
        if isHovered then
            state.contactHover[i] = math.min(state.contactHover[i] + 0.15, 1.0)
        else
            state.contactHover[i] = math.max(state.contactHover[i] - 0.15, 0.0)
        end
        
        -- Selection background with hover animation
        if isSelected then
            drawList:AddRectFilled(
                itemMin,
                itemMax,
                imgui.ColorConvertFloat4ToU32(CONFIG.colors.selected)
            )
        elseif state.contactHover[i] > 0 then
            -- Animated hover background
            local hoverColor = imgui.ImVec4(
                CONFIG.colors.selected.x,
                CONFIG.colors.selected.y,
                CONFIG.colors.selected.z,
                CONFIG.colors.selected.w * state.contactHover[i] * 0.5  -- half opacity max
            )
            drawList:AddRectFilled(
                itemMin,
                itemMax,
                imgui.ColorConvertFloat4ToU32(hoverColor)
            )
        end
        
        -- Apply slide animation to positions
        local slideX = itemSlideOffset
        
        -- Avatar circle with animation
        local avatarPos = imgui.ImVec2(itemPos.x + scaled(12) + slideX, itemPos.y + scaled(8))
        local avatarAlpha = itemAlpha
        
        local primaryWithAlpha = imgui.ImVec4(
            CONFIG.colors.primary.x, CONFIG.colors.primary.y, CONFIG.colors.primary.z,
            avatarAlpha
        )
        drawList:AddCircleFilled(
            imgui.ImVec2(avatarPos.x + scaled(18), avatarPos.y + scaled(18)),
            scaled(18),
            imgui.ColorConvertFloat4ToU32(primaryWithAlpha)
        )
        
        -- Initial letter with animation
        local contactName = cp1251_to_utf8(tostring(contact.name or "?"))
        local initial = contactName:sub(1, 1):upper()
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
        
        -- Online status indicator (small circle at bottom-right of avatar) with animation
        local isOnline = isContactOnline(contact.name)
        local statusBaseColor = isOnline and 
            imgui.ImVec4(0.3, 0.85, 0.39, itemAlpha) or  -- green (online)
            imgui.ImVec4(0.56, 0.56, 0.58, itemAlpha)     -- gray (offline)
        local statusPos = imgui.ImVec2(avatarPos.x + scaled(28), avatarPos.y + scaled(28))
        drawList:AddCircleFilled(statusPos, scaled(6), imgui.ColorConvertFloat4ToU32(statusBaseColor))
        local whiteWithAlpha = imgui.ImVec4(1, 1, 1, itemAlpha)
        drawList:AddCircle(statusPos, scaled(6), imgui.ColorConvertFloat4ToU32(whiteWithAlpha), 12, scaled(2))  -- white border
        
        -- Name (brighter color if unread to indicate importance) with animation
        imgui.SetCursorPos(imgui.ImVec2(scaled(60) + slideX, (i - 1) * itemHeight + scaled(10)))
        local nameColor = (contact.unreadCount or 0) > 0 and CONFIG.colors.primary or CONFIG.colors.textDark
        local nameColorWithAlpha = imgui.ImVec4(nameColor.x, nameColor.y, nameColor.z, itemAlpha)
        imgui.TextColored(nameColorWithAlpha, contactName)
        
        -- Last message preview with animation
        imgui.SetCursorPos(imgui.ImVec2(scaled(60) + slideX, (i - 1) * itemHeight + scaled(30)))
        local preview = cp1251_to_utf8(tostring(contact.lastMessage or "No messages"))
        if #preview > 28 then
            preview = preview:sub(1, 28) .. "..."
        end
        local previewColorWithAlpha = imgui.ImVec4(CONFIG.colors.textGray.x, CONFIG.colors.textGray.y, CONFIG.colors.textGray.z, itemAlpha)
        imgui.TextColored(previewColorWithAlpha, preview)
        
        -- Time with animation
        local timeStr = tostring(formatTime(contact.lastTimestamp) or "")
        if timeStr ~= "" then
            local timeSize = imgui.CalcTextSize(timeStr)
            imgui.SetCursorPos(imgui.ImVec2(panelWidth - timeSize.x - scaled(15), (i - 1) * itemHeight + scaled(10)))
            local timeColorWithAlpha = imgui.ImVec4(CONFIG.colors.textGray.x, CONFIG.colors.textGray.y, CONFIG.colors.textGray.z, itemAlpha)
            imgui.TextColored(timeColorWithAlpha, timeStr)
        end
        
        -- Unread indicator (blue dot with count) with pulse animation
        local unreadCount = contact.unreadCount or 0
        if unreadCount > 0 and itemAlpha > 0.5 then
            local dotRadius = scaled(5)
            local dotX = panelWidth - scaled(20) - slideX  -- counter-slide for fixed position
            local dotY = itemPos.y + itemHeight / 2
            
            -- Pulsing effect for unread indicator (scaled by item animation)
            local pulseScale = 1.0 + math.sin(state.newMessagePulse * math.pi * 2) * 0.2
            local pulseAlpha = (0.3 + math.sin(state.newMessagePulse * math.pi * 2) * 0.2) * itemAlpha
            
            -- Draw pulse halo
            local haloColor = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(
                CONFIG.colors.primary.x,
                CONFIG.colors.primary.y,
                CONFIG.colors.primary.z,
                pulseAlpha
            ))
            drawList:AddCircleFilled(
                imgui.ImVec2(windowPos.x + dotX, dotY),
                dotRadius * pulseScale * 1.5,
                haloColor
            )
            
            -- Draw main blue circle
            local mainDotColor = imgui.ImVec4(
                CONFIG.colors.primary.x, CONFIG.colors.primary.y, CONFIG.colors.primary.z,
                itemAlpha
            )
            drawList:AddCircleFilled(
                imgui.ImVec2(windowPos.x + dotX, dotY),
                dotRadius,
                imgui.ColorConvertFloat4ToU32(mainDotColor)
            )
            
            -- Draw white border
            local whiteWithAlpha = imgui.ImVec4(1, 1, 1, itemAlpha)
            drawList:AddCircle(
                imgui.ImVec2(windowPos.x + dotX, dotY),
                dotRadius,
                imgui.ColorConvertFloat4ToU32(whiteWithAlpha),
                12, scaled(1.5)
            )
            
            -- Draw count if more than 1
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
    
    imgui.EndChild()
end

return M
