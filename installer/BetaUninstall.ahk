;
; File encoding:  UTF-8
; Platform:  Windows XP/Vista/7
; Author:    A.N.Other <myemail@nowhere.com>
;
; Script description:
;	Template script
;

#NoEnv
#NoTrayIcon
#SingleInstance Ignore
#Include beta123uninst\Uninstall.ahk
SetWorkingDir, %A_ScriptDir%
Menu, Tray, NoStandard

title = SciTE4AutoHotkey uninstallation

if GetWinVer() >= 6 && !A_IsAdmin
{
	MsgBox, 16, %title%, Admin rights required.
	ExitApp
}

if 1 = /perform
	goto DoIt

MsgBox, 52, %title%, Are you sure you want to remove SciTE4AutoHotkey?
IfMsgBox, No
	ExitApp

FileCopy, %A_ScriptFullPath%, %A_Temp%\s4a-uninst.exe, 1
Run, "%A_Temp%\s4a-uninst.exe" /perform "%A_ScriptDir%"
ExitApp

DoIt:
FileRemoveDir, %2%, 1
RegDelete, HKCR, AutoHotkeyScript\Shell\EditSciTEBeta
RegDelete, HKLM, Software\Microsoft\Windows\CurrentVersion\Uninstall\SciTE4AutoHotkey
MsgBox, 52, %title%, Do you want to remove the user profile?
IfMsgBox, Yes
	WipeProfile(A_MyDocuments "\AutoHotkey\SciTE")
MsgBox, 64, %title%, SciTE4AutoHotkey removed successfully!
ExitApp

GetWinVer()
{
	pack := DllCall("GetVersion", "uint")
	return ((pack >> 16) "." (pack & 0xFFFF)) + 0.0
}

GetAutoHotkeyDir()
{
	if A_AhkPath =
		return
	SplitPath, A_AhkPath,, ahkdir
	return ahkdir
}

Util_Is64bitOS()
{
	return (A_PtrSize = 8) || DllCall("IsWow64Process", "ptr", DllCall("GetCurrentProcess"), "int*", isWow64) && isWow64
}
