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
end

local function drawMessageBubble(childDrawList, imgui, cursorScreenPos, cursorPosY, bubbleX, bubbleWidth, bubbleHeight, bubbleColor, textColor, msgText, fontScaleMultiplier, scaled, TextMetrics, stackPosition)
    local radius = scaled(15)
    if stackPosition == "middle" then
        radius = scaled(10)
    elseif stackPosition == "top" or stackPosition == "bottom" then
        radius = scaled(13)
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

local function drawDateSeparator(imgui, childDrawList, cursorScreenPos, cursorPosY, rightPanelWidth, label, scaled, CONFIG)
    if label == "" then return end

    local labelSize = imgui.CalcTextSize(label)
    local labelX = (rightPanelWidth - labelSize.x) / 2
    local labelY = cursorPosY + scaled(9)
    local lineY = cursorScreenPos.y + scaled(18)
    local linePadding = scaled(18)
    local labelPadding = scaled(10)
    local lineColor = imgui.ColorConvertFloat4ToU32(CONFIG.colors.border)

    childDrawList:AddLine(
        imgui.ImVec2(cursorScreenPos.x + linePadding, lineY),
        imgui.ImVec2(cursorScreenPos.x + labelX - labelPadding, lineY),
        lineColor,
        1.0
    )
    childDrawList:AddLine(
        imgui.ImVec2(cursorScreenPos.x + labelX + labelSize.x + labelPadding, lineY),
        imgui.ImVec2(cursorScreenPos.x + rightPanelWidth - linePadding, lineY),
        lineColor,
        1.0
    )

    imgui.SetCursorPos(imgui.ImVec2(labelX, labelY))
    imgui.TextColored(CONFIG.colors.textGray, label)
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
    imgui.SetCursorPos(imgui.ImVec2(rightPanelX + rightPanelWidth / 2 - scaled(100), windowSize.y / 2 - scaled(50)))
    imgui.TextColored(CONFIG.colors.textGray, "Select a contact to start messaging")
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
        if helpers.drawStyledButton(imgui, "Edit contact##menuedit", imgui.ImVec2(scaled(144), scaled(28)), {
            button = CONFIG.colors.searchBg,
            hovered = CONFIG.colors.selected,
            active = CONFIG.colors.border,
            text = CONFIG.colors.textDark
        }) then
            requestedAction = "edit"
            imgui.CloseCurrentPopup()
        end

        if helpers.drawStyledButton(imgui, "Delete contact##menudelete", imgui.ImVec2(scaled(144), scaled(28)), {
            button = CONFIG.colors.background,
            hovered = imgui.ImVec4(0.9, 0.3, 0.3, 0.22),
            active = imgui.ImVec4(0.9, 0.3, 0.3, 0.35),
            text = imgui.ImVec4(0.9, 0.3, 0.3, 1.0)
        }) then
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
        if helpers.drawIconButton(imgui, "##back", "back", imgui.ImVec2(scaled(30), scaled(30)), {
            button = CONFIG.colors.searchBg,
            hovered = CONFIG.colors.selected,
            active = CONFIG.colors.border,
            text = CONFIG.colors.textDark
        }, "Back to contacts", scaled(7)) then
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
    local statusColor = isOnline and 
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.3, 0.85, 0.39, 1.0)) or
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.56, 0.56, 0.58, 1.0))
    local statusPos = imgui.ImVec2(avatarPos.x + scaled(24), avatarPos.y + scaled(24))
    drawList:AddCircleFilled(statusPos, scaled(5), statusColor)
    drawList:AddCircle(statusPos, scaled(5), imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1, 1, 1, 1)), 12, scaled(2))
    
    local nameX = isMobile and scaled(95) or (rightPanelX + scaled(55))
    imgui.SetCursorPos(imgui.ImVec2(nameX, scaled(12)))
    imgui.TextColored(CONFIG.colors.textDark, contactName)
    imgui.SetCursorPos(imgui.ImVec2(nameX, scaled(30)))

    local onlineStatus = isContactOnline(contact.name) and "online" or "offline"
    local statusTextClr = isContactOnline(contact.name) and 
        imgui.ImVec4(0.3, 0.8, 0.4, 1.0) or 
        CONFIG.colors.textGray
    imgui.TextColored(statusTextClr, tostring(contact.phone or "") .. " | " .. onlineStatus)
    
    local actionSize = imgui.ImVec2(scaled(30), scaled(30))
    imgui.SetCursorPos(imgui.ImVec2(rightPanelX + rightPanelWidth - scaled(114), scaled(10)))
    if helpers.drawIconButton(imgui, "##callcontact", "phone", actionSize, {
        button = imgui.ImVec4(0.2, 0.7, 0.3, 1.0),
        hovered = imgui.ImVec4(0.2, 0.8, 0.35, 1.0),
        active = imgui.ImVec4(0.15, 0.6, 0.25, 1.0),
        text = imgui.ImVec4(1, 1, 1, 1)
    }, "Call contact", scaled(7)) then
        if contact.phone then
            sampSendChat("/c " .. contact.phone)
        end
    end
    
    imgui.SetCursorPos(imgui.ImVec2(rightPanelX + rightPanelWidth - scaled(78), scaled(10)))
    if helpers.drawIconButton(imgui, "##contactactionsbtn", "more", actionSize, {
        button = CONFIG.colors.searchBg,
        hovered = CONFIG.colors.selected,
        active = CONFIG.colors.border,
        text = CONFIG.colors.textDark
    }, "Contact actions", scaled(7)) then
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
        
        local totalMessagesHeight = scaled(10)
        local messageLayouts = {}
        local previousDayKey = nil
        
        for i, msg in ipairs(messages) do
            if type(msg) == "table" then
                local msgText = msg.text or ""

                local utf8Text = cp1251_to_utf8(msgText)

                local singleLineSize = imgui.CalcTextSize(utf8Text)
                local bubbleWidth = math.min(singleLineSize.x + scaled(30), rightPanelWidth * 0.7)
                local availableTextWidth = bubbleWidth - scaled(30)
                
                local lines, lineHeight
                if singleLineSize.x <= availableTextWidth then
                    lines = 1
                    lineHeight = TextMetrics.CHAR_WIDTHS.LINE_HEIGHT * fontScaleMultiplier
                else
                    lines, lineHeight = TextMetrics.estimateLines(utf8Text, availableTextWidth, fontScaleMultiplier)
                end

                local bubbleHeight = (lineHeight * lines) + scaled(3)
                
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
                local spacingAfter = showTime and scaled(12) or scaled(4)

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
                    drawDateSeparator(imgui, childDrawList, cursorScreenPos, cursorPosY, rightPanelWidth, messageLayouts[i].dateLabel, scaled, CONFIG)
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
    local sendBtnHeight = scaled(28)
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
    msgStyle.FrameRounding = scaled(5)
    imgui.PushItemWidth(rightPanelWidth - scaled(100))
    
    local enterPressed = imgui.InputText("##message", state.messageText, 512, imgui.InputTextFlags.EnterReturnsTrue)
    
    imgui.PopItemWidth()

    msgStyle.FramePadding = imgui.ImVec2(oldMsgFramePadding[1], oldMsgFramePadding[2])
    msgStyle.FrameRounding = oldMsgFrameRounding
    
    if enterPressed then
        local message = ffi.string(state.messageText)
        if message:gsub("%s+", "") ~= "" then
            MessageService.send(contact.phone, message)
            state.messageText = imgui.new.char[512]("")
            imgui.SetKeyboardFocusHere(-1)
        end
    end
    
    imgui.SameLine()
    imgui.SetCursorPos(imgui.ImVec2(rightPanelX + rightPanelWidth - scaled(85), inputY))
    
    local btnStyle = imgui.GetStyle()
    local oldBtnRounding = btnStyle.FrameRounding
    btnStyle.FrameRounding = scaled(5)
    
    if helpers.drawStyledButton(imgui, "Send##sendbtn", imgui.ImVec2(scaled(75), sendBtnHeight), {
        button = CONFIG.colors.primary,
        hovered = CONFIG.colors.primaryHover
    }) then
        local message = ffi.string(state.messageText)
        if message:gsub("%s+", "") ~= "" then
            MessageService.send(contact.phone, message)
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
