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
end

M.drawRightPanel = function()
    if not CONFIG.colors then return end
    
    -- Use TextMetrics module for character width metrics and text measurement
    -- Module is defined at end of file for Feature Envy refactoring
    -- Cached font scale multiplier for O(1) access
    -- Must be declared BEFORE any functions or code blocks that use it
    local fontScaleMultiplier = CONFIG.fontScale or 1.0
    
    local style = imgui.GetStyle()
    local drawList = imgui.GetWindowDrawList()
    local windowPos = imgui.GetWindowPos()
    local windowSize = imgui.GetWindowSize()
    
    -- Responsive breakpoint at 600px
    local isMobile = windowSize.x < 600
    
    -- Determine panel dimensions based on mode and whether a contact is selected
    local hasContact = state.selectedContact ~= nil
    local rightPanelX = isMobile and 0 or scaled(CONFIG.leftPanelWidth)
    local rightPanelWidth = isMobile and windowSize.x or (windowSize.x - scaled(CONFIG.leftPanelWidth))
    
    -- In mobile mode: hide if no contact selected (left panel shows instead)
    -- In desktop mode: always show, show empty state if no contact
    if isMobile and not hasContact then
        return
    end
    
    if not isMobile and not hasContact then
        -- Desktop empty state
        imgui.SetCursorPos(imgui.ImVec2(rightPanelX + rightPanelWidth / 2 - scaled(100), windowSize.y / 2 - scaled(50)))
        imgui.TextColored(CONFIG.colors.textGray, "Select a contact to start messaging")
        return
    end
    
    -- Header
    local serverKey = getCurrentServerKey()
    local contact = nil
    if serverKey and smsData.servers[serverKey] then
        contact = smsData.servers[serverKey].contacts[state.selectedContact.phone]
    end
    
    if contact then
        -- Right panel background (white)
        drawList:AddRectFilled(
            imgui.ImVec2(windowPos.x + rightPanelX, windowPos.y),
            imgui.ImVec2(windowPos.x + windowSize.x, windowPos.y + windowSize.y),
            imgui.ColorConvertFloat4ToU32(CONFIG.colors.background)
        )
        
        -- Header background
        drawList:AddRectFilled(
            imgui.ImVec2(windowPos.x + rightPanelX, windowPos.y),
            imgui.ImVec2(windowPos.x + windowSize.x, windowPos.y + scaled(CONFIG.headerHeight)),
            imgui.ColorConvertFloat4ToU32(CONFIG.colors.background)
        )
        
        -- Back button "<" (top left) - only in mobile mode
        if isMobile then
            imgui.SetCursorPos(imgui.ImVec2(scaled(12), scaled(12)))
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.9, 0.9, 0.9, 1.0))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, CONFIG.colors.primary)
            imgui.PushStyleColor(imgui.Col.ButtonActive, CONFIG.colors.primaryHover)
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.3, 0.3, 0.3, 1.0))
            if imgui.Button("<##back", imgui.ImVec2(scaled(32), scaled(26))) then
                state.selectedContact = nil
                state.scrollToBottom = false
            end
            imgui.PopStyleColor(4)
        end
        
        -- Avatar (positioned after back button in mobile, at left edge in desktop)
        local avatarX = isMobile and scaled(55) or (rightPanelX + scaled(15))
        local avatarPos = imgui.ImVec2(windowPos.x + avatarX, windowPos.y + scaled(10))
        drawList:AddCircleFilled(
            imgui.ImVec2(avatarPos.x + scaled(15), avatarPos.y + scaled(15)),
            scaled(15),
            imgui.ColorConvertFloat4ToU32(CONFIG.colors.primary)
        )
        
        local contactName = cp1251_to_utf8(tostring(contact.name or "?"))
        local initial = contactName:sub(1, 1):upper()
        local textSize = imgui.CalcTextSize(initial)
        drawList:AddText(
            imgui.ImVec2(avatarPos.x + scaled(15) - textSize.x / 2, avatarPos.y + scaled(15) - textSize.y / 2),
            imgui.ColorConvertFloat4ToU32(CONFIG.colors.textLight),
            initial
        )
        
        -- Online status indicator in chat header
        local isOnline = isContactOnline(contact.name)
        local statusColor = isOnline and 
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.3, 0.85, 0.39, 1.0)) or  -- green (online)
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.56, 0.56, 0.58, 1.0))     -- gray (offline)
        local statusPos = imgui.ImVec2(avatarPos.x + scaled(24), avatarPos.y + scaled(24))
        drawList:AddCircleFilled(statusPos, scaled(5), statusColor)
        drawList:AddCircle(statusPos, scaled(5), imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1, 1, 1, 1)), 12, scaled(2))  -- white border
        
        -- Name and number
        local nameX = isMobile and scaled(95) or (rightPanelX + scaled(55))
        imgui.SetCursorPos(imgui.ImVec2(nameX, scaled(12)))
        imgui.TextColored(CONFIG.colors.textDark, contactName)
        imgui.SetCursorPos(imgui.ImVec2(nameX, scaled(30)))
        -- Show phone and online status
        local onlineStatus = isContactOnline(contact.name) and "online" or "offline"
        local statusColor = isContactOnline(contact.name) and 
            imgui.ImVec4(0.3, 0.8, 0.4, 1.0) or 
            CONFIG.colors.textGray
        imgui.TextColored(statusColor, tostring(contact.phone or "") .. " | " .. onlineStatus)
        
        -- Call button - leftmost of the action buttons
        imgui.SetCursorPos(imgui.ImVec2(rightPanelX + rightPanelWidth - scaled(180), scaled(12)))
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.2, 0.7, 0.3, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.2, 0.8, 0.35, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.15, 0.6, 0.25, 1.0))
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1, 1, 1, 1))
        if imgui.Button("Call##callcontact", imgui.ImVec2(scaled(42), scaled(26))) then
            -- Make a call
            if contact.phone then
                sampSendChat("/c " .. contact.phone)
            end
        end
        imgui.PopStyleColor(4)
        
        -- Edit button - middle of the action buttons
        imgui.SetCursorPos(imgui.ImVec2(rightPanelX + rightPanelWidth - scaled(135), scaled(12)))
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.9, 0.9, 0.9, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, CONFIG.colors.primary)
        imgui.PushStyleColor(imgui.Col.ButtonActive, CONFIG.colors.primaryHover)
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.3, 0.3, 0.3, 1.0))
        if imgui.Button("Edit##editcontact", imgui.ImVec2(scaled(42), scaled(26))) then
            -- Pre-fill edit fields with current values
            state.editContactPhone = imgui.new.char[32](contact.phone or "")
            state.editContactName = imgui.new.char[64](contact.name or "")
            state.showEditContactDialog = true
            imgui.OpenPopup("Edit Contact")
        end
        imgui.PopStyleColor(4)
        
        -- Delete button - rightmost of the action buttons, left of close button
        imgui.SetCursorPos(imgui.ImVec2(rightPanelX + rightPanelWidth - scaled(90), scaled(12)))
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.9, 0.3, 0.3, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1.0, 0.4, 0.4, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.8, 0.2, 0.2, 1.0))
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1, 1, 1, 1))
        if imgui.Button("Del##deletecontact", imgui.ImVec2(scaled(42), scaled(26))) then
            -- Show confirmation dialog
            state.deleteContactName = contact.name or ""
            state.deleteContactPhone = contact.phone or ""
            state.showDeleteConfirmDialog = true
            imgui.OpenPopup("Confirm Delete")
        end
        imgui.PopStyleColor(4)
        
        -- Separator
        drawList:AddLine(
            imgui.ImVec2(windowPos.x + rightPanelX, windowPos.y + scaled(CONFIG.headerHeight)),
            imgui.ImVec2(windowPos.x + windowSize.x, windowPos.y + scaled(CONFIG.headerHeight)),
            imgui.ColorConvertFloat4ToU32(CONFIG.colors.border),
            1.0
        )
        
        -- Left panel border line (only in desktop mode)
        if not isMobile then
            drawList:AddLine(
                imgui.ImVec2(windowPos.x + rightPanelX, windowPos.y),
                imgui.ImVec2(windowPos.x + rightPanelX, windowPos.y + windowSize.y),
                imgui.ColorConvertFloat4ToU32(CONFIG.colors.border),
                1.0
            )
        end
        
        -- Set clip rect to prevent messages from drawing over header
        local messagesYStart = windowPos.y + scaled(CONFIG.headerHeight)
        local messagesYEnd = windowPos.y + windowSize.y - scaled(CONFIG.inputHeight) - scaled(TextMetrics.CHAR_WIDTHS.BOTTOM_PADDING)
        imgui.PushClipRect(
            imgui.ImVec2(windowPos.x + rightPanelX, messagesYStart),
            imgui.ImVec2(windowPos.x + windowSize.x, messagesYEnd),
            true
        )
        
        -- Messages area - positioned to end above input area
        imgui.SetCursorPos(imgui.ImVec2(rightPanelX, scaled(CONFIG.headerHeight)))
        local messagesHeight = windowSize.y - scaled(CONFIG.headerHeight) - scaled(CONFIG.inputHeight) - scaled(TextMetrics.CHAR_WIDTHS.BOTTOM_PADDING)
        imgui.BeginChild("MessagesArea", imgui.ImVec2(rightPanelWidth, messagesHeight), false)
        
        -- Get draw list for the child window (for proper scrolling)
        local childDrawList = imgui.GetWindowDrawList()
        
        local messages = contact.messages or {}
        
        -- Calculate total height of all messages first
        local totalMessagesHeight = scaled(10)  -- initial padding
        local messageSizes = {}
        
        -- Use module-level TextMetrics for O(1) text wrapping estimation
        for i, msg in ipairs(messages) do
            if type(msg) == "table" then
                local msgText = msg.text or ""
                -- Convert to UTF-8 for size calculation (imgui uses UTF-8)
                local utf8Text = cp1251_to_utf8(msgText)
                -- Calculate text size with word wrap estimation
                local singleLineSize = imgui.CalcTextSize(utf8Text)
                local bubbleWidth = math.min(singleLineSize.x + scaled(30), rightPanelWidth * 0.7)
                local availableTextWidth = bubbleWidth - scaled(30)
                
                -- Estimate lines using word wrap logic
                -- Use actual text width for accurate single-line detection
                local lines, lineHeight
                if singleLineSize.x <= availableTextWidth then
                    -- Text fits in one line, no estimation needed
                    lines = 1
                    lineHeight = TextMetrics.CHAR_WIDTHS.LINE_HEIGHT * fontScaleMultiplier
                else
                    lines, lineHeight = TextMetrics.estimateLines(utf8Text, availableTextWidth, fontScaleMultiplier)
                end
                -- Adjusted padding: more top, less bottom
                local bubbleHeight = (lineHeight * lines) + scaled(3)
                
                -- Ensure minimum bubble size for visibility
                if bubbleWidth < scaled(50) then bubbleWidth = scaled(50) end
                if bubbleHeight < scaled(25) then bubbleHeight = scaled(25) end
                
                table.insert(messageSizes, {text = msgText, utf8Text = utf8Text, textSize = singleLineSize, lines = lines, bubbleWidth = bubbleWidth, bubbleHeight = bubbleHeight})
                totalMessagesHeight = totalMessagesHeight + bubbleHeight + scaled(12)
            else
                table.insert(messageSizes, nil)
            end
        end
        
        -- Add top padding to push messages to bottom if they don't fill the area
        local messagesAreaHeight = windowSize.y - scaled(CONFIG.headerHeight) - scaled(CONFIG.inputHeight) - scaled(TextMetrics.CHAR_WIDTHS.BOTTOM_PADDING)
        local topPadding = messagesAreaHeight - totalMessagesHeight
        if topPadding > 0 then
            imgui.Dummy(imgui.ImVec2(1, topPadding))
        end
        
        for i, msg in ipairs(messages) do
            if type(msg) == "table" and messageSizes[i] then
                local isOutgoing = msg.isOutgoing
                local bubbleColor = isOutgoing and CONFIG.colors.sentBubble or CONFIG.colors.receivedBubble
                local textColor = isOutgoing and CONFIG.colors.textLight or CONFIG.colors.textDark
                
                local msgText = messageSizes[i].utf8Text
                
                -- Use pre-calculated sizes
                local bubbleWidth = messageSizes[i].bubbleWidth
                local bubbleHeight = messageSizes[i].bubbleHeight
                local textSize = messageSizes[i].textSize
                
                local bubbleX = isOutgoing and (rightPanelWidth - bubbleWidth - scaled(15)) or scaled(15)
                
                -- Get current cursor screen position (inside child window, includes scroll)
                local cursorScreenPos = imgui.GetCursorScreenPos()
                local cursorPosY = imgui.GetCursorPosY()
                
                -- Draw bubble using child draw list (respects scrolling)
                childDrawList:AddRectFilled(
                    imgui.ImVec2(cursorScreenPos.x + bubbleX, cursorScreenPos.y),
                    imgui.ImVec2(cursorScreenPos.x + bubbleX + bubbleWidth, cursorScreenPos.y + bubbleHeight),
                    imgui.ColorConvertFloat4ToU32(bubbleColor),
                    scaled(15)
                )
                
                -- Draw text inside bubble using SetCursorPos + TextWrapped
                -- Increased top offset, minimal bottom space
                local textOffsetY = scaled(4)
                
                -- O(1) calculation: Measure leading indentation for preservation
                local indentWidth, indentChars = TextMetrics.measureLeadingIndent(msgText, fontScaleMultiplier)
                
                -- Adjust text position to preserve visual indentation
                local textStartX = bubbleX + scaled(14) + indentWidth
                
                imgui.SetCursorPos(imgui.ImVec2(textStartX, cursorPosY + textOffsetY))
                imgui.PushTextWrapPos(bubbleX + bubbleWidth - scaled(14))
                imgui.PushStyleColor(imgui.Col.Text, textColor)
                imgui.TextUnformatted(msgText)
                imgui.PopStyleColor()
                imgui.PopTextWrapPos()
                
                -- Time
                local timeStr = tostring(os.date("%H:%M", tonumber(msg.timestamp) or 0) or "")
                local timeSize = imgui.CalcTextSize(timeStr)
                
                -- Read status indicator (checkmarks) for outgoing messages
                local readStatusWidth = 0
                if isOutgoing then
                    readStatusWidth = scaled(16)  -- space for checkmarks
                end
                
                -- Calculate time position (outside bubble) - align to bottom of bubble
                local timeX = isOutgoing and (bubbleX - timeSize.x - scaled(8) - readStatusWidth) or (bubbleX + bubbleWidth + scaled(8))
                local timeY = cursorPosY + bubbleHeight - timeSize.y - scaled(4)
                
                -- Draw time
                imgui.SetCursorPos(imgui.ImVec2(timeX, timeY))
                imgui.TextColored(CONFIG.colors.textGray, timeStr)
                
                -- Read status checkmarks for outgoing messages (drawn as lines)
                if isOutgoing then
                    -- Position checkmarks aligned with time text
                    local checkX = cursorScreenPos.x + bubbleX - scaled(20)
                    local checkY = cursorScreenPos.y + bubbleHeight - scaled(12)
                    local checkColor = msg.read and 
                        imgui.ColorConvertFloat4ToU32(CONFIG.colors.textLight) or 
                        imgui.ColorConvertFloat4ToU32(CONFIG.colors.textGray)
                    
                    -- Scale checkmark size with font
                    local checkSize = scaled(4)
                    local checkLong = scaled(10)
                    
                    -- Draw single checkmark (\ shape)
                    childDrawList:AddLine(
                        imgui.ImVec2(checkX, checkY + checkSize),
                        imgui.ImVec2(checkX + checkSize, checkY + checkLong - scaled(3)),
                        checkColor,
                        1.5
                    )
                    childDrawList:AddLine(
                        imgui.ImVec2(checkX + checkSize, checkY + checkLong - scaled(3)),
                        imgui.ImVec2(checkX + checkLong, checkY),
                        checkColor,
                        1.5
                    )
                    
                    -- If read, draw second checkmark offset slightly
                    if msg.read then
                        local offsetX = scaled(5)
                        childDrawList:AddLine(
                            imgui.ImVec2(checkX + offsetX, checkY + checkSize),
                            imgui.ImVec2(checkX + offsetX + checkSize, checkY + checkLong - scaled(3)),
                            checkColor,
                            1.5
                        )
                        childDrawList:AddLine(
                            imgui.ImVec2(checkX + offsetX + checkSize, checkY + checkLong - scaled(3)),
                            imgui.ImVec2(checkX + offsetX + checkLong, checkY),
                            checkColor,
                            1.5
                        )
                    end
                end
                
                -- Move cursor down for next message
                imgui.SetCursorPosY(cursorPosY + bubbleHeight + scaled(12))
            end
        end
        
        -- Scroll to bottom on new message or when opening chat
        local scrollMax = imgui.GetScrollMaxY()
        
        -- Track if scrollMax increased (new message was rendered)
        if state.lastScrollMax and scrollMax > state.lastScrollMax then
            -- New content was added, scroll to bottom
            imgui.SetScrollY(scrollMax)
            state.scrollToBottom = false
        elseif state.scrollToBottom then
            -- Forced scroll request
            imgui.SetScrollY(scrollMax)
            if scrollMax > 0 then
                state.scrollToBottom = false
            end
        end
        state.lastScrollMax = scrollMax
        
        imgui.EndChild()
        imgui.PopClipRect()
        
        -- Input area separator
        drawList:AddLine(
            imgui.ImVec2(windowPos.x + rightPanelX, windowPos.y + windowSize.y - scaled(CONFIG.inputHeight) - scaled(TextMetrics.CHAR_WIDTHS.BOTTOM_PADDING)),
            imgui.ImVec2(windowPos.x + windowSize.x, windowPos.y + windowSize.y - scaled(CONFIG.inputHeight) - scaled(TextMetrics.CHAR_WIDTHS.BOTTOM_PADDING)),
            imgui.ColorConvertFloat4ToU32(CONFIG.colors.border),
            1.0
        )
        
        -- Input area - positioned at the bottom, aligned with Send button
        local sendBtnHeight = scaled(35)
        local inputY = windowSize.y - scaled(CONFIG.inputHeight) + scaled(5)
        imgui.SetCursorPos(imgui.ImVec2(rightPanelX + scaled(10), inputY))
        
        -- Устанавливаем высоту инпута совпадающую с кнопкой SEND
        local fontSize = imgui.GetFontSize()
        local framePaddingY = math.max(4, (sendBtnHeight - fontSize) / 2)
        local msgStyle = imgui.GetStyle()
        local oldMsgFramePadding = { msgStyle.FramePadding.x, msgStyle.FramePadding.y }
        msgStyle.FramePadding = imgui.ImVec2(scaled(10), framePaddingY)
        imgui.PushItemWidth(rightPanelWidth - scaled(100))
        
        local enterPressed = imgui.InputText("##message", state.messageText, 512, imgui.InputTextFlags.EnterReturnsTrue)
        
        imgui.PopItemWidth()
        -- Восстанавливаем стиль
        msgStyle.FramePadding = imgui.ImVec2(oldMsgFramePadding[1], oldMsgFramePadding[2])
        
        if enterPressed then
            local message = ffi.string(state.messageText)
            if message:gsub("%s+", "") ~= "" then
                -- Send SMS command via MessageService module
                MessageService.send(contact.phone, message)
                -- Clear input
                state.messageText = imgui.new.char[512]("")
                -- Set focus back to input field
                imgui.SetKeyboardFocusHere(-1)
            end
        end
        
        -- Send button (larger, aligned with input field)
        imgui.SameLine()
        imgui.SetCursorPos(imgui.ImVec2(rightPanelX + rightPanelWidth - scaled(85), inputY))
        
        local btnColor = imgui.GetStyle().Colors[imgui.Col.Button]
        imgui.GetStyle().Colors[imgui.Col.Button] = CONFIG.colors.primary
        imgui.GetStyle().Colors[imgui.Col.ButtonHovered] = CONFIG.colors.primaryHover
        
        if imgui.Button("Send##sendbtn", imgui.ImVec2(scaled(75), sendBtnHeight)) then
            local message = ffi.string(state.messageText)
            if message:gsub("%s+", "") ~= "" then
                -- Send SMS command via MessageService module
                MessageService.send(contact.phone, message)
                state.messageText = imgui.new.char[512]("")
                -- Set focus back to input field
                imgui.SetKeyboardFocusHere(-1)
            end
        end
        
        imgui.GetStyle().Colors[imgui.Col.Button] = btnColor
    end
end

return M
