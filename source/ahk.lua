-- ahk.lua
-- =======

-- Part of SciTE4AutoHotkey
-- This file implements features specific to AHK in SciTE
-- November 7, 2010 - fincs

-- Functions:
--     AutoIndent for AutoHotkey
--     Some AutoComplete tweaks
--     Automatic backups
--     SciTEDebug.ahk DBGp debugger interface

-- ======================= --
-- AutoHotkey lexer styles --
-- ======================= --

local SCLEX_AHK1           = 999
local SCE_AHK_DEFAULT      =  0
local SCE_AHK_COMMENTLINE  =  1
local SCE_AHK_COMMENTBLOCK =  2
local SCE_AHK_ESCAPE       =  3
local SCE_AHK_SYNOPERATOR  =  4
local SCE_AHK_EXPOPERATOR  =  5
local SCE_AHK_STRING       =  6
local SCE_AHK_NUMBER       =  7
local SCE_AHK_IDENTIFIER   =  8
local SCE_AHK_VARREF       =  9
local SCE_AHK_LABEL        = 10
local SCE_AHK_WORD_CF      = 11
local SCE_AHK_WORD_CMD     = 12
local SCE_AHK_WORD_FN      = 13
local SCE_AHK_WORD_DIR     = 14
local SCE_AHK_WORD_KB      = 15
local SCE_AHK_WORD_VAR     = 16
local SCE_AHK_WORD_SP      = 17
local SCE_AHK_WORD_UD      = 18
local SCE_AHK_VARREFKW     = 19
local SCE_AHK_ERROR        = 20

-- ============================= --
-- Message pumper initialization --
-- ============================= --

local dbguihlp,err = package.loadlib(props['SciteDefaultHome'].."\\debugger\\dbguihlp.dll", "libinit")
local debugon  = true
local prepared = false

if dbguihlp then
	dbguihlp()
else
	print(err)
	debugon = false
end

-- ================================================== --
-- OnClear event - fired when SciTE changes documents --
-- ================================================== --

function OnClear()
	-- This function only works with the AutoHotkey lexer
	if editor.Lexer ~= SCLEX_AHK1 then return false end
	
	if not prepared then
		-- Remove the breakpoint and current line markers.
		-- This could be improved to autodetect if SciTE has itself
		-- placed the breakpoint (in yellow) and not delete it then.
		ClearAllMarkers()
	else
		-- Set the marker colors
		SetMarkerColors()
	end
end

-- ====================================== --
-- OnChar event - needed by some features --
-- ====================================== --

function OnChar(curChar)
	local ignoreStyles = {SCE_AHK_COMMENTLINE, SCE_AHK_COMMENTBLOCK, SCE_AHK_STRING, SCE_AHK_ERROR}
	
	-- This function only works with the AutoHotkey lexer
	if editor.Lexer ~= SCLEX_AHK1 then return false end

	if curChar == "\n" then
		local prevStyle = editor.StyleAt[getPrevLinePos()]
		if not isInTable(ignoreStyles, prevStyle) then
			return AutoIndent_OnNewLine()
		end
	elseif curChar == "{" then
		local curStyle = editor.StyleAt[editor.CurrentPos-2]
		if not isInTable(ignoreStyles, curStyle) then
			AutoIndent_OnOpeningBrace()
		end
	elseif curChar == "}" then
		local curStyle = editor.StyleAt[editor.CurrentPos-2]
		if not isInTable(ignoreStyles, curStyle) then
			AutoIndent_OnClosingBrace()
		end
	elseif curChar == "." then
		return CancelAutoComplete()
	else
		local curStyle = editor.StyleAt[editor.CurrentPos-2]
		
		-- Disable AutoComplete on comment/string/error/etc.
		if isInTable(ignoreStyles, curStyle) then
			return CancelAutoComplete()
		end
		
		-- Disable AutoComplete for words that start with underscore if it's not an object call
		local pos = editor:WordStartPosition(editor.CurrentPos)
		-- _ and .
		if editor.CharAt[pos] == 95 and editor.CharAt[pos-1] ~= 46 then
			return CancelAutoComplete()
		end
	end
	
	return false
end

function CancelAutoComplete()
	if editor:AutoCActive() then
		editor:AutoCCancel()
	end
	return true
end

-- ================================================== --
-- OnMarginClick event - needed to set up breakpoints --
-- ================================================== --

function OnMarginClick(position, margin)
	-- This function only works with the AutoHotkey lexer
	if editor.Lexer ~= SCLEX_AHK1 then return false end
	
	-- Sanity checks
	if not prepared then return false end
	if margin == 2 then return false end
	
	-- Tell the debugger to set a breakpoint
	return pumpmsg(4112, 1, editor:LineFromPosition(position))
end

--[=[

-- =============================================== --
-- OnDwellStart event - used to implement hovering --
-- =============================================== --

function OnDwellStart(pos, s)
	print "OnDwellStart"
	if not prepared then return end
	if s ~= '' then
		print ("Hovered on: ".. GetWord(pos))
	else
		print "Stopped hovering"
	end
end

]=]

-- ============== --
-- DBGp functions --
-- ============== --
-- The following are only reachable when an AutoHotkey script
-- is open so there's no need to check the lexer

function DBGp_Connect()
	if prepared then return end
	
	if not debugon then
		print("Debugging features are disabled because the debugger helper is not present.")
		print("Hit Ctrl-Alt-Z to close the debugger.")
		return
	end
	
	if localizewin("SciTEDebugStub") == false then
		print("Window doesn't exist.")
		return
	end
	
	-- Initialize
	pumpmsg(4112, 0, 0)
	prepared = true
	editor.MarginSensitiveN[1] = true
	SetMarkerColors()
	ClearAllMarkers()
end

function DBGp_Disconnect()
	-- Deinitialize
	u = pumpmsg(4112, 255, 0)
	if u == 0 then return false end
	
	editor.MarginSensitiveN[1] = false
	prepared = false
	ClearAllMarkers()
end

function DBGp_Inspect()
	if not prepared then return end
	pumpmsgstr(4112, 2, GetCurWord())
end

function DBGp_Run()
	if not prepared then return end
	pumpmsgstr(4112, 3, "run")
end

function DBGp_Stop()
	if not prepared then return end
	pumpmsgstr(4112, 3, "stop")
end

function DBGp_StepInto()
	if not prepared then return end
	pumpmsgstr(4112, 3, "stepinto")
end

function DBGp_StepOver()
	if not prepared then return end
	pumpmsgstr(4112, 3, "stepover")
end

function DBGp_StepOut()
	if not prepared then return end
	pumpmsgstr(4112, 3, "stepout")
end

function DBGp_Stacktrace()
	if not prepared then return end
	pumpmsgstr(4112, 3, "stacktrace")
end

function DBGp_Varlist()
	if not prepared then return end
	pumpmsgstr(4112, 3, "varlist")
end

-- ============================================================ --
-- AutoIndent section - it implements AutoIndent for AutoHotkey --
-- ============================================================ --

-- Patterns for syntax matching
--local varCharPat = "[#_@%w%[%]%$%?]"
local varCharPat = "[#_@%w%$]"
local ifPat = "[iI][fF]"
local altIfPat = ifPat.."%a+"
local whilePat = "[wW][hH][iI][lL][eE]"
local loopPat = "[lL][oO][oO][pP]"
local forPat = "[fF][oO][rR]"
local elsePat = "[eE][lL][sS][eE]"

-- Functions to detect certain types of statements

function isOpenBraceLine(line)
	return string.find(line, "^%s*{") ~= nil
end

function isIfLine(line)
	return string.find(line, "^%s*"..ifPat.."%s+"..varCharPat) ~= nil
		or string.find(line, "^%s*"..ifPat.."%s*%(") ~= nil
		or string.find(line, "^%s*"..ifPat.."%s+!") ~= nil
		or string.find(line, "^%s*"..altIfPat.."%s*,") ~= nil
		or string.find(line, "^%s*"..altIfPat.."%s+") ~= nil
end

function isIfLineNoBraces(line)
	return isIfLine(line) and string.find(line, "{%s*$") == nil
end

function isWhileLine(line)
	return string.find(line, "^%s*"..whilePat.."%s+") ~= nil
		or string.find(line, "^%s*"..whilePat.."%s*%(") ~= nil
end

function isLoopLine(line)
	return string.find(line, "^%s*"..loopPat.."%s*,") ~= nil
		or string.find(line, "^%s*"..loopPat.."%s+") ~= nil
end

function isForLine(line)
	return string.find(line, "^%s*"..forPat.."%s+"..varCharPat) ~= nil
end

function isLoopLineAllowBraces(line)
	return isLoopLine(line) or string.find(line, "^%s*"..loopPat.."{%s*$") ~= nil
end

function isElseLine(line)
	return string.find(line, "^%s*"..elsePat.."%s*$") ~= nil
		or string.find(line, "^%s*}%s*"..elsePat.."%s*$") ~= nil
end

function isElseWithClosingBrace(line)
	return string.find(line, "^%s*}%s*"..elsePat.."%s*$") ~= nil
end

function isElseLineAllowBraces(line)
	return isElseLine(line) or isElseWithClosingBrace(line)
		or string.find(line, "^%s*"..elsePat.."%s*{%s*$") ~= nil
		or string.find(line, "^%s*}%s*"..elsePat.."%s*{%s*$") ~= nil
end

function isFuncDef(line)
	return string.find(line, "^%s*"..varCharPat.."+%(.*%)%s*{%s*$") ~= nil
end

function isSingleLineIndentStatement(line)
	return isIfLineNoBraces(line) or isElseLine(line) or isElseWithClosingBrace(line)
		or isWhileLine(line) or isForLine(line) or isLoopLine(line)
end

function isIndentStatement(line)
	return isOpenBraceLine(line) or isIfLine(line) or isWhileLine(line) or isForLine(line)
		or isLoopLineAllowBraces(line) or isElseLineAllowBraces(line) or isFuncDef(line)
end

function isStartBlockStatement(line)
	return isIfLine(line) or isWhileLine(line) or isLoopLine(line)  or isForLine(line)
		or isElseLine(line) or isElseWithClosingBrace(line)
end

-- This function is called when the user presses {Enter}
function AutoIndent_OnNewLine()
	local prevprevPos = editor:LineFromPosition(editor.CurrentPos) - 2
	local prevPos = editor:LineFromPosition(editor.CurrentPos) - 1
	local prevLine = GetFilteredLine(prevPos, SCE_AHK_COMMENTLINE, SCE_AHK_COMMENTBLOCK)
	local curPos = prevPos + 1
	local curLine = editor:GetLine(curPos)
	
	if curLine ~= nil and string.find(curLine, "^%s*[^%s]+") then return end
	
	if prevprevPos >= 0 then
		local prevprevLine = GetFilteredLine(prevprevPos, SCE_AHK_COMMENTLINE, SCE_AHK_COMMENTBLOCK)
		local reqLvl = editor.LineIndentation[prevprevPos] + editor.Indent
		local prevLvl = editor.LineIndentation[prevPos]
		local curLvl = editor.LineIndentation[curPos]
		if isSingleLineIndentStatement(prevprevLine) and prevLvl == reqLvl and curLvl == reqLvl then
			editor:Home()
			editor:BackTab()
			editor:LineEnd()
			return true
		end
	end
	if isIndentStatement(prevLine) then
		editor:Home()
		editor:Tab()
		editor:LineEnd()
	end
	return false
end

-- This function is called when the user presses {
function AutoIndent_OnOpeningBrace()
	local prevPos = editor:LineFromPosition(editor.CurrentPos) - 1
	local curPos = prevPos+1
	if prevPos == -1 then return false end
	
	if editor.LineIndentation[curPos] == 0 then return false end
	
	local prevLine = GetFilteredLine(prevPos, SCE_AHK_COMMENTLINE, SCE_AHK_COMMENTBLOCK)
	local curLine = GetFilteredLine(curPos, SCE_AHK_COMMENTLINE, SCE_AHK_COMMENTBLOCK)
	
	if string.find(curLine, "^%s*{%s*$") and isStartBlockStatement(prevLine)
		and (editor.LineIndentation[curPos] > editor.LineIndentation[prevPos]) then
		editor:Home()
		editor:BackTab()
		editor:LineEnd()
	end
end

-- This function is called when the user presses }
function AutoIndent_OnClosingBrace()
	local curPos = editor:LineFromPosition(editor.CurrentPos)
	local curLine = GetFilteredLine(curPos, SCE_AHK_COMMENTLINE, SCE_AHK_COMMENTBLOCK)
	local prevPos = curPos - 1
	local prevprevPos = prevPos - 1
	local secondChance = false
	
	if curPos == 0 then return false end
	if editor.LineIndentation[curPos] == 0 then return false end
	
	if prevprevPos >= 0 then
		local prevprevLine = GetFilteredLine(prevprevPos, SCE_AHK_COMMENTLINE, SCE_AHK_COMMENTBLOCK)
		local lowLvl = editor.LineIndentation[prevprevPos]
		local highLvl = lowLvl + editor.Indent
		local prevLvl = editor.LineIndentation[prevPos]
		local curLvl = editor.LineIndentation[curPos]
		if isSingleLineIndentStatement(prevprevLine) and prevLvl == highLvl and curLvl == lowLvl then
			secondChance = true
		end
	end
	
	if string.find(curLine, "^%s*}%s*$") and (editor.LineIndentation[curPos] >= editor.LineIndentation[prevPos] or secondChance) then
		editor:Home()
		editor:BackTab()
		editor:LineEnd()
	end
end

-- ====================== --
-- Script Backup Function --
-- ====================== --

-- this functions creates backups for the files

function OnBeforeSave(filename)
	-- This function only works with the AutoHotkey lexer
	if editor.Lexer ~= SCLEX_AHK1 then return false end
	
	if props['make.backup'] == "1" then
		os.remove(filename .. ".bak")
		os.rename(filename, filename .. ".bak")
	end
end

-- ============= --
-- Open #Include --
-- ============= --

function OpenInclude()
	-- This function only works with the AutoHotkey lexer
	if editor.Lexer ~= SCLEX_AHK1 then return false end
	
	local CurrentLine = editor:GetLine(editor:LineFromPosition(editor.CurrentPos))
	if not string.find(CurrentLine, "^%s*%#[Ii][Nn][Cc][Ll][Uu][Dd][Ee]") then
		print("Not an include line!")
		return
	end
	local place = string.find(CurrentLine, "%#[Ii][Nn][Cc][Ll][Uu][Dd][Ee]")
	local IncFile = string.sub(CurrentLine, place + 8)
	if string.find(IncFile, "^[Aa][Gg][Aa][Ii][Nn]") then
		IncFile = string.sub(IncFile, 6)
	end
	IncFile = string.gsub(IncFile, "\r", "")  -- strip CR
	IncFile = string.gsub(IncFile, "\n", "")  -- strip LF
	IncFile = string.sub(IncFile, 2)          -- strip space at the beginning
	IncFile = string.gsub(IncFile, "*i ", "") -- strip *i option
	IncFile = string.gsub(IncFile, "*I ", "")
	-- Delete comments
	local cplace = string.find(IncFile, "%s*;")
	if cplace then
		IncFile = string.sub(IncFile, 1, cplace-1)
	end
	
	-- Delete spaces at the beginning and the end
	IncFile = string.gsub(IncFile, "^%s*", "")
	IncFile = string.gsub(IncFile, "%s*$", "")
	
	-- Replace variables
	IncFile = string.gsub(IncFile, "%%[Aa]_[Ss][Cc][Rr][Ii][Pp][Tt][Dd][Ii][Rr]%%", props['FileDir'])
	
	if FileExists(IncFile) then
		scite.Open(IncFile)
	else
		print("File not found! Specified: '"..IncFile.."'")
	end
end

-- ================ --
-- Helper Functions --
-- ================ --

function GetWord(pos)
	from = editor:WordStartPosition(pos)
	to = editor:WordEndPosition(pos)
	return editor:textrange(from, to)
end

function GetCurWord()
	local word = editor:GetSelText()
	if word == "" then
		word = GetWord(editor.CurrentPos)
	end
	return word
end

function getPrevLinePos()
	local line = editor:LineFromPosition(editor.CurrentPos)-1
	local linepos = editor:PositionFromLine(line)
	local linetxt = editor:GetLine(line)
	return linepos + string.len(linetxt) - 1
end

function isInTable(table, elem)
	for k,i in ipairs(table) do
		if i == elem then
			return true
		end
	end
	return false
end

function GetFilteredLine(linen, style1, style2)
	unline = editor:GetLine(linen)
	lpos = editor:PositionFromLine(linen)
	q = 0
	for i = 0, string.len(unline)-1 do
		if(editor.StyleAt[lpos+i] == style1 or editor.StyleAt[lpos+i] == style2) then
			unline = unline:sub(1, i).."\000"..unline:sub(i+2)
		end
	end
	unline = string.gsub(unline, "%z", "")
	return unline
end

function SetMarkerColors()
	editor:MarkerDefine(10, 0)  -- breakpoint
	editor:MarkerSetBack(10, 0x0000FF)
	editor:MarkerDefine(11, 2)  -- current line arrow
	editor:MarkerSetBack(11, 0xFFFF00)
	editor:MarkerDefine(12, 22) -- current line highlighting
	editor:MarkerSetBack(12, 0xFFFF00)
end

function ClearAllMarkers()
	for i = 0, 23, 1 do
		editor:MarkerDeleteAll(i)
	end
end

-- ======================= --
-- User Lua script loading --
-- ======================= --

function FileExists(file)
	local fobj = io.open(file, "r")
	if fobj then
		fobj:close()
		return true
	else
		return false
	end
end

local userlua = props['SciteUserHome'].."/UserLuaScript.lua"
if FileExists(userlua) then
	dofile(userlua)
end
