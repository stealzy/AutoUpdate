AutoUpdate(FILE, mode:=0, updateIntervalDays:=7, CHANGELOG:="", iniFile:="", backupNumber:=1) {
	iniFile := iniFile ? iniFile : GetNameNoExt(A_ScriptName) . ".ini"
	VERSION_FromScript_REGEX := "Oi)(?:^|\R);\s*ver\w*\s*=?\s*(\d+(?:\.\d+)?)(?:$|\R)"
	if NeedToCheckUpdate(mode, updateIntervalDays, iniFile) {
		if (CHANGELOG!="") {
			if Not (currVer := GetCurrentVer(iniFile))
				currVer := GetCurrentVerFromScript(VERSION_FromScript_REGEX)
			changelogContent := DownloadChangelog(CHANGELOG)
			If changelogContent {
				if (lastVer := GetLastVer(CHANGELOG, changelogContent)) {
					LastVerNews := GetLastVerNews(CHANGELOG, changelogContent)
					WriteLastCheckTime(iniFile)
					if Not (lastVer > currVer)
						Return
				}
			} else {
				if ((ErrorLevel != "") && (Manually := mode & 1)) {
					MsgBox 48,, %ErrorLevel%, 5
					Return
				}
			}
		}
		
		Update(FILE, mode, backupNumber, iniFile, currVer, lastVer, LastVerNews)
	}
}
NeedToCheckUpdate(mode, updateIntervalDays, iniFile) {
	if ((NotAuto := mode & 2) And Not (Manually := mode & 1)) {
		NeedToCheckUpdate := False
	} else if (A_Now > GetTimeToUpdate(updateIntervalDays, iniFile)) || (manually := mode & 1) {
		NeedToCheckUpdate := True
	}
	OutputDebug % "NeedToCheckUpdate: " (NeedToCheckUpdate ? "Yes" : "No")
	Return NeedToCheckUpdate
}
Update(FILE, mode, backupNumber, iniFile, currVer, lastVer, LastVerNews:="") {
	silentUpdate := ! ((mode & 4) || (mode & 1))
	if silentUpdate {
		OutputDebug % DownloadAndReplace(FILE, backupNumber, iniFile, lastVer, currVer)
		if (mode & 8)
			Reload
	} else {
		MsgBox, 36, %A_ScriptName% %currVer%, New version %lastVer% available.`n%LastVerNews%`nDownload it now? ; [Yes] [No]  [x][Don't check update]
		IfMsgBox Yes
		{
			if (Err := DownloadAndReplace(FILE, backupNumber, iniFile, lastVer, currVer)) {
				if ((Err != "") && (Err != "No access to the Internet"))
					MsgBox 48,, %Err%, 5
			} else {
				if (mode & 8)
					Reload
				else if ((mode & 16) || (mode & 1)) {
					MsgBox, 36, %A_ScriptName%, Script updated.`nRestart it now?
					IfMsgBox Yes
					{
						Reload ; no CL parameters!
					}
				}
			}
		}
	}
}
DownloadAndReplace(FILE, backupNumber, iniFile, lastVer, currVer) {
	; Download File from Net and replace origin
	; Return "" if update success Or return Error, if not
	; Write CurrentVersion to ini
	currFile := FileOpen(A_ScriptFullPath, "r").Read()
	if A_LastError
		Return "FileOpen Error: " A_LastError
	lastFile := UrlDownloadToVar(FILE)
	if ErrorLevel
		Return ErrorLevel
	OutputDebug DownloadAndReplace: File download
	if (RegExReplace(currFile, "\R", "`n") = RegExReplace(lastFile, "\R", "`n")) {
		WriteCurrentVersion(lastVer, iniFile)
		Return "Last version the same file"
	} else {
		backupName := A_ScriptFullPath ".v" currVer ".backup"
		FileCopy %A_ScriptFullPath%, %backupName%, 1
		if ErrorLevel
			Return "Error access to " A_ScriptFullPath " : " ErrorLevel

		file := FileOpen(A_ScriptFullPath, "w")
		if !IsObject(file) {
			MsgBox Can't open "%A_ScriptFullPath%" for writing.
			return
		}
		file.Write(lastFile)
		file.Close()

		; FileAppend %lastFile%, %A_ScriptFullPath%
		if ErrorLevel
			Return "Error create new " A_ScriptFullPath " : " ErrorLevel
	}
	WriteCurrentVersion(lastVer, iniFile)
	OutputDebug DownloadAndReplace: File update
}
GetTimeToUpdate(updateIntervalDays, iniFile) {
	timeToUpdate := GetLastCheckTime(iniFile)
	timeToUpdate += %updateIntervalDays%, days
	OutputDebug GetTimeToUpdate %timeToUpdate%
	Return timeToUpdate
}
GetLastCheckTime(iniFile) {
	IniRead lastCheckTime, %iniFile%, update, last check, 0
	OutputDebug LastCheckTime %lastCheckTime%
	Return lastCheckTime
}
WriteLastCheckTime(iniFile) {
	IniWrite, %A_Now%, %iniFile%, update, last check
	OutputDebug WriteLastCheckTime
	If ErrorLevel
		Return 1
}
WriteCurrentVersion(lastVer, iniFile) {
	OutputDebug WriteCurrentVersion %lastVer% to %iniFile%
	IniWrite %lastVer%, %iniFile%, update, current version
	If ErrorLevel
		Return 1
}
GetCurrentVer(iniFile) {
	IniRead currVer, %iniFile%, update, current version, 0
	OutputDebug, GetCurrentVer() = %currVer% from %iniFile%
	Return currVer
}
GetCurrentVerFromScript(Regex) {
	FileRead, ScriptText, % A_ScriptFullPath
	RegExMatch(ScriptText, Regex, currVerObj)
	currVer := currVerObj.1
	OutputDebug, GetCurrentVerFromScript() = %currVer% from %A_ScriptFullPath%
	Return currVer
}
GetLastVer(CHANGELOG, changelogContent) {
	If IsObject(CHANGELOG) {
		Regex := CHANGELOG[2]
		RegExMatch(changelogContent, Regex, changelogContentObj)
		lastVer := changelogContentObj.0
	} else
		lastVer := changelogContent

	OutputDebug, GetLastVer() = %lastVer%`, Regex = %Regex% 
	Return lastVer
}
GetLastVerNews(CHANGELOG, changelogContent) {
	If IsObject(CHANGELOG) {
		if (WhatNew_REGEX := CHANGELOG[3]) {
			RegExMatch(changelogContent, WhatNew_REGEX, WhatNewO)
			WhatNew := WhatNewO.1
		}
	}
	Return WhatNew
}
DownloadChangelog(CHANGELOG) {
	If IsObject(CHANGELOG)
		URL := CHANGELOG[1]
	else
		URL := CHANGELOG

	If changelogContent := UrlDownloadToVar(URL)
		Return changelogContent
}
UrlDownloadToVar(URL) {
	WebRequest := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	try WebRequest.Open("GET", URL, true)
	catch	Error {
		ErrorLevel := "Wrong URL"
		return false
		}
	WebRequest.Send()
	try WebRequest.WaitForResponse()
	catch	Error {
		ErrorLevel := "No access to the Internet"
		return false
		}
	HTTPStatusCode := WebRequest.status
	if (SubStr(HTTPStatusCode, 1, 1) ~= "4|5") { ; 4xx — Client Error, 5xx — Server Error. wikipedia.org/wiki/List_of_HTTP_status_codes
		ErrorLevel := "HTTPStatusCode: " HTTPStatusCode
		return false
		}
	OutputDebug UrlDownloadToVar() HTTPStatusCode = %HTTPStatusCode% 
	ans:=WebRequest.ResponseText
	return ans
}
GetNameNoExt(FileName) {
	SplitPath FileName,,, Extension, NameNoExt
	Return NameNoExt
}

/*
AutoUpdate(FILE, mode:=0, updateIntervalDays:="", CHANGELOG:="", iniFile:="", backupNumber:=1) {
CHANGELOG := [CHANGELOG_URL, VERSION_REGEX, WhatNew_REGEX]
FILE := [FILE_URL, FILE_REGEX, VERSION_FromScript_REGEX]

ini file strucnure:
[update]
	last check
	current version
	?auto check
	?auto download
	?auto restart

mode:
	manually(ignore timeToUpdate)							1 ? set updateIntervalDays:=0
	if auto, don't check updated							2 ? if (autocheck) {AU()}
	if exist update, ask before download it 	4
	auto restart after download 							8
	if not autorestart, ask if restart need 	16

	Scenaries:
	1) Silent check new version available, if exist such, AutoUpdate
	2) Silent check new version available, if exist such, ask whether you want to update
	3) Manual check new version available, if exist such, ask whether you want to update
	• (ToolTip/MsgBox) asking whether you want to reload straight away

updateIntervalDays: check for update every %updateIntervalDays% days

CHANGELOG:
	1)"url"
	2)"url regex"

3 места хранения: .ahk, .ini, regestry
	1)ini
		"ini:"        IniRead currVer, %A_ScriptNameNoExt%.ini, update, current version, 0
		"ini:xxx"     IniRead currVer, %xxx%, update, current version, 0
	2)inside
		"inside:"				currVer := regex("Oi)^;\s*(?:version|ver)?\s*=?\s*(\d+(?:\.\d+)?)", A_Script)
		"inside:xxx"    currVer := regex(xxx, A_Script)
	3)regestry
		"regestry:"				RegRead, currVer, HKEY_CURRENT_USER, SOFTWARE\%A_ScriptNameNoExt%\CurrentVersion, Version
		"regestry:xxx"		RegRead, currVer, HKEY_CURRENT_USER, SOFTWARE\%xxx%, Version

2 опциональных значения для хранения: currVers (если не указана, скрипт при проверке скачивается полностью и сравнивается с текущим), lastCheckDate (если не указана, проверка происходит при каждом вызове ф-ии AutoUpdate())

backupNumber:

