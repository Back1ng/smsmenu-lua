local ffi = require "ffi"

local M = {}

ffi.cdef[[
    short __stdcall GetAsyncKeyState(int vKey);
]]

local user32 = ffi.load("user32")

M.CANCEL_KEY = 0x1B -- Escape
M.BINDABLE_KEYS = {}

local keyNames = {}
local previousKeyState = {}

local function addKey(code, name)
    table.insert(M.BINDABLE_KEYS, code)
    keyNames[code] = name
end

addKey(0x08, "Backspace")
addKey(0x09, "Tab")
addKey(0x0D, "Enter")
addKey(0x13, "Pause")
addKey(0x14, "Caps Lock")
addKey(0x20, "Space")
addKey(0x21, "Page Up")
addKey(0x22, "Page Down")
addKey(0x23, "End")
addKey(0x24, "Home")
addKey(0x25, "Left")
addKey(0x26, "Up")
addKey(0x27, "Right")
addKey(0x28, "Down")
addKey(0x2C, "Print Screen")
addKey(0x2D, "Insert")
addKey(0x2E, "Delete")

for code = 0x30, 0x39 do
    addKey(code, string.char(code))
end

for code = 0x41, 0x5A do
    addKey(code, string.char(code))
end

addKey(0x5B, "Left Win")
addKey(0x5C, "Right Win")

for code = 0x60, 0x69 do
    addKey(code, "Num " .. tostring(code - 0x60))
end

addKey(0x6A, "Num *")
addKey(0x6B, "Num +")
addKey(0x6D, "Num -")
addKey(0x6E, "Num .")
addKey(0x6F, "Num /")

for code = 0x70, 0x87 do
    addKey(code, "F" .. tostring(code - 0x6F))
end

addKey(0x90, "Num Lock")
addKey(0x91, "Scroll Lock")
addKey(0xA0, "Left Shift")
addKey(0xA1, "Right Shift")
addKey(0xA2, "Left Ctrl")
addKey(0xA3, "Right Ctrl")
addKey(0xA4, "Left Alt")
addKey(0xA5, "Right Alt")
addKey(0xBA, ";")
addKey(0xBB, "=")
addKey(0xBC, ",")
addKey(0xBD, "-")
addKey(0xBE, ".")
addKey(0xBF, "/")
addKey(0xC0, "`")
addKey(0xDB, "[")
addKey(0xDC, "\\")
addKey(0xDD, "]")
addKey(0xDE, "'")

function M.getName(code)
    return keyNames[code] or string.format("VK 0x%02X", tonumber(code) or 0)
end

local function readKeyState(code)
    local state = tonumber(user32.GetAsyncKeyState(code))
    return state < 0, state % 2 ~= 0
end

function M.beginCapture()
    previousKeyState = {}
    previousKeyState[M.CANCEL_KEY] = readKeyState(M.CANCEL_KEY)

    for _, code in ipairs(M.BINDABLE_KEYS) do
        previousKeyState[code] = readKeyState(code)
    end
end

function M.pollCapture()
    local escapeDown, escapePressed = readKeyState(M.CANCEL_KEY)
    local escapeWasDown = previousKeyState[M.CANCEL_KEY] or false
    previousKeyState[M.CANCEL_KEY] = escapeDown
    if escapePressed or (escapeDown and not escapeWasDown) then
        return nil, true
    end

    for _, code in ipairs(M.BINDABLE_KEYS) do
        local isDown, wasPressed = readKeyState(code)
        local wasDown = previousKeyState[code] or false
        previousKeyState[code] = isDown
        if wasPressed or (isDown and not wasDown) then
            return code, false
        end
    end

    return nil, false
end

return M
