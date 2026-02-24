local SAMPServices = {}

function SAMPServices.init(deps)
    SAMPServices.smsData = deps.smsData
end

function SAMPServices.getCurrentServerKey()
    if not isSampAvailable() then return nil end
    local ip, port = sampGetCurrentServerAddress()
    if ip and port then
        return ip .. ":" .. port
    end
    return nil
end

function SAMPServices.getCurrentServerName()
    if not isSampAvailable() then return "Unknown Server" end

    local name = sampGetCurrentServerName and sampGetCurrentServerName() or nil
    if name and name ~= "" then
        return name
    end
    return "Server"
end

function SAMPServices.getOrCreateServer(serverKey)
    if not SAMPServices.smsData.servers[serverKey] then
        SAMPServices.smsData.servers[serverKey] = {
            name = SAMPServices.getCurrentServerName(),
            contacts = {}
        }
    end
    return SAMPServices.smsData.servers[serverKey]
end

SAMPServices.playerOnlineStatus = {}


function SAMPServices.updateOnlineStatus()
    if not isSampAvailable() then return end
    
    local serverKey = SAMPServices.getCurrentServerKey()
    if not serverKey or not SAMPServices.smsData.servers[serverKey] then return end
    

    SAMPServices.playerOnlineStatus = {}
    
    -- Build set of online players by nickname
    local onlinePlayers = {}
    local maxPlayers = sampGetMaxPlayerId and sampGetMaxPlayerId() or 1000
    
    for id = 0, maxPlayers do
        if sampIsPlayerConnected(id) then
            local name = sampGetPlayerNickname(id)
            if name and name ~= "" then
                onlinePlayers[name:lower()] = true
            end
        end
    end
    

    for phone, contact in pairs(SAMPServices.smsData.servers[serverKey].contacts) do
        if contact.name then
            SAMPServices.playerOnlineStatus[contact.name:lower()] = onlinePlayers[contact.name:lower()] or false
        end
    end
end


function SAMPServices.isContactOnline(name)
    if not name then return false end
    return SAMPServices.playerOnlineStatus[name:lower()] or false
end

return SAMPServices
