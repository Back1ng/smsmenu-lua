local encoding = require "encoding"
encoding.default = 'CP1251'
local UTF8 = encoding.UTF8
local CP1251 = encoding.CP1251

local M = {}

-- SAMP expects CP1251; script strings are UTF-8, ImGui renders UTF-8 as-is
M.utf8_str = setmetatable({}, {__call = function(_, str) return CP1251:encode(str, 'UTF-8') end})

-- Game messages arrive as CP1251; convert to UTF-8 for ImGui rendering
M.cp1251_to_utf8 = function(str)
    return UTF8:encode(str, 'CP1251')
end

return M
