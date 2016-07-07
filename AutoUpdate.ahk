; SetWorkingDir %A_ScriptDir%
; WhereCurrVer - ":%regex%" - write in same file, "%inifilename%" - write in ini file in section - update, key - current version
AutoUpdate(FILE, mode:=0, updateIntervalDays:=7, CHANGELOG:="", WhereCurrVer:="", backupNumber:=1) {
	OutputDebug AutoUpdate()
	if NeedToCheckUpdate(mode, updateIntervalDays) {
		currVer := GetCurrentVer(WhereCurrVer)
		lastVer := GetLastVer(CHANGELOG)
		if NewVerAvailable(mode, CHANGELOG, WhereCurrVer, currVer, lastVer)
			Update(FILE, mode, backupNumber, currVer, lastVer)
	}
}
NeedToCheckUpdate(mode, updateIntervalDays) {
	OutputDebug NeedToCheckUpdate()
	if ((NoAuto := mode & 2) And Not (Manually := mode & 1)) {
		OutputDebug NeedToCheckUpdate False
		Return False
	}
	if (A_Now > GetTimeToUpdate(updateIntervalDays)) || (manually := mode & 1) {
		OutputDebug NeedToCheckUpdate True
		Return True
	}
}
NewVerAvailable(mode, CHANGELOG, WhereCurrVer, currVer, lastVer) {
	WriteLastCheckTime(WhereCurrVer)
	if ((lastVer > currVer) || !CHANGELOG || !currVer)
		Return True
}
Update(FILE, mode, backupNumber, currVer, lastVer) {
	askBefore := (mode & 16)
	if (!askBefore) {
		Err := DownloadAndReplace(FILE, backupNumber, lastVer, WhereCurrVer)
		OutputDebug % Err
		if ((Err != "") && (Err != "No access to the Internet"))
			MsgBox 48,, %Err%, 5
	} else {
		MsgBox, 36, %A_ScriptName% %currVer%, New version %lastVer% available.`nDownload it now? ; [Y] [Later] [Don't check update] ; ToolTip - Later by def
		IfMsgBox Yes
		{
			if (Err := DownloadAndReplace(FILE, backupNumber, lastVer, WhereCurrVer))
				MsgBox 48,, %Err%, 5
			else {
				MsgBox, 36, %A_ScriptName%, Script updated.`nRestart it now? ; ToolTip Script updated.`nClick to restart script right now.
				IfMsgBox Yes
				{
					Reload ; no CL parameters!
				}
			}
		}
	}
}

DownloadAndReplace(FILE, backupNumber, lastVer, WhereCurrVer) {
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
		; FileAppend, % currFile, currFile.txt
		; FileAppend, % lastFile, lastFile.txt
		FileMove %A_ScriptFullPath%, %A_ScriptFullPath%._v%currVer%.backup
		if ErrorLevel
			Return "Error access to " A_ScriptFullPath " : " ErrorLevel
		FileAppend lastFile, %A_ScriptFullPath%
		if ErrorLevel
			Return "Error create new " A_ScriptFullPath " : " ErrorLevel
	}
	WriteCurrentVersion(lastVer, WhereCurrVer)
	OutputDebug -Update-
}

GetTimeToUpdate(updateIntervalDays) {
	timeToUpdate := ReadLastCheckTime()
	timeToUpdate += %updateIntervalDays%, days
	OutputDebug GetTimeToUpdate=%timeToUpdate%
	Return timeToUpdate
}
ReadLastCheckTime(iniFile:="") {
	iniFile := iniFile ? iniFile : GetNameNoExt(A_ScriptName) . ".ini"
	IniRead lastCheckTime, %iniFile%, update, last check, 0
	OutputDebug ReadLastCheckTime=%lastCheckTime%
	Return lastCheckTime
}
WriteLastCheckTime(iniFile:="") {
	iniFile := iniFile ? iniFile : GetNameNoExt(A_ScriptName) . ".ini"
	IniWrite, %A_Now%, %iniFile%, update, last check
	OutputDebug WriteLastCheckTime
}
WriteCurrentVersion(lastVer, iniFile:="") {
	iniFile := iniFile ? iniFile : GetNameNoExt(A_ScriptName) . ".ini"
	IniWrite %lastVer%, %iniName%, update, current version
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

	if regexMode {
		RegExMatch(changelogContent, Regex, changelogContentObj)
		lastVer := changelogContentObj.0
	} else
		lastVer := changelogContent

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

FILE: url last version of file

mode: 
1 - manually / auto
10 - if auto: on / off
100 - if exist upd: ask before download upd && show changelog / download auto
1000 - after download: ask before restart / restart auto / norestart

updateIntervalDays:

CHANGELOG:
1)"url"
2)"url regex"

WhereCurrVer:
1)ini
	""         IniRead currVer, %A_ScriptNameNoExt%.ini, update, current version, 0
	"xxx"      IniRead currVer, xxx.ini, update, current version, 0
2)inside
	":"				 currVer := regex("Oi)^;\s*(?:version|ver)?\s*=?\s*(\d+(?:\.\d+)?)", A_Script)
	":xxx"     currVer := regex(xxx, A_Script)

backupNumber:
}

Если найти метод загружать только первые N байт файла, то можно писать версию в начале файла и отказаться от
1) записи тек. версии в .ini файл
2) желательности файла changelog.md на сервере для сокращения траффика проверки.

TimeFormat in values: checkTime & updateInterval

Можно хранить дату последней проверки во времени изменения файла и полностью отказаться от .ini
Опции Проверка обновлений и Подтверждение обновления станут неизменяемыми. На крайний случай, перезапись тела скрипта.

Modes:
1) Silent check new version available, if exist such, AutoUpdate
2) Silent check new version available, if exist such, show (ToolTip/MsgBox) asking whether you want to update
3) Manual check new version available, if exist such, show (ToolTip/MsgBox) asking whether you want to update
• (ToolTip/MsgBox) asking whether you want to reload straight away
• check new version available, using CHANGELOG file. (You need uploade the CHANGELOG file with last version to a website)
Or all file downloaded.

write time of last check to (.ini | modify date of script)
If %last check time% was within a %updateInterval%, Update not start.
