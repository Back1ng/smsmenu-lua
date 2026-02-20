local encoding = require "encoding"
encoding.default = 'CP1251'
local UTF8 = encoding.UTF8
local CP1251 = encoding.CP1251

local M = {}

-- UTF-8 → CP1251 для SAMP (как в sms_spam.lua); строки в скрипте в UTF-8, в ImGui передаём как есть
M.utf8_str = setmetatable({}, {__call = function(_, str) return CP1251:encode(str, 'UTF-8') end})

-- CP1251 → UTF-8 для отображения в ImGui (сообщения из игры в CP1251)
M.cp1251_to_utf8 = function(str)
    return UTF8:encode(str, 'CP1251')
end

return M
