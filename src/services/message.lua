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
        

        if messageStr:gsub("%s+", "") == "" then
            return false
        end
        
        -- Convert UTF-8 to CP1251 because SAMP chat expects CP1251 encoding
        sampSendChat(encoding.utf8_str("/sms " .. phoneStr .. " " .. messageStr))
        
        return true
    end,
}

return MessageService
