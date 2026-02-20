local core_storage = require "src.core.storage"

local ContactService = {}

function ContactService.init(deps)
    ContactService.smsData = deps.smsData
    ContactService.saveData = deps.saveData
    ContactService.removeContactFromCache = deps.removeContactFromCache
    ContactService.getCurrentServerKey = deps.getCurrentServerKey
    ContactService.state = deps.state
    ContactService.findPhoneByName = deps.findPhoneByName
    ContactService.updateContactCache = deps.updateContactCache
    ContactService.getOrCreateServer = deps.getOrCreateServer
end

function ContactService.deleteContact(phone)
    local serverKey = ContactService.getCurrentServerKey()
    if serverKey and ContactService.smsData.servers[serverKey] then
        local contact = ContactService.smsData.servers[serverKey].contacts[phone]
        if contact then
            -- Remove from cache before deleting from storage
            ContactService.removeContactFromCache(serverKey, contact.name, phone)
        end
        
        ContactService.smsData.servers[serverKey].contacts[phone] = nil
        if ContactService.state.selectedContact and ContactService.state.selectedContact.phone == phone then
            ContactService.state.selectedContact = nil
        end
        ContactService.saveData()
    end
end

-- Mark all messages from a contact as read
function ContactService.markContactAsRead(phone)
    local serverKey = ContactService.getCurrentServerKey()
    if serverKey and ContactService.smsData.servers[serverKey] and ContactService.smsData.servers[serverKey].contacts[phone] then
        local contact = ContactService.smsData.servers[serverKey].contacts[phone]
        contact.unreadCount = 0
        for _, msg in ipairs(contact.messages) do
            msg.read = true
        end
        ContactService.saveData()
    end
end

-- Uses O(1) cache lookup for name-to-phone resolution
function ContactService.getOrCreateContact(serverKey, nickname, phoneNumber)
    local server = ContactService.getOrCreateServer(serverKey)
    
    -- O(1) cache lookup for existing contact by nickname
    local existingPhone = ContactService.findPhoneByName(serverKey, nickname)
    
    if existingPhone then
        local contact = server.contacts[existingPhone]
        if contact then
            -- Update phone number if it changed
            if existingPhone ~= phoneNumber then
                -- Migrate contact to new number
                server.contacts[phoneNumber] = contact
                server.contacts[existingPhone] = nil
                contact.phone = phoneNumber
                
                -- Update cache: remove old mapping, add new mapping
                ContactService.updateContactCache(serverKey, nickname, nickname, existingPhone, phoneNumber)
                
                ContactService.saveData()
            end
            return contact, phoneNumber
        end
    end
    
    -- Create new contact
    if not server.contacts[phoneNumber] then
        server.contacts[phoneNumber] = {
            name = nickname,
            phone = phoneNumber,
            messages = {},
            lastMessage = nil,
            lastTimestamp = 0,
            unreadCount = 0
        }
        
        -- Add to cache
        ContactService.updateContactCache(serverKey, nil, nickname, nil, phoneNumber)
        
        ContactService.saveData()
    end
    
    return server.contacts[phoneNumber], phoneNumber
end

function ContactService.getContactsList(serverKey)
    local server = ContactService.smsData.servers[serverKey]
    if not server then return {} end
    
    local contacts = {}
    for phone, contact in pairs(server.contacts) do
        table.insert(contacts, {
            phone = phone,
            name = contact.name,
            lastMessage = contact.lastMessage,
            lastTimestamp = contact.lastTimestamp,
            unreadCount = contact.unreadCount or 0
        })
    end
    
    -- Sort by unread first, then by last message timestamp (most recent first)
    table.sort(contacts, function(a, b)
        local aUnread = (a.unreadCount or 0) > 0
        local bUnread = (b.unreadCount or 0) > 0
        if aUnread ~= bUnread then
            return aUnread  -- unread contacts first
        end
        return (a.lastTimestamp or 0) > (b.lastTimestamp or 0)
    end)
    
    return contacts
end

function ContactService.filterContacts(searchText)
    if not searchText or searchText == "" or not ContactService.state.contacts then
        return ContactService.state.contacts or {}
    end
    
    local filtered = {}
    local search = searchText:lower()
    
    for _, contact in ipairs(ContactService.state.contacts) do
        if contact.name:lower():find(search, 1, true) or 
           contact.phone:find(search, 1, true) then
            table.insert(filtered, contact)
        end
    end
    
    return filtered
end

return ContactService
