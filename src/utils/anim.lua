local M = {}

M.lerp = function(a, b, t)
    return a + (b - a) * math.min(t, 1.0)
end

M.easeOutCubic = function(t)
    return 1 - math.pow(1 - t, 3)
end

M.easeOutBack = function(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
end

return M
