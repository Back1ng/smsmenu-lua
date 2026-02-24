local CONFIG = {
    dataFile = [[config\smsmenu\messages.json]],
    settingsFile = [[config\smsmenu\settings.json]],
    alertsDir = [[config\smsmenu\alerts]],
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
    fontScale = 1.0, -- UI font scale (0.8 - 1.5)
    PATTERNS = {
        incoming = "SMS: ([^|]+) | \xCE\xF2\xEF\xF0\xE0\xE2\xE8\xF2\xE5\xEB\xFC: ([^[]+) %[(.-)%.(%d+)%]",
        outgoing = "SMS: ([^|]+) | \xCF\xEE\xEB\xF3\xF7\xE0\xF2\xE5\xEB\xFC: ([^[]+) %[(.-)%.(%d+)%]"
    },
    CONSTANTS = {
        ANIMATION = {
            MESSAGE_DURATION = 0.4,
            WINDOW_TOGGLE_SPEED = 0.15,
            NEW_MSG_INDICATOR_SPEED = 0.02,
            HOVER_SPEED = 0.15,
            HOVER_MAX_OPACITY = 0.5,
            LIST_STAGGER_DELAY = 0.05,
            PULSE_SCALE = 0.2,
            PULSE_BASE_ALPHA = 0.3
        },
        TIMING = {
            ONLINE_UPDATE_INTERVAL = 2,
            SAVE_INTERVAL = 5
        },
        LIMITS = {
            MAX_MESSAGES_PER_CONTACT = 100
        },
        UI = {
            MOBILE_BREAKPOINT = 600,
            PADDING = { SMALL = 5, MEDIUM = 10, LARGE = 15 },
            AVATAR = { SMALL = 15, MEDIUM = 18 },
            BUTTONS = { ACTION_W = 42, ACTION_H = 26, ICON = 28 },
            PANEL = { LIST_ITEM_HEIGHT = 70 }
        }
    }
}

-- Get scaled dimension based on current font scale
local function scaled(value)
    return math.floor(value * CONFIG.fontScale)
end

return {
    CONFIG = CONFIG,
    scaled = scaled
}
