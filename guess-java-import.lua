#! /usr/bin/env lua
-- Attempt to guess import statements for the highlighted class name.
--
-- (c) 2014 Carl Antuar.
-- Distribution is permitted under the terms of the GPLv3
-- or any later version.

---- Define functions ----

debugEnabled = false

dofile(geany.appinfo()["scriptdir"]..geany.dirsep.."util.lua")

function getParent(classname)
	local index = classname:len() - classname:reverse():find(".", 1, true)
	debugMessage("Last dot in "..classname.." is at "..index)
	return classname:sub(1, index)
end

function getCurrentWord()
	local selectedText = geany.selection()

	if selectedText == nil or selectedText == "" then
		local oldCursorPos = geany.caret()
		debugMessage("No text selected; seeking current word for position "..oldCursorPos)
		geany.keycmd("SELECT_WORD")
		selectedText = geany.selection():gsub("^%s*(.-)%s*$", "%1")
		geany.caret(oldCursorPos)
	else
		debugMessage("Selected text: ["..selectedText.."]")
	end
	return selectedText
end

---- Start execution ----

local className = getCurrentWord()

debugMessage("Class name is ["..className.."]")
if geany.text():find("\nimport%s*[a-zA-Z0-9.]+"..className.."%s*;") then
	geany.message("Already imported "..className)
	return
end

local searchCommand = "cat "..getSupportDir()..geany.dirsep.."*.index |sort |uniq | grep '\\b"..className.."\\b'"
local count,qualifiedImports = getOutputLines(searchCommand)
for index,import in ipairs(qualifiedImports) do
	local starImport = getParent(import)..".*"
	debugMessage("Looking for "..starImport)
	if geany.text():find("\nimport%s*"..starImport:gsub("[*]", "[*]")..";") then
		geany.message("Already imported "..starImport)
		return
	end
end

if count > 0 then
	import = geany.choose("Is one of these the class you want?", qualifiedImports)
else
	geany.message("Couldn't guess import statement for ["..className.."]")
end
if not import then return end
debugMessage("Importing "..import)

local startIndex,stopIndex = geany.text():find("package%s")
if not startIndex then startIndex = 1 end

local insertedText = "\nimport "..import..";"
local oldCursorPos = geany.caret() + insertedText:len()
geany.caret(startIndex)
geany.navigate("edge", 1)
geany.selection(insertedText)
geany.caret(oldCursorPos)
