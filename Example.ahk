updateIntervalDays := 0
FILE := "https://raw.githubusercontent.com/stealzy/AutoUpdate/master/Example.ahk"
CHANGELOG_URL := "https://raw.githubusercontent.com/stealzy/AutoUpdate/master/CHANGELOG.md"
VERSION_FORMAT := "(?<=Version )(\d+(?:\.\d+)?)"
CHANGELOG := CHANGELOG_URL " " VERSION_FORMAT

AutoUpdate(FILE,, updateIntervalDays, CHANGELOG)
Return
#Include AutoUpdate.ahk