local ffi = require "ffi"

local ChatHookService = {}

function ChatHookService.init(deps)
    ChatHookService.CONFIG = deps.CONFIG
    ChatHookService.state = deps.state
    ChatHookService.SAMPServices = deps.SAMPServices
    ChatHookService.ContactService = deps.ContactService
    ChatHookService.addMessage = deps.addMessage
    ChatHookService.playAlertSound = deps.playAlertSound
end

function ChatHookService.handleChatMessage(msg)

    local text, sender, _, phone = msg:match(ChatHookService.CONFIG.PATTERNS.incoming)
    if text then text = text:match("^%s*(.-)%s*$") end  -- trim
    if sender then sender = sender:match("^%s*(.-)%s*$") end  -- trim
    
    if text and sender and phone then
        local serverKey = ChatHookService.SAMPServices.getCurrentServerKey()
        if serverKey then
            ChatHookService.addMessage(serverKey, sender, phone, text, false)

            ChatHookService.playAlertSound()

            if ChatHookService.state and ChatHookService.state.windowOpen[0] then
                ChatHookService.state.contacts = ChatHookService.ContactService.getContactsList(serverKey)
                ChatHookService.state.filteredContacts = ChatHookService.ContactService.filterContacts(ffi.string(ChatHookService.state.searchText))
                -- Auto-mark read if this contact's chat is currently open
                if ChatHookService.state.selectedContact and ChatHookService.state.selectedContact.phone == phone then
                    ChatHookService.ContactService.markContactAsRead(phone)
                    ChatHookService.state.contacts = ChatHookService.ContactService.getContactsList(serverKey)
                    ChatHookService.state.filteredContacts = ChatHookService.ContactService.filterContacts(ffi.string(ChatHookService.state.searchText))
                end
            end
        end
        return true -- Message was handled (incoming SMS)
    end
    

    text, sender, _, phone = msg:match(ChatHookService.CONFIG.PATTERNS.outgoing)
    if text then text = text:match("^%s*(.-)%s*$") end  -- trim
    if sender then sender = sender:match("^%s*(.-)%s*$") end  -- trim
    
    if text and sender and phone then
        local serverKey = ChatHookService.SAMPServices.getCurrentServerKey()
        if serverKey then
            ChatHookService.addMessage(serverKey, sender, phone, text, true)

            if ChatHookService.state and ChatHookService.state.windowOpen[0] then
                ChatHookService.state.contacts = ChatHookService.ContactService.getContactsList(serverKey)
            end
        end
        return true -- Message was handled (outgoing SMS)
    end
    
    return false -- Message was not an SMS
end

return ChatHookService
