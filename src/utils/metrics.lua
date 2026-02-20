--[[
    TextMetrics Module
    
    Provides O(1) constant-time text wrapping estimation and character width metrics.
    Extracted from drawRightPanel to address Feature Envy code smell.
    
    Features:
    - Precomputed character width metrics for standard proportional fonts
    - Tab-stop aligned tab width calculation
    - Cumulative indent metrics for hierarchical content
    - Internal whitespace detection
--]]
local TextMetrics
TextMetrics = {
    --[[
        Precomputed character width metrics (average pixel widths for typical UI font)
        These values are calibrated for standard proportional fonts at base scale 1.0
        ENHANCED: Added tab-stop configuration and cumulative indent support for large depths
    --]]
    CHAR_WIDTHS = {
        -- Base average width for ASCII characters
        AVG_CHAR_WIDTH = 7.0,
        -- Width of space character (typically narrower)
        SPACE_WIDTH = 3.5,
        -- Line height in pixels
        LINE_HEIGHT = 14.0,
        -- Safety padding factor for word boundary overhead (5% is sufficient for most cases)
        WORD_WRAP_OVERHEAD = 1.05,
        -- Minimum estimated characters per word (for word boundary calculation)
        MIN_WORD_LENGTH = 3.5,
        -- Legacy tab character width (deprecated: use tab-stop calculations instead)
        TAB_WIDTH = 14.0,
        -- Non-breaking space width
        NBSP_WIDTH = 3.5,
        
        --[[
            TAB-STOP CONFIGURATION
            Configurable tab-stop positions for proper tab width calculation.
            Tab width varies based on current column position (tab-stop alignment).
        --]]
        TAB_STOP = {
            -- Default tab-stop interval (4 or 8 character positions)
            INTERVAL = 4,
            -- Maximum number of tab-stops to precompute (covers up to 512 chars)
            MAX_PRECOMPUTED = 128,
            -- Space-equivalent width for statistical estimation
            AVG_TAB_WIDTH = 14.0,  -- 4 * SPACE_WIDTH
        },
        
        --[[
            CUMULATIVE INDENT CONFIGURATION
            Settings for handling indentation preserved across wrapped lines.
        --]]
        CUMULATIVE_INDENT = {
            -- Maximum indentation depth levels supported (10+ for deep nesting)
            MAX_DEPTH = 20,
            -- Factor for estimating wrapped lines per indentation level
            WRAP_FACTOR_PER_DEPTH = 0.15,
            -- Maximum cumulative indent as percentage of available width
            MAX_PERCENTAGE = 0.60,
            -- Statistical overhead for hierarchical content (bullet points, code blocks)
            HIERARCHICAL_OVERHEAD = 1.25,
        },
        
        --[[
            INTERNAL WHITESPACE PRESERVATION
            Settings for maintaining internal indentation structures.
        --]]
        INTERNAL_WHITESPACE = {
            -- Estimated percentage of text containing internal indentation
            OCCURRENCE_RATE = 0.20,
            -- Average internal indent width in characters
            AVG_INTERNAL_CHARS = 8,
            -- Overhead factor for multi-line indented content
            MULTILINE_OVERHEAD = 1.15,
        },
        
        --[[
            BOTTOM PADDING CONFIGURATION
            Bottom internal padding for message list container.
            Integrated with O(1) estimation pipeline for proper vertical layout.
        --]]
        BOTTOM_PADDING = 5.0,
    },
    
    --[[
        O(1) CONSTANT-TIME INDENTATION ANALYSIS WITH TAB-STOP CALCULATION
        
        Enhanced version that handles:
        - Tab-stop aligned tab widths (variable based on column position)
        - Mixed tabs and spaces in indentation
        - Cumulative indent metrics for hierarchical content
        - Large indentation depths (10+ levels) via statistical estimation
        
        Uses pattern matching (C-optimized in Lua) to detect leading whitespace
        without iterating through each character.
        
        @param text The text to analyze (string)
        @param fontScaleMultiplier Font scale for pixel calculations (number)
        @param columnPos Optional starting column position for tab-stop calc (default 0)
        @return indentWidth Width of leading indentation in pixels (number)
        @return indentChars Number of leading whitespace characters (number)
        @return indentDepth Estimated indentation depth level (number)
        @return cumulativeWidth Estimated cumulative width across wrapped lines (number)
    --]]
    measureLeadingIndent = function(text, fontScaleMultiplier, columnPos)
        columnPos = columnPos or 0
        fontScaleMultiplier = fontScaleMultiplier or 1.0
        
        if not text or text == "" then
            return 0, 0, 0, 0
        end
        
        local CHAR_WIDTHS = TextMetrics.CHAR_WIDTHS
        
        -- O(1) pattern match for leading whitespace using Lua's pattern engine
        local leadingSpaces, leadingTabs = 0, 0
        
        -- Match leading spaces (including non-breaking space \160)
        local spacePattern = text:match("^( *)")
        if spacePattern then
            leadingSpaces = #spacePattern
        end
        
        -- Match leading tabs
        local tabPattern = text:match("^(\t*)")
        if tabPattern then
            leadingTabs = #tabPattern
        end
        
        -- Build TAB_STOP_WIDTHS lookup table
        local TAB_STOP_WIDTHS = {}
        for col = 0, CHAR_WIDTHS.TAB_STOP.MAX_PRECOMPUTED - 1 do
            local spacesToNextTab = CHAR_WIDTHS.TAB_STOP.INTERVAL - (col % CHAR_WIDTHS.TAB_STOP.INTERVAL)
            TAB_STOP_WIDTHS[col] = spacesToNextTab * CHAR_WIDTHS.SPACE_WIDTH
        end
        
        -- O(1) tab-stop width calculation using precomputed lookup table
        local totalTabWidth = 0
        local currentCol = columnPos
        
        for t = 1, math.min(leadingTabs, 32) do  -- Limit to 32 tabs for safety
            local tabWidth = TAB_STOP_WIDTHS[currentCol] or CHAR_WIDTHS.TAB_STOP.AVG_TAB_WIDTH
            totalTabWidth = totalTabWidth + tabWidth
            -- Advance to next tab stop
            local spacesToNext = CHAR_WIDTHS.TAB_STOP.INTERVAL - (currentCol % CHAR_WIDTHS.TAB_STOP.INTERVAL)
            currentCol = currentCol + spacesToNext
        end
        
        -- Handle case of many tabs (>32) using statistical estimation
        if leadingTabs > 32 then
            local remainingTabs = leadingTabs - 32
            totalTabWidth = totalTabWidth + (remainingTabs * CHAR_WIDTHS.TAB_STOP.AVG_TAB_WIDTH)
            currentCol = currentCol + (remainingTabs * CHAR_WIDTHS.TAB_STOP.INTERVAL)
        end
        
        -- Calculate total indentation width in pixels
        local spaceWidth = leadingSpaces * CHAR_WIDTHS.SPACE_WIDTH
        local indentWidth = (spaceWidth + totalTabWidth) * fontScaleMultiplier
        
        -- O(1) indentation depth estimation based on total whitespace
        local totalWhitespace = leadingSpaces + (leadingTabs * CHAR_WIDTHS.TAB_STOP.INTERVAL)
        local indentDepth = math.min(
            math.floor(totalWhitespace / CHAR_WIDTHS.TAB_STOP.INTERVAL),
            CHAR_WIDTHS.CUMULATIVE_INDENT.MAX_DEPTH
        )
        
        -- Build INDENT_DEPTH_FACTORS lookup table
        local INDENT_DEPTH_FACTORS = {}
        for depth = 0, CHAR_WIDTHS.CUMULATIVE_INDENT.MAX_DEPTH do
            INDENT_DEPTH_FACTORS[depth] = 1.0 + (math.sqrt(depth) * CHAR_WIDTHS.CUMULATIVE_INDENT.WRAP_FACTOR_PER_DEPTH)
        end
        
        -- O(1) cumulative width estimation using depth factors
        local depthFactor = INDENT_DEPTH_FACTORS[indentDepth] or INDENT_DEPTH_FACTORS[CHAR_WIDTHS.CUMULATIVE_INDENT.MAX_DEPTH]
        local cumulativeWidth = indentWidth * depthFactor
        
        return indentWidth, leadingSpaces + leadingTabs, indentDepth, cumulativeWidth
    end,
    
    --[[
        O(1) CONSTANT-TIME LINE ESTIMATION WITH CUMULATIVE INDENT METRICS
        
        Uses statistical approximation based on:
        - Text length (byte count, O(1) operation)
        - Average character width (precomputed constant)
        - Word wrap overhead factor (statistical correction)
        - Leading indentation with tab-stop alignment (O(1) lookup)
        - Cumulative indent impact across wrapped lines (O(1) depth factor)
        
        @param text The text to estimate (string)
        @param maxWidth Maximum available width for the text (number)
        @param fontScaleMultiplier Font scale for calculations (number)
        @return lines Estimated number of lines (number)
        @return lineHeight Height of each line in pixels (number)
    --]]
    estimateLines = function(text, maxWidth, fontScaleMultiplier)
        fontScaleMultiplier = fontScaleMultiplier or 1.0
        local CHAR_WIDTHS = TextMetrics.CHAR_WIDTHS
        
        -- Handle edge cases (O(1))
        if not text or text == "" then
            return 1, CHAR_WIDTHS.LINE_HEIGHT * fontScaleMultiplier
        end
        
        -- Get text length - O(1) operation in Lua (# operator)
        local textLength = #text
        
        -- O(1) calculation: Measure leading indentation with tab-stop alignment
        local indentWidth, indentChars, indentDepth, cumulativeWidth =
            TextMetrics.measureLeadingIndent(text, fontScaleMultiplier)
        
        -- O(1) calculation: Detect internal whitespace structures
        local hasInternalIndent, internalIndentWidth = false, 0
        
        -- O(1) pattern match for internal whitespace patterns
        -- Check for indentation after newlines (O(1) single pattern match)
        local newlineIndent = text:match("\n([ \t]+)")
        if newlineIndent then
            hasInternalIndent = true
        end
        
        -- O(1) statistical estimation: check first occurrence only
        local spacePattern = text:match("[^%S\r\n]([ ]{3,})")
        if spacePattern then
            hasInternalIndent = true
        end
        
        local tabPattern = text:match("[^%S\r\n](\t+)")
        if tabPattern then
            hasInternalIndent = true
        end
        
        -- O(1) statistical width estimation for internal whitespace
        if hasInternalIndent then
            internalIndentWidth = CHAR_WIDTHS.INTERNAL_WHITESPACE.AVG_INTERNAL_CHARS *
                                  CHAR_WIDTHS.SPACE_WIDTH *
                                  CHAR_WIDTHS.INTERNAL_WHITESPACE.MULTILINE_OVERHEAD *
                                  fontScaleMultiplier
        end
        
        -- Quick single-line check for short texts (O(1))
        if textLength <= 10 and not hasInternalIndent then
            local estimatedWidth = textLength * CHAR_WIDTHS.AVG_CHAR_WIDTH * fontScaleMultiplier
            if estimatedWidth <= maxWidth then
                return 1, CHAR_WIDTHS.LINE_HEIGHT * fontScaleMultiplier
            end
        end
        
        -- O(1) calculation: Determine effective available width accounting for indentation
        local effectiveIndentWidth = indentWidth
        if indentDepth >= 3 then
            effectiveIndentWidth = indentWidth * math.min(1.0 + (indentDepth * 0.1), 1.5)
        end
        
        effectiveIndentWidth = effectiveIndentWidth + internalIndentWidth
        
        local effectiveMaxWidth = maxWidth - effectiveIndentWidth
        if effectiveMaxWidth < maxWidth * 0.4 then
            effectiveMaxWidth = maxWidth * 0.4
        end
        
        -- O(1) calculation: Determine raw character capacity per line
        local effectiveCharWidth = CHAR_WIDTHS.AVG_CHAR_WIDTH * fontScaleMultiplier
        local charsPerLine = effectiveMaxWidth / effectiveCharWidth
        
        -- O(1) calculation: Estimate raw lines needed without word wrap
        local rawLines = textLength / charsPerLine
        
        -- O(1) calculation: Estimate word count statistically
        local estimatedWordCount = textLength / CHAR_WIDTHS.MIN_WORD_LENGTH
        local estimatedWordsPerLine = charsPerLine / CHAR_WIDTHS.MIN_WORD_LENGTH
        local linesFromWords = estimatedWordCount / math.max(estimatedWordsPerLine, 1)
        
        -- O(1) calculation: Take maximum of character-based and word-based estimates
        local baseEstimate = math.max(rawLines, linesFromWords)
        
        -- O(1) calculation: Calculate cumulative indent metrics for wrapped lines
        -- Build INDENT_DEPTH_FACTORS lookup table
        local INDENT_DEPTH_FACTORS = {}
        for depth = 0, CHAR_WIDTHS.CUMULATIVE_INDENT.MAX_DEPTH do
            INDENT_DEPTH_FACTORS[depth] = 1.0 + (math.sqrt(depth) * CHAR_WIDTHS.CUMULATIVE_INDENT.WRAP_FACTOR_PER_DEPTH)
        end
        
        indentDepth = math.min(indentDepth, CHAR_WIDTHS.CUMULATIVE_INDENT.MAX_DEPTH)
        local depthFactor = INDENT_DEPTH_FACTORS[indentDepth] or 1.0
        
        local hierarchicalOverhead = 1.0
        if indentDepth >= 3 then
            hierarchicalOverhead = CHAR_WIDTHS.CUMULATIVE_INDENT.HIERARCHICAL_OVERHEAD
        end
        
        -- O(1) calculation: Apply word wrap overhead padding
        local indentOverhead = 1.0
        if indentDepth > 0 then
            indentOverhead = 1.05
            if indentDepth >= 3 then
                indentOverhead = indentOverhead * hierarchicalOverhead
            end
            if hasInternalIndent then
                indentOverhead = indentOverhead * CHAR_WIDTHS.INTERNAL_WHITESPACE.MULTILINE_OVERHEAD
            end
        end
        
        -- Calculate final estimated lines with all factors applied
        local estimatedLines = math.ceil(baseEstimate * CHAR_WIDTHS.WORD_WRAP_OVERHEAD * indentOverhead)
        
        -- Apply cumulative indent adjustment for deeply wrapped content
        if indentDepth > 0 and estimatedLines > 2 then
            estimatedLines = math.ceil(estimatedLines * depthFactor / math.sqrt(estimatedLines))
        end
        
        -- Ensure at least 1 line is returned
        return math.max(estimatedLines, 1), CHAR_WIDTHS.LINE_HEIGHT * fontScaleMultiplier
    end,
}

return TextMetrics
