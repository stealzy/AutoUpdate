#SingleInstance force
#Include AutoUpdate.ahk

FILE := "https://raw.githubusercontent.com/stealzy/AutoUpdate/master/ExampleManualUpdate.ahk"
mode := 1
CHANGELOG_URL := "https://raw.githubusercontent.com/stealzy/AutoUpdate/master/CHANGELOG.md"
VERSION_REGEX := "Oi)(?<=Version )(\d+(?:\.\d+)?)"

AutoUpdate(FILE, mode,, [CHANGELOG_URL, VERSION_REGEX])