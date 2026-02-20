local ffi = require "ffi"
local lfs = require "lfs"

local M = {}
local CONFIG = nil

ffi.cdef[[
    int PlaySoundA(const char* pszSound, void* hmod, unsigned long fdwSound);
    int MessageBeep(unsigned int uType);
]]
local winmm = ffi.load("winmm")
local SND_FILENAME = 0x00020000
local SND_ASYNC = 0x0001
local SND_NODEFAULT = 0x0002

M.ALERT_SOUNDS = {}

function M.init(deps)
    CONFIG = deps.CONFIG
    M.getFullPath = deps.getFullPath
end

function M.scanAlertSounds()
    for k in pairs(M.ALERT_SOUNDS) do
        M.ALERT_SOUNDS[k] = nil
    end
    local fullAlertsDir = M.getFullPath(CONFIG.alertsDir)
    
    if doesDirectoryExist(fullAlertsDir) then
        for file in lfs.dir(fullAlertsDir) do
            if file:match("%.wav$") then
                table.insert(M.ALERT_SOUNDS, file)
            end
        end
    else
        createDirectory(fullAlertsDir)
    end
    table.sort(M.ALERT_SOUNDS)
    return M.ALERT_SOUNDS
end

function M.playAlertSound()
    if not CONFIG.soundEnabled then return end
    if not CONFIG.currentSound or CONFIG.currentSound == "" then return end
    
    local soundPath = M.getFullPath(CONFIG.alertsDir .. [[\]] .. CONFIG.currentSound)
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

return M
