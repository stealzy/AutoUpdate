; checkTime, updateInterval, iniFile, dontUseChangeLog, AuUpDefEn, 
checkTime := ((A_YYYY-2015)*365 + A_YDay)*24 + A_Hour ; if you change time format, also clear value in .ini
updateInterval := 1
iniFile := A_ScriptName ".ini"
LAST_FILE_URL:="https://raw.githubusercontent.com/stealzy/AutoUpdate/master/AutoUpdate.ahk"

UpdateLib(LAST_FILE_URL,, checkTime, updateInterval, iniFile)
Return
;------------------------------------------------------------------------------
UpdateLib(LAST_FILE_URL, manually:="", checkTime:="", updateInterval:="", iniFile:="") {
	IniRead lastCheckTime, %iniFile%, update, Last checked time, 0
	if (checkTime - lastCheckTime > updateInterval) || manually
		CompareVerAndAction(LAST_FILE_URL, checkTime, iniFile)
}
CompareVerAndAction(LAST_FILE_URL, checkTime, iniFile) {
	CHANGELOG_URL:="https://raw.githubusercontent.com/stealzy/AutoUpdate/master/CHANGELOG.md"
	VERSION_FORMAT:="Oi)(?<=\nVersion )\d+(\.\d+)?"
	currVer := GetCurrentVer(iniFile)
	lastVer := GetLastVer(CHANGELOG_URL, VERSION_FORMAT)
	if (lastVer > currVer) {
		IniRead OnlyCheckNewVersion, %iniFile%, update, OnlyCheckNewVersion Enable, false
		if OnlyCheckNewVersion {
			if ((Err := Update(LAST_FILE_URL, iniFile, lastVer)) && (Err != "No access to the Internet"))
				MsgBox 48,, %Err%, 5
		} else {
			MsgBox, 36, %A_ScriptName% ver%currVer%, New version %lastVer% available.`nDownload it now? ; [Y] [Later] [Don't check update] ; ToolTip - Later by def
			IfMsgBox Yes
			{
				if (Err := Update(LAST_FILE_URL, iniFile, lastVer))
					MsgBox 48,, %Err%, 5
				else {
					MsgBox, 36, %A_ScriptName%, Script updated.`nRestart it now? ; ToolTip Script updated.`nClick to restart script right now.
					IfMsgBox Yes
						Reload ; no CL parameters!
				}
			}
		}
	}
	IniWrite, %CheckTime%, %iniFile%, update, Last Checked
}
Update(LAST_FILE_URL, iniFile, lastVer) {
	currFile := FileOpen(A_ScriptFullPath, "r").Read()
	if A_LastError
		Return "FileOpen Error: " A_LastError
	lastFile := UrlDownloadToVar(LAST_FILE_URL)
	if ErrorLevel
		Return ErrorLevel

	if (currFile = lastFile) {
		IniWrite lastVer, %iniFile%, update, Current Version
		Return "Last version the same file"
	} else {
		FileMove %A_ScriptFullPath%, %A_ScriptFullPath%._v%currVer%.backup
		if ErrorLevel
			Return "Error access to " A_ScriptFullPath " : " ErrorLevel
		FileAppend lastFile, %A_ScriptFullPath%
		if ErrorLevel
			Return "Error create new " A_ScriptFullPath " : " ErrorLevel
		IniWrite lastVer, %iniFile%, update, Current Version
	}
}

GetCurrentVer(method:="", param:="") {
	if (method="ini") {
		if (param="")
			param := A_ScriptName ".ini"
		IniRead currVer, %param%, update, Current Version, 0
	} else if (method="inside") {
		if (param="")
			param := "Oi)(?<=; Version = )\d+(\.\d+)?"
		If A_IsCompiled {
			FileGetVersion, currVer, %A_ScriptFullPath%
		} else {
			FileRead, text, %A_ScriptFullPath%
			RegExMatch(text, param, currVer)
			currVer := currVer.Value(0)
		}
	}
	Return currVer
}
GetLastVer(CHANGELOG_URL, VERSION_FORMAT) {
	text := UrlDownloadToVar(CHANGELOG_URL)

	RegExMatch(text, VERSION_FORMAT, lastVerObj)
	lastVer := lastVerObj.0
	Return lastVer
}
UrlDownloadToVar(URL) {
	; if Error return false, put explanation in ErrorLevel
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
	return WebRequest.ResponseText
}

; Если найти метод загружать только первые N байт файла, то можно писать версию в начале файла и отказаться от
; 1) записи тек. версии в .ini файл
; 2) желательности файла changelog.md на сервере для сокращения траффика проверки.

; TimeFormat in values: checkTime & updateInterval

; Можно хранить дату последней проверки во времени изменения файла и полностью отказаться от .ini
; Опции Проверка обновлений и Подтверждение обновления станут неизменяемыми. Накрайняк, перезапись тела скрипта.

; Modes:
; 1) Silent check new version available, if exist such, AutoUpdate
; 2) Silent check new version available, if exist such, show (ToolTip/MsgBox) asking whether you want to update
; 3) Manual check new version available, if exist such, show (ToolTip/MsgBox) asking whether you want to update
; • (ToolTip/MsgBox) asking whether you want to reload straight away
; • check new version available, using CHANGELOG file. (You need uploade the CHANGELOG file with last version to a website)
; Or all file downloaded.

; If run not manually, it write time of last check to (.ini | modify date of script)
; If %last check time% was within a %updateInterval%, Update not start.
