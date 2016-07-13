#Include AutoUpdate.ahk

updateIntervalDays := 0
FILE := "https://raw.githubusercontent.com/stealzy/AutoUpdate/master/ExampleSilentAutoUpdate.ahk"
CHANGELOG_URL := "https://raw.githubusercontent.com/stealzy/AutoUpdate/master/CHANGELOG.md"
VERSION_REGEX := "(?<=Version )(\d+(?:\.\d+)?)"
CHANGELOG := CHANGELOG_URL " " VERSION_REGEX

AutoUpdate(FILE,, updateIntervalDays, CHANGELOG)