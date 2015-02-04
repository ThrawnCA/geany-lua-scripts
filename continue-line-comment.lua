#! /usr/bin/env lua
-- Insert a new line with the same commenting as the previous line.
--
-- (c) 2015 by Carl Antuar.
-- Distribution is permitted under the terms of the GPLv3 or any later version.

---- Define functions ----
debugEnabled = false

function debugMessage(message)
    if debugEnabled then geany.message("DEBUG", message) end
end

function getCommentText(lineIndex)
    local lineText = geany.lines(lineIndex)
    debugMessage("Line is "..lineText)

    local commentStart = lineText:find("%S")
    if not commentStart then return nil end

    if lineText:sub(commentStart, commentStart):find("[a-zA-Z0-9]") then
        debugMessage("Alphanumeric character found; not a comment")
        return nil
    end

    local commentEnd = lineText:find("%s", commentStart)
    if not commentEnd then commentEnd = lineText:len() end

    local commentText = lineText:sub(1, commentEnd)
    debugMessage("Comment text is ["..commentText.."]")
    return commentText
end

---- Start execution ----
local lineIndex = geany.rowcol(geany.caret())
local commentText = getCommentText(lineIndex)
if commentText then
    geany.selection("\n"..commentText)
end
