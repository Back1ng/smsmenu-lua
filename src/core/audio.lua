local lfs = require "lfs"

local M = {}
local CONFIG = nil
local activeStream = nil

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

local function releaseActiveStream()
    if activeStream == nil then return end
    releaseAudioStream(activeStream)
    activeStream = nil
end

function M.playAlertSound()
    releaseActiveStream()

    if not CONFIG.soundEnabled then return end
    if type(CONFIG.soundVolume) ~= "number" or CONFIG.soundVolume <= 0 then return end
    if not CONFIG.currentSound or CONFIG.currentSound == "" then return end
    
    local soundPath = M.getFullPath(CONFIG.alertsDir .. [[\]] .. CONFIG.currentSound)
    soundPath = soundPath:gsub("/", "\\")
    
    if not doesFileExist(soundPath) then return end

    local stream = loadAudioStream(soundPath)
    if not stream then return end

    activeStream = stream
    setAudioStreamLooped(activeStream, false)
    setAudioStreamVolume(activeStream, math.max(0, math.min(1, CONFIG.soundVolume / 100)))
    setAudioStreamState(activeStream, 1)
end

function M.update()
    if activeStream ~= nil and getAudioStreamState(activeStream) == -1 then
        releaseActiveStream()
    end
end

return M
