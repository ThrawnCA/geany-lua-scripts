#! /usr/bin/env lua
-- Extract the current selection to the end of the previous line.
-- This is intended for extracting a value to a new variable.
--
-- (c) 2015 by Carl Antuar.
-- Distribution is permitted under the terms of the GPLv3 or any later version.

---- Define functions ----
debugEnabled = false

dofile(geany.appinfo()["scriptdir"]..geany.dirsep.."util.lua")

---- Start execution ----
local text = geany.selection()
if not text then return end
debugMessage("Moving "..text.." to end of previous line")
local replacement = geany.input("Replacement text:")
if not replacement then return end
geany.selection(replacement)
geany.navigate("edge", -1)
if atDocumentEdge() then
    debugMessage("Inserting new line at top of document")
    geany.selection(text..'\n')
else
    geany.navigate("line", -1)
    geany.navigate("edge", 1)
    geany.selection(' '..text)
end
