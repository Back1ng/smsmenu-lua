local M = {}
local imgui = nil

function M.init(deps)
    imgui = deps.imgui
end

function M.createState()
    return {
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
end

return M
