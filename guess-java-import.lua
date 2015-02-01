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
	local reverseIndex = classname:reverse():find(".", 1, true)
	if reverseIndex then
		local index = classname:len() - reverseIndex
		debugMessage("Last dot in "..classname.." is at "..index)
		return classname:sub(1, index)
	else return nil
	end
end

function getSurroundingLine(caret)
	return geany.lines(geany.rowcol(caret))
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
if geany.text():find("\nimport%s*[a-zA-Z0-9.]+%."..className.."%s*;") then
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

local startIndex = geany.text():find("package%s")
if startIndex then
	startIndex = startIndex + getSurroundingLine(startIndex):len() - 1
else
	startIndex = 0
end

local insertedText = "import "..import..";\n"
local package = insertedText
local found = false
repeat
	debugMessage("Seeking optimal entry point for "..package)
	insertionIndex = geany.text():find(package)
	if insertionIndex then
		-- seek the best position
		startIndex = insertionIndex - 1
		repeat
			local existingLine = getSurroundingLine(startIndex + 1)
			if insertedText > existingLine and existingLine:find(package) then
				startIndex = startIndex + existingLine:len()
			else
				found = true
			end
		until found
	end
	-- subtract one character at a time until we find a match
	package = package:sub(1, package:len()-1)
until found or package:len() == 8

local oldCursorPos = geany.caret() + insertedText:len()
geany.caret(startIndex)
debugMessage("About to insert "..insertedText.." at "..startIndex)
geany.selection(insertedText)
geany.caret(oldCursorPos)
