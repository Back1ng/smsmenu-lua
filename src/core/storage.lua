local json = require "lib.dkjson"

local M = {}
local CONFIG = nil

M.smsData = { servers = {} }
M.nameToPhoneCache = {}
M.lastSaveTime = 0
M.pendingSave = false

function M.init(deps)
    CONFIG = deps.CONFIG
    M.getFullPath = deps.getFullPath
end

local function ensureDirectoryExists(path)
    local dir = path:match("(.+)\\[^\\]+$")
    if dir and not doesDirectoryExist(dir) then
        createDirectory(dir)
    end
end

function M.loadData()
    local fullPath = M.getFullPath(CONFIG.dataFile)
    ensureDirectoryExists(fullPath)
    if doesFileExist(fullPath) then
        local file = io.open(fullPath, "r")
        if file then
            local content = file:read("*all")
            file:close()
            local data, _, err = json.decode(content)
            if data then
                -- copy to maintain table reference
                for k in pairs(M.smsData) do M.smsData[k] = nil end
                for k, v in pairs(data) do M.smsData[k] = v end
            end
        end
    end
    
    M.nameToPhoneCache = {}
    for serverKey, server in pairs(M.smsData.servers) do
        M.nameToPhoneCache[serverKey] = {}
        for phone, contact in pairs(server.contacts) do
            if contact.name then
                local nameKey = contact.name:lower()
                M.nameToPhoneCache[serverKey][nameKey] = phone
            end
        end
    end
    return M.smsData, M.nameToPhoneCache
end

function M.saveData()
    local fullPath = M.getFullPath(CONFIG.dataFile)
    ensureDirectoryExists(fullPath)
    local file = io.open(fullPath, "w")
    if file then
        file:write(json.encode(M.smsData, { indent = true }))
        file:close()
    end
    M.lastSaveTime = os.time()
    M.pendingSave = false
end

function M.loadSettings()
    local fullPath = M.getFullPath(CONFIG.settingsFile)
    ensureDirectoryExists(fullPath)
    if doesFileExist(fullPath) then
        local file = io.open(fullPath, "r")
        if file then
            local content = file:read("*all")
            file:close()
            local data, _, err = json.decode(content)
            if data then
                if data.theme then CONFIG.currentTheme = data.theme end
                if data.soundEnabled ~= nil then CONFIG.soundEnabled = data.soundEnabled end
                if data.currentSound then CONFIG.currentSound = data.currentSound end
                if data.hideSMSFromChat ~= nil then CONFIG.hideSMSFromChat = data.hideSMSFromChat end
                if data.fontScale ~= nil then CONFIG.fontScale = math.max(0.8, math.min(1.5, data.fontScale)) end
            end
        end
    end
end

function M.saveSettings()
    local fullPath = M.getFullPath(CONFIG.settingsFile)
    ensureDirectoryExists(fullPath)
    local file = io.open(fullPath, "w")
    if file then
        file:write(json.encode({ 
            theme = CONFIG.currentTheme,
            soundEnabled = CONFIG.soundEnabled,
            currentSound = CONFIG.currentSound,
            hideSMSFromChat = CONFIG.hideSMSFromChat,
            fontScale = CONFIG.fontScale
        }, { indent = true }))
        file:close()
    end
end

function M.rebuildServerCache(serverKey)
    if not serverKey or not M.smsData.servers[serverKey] then return end
    M.nameToPhoneCache[serverKey] = {}
    for phone, contact in pairs(M.smsData.servers[serverKey].contacts) do
        if contact.name then
            local nameKey = contact.name:lower()
            M.nameToPhoneCache[serverKey][nameKey] = phone
        end
    end
end

function M.updateContactCache(serverKey, oldName, newName, oldPhone, newPhone)
    if not serverKey then return end
    if not M.nameToPhoneCache[serverKey] then M.nameToPhoneCache[serverKey] = {} end
    if oldName then
        local oldNameKey = oldName:lower()
        if M.nameToPhoneCache[serverKey][oldNameKey] == oldPhone then
            M.nameToPhoneCache[serverKey][oldNameKey] = nil
        end
    end
    if newName and newPhone then
        local newNameKey = newName:lower()
        M.nameToPhoneCache[serverKey][newNameKey] = newPhone
    end
end

function M.removeContactFromCache(serverKey, name, phone)
    if not serverKey or not M.nameToPhoneCache[serverKey] then return end
    if name then
        local nameKey = name:lower()
        if M.nameToPhoneCache[serverKey][nameKey] == phone then
            M.nameToPhoneCache[serverKey][nameKey] = nil
        end
    end
end

function M.findPhoneByName(serverKey, nickname)
    if not serverKey or not nickname then return nil end
    if not M.nameToPhoneCache[serverKey] then return nil end
    local nameKey = nickname:lower()
    return M.nameToPhoneCache[serverKey][nameKey]
end

function M.validateCache(serverKey)
    if not serverKey or not M.smsData.servers[serverKey] then return true end
    local cache = M.nameToPhoneCache[serverKey]
    if not cache then return false end
    for nameKey, phone in pairs(cache) do
        local contact = M.smsData.servers[serverKey].contacts[phone]
        if not contact then return false end
        if contact.name:lower() ~= nameKey then return false end
    end
    for phone, contact in pairs(M.smsData.servers[serverKey].contacts) do
        if contact.name then
            local nameKey = contact.name:lower()
            if cache[nameKey] ~= phone then return false end
        end
    end
    return true
end

function M.ensureCacheIntegrity(serverKey)
    if not M.validateCache(serverKey) then
        M.rebuildServerCache(serverKey)
        return false
    end
    return true
end

return M
