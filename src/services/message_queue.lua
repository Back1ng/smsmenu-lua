local MessageQueue = {}

local messageQueue = {}
local isProcessingQueue = false
local deps = {}

function MessageQueue.init(dependencies)
    deps = dependencies
end

function MessageQueue.processMessageQueue()
    if isProcessingQueue then return end
    isProcessingQueue = true
    
    while #messageQueue > 0 do
        local msgData = table.remove(messageQueue, 1)
        local serverKey = msgData.serverKey
        local nickname = msgData.nickname
        local phoneNumber = msgData.phoneNumber
        local text = msgData.text
        local isOutgoing = msgData.isOutgoing
        

        local contact, currentNumber = deps.ContactService.getOrCreateContact(serverKey, nickname, phoneNumber)
        
        local message = {
            text = text,
            timestamp = msgData.timestamp or os.time(),
            isOutgoing = isOutgoing,
            senderName = isOutgoing and "You" or nickname,
            read = isOutgoing  -- outgoing messages are always "read", incoming are unread
        }
        
        table.insert(contact.messages, message)
        contact.lastMessage = text
        contact.lastTimestamp = message.timestamp
        
        -- Incoming messages start unread
        if not isOutgoing then
            contact.unreadCount = (contact.unreadCount or 0) + 1
        end
        
        -- Prevent unbounded growth
        if #contact.messages > deps.CONFIG.CONSTANTS.LIMITS.MAX_MESSAGES_PER_CONTACT then
            table.remove(contact.messages, 1)
        end
    end
    
    -- Save all changes at once after processing queue
    if deps.core_storage.pendingSave then
        deps.saveData()
    end
    
    isProcessingQueue = false
end

function MessageQueue.queueMessage(serverKey, nickname, phoneNumber, text, isOutgoing)
    table.insert(messageQueue, {
        serverKey = serverKey,
        nickname = nickname,
        phoneNumber = phoneNumber,
        text = text,
        isOutgoing = isOutgoing,
        timestamp = os.time()
    })
    deps.core_storage.pendingSave = true
    

    MessageQueue.processMessageQueue()
    
    return phoneNumber
end

function MessageQueue.addMessage(serverKey, nickname, phoneNumber, text, isOutgoing)
    -- Use queue-based processing to prevent race conditions
    local currentNumber = MessageQueue.queueMessage(serverKey, nickname, phoneNumber, text, isOutgoing)
    

    if deps.state then
        deps.state.scrollToBottom = true
        deps.state.newMessageAnim = 1.0
    end
    
    return currentNumber
end

function MessageQueue.hasMessages()
    return #messageQueue > 0
end

return MessageQueue
