local M = {}

M.formatTime = function(timestamp)
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

return M
