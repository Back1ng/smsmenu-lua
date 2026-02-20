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
