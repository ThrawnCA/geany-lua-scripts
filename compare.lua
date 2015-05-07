#! /usr/bin/env lua
-- Compare the current file contents to any open file
-- (including the saved version of the current file).
--
-- v0.2 - Changed to use io.popen to retrieve command output,
-- instead of piping to temporary file.
-- 0.3 - Changed to show full name of current file
-- when choosing file for comparison.
-- (c) 2013 by Carl Antuar.
-- Distribution is permitted under the terms of the GPLv2
-- or any later version.

-- Define functions --
debugEnabled = false

dofile(geany.appinfo()["scriptdir"]..geany.dirsep.."util.lua")

local function getDiffCommand()
	if tryCommand("meld --version") then return "meld" end
	if tryCommand("kompare --version") then return "kompare" end
	if tryCommand("kdiff3 --version") then return "kdiff3" end
	if tryCommand("diffuse --version") then return "diffuse" end
	if tryCommand("tkdiff --version") then return "tkdiff" end
	if tryCommand("opendiff --version") then return "opendiff" end
	return "diff"
end

---- Start execution ----

local file1 = geany.filename()
if geany.fileinfo().changed then
	if file1 == nil then
		file1 = "untitled"
	end
	file1 = os.tmpname().."_"..geany.basename(file1)
	-- copy current contents to temporary file
	local file1Handle = io.open(file1, "w")
	file1Handle:write(geany.text())
	file1Handle:flush()
	io.close(file1Handle)
end

local msg
if geany.filename() then
	msg = "Which document do you want to compare "..geany.filename().." to?"
else
	msg = "Which document do you want to compare "..geany.fileinfo().name.." to?"
end
msg = msg.._SPACER
local file2Index = 1
local files = {}
for filename in geany.documents() do
	if geany.fileinfo().changed or filename ~= geany.filename() then
		files[file2Index] = filename
		file2Index = file2Index + 1
	end
end
file2 = geany.choose(msg, files)
if not (file2 == nil) then
	local diffCommand = getDiffCommand()
	debugMessage("Using diff command "..diffCommand)
	if diffCommand == "diff" then
		-- no external program found; use diff
		geany.newfile()
		local f = io.popen(diffCommand.." "..file1.." "..file2, 'r')
		if f == nil then
			geany.message("Failed to perform diff")
			return
		end
		local s = f:read('*a')
		debugMessage("Command output was: "..s)
		geany.selection(s)
	else
		local ok,msg = geany.launch(diffCommand, file1, file2)
		if not ok then geany.message(msg) end
	end
else
	geany.message("Cancelling")
end
