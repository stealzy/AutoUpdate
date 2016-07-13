#Include AutoUpdate.ahk

FILE := "https://raw.githubusercontent.com/stealzy/AutoUpdate/master/ExampleManualUpdate.ahk"
mode := 1
CHANGELOG_URL := "https://raw.githubusercontent.com/stealzy/AutoUpdate/master/CHANGELOG.md"
VERSION_REGEX := "(?<=Version )(\d+(?:\.\d+)?)"
CHANGELOG := CHANGELOG_URL " " VERSION_REGEX

AutoUpdate(FILE, mode,, CHANGELOG)