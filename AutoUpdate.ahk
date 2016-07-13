AutoUpdate(FILE, mode:=0, updateIntervalDays:=7, CHANGELOG:="", WhereCurrVer:="", backupNumber:=1) {
	OutputDebug AutoUpdate()
	if NeedToCheckUpdate(mode, updateIntervalDays) {
		currVer := GetCurrentVer(WhereCurrVer)
		lastVer := GetLastVer(CHANGELOG)
		if NewVerAvailable(mode, CHANGELOG, WhereCurrVer, currVer, lastVer)
			Update(FILE, mode, backupNumber, WhereCurrVer, currVer, lastVer)
	}
}
NeedToCheckUpdate(mode, updateIntervalDays) {
	if ((NoAuto := mode & 2) And Not (Manually := mode & 1)) {
		NeedToCheckUpdate := False
	} else if (A_Now > GetTimeToUpdate(updateIntervalDays)) || (manually := mode & 1) {
		NeedToCheckUpdate := True
	}
	OutputDebug NeedToCheckUpdate %NeedToCheckUpdate%
	Return %NeedToCheckUpdate%
}
NewVerAvailable(mode, CHANGELOG, WhereCurrVer, currVer, lastVer) {
	WriteLastCheckTime(WhereCurrVer)
	if ((lastVer > currVer) || !CHANGELOG || !currVer)
		Return True
}
Update(FILE, mode, backupNumber, WhereCurrVer, currVer, lastVer) {
	silentUpdate := !(mode & 4)
	if silentUpdate {
		OutputDebug % DownloadAndReplace(FILE, backupNumber, WhereCurrVer, lastVer, currVer)
		if (mode & 8)
			Reload
	} else {
		MsgBox, 36, %A_ScriptName% %currVer%, New version %lastVer% available.`nDownload it now? ; [Yes] [No]  [x][Don't check update]
		IfMsgBox Yes
		{
			if (Err := DownloadAndReplace(FILE, backupNumber, WhereCurrVer, lastVer, currVer)) {
				if ((Err != "") && (Err != "No access to the Internet"))
					MsgBox 48,, %Err%, 5
			} else {
				if (mode & 8)
					Reload
				else if (mode & 16) {
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

DownloadAndReplace(FILE, backupNumber, WhereCurrVer, lastVer, currVer) {
	; Download File from Net and replace origin
	; Return "" if update success Or return Error, if not
	; Write CurrentVersion to ini
	currFile := FileOpen(A_ScriptFullPath, "r").Read()
	if A_LastError
		Return "FileOpen Error: " A_LastError
	lastFile := UrlDownloadToVar(FILE)
	if ErrorLevel
		Return ErrorLevel
	OutputDebug -Update-0
	if (RegExReplace(currFile, "\R", "`n") = RegExReplace(lastFile, "\R", "`n")) {
		WriteCurrentVersion(lastVer, WhereCurrVer)
		Return "Last version the same file"
	} else {
		backupName := A_ScriptFullPath ".v" currVer "_backup"
		FileMove %A_ScriptFullPath%, %backupName%, 1
		if ErrorLevel
			Return "Error access to " A_ScriptFullPath " : " ErrorLevel
		FileAppend %lastFile%, %A_ScriptFullPath%
		if ErrorLevel
			Return "Error create new " A_ScriptFullPath " : " ErrorLevel
	}
	WriteCurrentVersion(lastVer, WhereCurrVer)
	OutputDebug -Update-
}

GetTimeToUpdate(updateIntervalDays) {
	timeToUpdate := ReadLastCheckTime()
	timeToUpdate += %updateIntervalDays%, days
	OutputDebug GetTimeToUpdate %timeToUpdate%
	Return timeToUpdate
}
GetLastCheckTime(iniFile:="") {
	iniFile := iniFile ? iniFile : GetNameNoExt(A_ScriptName) . ".ini"
	IniRead lastCheckTime, %iniFile%, update, last check, 0
	OutputDebug LastCheckTime %lastCheckTime%
	Return lastCheckTime
}
WriteLastCheckTime(iniFile:="") {
	iniFile := iniFile ? iniFile : GetNameNoExt(A_ScriptName) . ".ini"
	IniWrite, %A_Now%, %iniFile%, update, last check
	OutputDebug WriteLastCheckTime
}
WriteCurrentVersion(lastVer, iniFile:="") {
	iniFile := iniFile ? iniFile : GetNameNoExt(A_ScriptName) . ".ini"
	OutputDebug WriteCurrentVersion %lastVer% to %iniFile%
	IniWrite %lastVer%, %iniFile%, update, current version
}
GetCurrentVer(WhereCurrVer) {
	if (SubStr(WhereCurrVer, 1, 1) =":") {
		if (WhereCurrVer=":")
			currVer:=""
		else {
			If A_IsCompiled {
				FileGetVersion, currVer, %A_ScriptFullPath%
			} else {
				param := SubStr(WhereCurrVer, 2) ;"Oi)(?<=; Version = )\d+(\.\d+)?"
				FileRead, text, %A_ScriptFullPath%
				RegExMatch(text, param, currVer)
				currVer := currVer.0
			}
		}
	}	else {
		if (WhereCurrVer="")
			iniName := GetNameNoExt(A_ScriptName) ".ini"
		else
			iniName := WhereCurrVer
		IniRead currVer, %iniName%, update, current version, 0
	}

	OutputDebug, GetCurrentVer() = %currVer% from %iniName%
	Return currVer
}
GetLastVer(CHANGELOG) {
	If InStr(CHANGELOG, " ")
		regexMode:=true
	Array := StrSplit(CHANGELOG, " ")
	URL := Array[1]
	Regex := "Oi)" SubStr(CHANGELOG, StrLen(URL)+2)

	changelogContent := UrlDownloadToVar(URL)

	if ErrorLevel {
		if ((Err != "") && (NoAuto := mode & 2))
			MsgBox 48,, %Err%, 5
	} else {
		if regexMode {
			RegExMatch(changelogContent, Regex, changelogContentObj)
			lastVer := changelogContentObj.0
		} else
			lastVer := changelogContent
	}

	OutputDebug, GetLastVer() = %lastVer%
	Return lastVer
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
	ans:=WebRequest.ResponseText
	OutputDebug UrlDownloadToVar() HTTPStatusCode = %HTTPStatusCode% 
	return ans
}
GetNameNoExt(FileName) {
	SplitPath FileName,,, Extension, NameNoExt
	Return NameNoExt
}

/*
AutoUpdate(FILE, mode:=0, updateIntervalDays:="", CHANGELOG:="", WhereCurrVer:="", backupNumber:=1) {

FILE: url last version of .ahk file

mode:
	manually																	1
	if auto, don't check updated							2
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

WhereCurrVer:
	3 места хранения: .ahk, .ini, regestry
		1)ini
			""        IniRead currVer, %A_ScriptNameNoExt%.ini, update, current version, 0
			"xxx"     IniRead currVer, xxx.ini, update, current version, 0
		2)inside
			"inside:"				currVer := regex("Oi)^;\s*(?:version|ver)?\s*=?\s*(\d+(?:\.\d+)?)", A_Script)
			"inside:xxx"    currVer := regex(xxx, A_Script)
		3)regestry
			"regestry:"				RegRead, currVer, HKEY_CURRENT_USER, SOFTWARE\%A_ScriptNameNoExt%\CurrentVersion, Version
			"regestry:xxx"		RegRead, currVer, HKEY_CURRENT_USER, SOFTWARE\%xxx%, Version

	2 опциональных значения для хранения: currVers (если не указана, скрипт при проверке скачивается полностью и сравнивается с текущим), lastCheckDate (если не указана, проверка происходит при каждом вызове ф-ии AutoUpdate())

backupNumber:

