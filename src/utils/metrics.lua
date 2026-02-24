local TextMetrics = {
    CHAR_WIDTHS = {
        AVG_CHAR_WIDTH = 7.0,
        SPACE_WIDTH = 3.5,
        LINE_HEIGHT = 14.0,
        WORD_WRAP_OVERHEAD = 1.05,
        MIN_WORD_LENGTH = 3.5,
        BOTTOM_PADDING = 0.0,
        TAB_WIDTH = 14.0
    },

    measureLeadingIndent = function(text, fontScaleMultiplier)
        fontScaleMultiplier = fontScaleMultiplier or 1.0
        if not text or text == "" then return 0, 0 end
        
        local leadingSpaces = #(text:match("^( *)") or "")
        local leadingTabs = #(text:match("^(\t*)") or "")
        
        local indentWidth = (leadingSpaces * TextMetrics.CHAR_WIDTHS.SPACE_WIDTH + 
                             leadingTabs * TextMetrics.CHAR_WIDTHS.TAB_WIDTH) * fontScaleMultiplier
                             
        return indentWidth, leadingSpaces + leadingTabs
    end,

    estimateLines = function(text, maxWidth, fontScaleMultiplier)
        fontScaleMultiplier = fontScaleMultiplier or 1.0
        local CHAR_WIDTHS = TextMetrics.CHAR_WIDTHS
        
        if not text or text == "" then
            return 1, CHAR_WIDTHS.LINE_HEIGHT * fontScaleMultiplier
        end
        
        local textLength = #text
        local indentWidth = TextMetrics.measureLeadingIndent(text, fontScaleMultiplier)
        
        if textLength <= 10 then
            local estimatedWidth = textLength * CHAR_WIDTHS.AVG_CHAR_WIDTH * fontScaleMultiplier
            if estimatedWidth <= maxWidth then
                return 1, CHAR_WIDTHS.LINE_HEIGHT * fontScaleMultiplier
            end
        end
        
        local effectiveMaxWidth = math.max(maxWidth - indentWidth, maxWidth * 0.4)
        local effectiveCharWidth = CHAR_WIDTHS.AVG_CHAR_WIDTH * fontScaleMultiplier
        local charsPerLine = effectiveMaxWidth / effectiveCharWidth
        
        local rawLines = textLength / charsPerLine
        local estimatedLines = math.ceil(rawLines * CHAR_WIDTHS.WORD_WRAP_OVERHEAD)
        
        return math.max(estimatedLines, 1), CHAR_WIDTHS.LINE_HEIGHT * fontScaleMultiplier
    end
}

return TextMetrics
