#! /usr/bin/env lua
-- Retrieve changes from SVN for a specified revision number.
--
-- v0.3 - included commit comments when choosing revision,
-- added 'quick scan' option for choosing only the most recent commits,
-- added support for graphical diff viewers.
-- v0.4 - replace 'quick scan' and 'full scan'
-- with progressive disclosure of scan results;
-- add 'all changes since revision' option.
-- v0.5 - consolidate choices into custom preferences dialog.
-- (c) 2013 by Carl Antuar.
-- Distribution is permitted under the terms of the GPLv3
-- or any later version.

---- Define constants ----

debugEnabled = false
_PREFERENCE_FILENAME = "file"
_PREFERENCE_SCAN_SIZE = "scanCount"
_PREFERENCE_DIFF_VIEWER = "diffViewer"

---- Define utility functions ----

function debugMessage(message)
	if debugEnabled then geany.message("DEBUG", message) end
end

function getLogCommand(filename)
	local command = "svn log "..filename.." | sed -e 's/^r\\([0-9]\\+\\) |.*/\\1 /g' | tr -d '\\n' | sed -e 's/--\\+/\\n/g' | tail -n +2"
	debugMessage("Log command is "..command)
	return command
end

function getQuickLogCommand(filename, revisionCount)
	local command = "svn log "..filename.." | head -"..(revisionCount * 4).." | sed -e 's/^r\\([0-9]\\+\\) |.*/\\1 /g' | tr -d '\\n' | sed -e 's/--\\+/\\n/g' | tail -n +2"
	debugMessage("Log command is "..command)
	return command
end

function getSVNDiffCommand(revision, filename, diffViewer)
	local command = "svn diff --diff-cmd="..diffViewer
	if string.find(revision, ":") then
		command =  command.." -r "..revision.." "..filename
	else
		command = command.." -c "..revision.." "..filename
	end
	debugMessage("Diff command is "..command)
	return command
end

function getOutputLines(command)
	local lines = {}
	local lineCount = 0
	local result = io.popen(command, 'r')
	if result == nil then
		geany.message("ERROR", "Failed to get output of command ["..command.."]")
		return
	end
	for line in result:lines() do
		-- need to index from 1 to show up properly in choose dialog
		lineCount = lineCount + 1
		lines[lineCount] = line
	end
	result:close()
	debugMessage("Returning "..lineCount.." output lines")
	return lineCount,lines
end

function isProjectOpen()
	return not (geany.appinfo().project == nil)
end

---- Define script-specific functions ----

local function addDiffViewer(dialogBox, application)
	if os.execute(application.." --version") == 0 then
		dialogBox:radio("diffViewer", application, application)
	end
end

local function getRevisionOptions()
	local buttons = {[1]="_Cancel", [2]="_OK"}
	local svnDialog = dialog.new("SVN Revisions", buttons)

	-- choose file type
	svnDialog:group("fileType", "currentFile", "File/directory to review:")
	if geany.filename() then
		svnDialog:radio("fileType", "currentFile", "Current file ("..geany.filename()..")")
		svnDialog:radio("fileType", "currentDir", "Current directory ("..geany.dirname(geany.filename())..")")
	end
	if isProjectOpen() then
		svnDialog:radio("fileType", "projectBaseDir", "Project base directory")
	end
	svnDialog:radio("fileType", "customFile", "Other:")
	svnDialog:file("customFile", geany.wkdir(), "")

	svnDialog:hr()

	-- choose initial scan size
	svnDialog:text("scanCount", "30", "Initial # of revisions to scan  \n(0 = unlimited)")

	svnDialog:hr()

	-- choose diff viewer
	svnDialog:group("diffViewer", "diff", "Diff viewer")
	addDiffViewer(svnDialog, "diff")
	addDiffViewer(svnDialog, "meld")
	addDiffViewer(svnDialog, "kompare")
	addDiffViewer(svnDialog, "kdiff3")
	addDiffViewer(svnDialog, "diffuse")
	addDiffViewer(svnDialog, "tkdiff")
	addDiffViewer(svnDialog, "opendiff")
	svnDialog:radio("diffViewer", "customDiffViewer", "Other:")
	svnDialog:text("customDiffViewer", "", "")

	-- execute

	local resultIndex,resultTable = svnDialog:run()
	debugMessage("Result ["..resultIndex.."]: ["..buttons[resultIndex].."]")
	if not (resultIndex == 2) then return nil end

	local preferences = {}
	if resultTable["fileType"] == "currentFile" then
		preferences[_PREFERENCE_FILENAME] = geany.filename()
	elseif resultTable["fileType"] == "currentDir" then
		preferences[_PREFERENCE_FILENAME] = geany.dirname(geany.filename())
	elseif resultTable["fileType"] == "projectBaseDir" then
		preferences[_PREFERENCE_FILENAME] = geany.appinfo()["project"]["base"]
	elseif resultTable["fileType"] == "customFile" then
		if (resultTable["customFile"] == nil) or resultTable["customFile"] == "" then
			geany.message("ERROR", "You must specify a target file.")
			return nil
		end
		preferences[_PREFERENCE_FILENAME] = resultTable["customFile"]
	end

	preferences[_PREFERENCE_SCAN_SIZE] = resultTable["scanCount"]

	if resultTable["diffViewer"] == "customDiffViewer" then
		if (resultTable["customDiffViewer"] == nil) or resultTable["customDiffViewer"] == "" then
			geany.message("ERROR", "You must specify a diff viewer.")
			return nil
		end
		preferences[_PREFERENCE_DIFF_VIEWER] = resultTable["customDiffViewer"]
	else
		preferences[_PREFERENCE_DIFF_VIEWER] = resultTable["diffViewer"]
	end

	return preferences
end

---- Start execution ----

local preferences = getRevisionOptions()
if not preferences then
	debugMessage("No results; cancelling")
	return
end

local filename = preferences[_PREFERENCE_FILENAME]
local scanCount = preferences[_PREFERENCE_SCAN_SIZE]
local diffViewer = preferences[_PREFERENCE_DIFF_VIEWER]

local revision
local revisionTypes = {[1]="Single revision", [2]="All changes since revision", [3]="Custom"}
local revisionType = geany.choose("What revision range would you like to view?", revisionTypes)

if revisionType == nil then return end

debugMessage("Revision type is "..revisionType)
if revisionType == revisionTypes[3] then
	revision = geany.input("Please enter a revision or range to review")
else
	local increaseScanItem = "Show more.."
	repeat
		local revisionCount,revisions = getOutputLines(getQuickLogCommand(filename, scanCount))
		if revisionCount == scanCount then
			revisions[revisionCount + 1] = increaseScanItem
		end
		if revisionCount == 0 then
			geany.message("Unable to get revision log for "..filename..". Please ensure that this file is under version control.")
			return
		else
			revision = geany.choose("Please choose a revision", revisions)
			if not revision then return
			elseif revision == increaseScanItem then
				scanCount = scanCount * 2
			else
				revision = string.match(revision, "^[0-9]+")
			end
		end
	until not (revision == increaseScanItem)
	if revisionType == revisionTypes[2] then
		revision = (revision - 1)..":HEAD"
	end
end
if revision == nil then return end
debugMessage("Revision was "..revision)

if diffViewer == "diff" then
	local tempFile = os.tmpname()
	debugMessage("Generating diff into "..tempFile)
	os.execute(getSVNDiffCommand(revision, filename, diffViewer).." > "..tempFile)
	geany.open(tempFile)
else
	geany.timeout(0)
	os.execute(getSVNDiffCommand(revision, filename))
end
