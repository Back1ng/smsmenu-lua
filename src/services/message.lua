local encoding = require "src.utils.encoding"

local MessageService = {
    --[[
        Send an SMS message to a phone number.
        
        @param phone The recipient phone number (string or number)
        @param message The message text to send (string)
        @return true if message was sent, false otherwise (boolean)
    --]]
    send = function(phone, message)
        if not phone or not message then
            return false
        end
        
        local phoneStr = tostring(phone)
        local messageStr = tostring(message)
        
        -- Validate message is not empty after trimming whitespace
        if messageStr:gsub("%s+", "") == "" then
            return false
        end
        
        -- Send SMS command (convert UTF-8 to CP1251 for game chat)
        -- sampSendChat is a global function available in the Moonloader environment
        sampSendChat(encoding.utf8_str("/sms " .. phoneStr .. " " .. messageStr))
        
        return true
    end,
}

return MessageService
