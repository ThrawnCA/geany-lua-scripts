#! /usr/bin/env lua
-- Extract the current selection to the end of the previous line.
-- This is intended for extracting a value to a new variable.
--
-- (c) 2015 by Carl Antuar.
-- Distribution is permitted under the terms of the GPLv3 or any later version.

---- Define functions ----
debugEnabled = false

dofile(geany.appinfo()["scriptdir"]..geany.dirsep.."util.lua")

local function replace(text, replacementCaret, defaultReplacement)
    replacement = geany.input("Replacement text:", defaultReplacement)
    if replacement then
        geany.selection(text)
        replacementCaret = replacementCaret + text:len()
    else
        replacement = trim(text)
    end
    geany.caret(replacementCaret)
    geany.selection(replacement)
    geany.navigate("line", -1)
    geany.navigate("edge", 1)
end

---- Start execution ----
local text = geany.selection()
if not text then return end
debugMessage("Moving "..text.." to end of previous line")
geany.selection("")
local replacementCaret = geany.caret();
geany.navigate("edge", -1)
if atDocumentEdge() then
    debugMessage("Inserting new line at top of document")
    replace(text..'\n', replacementCaret, "")
else
    geany.navigate("line", -1)
    geany.navigate("edge", 1)
    local currentLine = getCurrentLine()
    debugMessage("Target line is "..currentLine)
    local _, _, replacement = currentLine:find("(%S+)%s*=")
    replace(text, replacementCaret, replacement)
end
