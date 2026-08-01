local M = {}

local CONFIG = nil
local TextMetrics = nil
local imgui = nil
local state = nil
local scaled = nil
local getCurrentServerKey = nil
local smsData = nil
local cp1251_to_utf8 = nil
local isContactOnline = nil
local sampSendChat = nil
local MessageService = nil
local ffi = nil
local helpers = nil
local design = nil

function M.init(deps)
    CONFIG = deps.CONFIG
    TextMetrics = deps.TextMetrics
    imgui = deps.imgui
    state = deps.state
    scaled = deps.scaled
    getCurrentServerKey = deps.getCurrentServerKey
    smsData = deps.smsData
    cp1251_to_utf8 = deps.cp1251_to_utf8
    isContactOnline = deps.isContactOnline
    sampSendChat = deps.sampSendChat
    MessageService = deps.MessageService
    ffi = deps.ffi
    helpers = deps.helpers
    design = deps.design
end

local function drawMessageBubble(childDrawList, imgui, cursorScreenPos, cursorPosY, bubbleX, bubbleWidth, bubbleHeight, bubbleColor, textColor, msgText, fontScaleMultiplier, scaled, TextMetrics, stackPosition)
    local radius = design.radius("LG")
    if stackPosition == "middle" then
        radius = design.radius("MD")
    elseif stackPosition == "top" or stackPosition == "bottom" then
        radius = design.radius("LG")
    end

    childDrawList:AddRectFilled(
        imgui.ImVec2(cursorScreenPos.x + bubbleX, cursorScreenPos.y),
        imgui.ImVec2(cursorScreenPos.x + bubbleX + bubbleWidth, cursorScreenPos.y + bubbleHeight),
        imgui.ColorConvertFloat4ToU32(bubbleColor),
        radius
    )
    
    local textOffsetY = scaled(4)
    local indentWidth = TextMetrics.measureLeadingIndent(msgText, fontScaleMultiplier)
    local textStartX = bubbleX + scaled(14) + indentWidth
    
    imgui.SetCursorPos(imgui.ImVec2(textStartX, cursorPosY + textOffsetY))
    imgui.PushTextWrapPos(bubbleX + bubbleWidth - scaled(14))
    imgui.PushStyleColor(imgui.Col.Text, textColor)
    imgui.TextUnformatted(msgText)
    imgui.PopStyleColor()
    imgui.PopTextWrapPos()
end

local function drawMessageTime(imgui, timeStr, bubbleX, bubbleWidth, bubbleHeight, cursorPosY, isOutgoing, scaled, CONFIG)
    local timeSize = imgui.CalcTextSize(timeStr)
    local timeX = isOutgoing and (bubbleX + bubbleWidth - timeSize.x - scaled(2)) or (bubbleX + scaled(2))
    local timeY = cursorPosY + bubbleHeight + scaled(3)

    imgui.SetCursorPos(imgui.ImVec2(timeX, timeY))
    imgui.TextColored(CONFIG.colors.textGray, timeStr)
end

local monthNames = {
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
}

local function getDayKey(timestamp)
    timestamp = tonumber(timestamp)
    if not timestamp or timestamp == 0 then return "" end

    return os.date("%Y-%m-%d", timestamp) or ""
end

local function formatDateSeparator(timestamp)
    timestamp = tonumber(timestamp)
    if not timestamp or timestamp == 0 then return "" end

    local messageDate = os.date("*t", timestamp)
    local todayDate = os.date("*t", os.time())
    if not messageDate or not todayDate then return "" end

    local messageStart = os.time({year = messageDate.year, month = messageDate.month, day = messageDate.day, hour = 0, min = 0, sec = 0})
    local todayStart = os.time({year = todayDate.year, month = todayDate.month, day = todayDate.day, hour = 0, min = 0, sec = 0})
    local dayDiff = math.floor((todayStart - messageStart) / 86400)

    if dayDiff == 0 then
        return "Today"
    elseif dayDiff == 1 then
        return "Yesterday"
    end

    local monthName = monthNames[messageDate.month] or tostring(messageDate.month)
    return tostring(messageDate.day) .. " " .. monthName
end

local function drawDateSeparator(imgui, childDrawList, cursorScreenPos, rightPanelWidth, label, scaled, CONFIG)
    if label == "" then return end

    local labelSize = imgui.CalcTextSize(label)
    local pillWidth = labelSize.x + scaled(20)
    local pillHeight = labelSize.y + scaled(8)
    local pillX = (rightPanelWidth - pillWidth) / 2
    local pillY = cursorScreenPos.y + scaled(7)

    childDrawList:AddRectFilled(
        imgui.ImVec2(cursorScreenPos.x + pillX, pillY),
        imgui.ImVec2(cursorScreenPos.x + pillX + pillWidth, pillY + pillHeight),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.surface),
        pillHeight / 2
    )
    childDrawList:AddText(
        imgui.ImVec2(cursorScreenPos.x + pillX + scaled(10), pillY + scaled(4)),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.textGray),
        label
    )
end

local function drawConversationPlaceholder(drawList, areaMin, areaMax, title, subtitle)
    local centerX = (areaMin.x + areaMax.x) / 2
    local centerY = (areaMin.y + areaMax.y) / 2 - scaled(18)
    local iconColor = imgui.ColorConvertFloat4ToU32(CONFIG.colors.primary)
    local iconSurface = design.withAlpha(CONFIG.colors.primary, 0.12)

    drawList:AddCircleFilled(
        imgui.ImVec2(centerX, centerY - scaled(22)),
        scaled(24),
        imgui.ColorConvertFloat4ToU32(iconSurface),
        24
    )
    drawList:AddRect(
        imgui.ImVec2(centerX - scaled(10), centerY - scaled(29)),
        imgui.ImVec2(centerX + scaled(10), centerY - scaled(16)),
        iconColor,
        scaled(5),
        0,
        scaled(1.6)
    )
    drawList:AddLine(
        imgui.ImVec2(centerX - scaled(5), centerY - scaled(16)),
        imgui.ImVec2(centerX - scaled(8), centerY - scaled(12)),
        iconColor,
        scaled(1.6)
    )
    for x = -5, 5, 5 do
        drawList:AddCircleFilled(
            imgui.ImVec2(centerX + scaled(x), centerY - scaled(22.5)),
            scaled(1.2),
            iconColor
        )
    end

    local titleSize = imgui.CalcTextSize(title)
    local subtitleSize = imgui.CalcTextSize(subtitle)
    drawList:AddText(
        imgui.ImVec2(centerX - titleSize.x / 2, centerY + scaled(12)),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.textDark),
        title
    )
    drawList:AddText(
        imgui.ImVec2(centerX - subtitleSize.x / 2, centerY + scaled(34)),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.textGray),
        subtitle
    )
end

local function getStackPosition(prevSameGroup, nextSameGroup)
    if prevSameGroup and nextSameGroup then
        return "middle"
    elseif nextSameGroup then
        return "top"
    elseif prevSameGroup then
        return "bottom"
    end

    return "single"
end

local function drawEmptyState(rightPanelX, rightPanelWidth, windowSize)
    local windowPos = imgui.GetWindowPos()
    local drawList = imgui.GetWindowDrawList()
    local areaMin = imgui.ImVec2(windowPos.x + rightPanelX, windowPos.y)
    local areaMax = imgui.ImVec2(windowPos.x + rightPanelX + rightPanelWidth, windowPos.y + windowSize.y)

    drawList:AddRectFilled(
        areaMin,
        areaMax,
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.background)
    )
    drawList:AddLine(
        imgui.ImVec2(areaMin.x, windowPos.y),
        imgui.ImVec2(areaMin.x, windowPos.y + windowSize.y),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.border),
        1.0
    )
    drawConversationPlaceholder(drawList, areaMin, areaMax, "Your messages", "Select a contact to start chatting")
end

local function openEditContactDialog(contact)
    state.editContactPhone = imgui.new.char[32](contact.phone or "")
    state.editContactName = imgui.new.char[64](contact.name or "")
    state.showEditContactDialog = true
    imgui.OpenPopup("Edit Contact")
end

local function openDeleteContactDialog(contact)
    state.deleteContactName = contact.name or ""
    state.deleteContactPhone = contact.phone or ""
    state.showDeleteConfirmDialog = true
    imgui.OpenPopup("Confirm Delete")
end

local function drawContactActionsMenu(contact)
    local requestedAction = nil
    imgui.SetNextWindowSize(imgui.ImVec2(scaled(160), scaled(82)), imgui.Cond.Always)
    imgui.PushStyleColor(imgui.Col.PopupBg, CONFIG.colors.background)
    imgui.PushStyleColor(imgui.Col.Border, CONFIG.colors.border)
    if imgui.BeginPopup("##contactactions") then
        if helpers.drawStyledButton(imgui, "Edit contact##menuedit", imgui.ImVec2(scaled(144), design.controlHeight("COMPACT")), design.button("neutral")) then
            requestedAction = "edit"
            imgui.CloseCurrentPopup()
        end

        if helpers.drawStyledButton(imgui, "Delete contact##menudelete", imgui.ImVec2(scaled(144), design.controlHeight("COMPACT")), design.button("dangerGhost")) then
            requestedAction = "delete"
            imgui.CloseCurrentPopup()
        end
        imgui.EndPopup()
    end
    imgui.PopStyleColor(2)

    if requestedAction == "edit" then
        openEditContactDialog(contact)
    elseif requestedAction == "delete" then
        openDeleteContactDialog(contact)
    end
end

local function drawChatHeader(drawList, windowPos, windowSize, rightPanelX, rightPanelWidth, isMobile, contact)
    drawList:AddRectFilled(
        imgui.ImVec2(windowPos.x + rightPanelX, windowPos.y),
        imgui.ImVec2(windowPos.x + windowSize.x, windowPos.y + scaled(CONFIG.headerHeight)),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.background)
    )
    
    if isMobile then
        imgui.SetCursorPos(imgui.ImVec2(scaled(12), scaled(10)))
        local backSize = design.controlHeight("ICON")
        if helpers.drawIconButton(imgui, "##back", "back", imgui.ImVec2(backSize, backSize), design.button("neutral"), "Back to contacts", design.radius("MD")) then
            state.selectedContact = nil
            state.scrollToBottom = false
        end
    end
    
    local avatarX = isMobile and scaled(55) or (rightPanelX + scaled(15))
    local avatarPos = imgui.ImVec2(windowPos.x + avatarX, windowPos.y + scaled(10))
    drawList:AddCircleFilled(
        imgui.ImVec2(avatarPos.x + scaled(15), avatarPos.y + scaled(15)),
        scaled(15),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.primary)
    )
    
    local contactNameRaw = tostring(contact.name or "?")
    local contactName = cp1251_to_utf8(contactNameRaw)
    local initial = cp1251_to_utf8(contactNameRaw:sub(1, 1)):upper()
    local textSize = imgui.CalcTextSize(initial)
    drawList:AddText(
        imgui.ImVec2(avatarPos.x + scaled(15) - textSize.x / 2, avatarPos.y + scaled(15) - textSize.y / 2),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.textLight),
        initial
    )
    
    local isOnline = isContactOnline(contact.name)
    local statusColor = imgui.ColorConvertFloat4ToU32(
        isOnline and CONFIG.colors.statusOnline or CONFIG.colors.statusOffline
    )
    local statusPos = imgui.ImVec2(avatarPos.x + scaled(24), avatarPos.y + scaled(24))
    drawList:AddCircleFilled(statusPos, scaled(5), statusColor)
    drawList:AddCircle(statusPos, scaled(5), imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1, 1, 1, 1)), 12, scaled(2))
    
    local nameX = isMobile and scaled(95) or (rightPanelX + scaled(55))
    imgui.SetCursorPos(imgui.ImVec2(nameX, scaled(12)))
    imgui.TextColored(CONFIG.colors.textDark, contactName)
    imgui.SetCursorPos(imgui.ImVec2(nameX, scaled(30)))

    local onlineStatus = isContactOnline(contact.name) and "online" or "offline"
    local statusTextClr = isContactOnline(contact.name) and CONFIG.colors.statusOnline or CONFIG.colors.textGray
    imgui.TextColored(statusTextClr, tostring(contact.phone or "") .. " | " .. onlineStatus)
    
    local iconSize = design.controlHeight("ICON")
    local actionSize = imgui.ImVec2(iconSize, iconSize)
    imgui.SetCursorPos(imgui.ImVec2(rightPanelX + rightPanelWidth - scaled(114), scaled(10)))
    if helpers.drawIconButton(imgui, "##callcontact", "phone", actionSize, design.button("success"), "Call contact", design.radius("MD")) then
        if contact.phone then
            sampSendChat("/c " .. contact.phone)
        end
    end
    
    imgui.SetCursorPos(imgui.ImVec2(rightPanelX + rightPanelWidth - scaled(78), scaled(10)))
    if helpers.drawIconButton(imgui, "##contactactionsbtn", "more", actionSize, design.button("neutral"), "Contact actions", design.radius("MD")) then
        imgui.OpenPopup("##contactactions")
    end
    drawContactActionsMenu(contact)
    
    drawList:AddLine(
        imgui.ImVec2(windowPos.x + rightPanelX, windowPos.y + scaled(CONFIG.headerHeight)),
        imgui.ImVec2(windowPos.x + windowSize.x, windowPos.y + scaled(CONFIG.headerHeight)),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.border),
        1.0
    )
    
    if not isMobile then
        drawList:AddLine(
            imgui.ImVec2(windowPos.x + rightPanelX, windowPos.y),
            imgui.ImVec2(windowPos.x + rightPanelX, windowPos.y + windowSize.y),
            imgui.ColorConvertFloat4ToU32(CONFIG.colors.border),
            1.0
        )
    end
end

local function drawMessagesList(drawList, windowPos, windowSize, rightPanelX, rightPanelWidth, contact, fontScaleMultiplier)
    -- Clip to prevent messages from rendering over header area
    local messagesYStart = windowPos.y + scaled(CONFIG.headerHeight)
    local messagesYEnd = windowPos.y + windowSize.y - scaled(CONFIG.inputHeight - 20) - scaled(TextMetrics.CHAR_WIDTHS.BOTTOM_PADDING)
    imgui.PushClipRect(
        imgui.ImVec2(windowPos.x + rightPanelX, messagesYStart),
        imgui.ImVec2(windowPos.x + windowSize.x, messagesYEnd),
        true
    )
    
    imgui.SetCursorPos(imgui.ImVec2(rightPanelX, scaled(CONFIG.headerHeight)))
    local messagesHeight = windowSize.y - scaled(CONFIG.headerHeight) - scaled(CONFIG.inputHeight - 20) - scaled(TextMetrics.CHAR_WIDTHS.BOTTOM_PADDING)
    
    helpers.withStyle(imgui, {
        [imgui.Col.ScrollbarBg] = CONFIG.colors.background,
        [imgui.Col.ScrollbarGrab] = CONFIG.colors.scrollbarGrab,
        [imgui.Col.ScrollbarGrabHovered] = CONFIG.colors.scrollbarGrabHovered,
        [imgui.Col.ScrollbarGrabActive] = CONFIG.colors.scrollbarGrabActive
    }, nil, function()
        imgui.BeginChild("MessagesArea", imgui.ImVec2(rightPanelWidth, messagesHeight), false)
        
        local childDrawList = imgui.GetWindowDrawList()
        local messages = contact.messages or {}

        if #messages == 0 then
            local childPos = imgui.GetWindowPos()
            local childSize = imgui.GetWindowSize()
            drawConversationPlaceholder(
                childDrawList,
                childPos,
                imgui.ImVec2(childPos.x + childSize.x, childPos.y + childSize.y),
                "No messages yet",
                "Send a message to start the conversation"
            )
            imgui.Dummy(imgui.ImVec2(1, math.max(1, messagesHeight - scaled(1))))
            state.lastScrollMax = 0
            imgui.EndChild()
            return
        end
        
        local totalMessagesHeight = scaled(10)
        local messageLayouts = {}
        local previousDayKey = nil
        local maxBubbleRatio = rightPanelWidth < scaled(CONFIG.CONSTANTS.UI.MOBILE_BREAKPOINT) and 0.78 or 0.62
        
        for i, msg in ipairs(messages) do
            if type(msg) == "table" then
                local msgText = msg.text or ""

                local utf8Text = cp1251_to_utf8(msgText)

                local singleLineSize = imgui.CalcTextSize(utf8Text)
                local bubbleWidth = math.min(singleLineSize.x + scaled(30), rightPanelWidth * maxBubbleRatio)
                local availableTextWidth = bubbleWidth - scaled(30)
                
                local lines, lineHeight
                if singleLineSize.x <= availableTextWidth then
                    lines = 1
                    lineHeight = TextMetrics.CHAR_WIDTHS.LINE_HEIGHT * fontScaleMultiplier
                else
                    lines, lineHeight = TextMetrics.estimateLines(utf8Text, availableTextWidth, fontScaleMultiplier)
                end

                local bubbleHeight = (lineHeight * lines) + scaled(10)
                
                if bubbleWidth < scaled(50) then bubbleWidth = scaled(50) end
                if bubbleHeight < scaled(25) then bubbleHeight = scaled(25) end

                local currentDayKey = getDayKey(msg.timestamp)
                local dateLabel = nil
                if currentDayKey ~= "" and currentDayKey ~= previousDayKey then
                    dateLabel = formatDateSeparator(msg.timestamp)
                    totalMessagesHeight = totalMessagesHeight + scaled(36)
                end

                local prevMsg = messages[i - 1]
                local nextMsg = messages[i + 1]
                local prevSameGroup = type(prevMsg) == "table" and prevMsg.isOutgoing == msg.isOutgoing and getDayKey(prevMsg.timestamp) == currentDayKey
                local nextSameGroup = type(nextMsg) == "table" and nextMsg.isOutgoing == msg.isOutgoing and getDayKey(nextMsg.timestamp) == currentDayKey
                local showTime = not nextSameGroup
                local timeStr = tostring(os.date("%H:%M", tonumber(msg.timestamp) or 0) or "")
                local timeHeight = showTime and (imgui.CalcTextSize(timeStr).y + scaled(6)) or 0
                local spacingAfter = showTime and scaled(12) or scaled(3)

                messageLayouts[i] = {
                    text = msgText,
                    utf8Text = utf8Text,
                    textSize = singleLineSize,
                    lines = lines,
                    bubbleWidth = bubbleWidth,
                    bubbleHeight = bubbleHeight,
                    dateLabel = dateLabel,
                    showTime = showTime,
                    timeStr = timeStr,
                    stackPosition = getStackPosition(prevSameGroup, nextSameGroup),
                    spacingAfter = spacingAfter
                }
                totalMessagesHeight = totalMessagesHeight + bubbleHeight + timeHeight + spacingAfter
                previousDayKey = currentDayKey
            else
                messageLayouts[i] = nil
            end
        end
        
        -- Push messages to bottom when they don't fill the viewport
        local messagesAreaHeight = windowSize.y - scaled(CONFIG.headerHeight) - scaled(CONFIG.inputHeight - 20) - scaled(TextMetrics.CHAR_WIDTHS.BOTTOM_PADDING)
        local topPadding = messagesAreaHeight - totalMessagesHeight
        if topPadding > 0 then
            imgui.Dummy(imgui.ImVec2(1, topPadding))
        end
        
        for i, msg in ipairs(messages) do
            if type(msg) == "table" and messageLayouts[i] then
                local isOutgoing = msg.isOutgoing
                local bubbleColor = isOutgoing and CONFIG.colors.sentBubble or CONFIG.colors.receivedBubble
                local textColor = isOutgoing and CONFIG.colors.textLight or CONFIG.colors.textDark
                
                local msgText = messageLayouts[i].utf8Text
                
                local bubbleWidth = messageLayouts[i].bubbleWidth
                local bubbleHeight = messageLayouts[i].bubbleHeight
                local bubbleX = isOutgoing and (rightPanelWidth - bubbleWidth - scaled(15)) or scaled(15)
                
                local cursorScreenPos = imgui.GetCursorScreenPos()
                local cursorPosY = imgui.GetCursorPosY()

                if messageLayouts[i].dateLabel then
                    drawDateSeparator(imgui, childDrawList, cursorScreenPos, rightPanelWidth, messageLayouts[i].dateLabel, scaled, CONFIG)
                    imgui.SetCursorPosY(cursorPosY + scaled(36))
                    cursorScreenPos = imgui.GetCursorScreenPos()
                    cursorPosY = imgui.GetCursorPosY()
                end
                
                drawMessageBubble(childDrawList, imgui, cursorScreenPos, cursorPosY, bubbleX, bubbleWidth, bubbleHeight, bubbleColor, textColor, msgText, fontScaleMultiplier, scaled, TextMetrics, messageLayouts[i].stackPosition)

                if messageLayouts[i].showTime then
                    drawMessageTime(imgui, messageLayouts[i].timeStr, bubbleX, bubbleWidth, bubbleHeight, cursorPosY, isOutgoing, scaled, CONFIG)
                end

                local timeHeight = messageLayouts[i].showTime and (imgui.CalcTextSize(messageLayouts[i].timeStr).y + scaled(6)) or 0
                imgui.SetCursorPosY(cursorPosY + bubbleHeight + timeHeight + messageLayouts[i].spacingAfter)
            end
        end
        
        local scrollMax = imgui.GetScrollMaxY()
        
        -- Auto-scroll: detect new content or honor forced scroll request
        if state.lastScrollMax and scrollMax > state.lastScrollMax then
            imgui.SetScrollY(scrollMax)
            state.scrollToBottom = false
        elseif state.scrollToBottom then
            imgui.SetScrollY(scrollMax)
            if scrollMax > 0 then
                state.scrollToBottom = false
            end
        end
        state.lastScrollMax = scrollMax
        
        imgui.EndChild()
    end)
    imgui.PopClipRect()
    
    drawList:AddLine(
        imgui.ImVec2(windowPos.x + rightPanelX, windowPos.y + windowSize.y - scaled(CONFIG.inputHeight - 20) - scaled(TextMetrics.CHAR_WIDTHS.BOTTOM_PADDING)),
        imgui.ImVec2(windowPos.x + windowSize.x, windowPos.y + windowSize.y - scaled(CONFIG.inputHeight - 20) - scaled(TextMetrics.CHAR_WIDTHS.BOTTOM_PADDING)),
        imgui.ColorConvertFloat4ToU32(CONFIG.colors.border),
        1.0
    )
end

local function drawInputArea(windowSize, rightPanelX, rightPanelWidth, contact)
    local sendBtnHeight = design.controlHeight("COMPACT")
    local inputAreaHeight = scaled(CONFIG.inputHeight - 20) + scaled(TextMetrics.CHAR_WIDTHS.BOTTOM_PADDING)
    local inputY = windowSize.y - inputAreaHeight + (inputAreaHeight - sendBtnHeight) / 2
    imgui.SetCursorPos(imgui.ImVec2(rightPanelX + scaled(10), inputY))
    
    -- Match input frame to Send button height
    local fontSize = imgui.GetFontSize()
    local framePaddingY = math.max(4, (sendBtnHeight - fontSize) / 2)
    local msgStyle = imgui.GetStyle()
    local oldMsgFramePadding = { msgStyle.FramePadding.x, msgStyle.FramePadding.y }
    local oldMsgFrameRounding = msgStyle.FrameRounding
    msgStyle.FramePadding = imgui.ImVec2(scaled(10), framePaddingY)
    msgStyle.FrameRounding = design.radius("MD")
    imgui.PushItemWidth(rightPanelWidth - scaled(100))

    local inputScreenPos = imgui.GetCursorScreenPos()
    local inputColors = design.inputColors()
    imgui.PushStyleColor(imgui.Col.FrameBg, inputColors.background)
    imgui.PushStyleColor(imgui.Col.FrameBgHovered, inputColors.hovered)
    imgui.PushStyleColor(imgui.Col.FrameBgActive, inputColors.active)
    imgui.PushStyleColor(imgui.Col.Text, inputColors.text)
    local enterPressed = imgui.InputText("##message", state.messageText, 512, imgui.InputTextFlags.EnterReturnsTrue)
    local inputActive = imgui.IsItemActive()
    imgui.PopStyleColor(4)

    local draftMessage = ffi.string(state.messageText)
    local canSend = draftMessage:gsub("%s+", "") ~= ""
    if not canSend and not inputActive then
        local placeholder = "Type a message..."
        local placeholderSize = imgui.CalcTextSize(placeholder)
        imgui.GetWindowDrawList():AddText(
            imgui.ImVec2(
                inputScreenPos.x + scaled(10),
                inputScreenPos.y + (sendBtnHeight - placeholderSize.y) / 2
            ),
            imgui.ColorConvertFloat4ToU32(inputColors.placeholder),
            placeholder
        )
    end
    
    imgui.PopItemWidth()

    msgStyle.FramePadding = imgui.ImVec2(oldMsgFramePadding[1], oldMsgFramePadding[2])
    msgStyle.FrameRounding = oldMsgFrameRounding
    
    if enterPressed and canSend then
        MessageService.send(contact.phone, draftMessage)
        state.messageText = imgui.new.char[512]("")
        imgui.SetKeyboardFocusHere(-1)
    end
    
    imgui.SameLine()
    imgui.SetCursorPos(imgui.ImVec2(rightPanelX + rightPanelWidth - scaled(85), inputY))
    
    local btnStyle = imgui.GetStyle()
    local oldBtnRounding = btnStyle.FrameRounding
    btnStyle.FrameRounding = design.radius("MD")
    
    if helpers.drawStyledButton(
        imgui,
        "Send##sendbtn",
        imgui.ImVec2(scaled(75), sendBtnHeight),
        canSend and design.button("primary") or design.button("disabled")
    ) then
        if canSend then
            MessageService.send(contact.phone, draftMessage)
            state.messageText = imgui.new.char[512]("")
            imgui.SetKeyboardFocusHere(-1)
        end
    end
    
    btnStyle.FrameRounding = oldBtnRounding
end

M.drawRightPanel = function()
    if not CONFIG.colors then return end
    
    local fontScaleMultiplier = CONFIG.fontScale or 1.0
    
    local style = imgui.GetStyle()
    local drawList = imgui.GetWindowDrawList()
    local windowPos = imgui.GetWindowPos()
    local windowSize = imgui.GetWindowSize()
    
    local isMobile = windowSize.x < CONFIG.CONSTANTS.UI.MOBILE_BREAKPOINT
    
    local hasContact = state.selectedContact ~= nil
    local rightPanelX = isMobile and 0 or scaled(CONFIG.leftPanelWidth)
    local rightPanelWidth = isMobile and windowSize.x or (windowSize.x - scaled(CONFIG.leftPanelWidth))
    
    if isMobile and not hasContact then
        return
    end
    
    if not isMobile and not hasContact then
        drawEmptyState(rightPanelX, rightPanelWidth, windowSize)
        return
    end
    
    local serverKey = getCurrentServerKey()
    local contact = nil
    if serverKey and smsData.servers[serverKey] then
        contact = smsData.servers[serverKey].contacts[state.selectedContact.phone]
    end
    
    if contact then
        drawList:AddRectFilled(
            imgui.ImVec2(windowPos.x + rightPanelX, windowPos.y),
            imgui.ImVec2(windowPos.x + windowSize.x, windowPos.y + windowSize.y),
            imgui.ColorConvertFloat4ToU32(CONFIG.colors.background)
        )
        
        drawChatHeader(drawList, windowPos, windowSize, rightPanelX, rightPanelWidth, isMobile, contact)
        drawMessagesList(drawList, windowPos, windowSize, rightPanelX, rightPanelWidth, contact, fontScaleMultiplier)
        drawInputArea(windowSize, rightPanelX, rightPanelWidth, contact)
    end
end

return M
