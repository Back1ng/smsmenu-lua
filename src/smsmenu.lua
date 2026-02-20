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

-- Utils
local utils_encoding = require "src.utils.encoding"
local utils_time = require "src.utils.time"
local utils_anim = require "src.utils.anim"
local TextMetrics = require "src.utils.metrics"
local MessageService = require "src.services.message"
local ContactService = require "src.services.contact"
local SAMPServices = require "src.services.samp"
local ChatHookService = require "src.services.chat_hook"

local messageQueue = {}
local isProcessingQueue = false

local utf8_str = utils_encoding.utf8_str
local cp1251_to_utf8 = utils_encoding.cp1251_to_utf8
local formatTime = utils_time.formatTime
local lerp = utils_anim.lerp
local easeOutCubic = utils_anim.easeOutCubic
local easeOutBack = utils_anim.easeOutBack

-- Helper function to get full path from relative path
local ui_modals = require "src.ui.modals"
local ui_left_panel = require "src.ui.left_panel"
local ui_right_panel = require "src.ui.right_panel"
local ui_window = require "src.ui.window"
local function getFullPath(relativePath)
    return getWorkingDirectory() .. [[\]] .. relativePath
end



-- Core modules extraction
local core_config = require "src.core.config"
local core_theme = require "src.core.theme"
local core_state = require "src.core.state"
local core_audio = require "src.core.audio"
local core_storage = require "src.core.storage"

local CONFIG = core_config.CONFIG
local scaled = core_config.scaled
local THEMES = core_theme.THEMES

-- Audio
local ALERT_SOUNDS = core_audio.ALERT_SOUNDS
local scanAlertSounds = core_audio.scanAlertSounds
local playAlertSound = core_audio.playAlertSound

-- Storage
local smsData = core_storage.smsData
local nameToPhoneCache = core_storage.nameToPhoneCache

local loadData = core_storage.loadData
local saveData = core_storage.saveData
local loadSettings = core_storage.loadSettings
local saveSettings = core_storage.saveSettings
local validateCache = core_storage.validateCache
local ensureCacheIntegrity = core_storage.ensureCacheIntegrity
local rebuildServerCache = core_storage.rebuildServerCache
local updateContactCache = core_storage.updateContactCache
local removeContactFromCache = core_storage.removeContactFromCache
local findPhoneByName = core_storage.findPhoneByName

-- Theme
local applyTheme = core_theme.applyTheme

-- State initialization
local state = nil

-- Initialize core modules
core_storage.init({ CONFIG = CONFIG, getFullPath = getFullPath })
core_theme.init({ CONFIG = CONFIG, saveSettings = saveSettings })
core_audio.init({ CONFIG = CONFIG, getFullPath = getFullPath })
core_state.init({ imgui = imgui })

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
        local contact, currentNumber = ContactService.getOrCreateContact(serverKey, nickname, phoneNumber)
        
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
    if core_storage.pendingSave then
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
    core_storage.pendingSave = true
    
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

-- Main function
function main()
    while not isSampAvailable() do
        wait(100)
    end
    
    -- Load settings (theme) before initializing state
    loadSettings()
    
    -- Initialize state after imgui is available
    state = core_state.createState()
    
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

    SAMPServices.init({
        smsData = smsData
    })
    
    ContactService.init({
        smsData = smsData,
        saveData = saveData,
        removeContactFromCache = removeContactFromCache,
        getCurrentServerKey = SAMPServices.getCurrentServerKey,
        state = state,
        findPhoneByName = findPhoneByName,
        updateContactCache = updateContactCache,
        getOrCreateServer = SAMPServices.getOrCreateServer
    })
    ChatHookService.init({
        CONFIG = CONFIG,
        state = state,
        SAMPServices = SAMPServices,
        ContactService = ContactService,
        addMessage = addMessage,
        playAlertSound = playAlertSound
    })
    
    -- Initialize UI modules
    local uiDeps = {
        imgui = imgui,
        ffi = ffi,
        CONFIG = CONFIG,
        state = state,
        scaled = scaled,
        applyTheme = applyTheme,
        cp1251_to_utf8 = cp1251_to_utf8,
        isContactOnline = SAMPServices.isContactOnline,
        filterContacts = ContactService.filterContacts,
        easeOutCubic = easeOutCubic,
        easeOutBack = easeOutBack,
        getCurrentServerKey = SAMPServices.getCurrentServerKey,
        getContactsList = ContactService.getContactsList,
        markContactAsRead = ContactService.markContactAsRead,
        getOrCreateServer = SAMPServices.getOrCreateServer,
        updateContactCache = updateContactCache,
        saveData = saveData,
        deleteContact = ContactService.deleteContact,
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
            local serverKey = SAMPServices.getCurrentServerKey()
            if serverKey then
                state.contacts = ContactService.getContactsList(serverKey)
                state.filteredContacts = {}
            end
            -- Scroll to bottom if contact selected and mark as read
            if state.selectedContact then
                state.scrollToBottom = true
                ContactService.markContactAsRead(state.selectedContact.phone)
                -- Refresh to update unread indicators
                state.contacts = ContactService.getContactsList(serverKey)
            end
            -- Update online status immediately when opening
            SAMPServices.updateOnlineStatus()
        end
        

    end
    
    -- Register chat command
    sampRegisterChatCommand("smsm", _G.toggleSMSMenu)
    
    -- Register imgui frame handler
    
    -- Hook chat messages using sampEvents
    -- Returns false to hide message from chat, true/nil to show
    sampEvents.onServerMessage = function(color, text)
        if text then
            local isSMS = ChatHookService.handleChatMessage(tostring(text))
            if isSMS and CONFIG.hideSMSFromChat then
                return false -- Hide SMS from chat
            end
        end
    end
    
    sampEvents.onChatMessage = function(playerId, text)
        if text then
            local isSMS = ChatHookService.handleChatMessage(tostring(text))
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
        if state.windowOpen[0] and os.time() - (SAMPServices.lastOnlineUpdate or 0) >= 2 then
            SAMPServices.updateOnlineStatus()
            SAMPServices.lastOnlineUpdate = os.time()
        end
        
        -- Process any pending messages in queue and save if needed
        if #messageQueue > 0 or core_storage.pendingSave then
            processMessageQueue()
        end
        
        -- Periodic save every 5 seconds if there are pending changes
        if core_storage.pendingSave and os.time() - core_storage.lastSaveTime >= 5 then
            saveData()
        end
        
    end
    
    -- Final save on script exit
    saveData()
end
