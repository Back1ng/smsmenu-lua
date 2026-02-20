script_name("SMS Menu")
script_author("Back1ng")
script_version("1.0.0")
script_description("SMS Messenger for SAMP with Facebook Messenger-style UI")

require "lib.moonloader"
local imgui = require "lib.mimgui"
local ffi = require "ffi"
local json = require "lib.dkjson"
local lfs = require "lfs"
local sampEvents = require "lib.samp.events"
local encoding = require "encoding"
encoding.default = 'CP1251'
local UTF8 = encoding.UTF8
local CP1251 = encoding.CP1251

-- Helper function to get full path from relative path
local ui_modals = require "src.ui.modals"
local ui_left_panel = require "src.ui.left_panel"
local ui_right_panel = require "src.ui.right_panel"
local ui_window = require "src.ui.window"
local function getFullPath(relativePath)
    return getWorkingDirectory() .. [[\]] .. relativePath
end

-- UTF-8 → CP1251 для SAMP (как в sms_spam.lua); строки в скрипте в UTF-8, в ImGui передаём как есть
local utf8_str = setmetatable({}, {__call = function(_, str) return CP1251:encode(str, 'UTF-8') end})

-- CP1251 → UTF-8 для отображения в ImGui (сообщения из игры в CP1251)
local cp1251_to_utf8 = function(str)
    return UTF8:encode(str, 'CP1251')
end

-- Theme definitions
local THEMES = {
    light = {
        primary = imgui.ImVec4(0.0, 0.518, 1.0, 1.0),
        primaryHover = imgui.ImVec4(0.0, 0.45, 0.9, 1.0),
        background = imgui.ImVec4(1.0, 1.0, 1.0, 1.0),
        leftPanel = imgui.ImVec4(0.98, 0.98, 0.98, 1.0),
        receivedBubble = imgui.ImVec4(0.9, 0.9, 0.9, 1.0),
        sentBubble = imgui.ImVec4(0.0, 0.518, 1.0, 1.0),
        textDark = imgui.ImVec4(0.15, 0.15, 0.15, 1.0),
        textLight = imgui.ImVec4(1.0, 1.0, 1.0, 1.0),
        textGray = imgui.ImVec4(0.5, 0.5, 0.5, 1.0),
        border = imgui.ImVec4(0.88, 0.88, 0.88, 1.0),
        searchBg = imgui.ImVec4(0.93, 0.93, 0.93, 1.0),
        selected = imgui.ImVec4(0.88, 0.94, 1.0, 1.0)
    },
    dark = {
        primary = imgui.ImVec4(0.0, 0.6, 1.0, 1.0),
        primaryHover = imgui.ImVec4(0.0, 0.7, 1.0, 1.0),
        background = imgui.ImVec4(0.12, 0.12, 0.12, 1.0),
        leftPanel = imgui.ImVec4(0.18, 0.18, 0.18, 1.0),
        receivedBubble = imgui.ImVec4(0.25, 0.25, 0.25, 1.0),
        sentBubble = imgui.ImVec4(0.0, 0.6, 1.0, 1.0),
        textDark = imgui.ImVec4(0.95, 0.95, 0.95, 1.0),
        textLight = imgui.ImVec4(1.0, 1.0, 1.0, 1.0),
        textGray = imgui.ImVec4(0.6, 0.6, 0.6, 1.0),
        border = imgui.ImVec4(0.3, 0.3, 0.3, 1.0),
        searchBg = imgui.ImVec4(0.25, 0.25, 0.25, 1.0),
        selected = imgui.ImVec4(0.2, 0.35, 0.5, 1.0)
    }
}

-- Configuration (colors will be initialized later)
local CONFIG = {
    dataFile = [[config\smsmenu\messages.json]],
    settingsFile = [[config\smsmenu\settings.json]],
    alertsDir = [[config\smsmenu\allerts]],
    windowWidth = 900,
    windowHeight = 600,
    leftPanelWidth = 280,
    headerHeight = 50,
    inputHeight = 60,
    colors = nil, -- Will be initialized in main()
    currentTheme = "light",
    soundEnabled = true,
    hideSMSFromChat = true, -- hide SMS messages from SAMP chat
    currentSound = "1.wav", -- default sound file
    fontScale = 1.0 -- UI font scale (0.8 - 1.5)
}

-- Get scaled dimension based on current font scale
local function scaled(value)
    return math.floor(value * CONFIG.fontScale)
end

-- Available alert sounds
local ALERT_SOUNDS = {}



-- Scan available alert sounds
local function scanAlertSounds()
    ALERT_SOUNDS = {}
    local fullAlertsDir = getFullPath(CONFIG.alertsDir)
    
    if doesDirectoryExist(fullAlertsDir) then
        for file in lfs.dir(fullAlertsDir) do
            if file:match("%.wav$") then
                table.insert(ALERT_SOUNDS, file)
            end
        end
    else
        createDirectory(fullAlertsDir)
    end
    
    -- Sort alphabetically
    table.sort(ALERT_SOUNDS)
end

-- Windows PlaySound API (must be before playAlertSound)
ffi.cdef[[
    int PlaySoundA(const char* pszSound, void* hmod, unsigned long fdwSound);
    int MessageBeep(unsigned int uType);
]]
local winmm = ffi.load("winmm")
local SND_FILENAME = 0x00020000
local SND_ASYNC = 0x0001
local SND_NODEFAULT = 0x0002

-- Play alert sound using Windows API
local function playAlertSound()
    if not CONFIG.soundEnabled then return end
    if not CONFIG.currentSound or CONFIG.currentSound == "" then return end
    
    local soundPath = getFullPath(CONFIG.alertsDir .. [[\]] .. CONFIG.currentSound)
    soundPath = soundPath:gsub("/", "\\")
    
    if doesFileExist(soundPath) then
        local flags = SND_FILENAME + SND_ASYNC + SND_NODEFAULT
        local result = winmm.PlaySoundA(soundPath, nil, flags)
        if result == 0 then
            ffi.C.MessageBeep(0x40)
        end
    else
        ffi.C.MessageBeep(0xFFFFFFFF)
    end
end

-- State (will be initialized in main after imgui is ready)
local state = nil

-- Data storage
local smsData = {
    servers = {}
}

-- Reverse lookup cache: serverKey → { [name:lower()] = phone }
-- Provides O(1) name-to-phone lookup, eliminating O(n²) bottleneck
local nameToPhoneCache = {}

-- Message queue to prevent race conditions when multiple SMS arrive simultaneously
local messageQueue = {}
local isProcessingQueue = false
local lastSaveTime = 0
local pendingSave = false

-- SMS Patterns
local PATTERNS = {
    incoming = "SMS: ([^|]+) | \xCE\xF2\xEF\xF0\xE0\xE2\xE8\xF2\xE5\xEB\xFC: ([^[]+) %[(.-)%.(%d+)%]",
    outgoing = "SMS: ([^|]+) | \xCF\xEE\xEB\xF3\xF7\xE0\xF2\xE5\xEB\xFC: ([^[]+) %[(.-)%.(%d+)%]"
}

-- Utility Functions
local function ensureDirectoryExists(path)
    local dir = path:match("(.+)\\[^\\]+$")
    if dir and not doesDirectoryExist(dir) then
        createDirectory(dir)
    end
end

local function loadData()
    local fullPath = getFullPath(CONFIG.dataFile)
    ensureDirectoryExists(fullPath)
    if doesFileExist(fullPath) then
        local file = io.open(fullPath, "r")
        if file then
            local content = file:read("*all")
            file:close()
            local data, _, err = json.decode(content)
            if data then
                smsData = data
            end
        end
    end
    
    -- Build reverse lookup cache after loading data
    nameToPhoneCache = {}
    for serverKey, server in pairs(smsData.servers) do
        nameToPhoneCache[serverKey] = {}
        for phone, contact in pairs(server.contacts) do
            if contact.name then
                local nameKey = contact.name:lower()
                nameToPhoneCache[serverKey][nameKey] = phone
            end
        end
    end
end

-- Cache Management Functions

-- Rebuild the name-to-phone cache for a specific server
local function rebuildServerCache(serverKey)
    if not serverKey or not smsData.servers[serverKey] then return end
    
    nameToPhoneCache[serverKey] = {}
    for phone, contact in pairs(smsData.servers[serverKey].contacts) do
        if contact.name then
            local nameKey = contact.name:lower()
            nameToPhoneCache[serverKey][nameKey] = phone
        end
    end
end

-- Add or update a contact in the cache
local function updateContactCache(serverKey, oldName, newName, oldPhone, newPhone)
    if not serverKey then return end
    if not nameToPhoneCache[serverKey] then
        nameToPhoneCache[serverKey] = {}
    end
    
    -- Remove old name mapping if it exists
    if oldName then
        local oldNameKey = oldName:lower()
        if nameToPhoneCache[serverKey][oldNameKey] == oldPhone then
            nameToPhoneCache[serverKey][oldNameKey] = nil
        end
    end
    
    -- Add new name mapping
    if newName and newPhone then
        local newNameKey = newName:lower()
        nameToPhoneCache[serverKey][newNameKey] = newPhone
    end
end

-- Remove a contact from the cache
local function removeContactFromCache(serverKey, name, phone)
    if not serverKey or not nameToPhoneCache[serverKey] then return end
    
    if name then
        local nameKey = name:lower()
        -- Only remove if the mapping matches our phone
        if nameToPhoneCache[serverKey][nameKey] == phone then
            nameToPhoneCache[serverKey][nameKey] = nil
        end
    end
end

-- O(1) lookup: Find phone number by contact name using cache
local function findPhoneByName(serverKey, nickname)
    if not serverKey or not nickname then return nil end
    if not nameToPhoneCache[serverKey] then return nil end
    
    local nameKey = nickname:lower()
    return nameToPhoneCache[serverKey][nameKey]
end

-- Cache Validation and Recovery

-- Validate cache consistency against primary storage
-- Returns true if valid, false if corruption detected
local function validateCache(serverKey)
    if not serverKey or not smsData.servers[serverKey] then return true end
    
    local cache = nameToPhoneCache[serverKey]
    if not cache then
        -- Cache missing, needs rebuild
        return false
    end
    
    -- Check all cache entries match primary storage
    for nameKey, phone in pairs(cache) do
        local contact = smsData.servers[serverKey].contacts[phone]
        if not contact then
            -- Cache points to non-existent contact
            return false
        end
        if contact.name:lower() ~= nameKey then
            -- Name mismatch
            return false
        end
    end
    
    -- Check all contacts exist in cache
    for phone, contact in pairs(smsData.servers[serverKey].contacts) do
        if contact.name then
            local nameKey = contact.name:lower()
            if cache[nameKey] ~= phone then
                -- Contact missing from cache or wrong phone
                return false
            end
        end
    end
    
    return true
end

-- Rebuild cache if validation fails
local function ensureCacheIntegrity(serverKey)
    if not validateCache(serverKey) then
        rebuildServerCache(serverKey)
        return false
    end
    return true
end

local function loadSettings()
    local fullPath = getFullPath(CONFIG.settingsFile)
    ensureDirectoryExists(fullPath)
    if doesFileExist(fullPath) then
        local file = io.open(fullPath, "r")
        if file then
            local content = file:read("*all")
            file:close()
            local data, _, err = json.decode(content)
            if data then
                if data.theme then
                    CONFIG.currentTheme = data.theme
                end
                if data.soundEnabled ~= nil then
                    CONFIG.soundEnabled = data.soundEnabled
                end
                if data.currentSound then
                    CONFIG.currentSound = data.currentSound
                end
                if data.hideSMSFromChat ~= nil then
                    CONFIG.hideSMSFromChat = data.hideSMSFromChat
                end
                if data.fontScale ~= nil then
                    CONFIG.fontScale = math.max(0.8, math.min(1.5, data.fontScale))
                end
            end
        end
    end
end

local function saveSettings()
    local fullPath = getFullPath(CONFIG.settingsFile)
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

local function applyTheme(themeName)
    CONFIG.currentTheme = themeName
    CONFIG.colors = THEMES[themeName]
    saveSettings()
end

local function saveData()
    local fullPath = getFullPath(CONFIG.dataFile)
    ensureDirectoryExists(fullPath)
    local file = io.open(fullPath, "w")
    if file then
        file:write(json.encode(smsData, { indent = true }))
        file:close()
    end
    lastSaveTime = os.time()
    pendingSave = false
end





local function getCurrentServerKey()
    if not isSampAvailable() then return nil end
    local ip, port = sampGetCurrentServerAddress()
    if ip and port then
        return ip .. ":" .. port
    end
    return nil
end

local function getCurrentServerName()
    if not isSampAvailable() then return "Unknown Server" end
    -- Try to get server name from SAMP
    local name = sampGetCurrentServerName and sampGetCurrentServerName() or nil
    if name and name ~= "" then
        return name
    end
    return "Server"
end

local function getOrCreateServer(serverKey)
    if not smsData.servers[serverKey] then
        smsData.servers[serverKey] = {
            name = getCurrentServerName(),
            contacts = {}
        }
    end
    return smsData.servers[serverKey]
end

local function deleteContact(phone)
    local serverKey = getCurrentServerKey()
    if serverKey and smsData.servers[serverKey] then
        local contact = smsData.servers[serverKey].contacts[phone]
        if contact then
            -- Remove from cache before deleting from storage
            removeContactFromCache(serverKey, contact.name, phone)
        end
        
        smsData.servers[serverKey].contacts[phone] = nil
        if state.selectedContact and state.selectedContact.phone == phone then
            state.selectedContact = nil
        end
        saveData()
    end
end

-- Mark all messages from a contact as read
local function markContactAsRead(phone)
    local serverKey = getCurrentServerKey()
    if serverKey and smsData.servers[serverKey] and smsData.servers[serverKey].contacts[phone] then
        local contact = smsData.servers[serverKey].contacts[phone]
        contact.unreadCount = 0
        for _, msg in ipairs(contact.messages) do
            msg.read = true
        end
        saveData()
    end
end

-- Online status tracking
local playerOnlineStatus = {} -- cache: name -> boolean
local lastOnlineUpdate = 0

-- Update online status for all contacts
local function updateOnlineStatus()
    if not isSampAvailable() then return end
    
    local serverKey = getCurrentServerKey()
    if not serverKey or not smsData.servers[serverKey] then return end
    
    -- Clear cache
    playerOnlineStatus = {}
    
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
    
    -- Update status for all contacts
    for phone, contact in pairs(smsData.servers[serverKey].contacts) do
        if contact.name then
            playerOnlineStatus[contact.name:lower()] = onlinePlayers[contact.name:lower()] or false
        end
    end
    
    lastOnlineUpdate = os.time()
end

-- Check if a contact is online
local function isContactOnline(name)
    if not name then return false end
    return playerOnlineStatus[name:lower()] or false
end

-- Animation helper functions
local function lerp(a, b, t)
    return a + (b - a) * math.min(t, 1.0)
end

local function easeOutCubic(t)
    return 1 - math.pow(1 - t, 3)
end

local function easeOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
end

-- Initialize message animation for a contact
local function startMessageAnimation(phone)
    if not state then return end
    state.messageAnimations[phone] = {
        startTime = imgui.GetTime(),
        duration = 0.4
    }
end

-- Get message animation progress (0-1)
local function getMessageAnimationProgress(phone)
    if not state or not state.messageAnimations[phone] then return 1.0 end
    local anim = state.messageAnimations[phone]
    local elapsed = imgui.GetTime() - anim.startTime
    local progress = elapsed / anim.duration
    if progress >= 1.0 then
        state.messageAnimations[phone] = nil
        return 1.0
    end
    return easeOutCubic(progress)
end

-- Contact Management (Nickname-based with number updates)
-- Uses O(1) cache lookup for name-to-phone resolution
local function getOrCreateContact(serverKey, nickname, phoneNumber)
    local server = getOrCreateServer(serverKey)
    
    -- O(1) cache lookup for existing contact by nickname
    local existingPhone = findPhoneByName(serverKey, nickname)
    
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
                updateContactCache(serverKey, nickname, nickname, existingPhone, phoneNumber)
                
                saveData()
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
        updateContactCache(serverKey, nil, nickname, nil, phoneNumber)
        
        saveData()
    end
    
    return server.contacts[phoneNumber], phoneNumber
end

-- Process queued messages one by one to prevent race conditions
local function processMessageQueue()
    if isProcessingQueue then return end
    isProcessingQueue = true
    
    while #messageQueue > 0 do
        local msgData = table.remove(messageQueue, 1)
        local serverKey = msgData.serverKey
        local nickname = msgData.nickname
        local phoneNumber = msgData.phoneNumber
        local text = msgData.text
        local isOutgoing = msgData.isOutgoing
        
        -- Get or create contact
        local contact, currentNumber = getOrCreateContact(serverKey, nickname, phoneNumber)
        
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
        
        -- Increment unread count for incoming messages
        if not isOutgoing then
            contact.unreadCount = (contact.unreadCount or 0) + 1
        end
        
        -- Limit message history to last 100 messages per contact
        if #contact.messages > 100 then
            table.remove(contact.messages, 1)
        end
    end
    
    -- Save all changes at once after processing queue
    if pendingSave then
        saveData()
    end
    
    isProcessingQueue = false
end

-- Queue a message for processing (thread-safe)
local function queueMessage(serverKey, nickname, phoneNumber, text, isOutgoing)
    table.insert(messageQueue, {
        serverKey = serverKey,
        nickname = nickname,
        phoneNumber = phoneNumber,
        text = text,
        isOutgoing = isOutgoing,
        timestamp = os.time()
    })
    pendingSave = true
    
    -- Process immediately if possible
    processMessageQueue()
    
    return phoneNumber
end

local function addMessage(serverKey, nickname, phoneNumber, text, isOutgoing)
    -- Use queue-based processing to prevent race conditions
    local currentNumber = queueMessage(serverKey, nickname, phoneNumber, text, isOutgoing)
    
    -- Trigger UI updates
    if state then
        state.scrollToBottom = true
        state.newMessageAnim = 1.0
    end
    
    return currentNumber
end

local function getContactsList(serverKey)
    local server = smsData.servers[serverKey]
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

-- UI Helper Functions (moved here to be available for handleChatMessage)
local function formatTime(timestamp)
    timestamp = tonumber(timestamp)
    if not timestamp or timestamp == 0 then return "" end
    local diff = os.time() - timestamp
    
    if diff < 60 then
        return "now"
    elseif diff < 3600 then
        return tostring(math.floor(diff / 60)) .. "m"
    elseif diff < 86400 then
        return tostring(math.floor(diff / 3600)) .. "h"
    else
        return os.date("%d.%m", timestamp) or ""
    end
end

local function filterContacts(searchText)
    if not searchText or searchText == "" then
        return state.contacts
    end
    
    local filtered = {}
    local search = searchText:lower()
    
    for _, contact in ipairs(state.contacts) do
        if contact.name:lower():find(search, 1, true) or 
           contact.phone:find(search, 1, true) then
            table.insert(filtered, contact)
        end
    end
    
    return filtered
end

-- SMS Capture
local function handleChatMessage(msg)
    -- Check for incoming SMS
    local text, sender, _, phone = msg:match(PATTERNS.incoming)
    if text then text = text:match("^%s*(.-)%s*$") end  -- trim
    if sender then sender = sender:match("^%s*(.-)%s*$") end  -- trim
    if text and sender and phone then
        local serverKey = getCurrentServerKey()
        if serverKey then
            addMessage(serverKey, sender, phone, text, false)
            -- Play alert sound for incoming message
            playAlertSound()
            -- Refresh contacts list if window is open
            if state and state.windowOpen[0] then
                state.contacts = getContactsList(serverKey)
                state.filteredContacts = filterContacts(ffi.string(state.searchText))
                -- If this contact is currently selected, mark as read immediately
                if state.selectedContact and state.selectedContact.phone == phone then
                    markContactAsRead(phone)
                    state.contacts = getContactsList(serverKey)
                    state.filteredContacts = filterContacts(ffi.string(state.searchText))
                end
            end
        end
        return true -- Message was handled (incoming SMS)
    end
    
    -- Check for outgoing SMS
    text, sender, _, phone = msg:match(PATTERNS.outgoing)
    if text then text = text:match("^%s*(.-)%s*$") end  -- trim
    if sender then sender = sender:match("^%s*(.-)%s*$") end  -- trim
    if text and sender and phone then
        local serverKey = getCurrentServerKey()
        if serverKey then
            addMessage(serverKey, sender, phone, text, true)
            -- Refresh contacts list if window is open
            if state and state.windowOpen[0] then
                state.contacts = getContactsList(serverKey)
            end
        end
        return true -- Message was handled (outgoing SMS)
    end
    return false -- Message was not an SMS
end


-- =============================================================================
-- EXTRACTED MODULES - Feature Envy Refactoring
-- These modules extract text metrics and SMS sending logic from drawRightPanel
-- =============================================================================

--[[
    TextMetrics Module
    
    Provides O(1) constant-time text wrapping estimation and character width metrics.
    Extracted from drawRightPanel to address Feature Envy code smell.
    
    Features:
    - Precomputed character width metrics for standard proportional fonts
    - Tab-stop aligned tab width calculation
    - Cumulative indent metrics for hierarchical content
    - Internal whitespace detection
--]]
local TextMetrics
TextMetrics = {
    --[[
        Precomputed character width metrics (average pixel widths for typical UI font)
        These values are calibrated for standard proportional fonts at base scale 1.0
        ENHANCED: Added tab-stop configuration and cumulative indent support for large depths
    --]]
    CHAR_WIDTHS = {
        -- Base average width for ASCII characters
        AVG_CHAR_WIDTH = 7.0,
        -- Width of space character (typically narrower)
        SPACE_WIDTH = 3.5,
        -- Line height in pixels
        LINE_HEIGHT = 14.0,
        -- Safety padding factor for word boundary overhead (5% is sufficient for most cases)
        WORD_WRAP_OVERHEAD = 1.05,
        -- Minimum estimated characters per word (for word boundary calculation)
        MIN_WORD_LENGTH = 3.5,
        -- Legacy tab character width (deprecated: use tab-stop calculations instead)
        TAB_WIDTH = 14.0,
        -- Non-breaking space width
        NBSP_WIDTH = 3.5,
        
        --[[
            TAB-STOP CONFIGURATION
            Configurable tab-stop positions for proper tab width calculation.
            Tab width varies based on current column position (tab-stop alignment).
        --]]
        TAB_STOP = {
            -- Default tab-stop interval (4 or 8 character positions)
            INTERVAL = 4,
            -- Maximum number of tab-stops to precompute (covers up to 512 chars)
            MAX_PRECOMPUTED = 128,
            -- Space-equivalent width for statistical estimation
            AVG_TAB_WIDTH = 14.0,  -- 4 * SPACE_WIDTH
        },
        
        --[[
            CUMULATIVE INDENT CONFIGURATION
            Settings for handling indentation preserved across wrapped lines.
        --]]
        CUMULATIVE_INDENT = {
            -- Maximum indentation depth levels supported (10+ for deep nesting)
            MAX_DEPTH = 20,
            -- Factor for estimating wrapped lines per indentation level
            WRAP_FACTOR_PER_DEPTH = 0.15,
            -- Maximum cumulative indent as percentage of available width
            MAX_PERCENTAGE = 0.60,
            -- Statistical overhead for hierarchical content (bullet points, code blocks)
            HIERARCHICAL_OVERHEAD = 1.25,
        },
        
        --[[
            INTERNAL WHITESPACE PRESERVATION
            Settings for maintaining internal indentation structures.
        --]]
        INTERNAL_WHITESPACE = {
            -- Estimated percentage of text containing internal indentation
            OCCURRENCE_RATE = 0.20,
            -- Average internal indent width in characters
            AVG_INTERNAL_CHARS = 8,
            -- Overhead factor for multi-line indented content
            MULTILINE_OVERHEAD = 1.15,
        },
        
        --[[
            BOTTOM PADDING CONFIGURATION
            Bottom internal padding for message list container.
            Integrated with O(1) estimation pipeline for proper vertical layout.
        --]]
        BOTTOM_PADDING = 5.0,
    },
    
    --[[
        O(1) CONSTANT-TIME INDENTATION ANALYSIS WITH TAB-STOP CALCULATION
        
        Enhanced version that handles:
        - Tab-stop aligned tab widths (variable based on column position)
        - Mixed tabs and spaces in indentation
        - Cumulative indent metrics for hierarchical content
        - Large indentation depths (10+ levels) via statistical estimation
        
        Uses pattern matching (C-optimized in Lua) to detect leading whitespace
        without iterating through each character.
        
        @param text The text to analyze (string)
        @param fontScaleMultiplier Font scale for pixel calculations (number)
        @param columnPos Optional starting column position for tab-stop calc (default 0)
        @return indentWidth Width of leading indentation in pixels (number)
        @return indentChars Number of leading whitespace characters (number)
        @return indentDepth Estimated indentation depth level (number)
        @return cumulativeWidth Estimated cumulative width across wrapped lines (number)
    --]]
    measureLeadingIndent = function(text, fontScaleMultiplier, columnPos)
        columnPos = columnPos or 0
        fontScaleMultiplier = fontScaleMultiplier or 1.0
        
        if not text or text == "" then
            return 0, 0, 0, 0
        end
        
        local CHAR_WIDTHS = TextMetrics.CHAR_WIDTHS
        
        -- O(1) pattern match for leading whitespace using Lua's pattern engine
        local leadingSpaces, leadingTabs = 0, 0
        
        -- Match leading spaces (including non-breaking space \160)
        local spacePattern = text:match("^( *)")
        if spacePattern then
            leadingSpaces = #spacePattern
        end
        
        -- Match leading tabs
        local tabPattern = text:match("^(\t*)")
        if tabPattern then
            leadingTabs = #tabPattern
        end
        
        -- Build TAB_STOP_WIDTHS lookup table
        local TAB_STOP_WIDTHS = {}
        for col = 0, CHAR_WIDTHS.TAB_STOP.MAX_PRECOMPUTED - 1 do
            local spacesToNextTab = CHAR_WIDTHS.TAB_STOP.INTERVAL - (col % CHAR_WIDTHS.TAB_STOP.INTERVAL)
            TAB_STOP_WIDTHS[col] = spacesToNextTab * CHAR_WIDTHS.SPACE_WIDTH
        end
        
        -- O(1) tab-stop width calculation using precomputed lookup table
        local totalTabWidth = 0
        local currentCol = columnPos
        
        for t = 1, math.min(leadingTabs, 32) do  -- Limit to 32 tabs for safety
            local tabWidth = TAB_STOP_WIDTHS[currentCol] or CHAR_WIDTHS.TAB_STOP.AVG_TAB_WIDTH
            totalTabWidth = totalTabWidth + tabWidth
            -- Advance to next tab stop
            local spacesToNext = CHAR_WIDTHS.TAB_STOP.INTERVAL - (currentCol % CHAR_WIDTHS.TAB_STOP.INTERVAL)
            currentCol = currentCol + spacesToNext
        end
        
        -- Handle case of many tabs (>32) using statistical estimation
        if leadingTabs > 32 then
            local remainingTabs = leadingTabs - 32
            totalTabWidth = totalTabWidth + (remainingTabs * CHAR_WIDTHS.TAB_STOP.AVG_TAB_WIDTH)
            currentCol = currentCol + (remainingTabs * CHAR_WIDTHS.TAB_STOP.INTERVAL)
        end
        
        -- Calculate total indentation width in pixels
        local spaceWidth = leadingSpaces * CHAR_WIDTHS.SPACE_WIDTH
        local indentWidth = (spaceWidth + totalTabWidth) * fontScaleMultiplier
        
        -- O(1) indentation depth estimation based on total whitespace
        local totalWhitespace = leadingSpaces + (leadingTabs * CHAR_WIDTHS.TAB_STOP.INTERVAL)
        local indentDepth = math.min(
            math.floor(totalWhitespace / CHAR_WIDTHS.TAB_STOP.INTERVAL),
            CHAR_WIDTHS.CUMULATIVE_INDENT.MAX_DEPTH
        )
        
        -- Build INDENT_DEPTH_FACTORS lookup table
        local INDENT_DEPTH_FACTORS = {}
        for depth = 0, CHAR_WIDTHS.CUMULATIVE_INDENT.MAX_DEPTH do
            INDENT_DEPTH_FACTORS[depth] = 1.0 + (math.sqrt(depth) * CHAR_WIDTHS.CUMULATIVE_INDENT.WRAP_FACTOR_PER_DEPTH)
        end
        
        -- O(1) cumulative width estimation using depth factors
        local depthFactor = INDENT_DEPTH_FACTORS[indentDepth] or INDENT_DEPTH_FACTORS[CHAR_WIDTHS.CUMULATIVE_INDENT.MAX_DEPTH]
        local cumulativeWidth = indentWidth * depthFactor
        
        return indentWidth, leadingSpaces + leadingTabs, indentDepth, cumulativeWidth
    end,
    
    --[[
        O(1) CONSTANT-TIME LINE ESTIMATION WITH CUMULATIVE INDENT METRICS
        
        Uses statistical approximation based on:
        - Text length (byte count, O(1) operation)
        - Average character width (precomputed constant)
        - Word wrap overhead factor (statistical correction)
        - Leading indentation with tab-stop alignment (O(1) lookup)
        - Cumulative indent impact across wrapped lines (O(1) depth factor)
        
        @param text The text to estimate (string)
        @param maxWidth Maximum available width for the text (number)
        @param fontScaleMultiplier Font scale for calculations (number)
        @return lines Estimated number of lines (number)
        @return lineHeight Height of each line in pixels (number)
    --]]
    estimateLines = function(text, maxWidth, fontScaleMultiplier)
        fontScaleMultiplier = fontScaleMultiplier or 1.0
        local CHAR_WIDTHS = TextMetrics.CHAR_WIDTHS
        
        -- Handle edge cases (O(1))
        if not text or text == "" then
            return 1, CHAR_WIDTHS.LINE_HEIGHT * fontScaleMultiplier
        end
        
        -- Get text length - O(1) operation in Lua (# operator)
        local textLength = #text
        
        -- O(1) calculation: Measure leading indentation with tab-stop alignment
        local indentWidth, indentChars, indentDepth, cumulativeWidth =
            TextMetrics.measureLeadingIndent(text, fontScaleMultiplier)
        
        -- O(1) calculation: Detect internal whitespace structures
        local hasInternalIndent, internalIndentWidth = false, 0
        
        -- O(1) pattern match for internal whitespace patterns
        -- Check for indentation after newlines (O(1) single pattern match)
        local newlineIndent = text:match("\n([ \t]+)")
        if newlineIndent then
            hasInternalIndent = true
        end
        
        -- O(1) statistical estimation: check first occurrence only
        local spacePattern = text:match("[^%S\r\n]([ ]{3,})")
        if spacePattern then
            hasInternalIndent = true
        end
        
        local tabPattern = text:match("[^%S\r\n](\t+)")
        if tabPattern then
            hasInternalIndent = true
        end
        
        -- O(1) statistical width estimation for internal whitespace
        if hasInternalIndent then
            internalIndentWidth = CHAR_WIDTHS.INTERNAL_WHITESPACE.AVG_INTERNAL_CHARS *
                                  CHAR_WIDTHS.SPACE_WIDTH *
                                  CHAR_WIDTHS.INTERNAL_WHITESPACE.MULTILINE_OVERHEAD *
                                  fontScaleMultiplier
        end
        
        -- Quick single-line check for short texts (O(1))
        if textLength <= 10 and not hasInternalIndent then
            local estimatedWidth = textLength * CHAR_WIDTHS.AVG_CHAR_WIDTH * fontScaleMultiplier
            if estimatedWidth <= maxWidth then
                return 1, CHAR_WIDTHS.LINE_HEIGHT * fontScaleMultiplier
            end
        end
        
        -- O(1) calculation: Determine effective available width accounting for indentation
        local effectiveIndentWidth = indentWidth
        if indentDepth >= 3 then
            effectiveIndentWidth = indentWidth * math.min(1.0 + (indentDepth * 0.1), 1.5)
        end
        
        effectiveIndentWidth = effectiveIndentWidth + internalIndentWidth
        
        local effectiveMaxWidth = maxWidth - effectiveIndentWidth
        if effectiveMaxWidth < maxWidth * 0.4 then
            effectiveMaxWidth = maxWidth * 0.4
        end
        
        -- O(1) calculation: Determine raw character capacity per line
        local effectiveCharWidth = CHAR_WIDTHS.AVG_CHAR_WIDTH * fontScaleMultiplier
        local charsPerLine = effectiveMaxWidth / effectiveCharWidth
        
        -- O(1) calculation: Estimate raw lines needed without word wrap
        local rawLines = textLength / charsPerLine
        
        -- O(1) calculation: Estimate word count statistically
        local estimatedWordCount = textLength / CHAR_WIDTHS.MIN_WORD_LENGTH
        local estimatedWordsPerLine = charsPerLine / CHAR_WIDTHS.MIN_WORD_LENGTH
        local linesFromWords = estimatedWordCount / math.max(estimatedWordsPerLine, 1)
        
        -- O(1) calculation: Take maximum of character-based and word-based estimates
        local baseEstimate = math.max(rawLines, linesFromWords)
        
        -- O(1) calculation: Calculate cumulative indent metrics for wrapped lines
        -- Build INDENT_DEPTH_FACTORS lookup table
        local INDENT_DEPTH_FACTORS = {}
        for depth = 0, CHAR_WIDTHS.CUMULATIVE_INDENT.MAX_DEPTH do
            INDENT_DEPTH_FACTORS[depth] = 1.0 + (math.sqrt(depth) * CHAR_WIDTHS.CUMULATIVE_INDENT.WRAP_FACTOR_PER_DEPTH)
        end
        
        indentDepth = math.min(indentDepth, CHAR_WIDTHS.CUMULATIVE_INDENT.MAX_DEPTH)
        local depthFactor = INDENT_DEPTH_FACTORS[indentDepth] or 1.0
        
        local hierarchicalOverhead = 1.0
        if indentDepth >= 3 then
            hierarchicalOverhead = CHAR_WIDTHS.CUMULATIVE_INDENT.HIERARCHICAL_OVERHEAD
        end
        
        -- O(1) calculation: Apply word wrap overhead padding
        local indentOverhead = 1.0
        if indentDepth > 0 then
            indentOverhead = 1.05
            if indentDepth >= 3 then
                indentOverhead = indentOverhead * hierarchicalOverhead
            end
            if hasInternalIndent then
                indentOverhead = indentOverhead * CHAR_WIDTHS.INTERNAL_WHITESPACE.MULTILINE_OVERHEAD
            end
        end
        
        -- Calculate final estimated lines with all factors applied
        local estimatedLines = math.ceil(baseEstimate * CHAR_WIDTHS.WORD_WRAP_OVERHEAD * indentOverhead)
        
        -- Apply cumulative indent adjustment for deeply wrapped content
        if indentDepth > 0 and estimatedLines > 2 then
            estimatedLines = math.ceil(estimatedLines * depthFactor / math.sqrt(estimatedLines))
        end
        
        -- Ensure at least 1 line is returned
        return math.max(estimatedLines, 1), CHAR_WIDTHS.LINE_HEIGHT * fontScaleMultiplier
    end,
}

--[[
    MessageService Module
    
    Handles SMS sending functionality.
    Extracted from drawRightPanel to address Feature Envy code smell.
    
    Provides a clean interface for sending SMS messages through the game chat system.
    Handles UTF-8 to CP1251 conversion automatically.
--]]
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
        -- utf8_str and sampSendChat are global functions available in the script
        sampSendChat(utf8_str("/sms " .. phoneStr .. " " .. messageStr))
        
        return true
    end,
}


-- Main function
function main()
    while not isSampAvailable() do
        wait(100)
    end
    
    -- Load settings (theme) before initializing state
    loadSettings()
    
    -- Initialize state after imgui is available
    state = {
        windowOpen = imgui.new.bool(false),
        searchText = imgui.new.char[256](""),
        messageText = imgui.new.char[512](""),
        selectedContact = nil,
        contacts = {},
        filteredContacts = {},
        currentServer = nil,
        scrollToBottom = false,
        newMessageAnim = 0.0,
        showNewContactDialog = false,
        newContactPhone = imgui.new.char[32](""),
        newContactName = imgui.new.char[64](""),
        showEditContactDialog = false,
        editContactPhone = imgui.new.char[32](""),
        editContactName = imgui.new.char[64](""),
        showDeleteConfirmDialog = false,
        deleteContactName = "",
        deleteContactPhone = "",
        showSettingsDialog = false,
        lastScrollMax = 0,
        -- Animation states
        messageAnimations = {}, -- phone -> { startTime, duration }
        contactHover = {},      -- index -> hoverProgress (0-1)
        windowOpenAnim = 0.0,   -- 0-1 fade in
        newMessagePulse = 0.0,  -- pulse animation for unread indicator
    }
    
    -- Apply saved or default theme
    applyTheme(CONFIG.currentTheme)
    
    -- Load saved data
    loadData()
    
    -- Scan available alert sounds
    scanAlertSounds()
    
    -- Create empty messages.json on first run if doesn't exist
    if not doesFileExist(getFullPath(CONFIG.dataFile)) then
        saveData()
    end
    

    
    -- Initialize UI modules
    local uiDeps = {
        imgui = imgui,
        ffi = ffi,
        CONFIG = CONFIG,
        state = state,
        scaled = scaled,
        applyTheme = applyTheme,
        cp1251_to_utf8 = cp1251_to_utf8,
        isContactOnline = isContactOnline,
        filterContacts = filterContacts,
        easeOutCubic = easeOutCubic,
        easeOutBack = easeOutBack,
        getCurrentServerKey = getCurrentServerKey,
        getContactsList = getContactsList,
        markContactAsRead = markContactAsRead,
        getOrCreateServer = getOrCreateServer,
        updateContactCache = updateContactCache,
        saveData = saveData,
        deleteContact = deleteContact,
        smsData = smsData,
        saveSettings = saveSettings,
        ALERT_SOUNDS = ALERT_SOUNDS,
        playAlertSound = playAlertSound,
        TextMetrics = TextMetrics,
        sampSendChat = sampSendChat,
        MessageService = MessageService,
        formatTime = formatTime,
        drawLeftPanel = ui_left_panel.drawLeftPanel,
        drawRightPanel = ui_right_panel.drawRightPanel,
        drawNewContactDialog = ui_modals.drawNewContactDialog,
        drawEditContactDialog = ui_modals.drawEditContactDialog,
        drawDeleteConfirmDialog = ui_modals.drawDeleteConfirmDialog,
        drawSettingsDialog = ui_modals.drawSettingsDialog
    }
    ui_modals.init(uiDeps)
    ui_left_panel.init(uiDeps)
    ui_right_panel.init(uiDeps)
    ui_window.init(uiDeps)
    
    ui_window.setup()

    -- Toggle function (available globally for binders)
    _G.toggleSMSMenu = function()
        if not state or not state.windowOpen then return end
        local wasOpen = state.windowOpen[0]
        state.windowOpen[0] = not state.windowOpen[0]
        if state.windowOpen[0] then
            -- Reset window animation
            state.windowOpenAnim = 0.0
            -- Reset contact hover animations
            state.contactHover = {}
            -- Refresh contacts when opening
            local serverKey = getCurrentServerKey()
            if serverKey then
                state.contacts = getContactsList(serverKey)
                state.filteredContacts = {}
            end
            -- Scroll to bottom if contact selected and mark as read
            if state.selectedContact then
                state.scrollToBottom = true
                markContactAsRead(state.selectedContact.phone)
                -- Refresh to update unread indicators
                state.contacts = getContactsList(serverKey)
            end
            -- Update online status immediately when opening
            updateOnlineStatus()
        end
        

    end
    
    -- Register chat command
    sampRegisterChatCommand("smsm", _G.toggleSMSMenu)
    
    -- Register imgui frame handler
    
    -- Hook chat messages using sampEvents
    -- Returns false to hide message from chat, true/nil to show
    sampEvents.onServerMessage = function(color, text)
        if text then
            local isSMS = handleChatMessage(tostring(text))
            if isSMS and CONFIG.hideSMSFromChat then
                return false -- Hide SMS from chat
            end
        end
    end
    
    sampEvents.onChatMessage = function(playerId, text)
        if text then
            local isSMS = handleChatMessage(tostring(text))
            if isSMS and CONFIG.hideSMSFromChat then
                return false -- Hide SMS from chat
            end
        end
    end
    
    -- Main loop
    while true do
        wait(0)
        
        -- F3 hotkey to toggle messenger
        if isKeyJustPressed(0x72) and not sampIsChatInputActive() and not sampIsDialogActive() then
            _G.toggleSMSMenu()
        end
        
        -- Animate new message indicator
        if state.newMessageAnim > 0 then
            state.newMessageAnim = state.newMessageAnim - 0.02
            if state.newMessageAnim < 0 then
                state.newMessageAnim = 0
            end
        end
        
        -- Animate window open
        if state.windowOpen[0] and state.windowOpenAnim < 1.0 then
            state.windowOpenAnim = math.min(state.windowOpenAnim + 0.15, 1.0)
        elseif not state.windowOpen[0] and state.windowOpenAnim > 0 then
            state.windowOpenAnim = math.max(state.windowOpenAnim - 0.15, 0)
        end
        
        -- Animate new message pulse
        state.newMessagePulse = (os.clock() % 1.0)  -- 0 to 1 cycle
        

        
        -- Update online status every 2 seconds when window is open
        if state.windowOpen[0] and os.time() - lastOnlineUpdate >= 2 then
            updateOnlineStatus()
        end
        
        -- Process any pending messages in queue and save if needed
        if #messageQueue > 0 or pendingSave then
            processMessageQueue()
        end
        
        -- Periodic save every 5 seconds if there are pending changes
        if pendingSave and os.time() - lastSaveTime >= 5 then
            saveData()
        end
        
    end
    
    -- Final save on script exit
    saveData()
end
