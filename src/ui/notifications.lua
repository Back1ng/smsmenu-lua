local M = {}

local imgui = nil
local state = nil
local CONFIG = nil
local scaled = nil
local cp1251_to_utf8 = nil

local notifications = {}

local DURATION = 5.0
local FADE_IN_DURATION = 0.25
local FADE_OUT_DURATION = 0.4
local MAX_NOTIFICATIONS = 3

local function clearNotifications()
    for i = #notifications, 1, -1 do
        table.remove(notifications, i)
    end
end

local function currentTime()
    -- OnFrame conditions run in MoonLoader's updater coroutine, outside the
    -- active ImGui context. os.clock() is safe in both that coroutine and the
    -- render callback, so all notification timestamps use the same clock.
    return os.clock()
end

local function pruneExpired(now)
    for i = #notifications, 1, -1 do
        if now - notifications[i].createdAt >= DURATION then
            table.remove(notifications, i)
        end
    end
end

local function withAlpha(color, alpha)
    return imgui.ColorConvertFloat4ToU32(imgui.ImVec4(
        color.x,
        color.y,
        color.z,
        color.w * alpha
    ))
end

local function splitUtf8(text)
    local characters = {}
    for character in tostring(text or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        table.insert(characters, character)
    end
    return characters
end

local function fitSingleLine(text, maxWidth)
    local normalized = tostring(text or ""):gsub("[%s\r\n]+", " ")
    if imgui.CalcTextSize(normalized).x <= maxWidth then
        return normalized
    end

    local characters = splitUtf8(normalized)
    local ellipsis = "..."
    while #characters > 0 do
        table.remove(characters)
        local candidate = table.concat(characters) .. ellipsis
        if imgui.CalcTextSize(candidate).x <= maxWidth then
            return candidate
        end
    end
    return ellipsis
end

local function fitTwoLines(text, maxWidth)
    local normalized = tostring(text or ""):gsub("[%s\r\n]+", " ")
    local characters = splitUtf8(normalized)
    local lines = { "" }
    local lineIndex = 1

    for index, character in ipairs(characters) do
        local candidate = lines[lineIndex] .. character
        if imgui.CalcTextSize(candidate).x <= maxWidth then
            lines[lineIndex] = candidate
        elseif lineIndex == 1 then
            lineIndex = 2
            lines[lineIndex] = character == " " and "" or character
        else
            local ellipsis = "..."
            local lineCharacters = splitUtf8(lines[lineIndex])
            while #lineCharacters > 0 and imgui.CalcTextSize(table.concat(lineCharacters) .. ellipsis).x > maxWidth do
                table.remove(lineCharacters)
            end
            lines[lineIndex] = table.concat(lineCharacters) .. ellipsis
            return table.concat(lines, "\n")
        end

        if index == #characters then
            return table.concat(lines, "\n")
        end
    end

    return table.concat(lines, "\n")
end

local function getAlpha(elapsed)
    if elapsed < FADE_IN_DURATION then
        return math.max(0, math.min(1, elapsed / FADE_IN_DURATION))
    end

    local remaining = DURATION - elapsed
    if remaining < FADE_OUT_DURATION then
        return math.max(0, math.min(1, remaining / FADE_OUT_DURATION))
    end

    return 1.0
end

local function drawNotification(drawList, notification, cardX, cardY, cardWidth, cardHeight, alpha)
    local cardMin = imgui.ImVec2(cardX, cardY)
    local cardMax = imgui.ImVec2(cardX + cardWidth, cardY + cardHeight)
    local rounding = scaled(10)

    drawList:AddRectFilled(
        imgui.ImVec2(cardX + scaled(2), cardY + scaled(3)),
        imgui.ImVec2(cardX + cardWidth + scaled(2), cardY + cardHeight + scaled(3)),
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0, 0, 0, 0.22 * alpha)),
        rounding
    )
    drawList:AddRectFilled(cardMin, cardMax, withAlpha(CONFIG.colors.background, alpha), rounding)
    drawList:AddRect(cardMin, cardMax, withAlpha(CONFIG.colors.border, alpha), rounding, 0, scaled(1))

    local avatarRadius = scaled(18)
    local avatarCenter = imgui.ImVec2(cardX + scaled(28), cardY + cardHeight / 2)
    drawList:AddCircleFilled(avatarCenter, avatarRadius, withAlpha(CONFIG.colors.primary, alpha), 24)

    local initial = notification.sender:match("[%z\1-\127\194-\244][\128-\191]*") or "?"
    local initialSize = imgui.CalcTextSize(initial)
    drawList:AddText(
        imgui.ImVec2(avatarCenter.x - initialSize.x / 2, avatarCenter.y - initialSize.y / 2),
        withAlpha(CONFIG.colors.textLight, alpha),
        initial
    )

    local textX = cardX + scaled(56)
    local textWidth = cardWidth - scaled(70)
    local sender = fitSingleLine(notification.sender, textWidth)
    local preview = fitTwoLines(notification.text, textWidth)

    drawList:AddText(
        imgui.ImVec2(textX, cardY + scaled(12)),
        withAlpha(CONFIG.colors.textDark, alpha),
        sender
    )
    drawList:AddText(
        imgui.ImVec2(textX, cardY + scaled(35)),
        withAlpha(CONFIG.colors.textGray, alpha),
        preview
    )
end

function M.init(deps)
    imgui = deps.imgui
    state = deps.state
    CONFIG = deps.CONFIG
    scaled = deps.scaled
    cp1251_to_utf8 = deps.cp1251_to_utf8
end

function M.push(sender, text)
    if not imgui or not state or not CONFIG then return end
    if not CONFIG.screenNotificationsEnabled or state.windowOpen[0] then return end

    table.insert(notifications, {
        sender = cp1251_to_utf8(tostring(sender or "?")),
        text = cp1251_to_utf8(tostring(text or "")),
        createdAt = currentTime()
    })

    while #notifications > MAX_NOTIFICATIONS do
        table.remove(notifications, 1)
    end
end

function M.hasVisibleNotifications()
    if not state or not CONFIG then return false end
    if state.windowOpen[0] or not CONFIG.screenNotificationsEnabled then
        clearNotifications()
        return false
    end

    pruneExpired(currentTime())
    return #notifications > 0
end

function M.setup()
    local frameSubscription = imgui.OnFrame(function()
        return M.hasVisibleNotifications()
    end, function()
        local now = currentTime()
        pruneExpired(now)
        if #notifications == 0 then return end

        local cardWidth = scaled(320)
        local cardHeight = scaled(82)
        local gap = scaled(8)
        local margin = scaled(18)
        local slideDistance = scaled(20)
        local totalHeight = #notifications * cardHeight + (#notifications - 1) * gap
        local displaySize = imgui.GetIO().DisplaySize

        imgui.SetNextWindowPos(
            imgui.ImVec2(displaySize.x - margin, displaySize.y - margin),
            imgui.Cond.Always,
            imgui.ImVec2(1, 1)
        )
        imgui.SetNextWindowSize(imgui.ImVec2(cardWidth + slideDistance, totalHeight + scaled(4)), imgui.Cond.Always)

        local flags = imgui.WindowFlags.NoTitleBar +
                      imgui.WindowFlags.NoResize +
                      imgui.WindowFlags.NoMove +
                      imgui.WindowFlags.NoScrollbar +
                      imgui.WindowFlags.NoScrollWithMouse +
                      imgui.WindowFlags.NoCollapse +
                      imgui.WindowFlags.NoSavedSettings +
                      imgui.WindowFlags.NoFocusOnAppearing +
                      imgui.WindowFlags.NoBringToFrontOnFocus +
                      imgui.WindowFlags.NoBackground +
                      imgui.WindowFlags.NoInputs

        imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(0, 0))
        imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 0)
        if imgui.Begin("SMS Notifications##overlay", nil, flags) then
            imgui.SetWindowFontScale(CONFIG.fontScale)
            local windowPos = imgui.GetWindowPos()
            local drawList = imgui.GetWindowDrawList()

            for index, notification in ipairs(notifications) do
                local elapsed = now - notification.createdAt
                local alpha = getAlpha(elapsed)
                local slide = slideDistance * (1 - alpha)
                local cardX = windowPos.x + slide
                local cardY = windowPos.y + (index - 1) * (cardHeight + gap)
                drawNotification(drawList, notification, cardX, cardY, cardWidth, cardHeight, alpha)
            end
        end
        imgui.SetWindowFontScale(1.0)
        imgui.End()
        imgui.PopStyleVar(2)
    end)
    frameSubscription.HideCursor = true
end

return M
